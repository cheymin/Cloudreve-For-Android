import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/sync_config_model.dart';
import '../models/file_item.dart';
import 'api_service.dart';
import 'package:dio/dio.dart';

class SyncService extends ChangeNotifier {
  static const String _storageKey = 'sync_configs';
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  static SyncService get instance => _instance;
  SyncService._internal();

  SharedPreferences? _prefs;
  final List<SyncConfig> _configs = [];
  final Map<String, Timer?> _timers = {};
  CloudreveApi? _api;
  final Dio _dio = Dio();

  List<SyncConfig> get configs => List.unmodifiable(_configs);

  void setApi(CloudreveApi api) {
    _api = api;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await loadConfigs();
    _startAllTimers();
  }

  Future<void> loadConfigs() async {
    if (_prefs == null) return;
    final jsonStr = _prefs!.getString(_storageKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        _configs.clear();
        _configs.addAll(SyncConfig.listFromJson(jsonStr));
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _saveConfigs() async {
    if (_prefs == null) return;
    await _prefs!.setString(
      _storageKey,
      SyncConfig.listToJson(_configs),
    );
  }

  Future<String> getDefaultLocalPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return path.join(dir.path, 'sync');
  }

  SyncConfig? getConfigById(String id) {
    try {
      return _configs.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<SyncConfig> addConfig(SyncConfig config) async {
    final newConfig = SyncConfig(
      id: const Uuid().v4(),
      name: config.name,
      localPath: config.localPath,
      remoteUri: config.remoteUri,
      syncMode: config.syncMode,
      isEnabled: config.isEnabled,
      includePatterns: config.includePatterns,
      excludePatterns: config.excludePatterns,
      syncIntervalMinutes: config.syncIntervalMinutes,
    );
    _configs.add(newConfig);
    await _saveConfigs();
    _startTimer(newConfig.id);
    notifyListeners();
    return newConfig;
  }

  Future<void> updateConfig(SyncConfig config) async {
    final index = _configs.indexWhere((c) => c.id == config.id);
    if (index != -1) {
      _configs[index] = config;
      await _saveConfigs();
      _restartTimer(config.id);
      notifyListeners();
    }
  }

  Future<void> deleteConfig(String id) async {
    _configs.removeWhere((c) => c.id == id);
    await _saveConfigs();
    _stopTimer(id);
    notifyListeners();
  }

  void _startAllTimers() {
    for (final config in _configs) {
      if (config.isEnabled && config.syncIntervalMinutes > 0) {
        _startTimer(config.id);
      }
    }
  }

  void _startTimer(String id) {
    _stopTimer(id);
    final config = getConfigById(id);
    if (config == null || !config.isEnabled || config.syncIntervalMinutes <= 0) return;

    final duration = Duration(minutes: config.syncIntervalMinutes);
    _timers[id] = Timer.periodic(duration, (_) {
      syncConfig(id);
    });
  }

  void _stopTimer(String id) {
    _timers[id]?.cancel();
    _timers.remove(id);
  }

  void _restartTimer(String id) {
    _stopTimer(id);
    _startTimer(id);
  }

  Future<void> syncConfig(String id) async {
    final config = getConfigById(id);
    if (config == null || _api == null) return;
    if (config.status == SyncStatus.syncing) return;

    final index = _configs.indexWhere((c) => c.id == id);
    if (index == -1) return;

    _configs[index] = config.copyWith(
      status: SyncStatus.syncing,
      lastError: null,
      totalFiles: 0,
      syncedFiles: 0,
      currentFile: null,
    );
    notifyListeners();

    try {
      await _performSync(config);
      _configs[index] = _configs[index].copyWith(
        status: SyncStatus.success,
        lastSyncTime: DateTime.now(),
      );
    } catch (e) {
      _configs[index] = _configs[index].copyWith(
        status: SyncStatus.failed,
        lastError: e.toString(),
      );
    }

    await _saveConfigs();
    notifyListeners();
  }

  Future<void> _performSync(SyncConfig config) async {
    if (_api == null) throw Exception('API not initialized');

    final localDir = Directory(config.localPath);
    if (!await localDir.exists()) {
      await localDir.create(recursive: true);
    }

    final remoteFiles = await _fetchAllRemoteFiles(config.remoteUri);
    final localFiles = await _fetchAllLocalFiles(localDir);

    final totalFiles = remoteFiles.length + localFiles.length;
    final index = _configs.indexWhere((c) => c.id == config.id);
    if (index != -1) {
      _configs[index] = _configs[index].copyWith(totalFiles: totalFiles);
      notifyListeners();
    }

    switch (config.syncMode) {
      case SyncMode.downloadOnly:
        await _syncDownloadOnly(config, remoteFiles, localDir);
        break;
      case SyncMode.uploadOnly:
        await _syncUploadOnly(config, localFiles, config.remoteUri);
        break;
      case SyncMode.bidirectional:
        await _syncBidirectional(config, remoteFiles, localFiles, localDir);
        break;
    }
  }

  Future<List<FileItem>> _fetchAllRemoteFiles(String baseUri) async {
    final List<FileItem> allFiles = [];
    await _fetchRemoteFilesRecursive(baseUri, allFiles);
    return allFiles;
  }

  Future<void> _fetchRemoteFilesRecursive(String uri, List<FileItem> allFiles) async {
    if (_api == null) return;
    try {
      final response = await _api!.listFiles(uri);
      for (final item in response.items) {
        allFiles.add(item);
        if (item.isFolder) {
          await _fetchRemoteFilesRecursive(item.uri, allFiles);
        }
      }
    } catch (_) {}
  }

  Future<List<File>> _fetchAllLocalFiles(Directory dir) async {
    final List<File> files = [];
    if (!await dir.exists()) return files;

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        files.add(entity);
      }
    }
    return files;
  }

  bool _shouldSyncFile(String fileName, SyncConfig config) {
    if (config.includePatterns.isNotEmpty) {
      final included = config.includePatterns.any((pattern) {
        return _matchesPattern(fileName, pattern);
      });
      if (!included) return false;
    }

    if (config.excludePatterns.isNotEmpty) {
      final excluded = config.excludePatterns.any((pattern) {
        return _matchesPattern(fileName, pattern);
      });
      if (excluded) return false;
    }

    return true;
  }

  bool _matchesPattern(String fileName, String pattern) {
    if (pattern.contains('*')) {
      final regex = RegExp(
        '^${pattern.replaceAll('.', r'\.').replaceAll('*', '.*')}\$',
        caseSensitive: false,
      );
      return regex.hasMatch(fileName);
    }
    return fileName.toLowerCase() == pattern.toLowerCase();
  }

  Future<void> _syncDownloadOnly(
    SyncConfig config,
    List<FileItem> remoteFiles,
    Directory localDir,
  ) async {
    int synced = 0;
    final index = _configs.indexWhere((c) => c.id == config.id);

    for (final remoteFile in remoteFiles) {
      if (remoteFile.isFolder) continue;
      if (!_shouldSyncFile(remoteFile.name, config)) continue;

      if (index != -1) {
        _configs[index] = _configs[index].copyWith(currentFile: remoteFile.name);
        notifyListeners();
      }

      final relativePath = _getRelativePath(remoteFile.path, config.remoteUri);
      final localFilePath = path.join(localDir.path, relativePath);
      final localFile = File(localFilePath);

      final needsDownload = await _needsDownload(remoteFile, localFile);
      if (needsDownload) {
        await _downloadFile(remoteFile, localFile);
      }

      synced++;
      if (index != -1) {
        _configs[index] = _configs[index].copyWith(syncedFiles: synced);
        notifyListeners();
      }
    }
  }

  Future<void> _syncUploadOnly(
    SyncConfig config,
    List<File> localFiles,
    String remoteBaseUri,
  ) async {
    int synced = 0;
    final index = _configs.indexWhere((c) => c.id == config.id);

    for (final localFile in localFiles) {
      final fileName = path.basename(localFile.path);
      if (!_shouldSyncFile(fileName, config)) continue;

      if (index != -1) {
        _configs[index] = _configs[index].copyWith(currentFile: fileName);
        notifyListeners();
      }

      final relativePath = _getLocalRelativePath(localFile.path, config.localPath);
      final remoteUri = _joinRemotePath(remoteBaseUri, relativePath);

      await _uploadFile(localFile, remoteUri);

      synced++;
      if (index != -1) {
        _configs[index] = _configs[index].copyWith(syncedFiles: synced);
        notifyListeners();
      }
    }
  }

  Future<void> _syncBidirectional(
    SyncConfig config,
    List<FileItem> remoteFiles,
    List<File> localFiles,
    Directory localDir,
  ) async {
    await _syncDownloadOnly(config, remoteFiles, localDir);
    await _syncUploadOnly(config, localFiles, config.remoteUri);
  }

  String _getRelativePath(String fullPath, String basePath) {
    if (fullPath.startsWith(basePath)) {
      return fullPath.substring(basePath.length).replaceAll('\\', '/');
    }
    return fullPath;
  }

  String _getLocalRelativePath(String fullPath, String basePath) {
    final relative = path.relative(fullPath, from: basePath);
    return relative.replaceAll('\\', '/');
  }

  String _joinRemotePath(String base, String relative) {
    final normalizedBase = base.endsWith('/') ? base : '$base/';
    final normalizedRelative = relative.startsWith('/') ? relative.substring(1) : relative;
    return '$normalizedBase$normalizedRelative';
  }

  Future<bool> _needsDownload(FileItem remoteFile, File localFile) async {
    if (!await localFile.exists()) return true;

    final localStat = await localFile.stat();
    if (remoteFile.size != 0 && localStat.size != remoteFile.size) return true;

    if (remoteFile.updatedAt != null) {
      if (localStat.modified.isBefore(remoteFile.updatedAt!)) {
        return true;
      }
    }

    return false;
  }

  Future<void> _downloadFile(FileItem remoteFile, File localFile) async {
    if (_api == null) throw Exception('API not initialized');

    final parentDir = localFile.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    final downloadUrl = await _api!.getDownloadUrl(remoteFile.uri);
    if (downloadUrl.isEmpty) throw Exception('Failed to get download URL');

    final fullUrl = _buildFullUrl(downloadUrl);

    await _dio.download(
      fullUrl,
      localFile.path,
      options: Options(
        headers: {
          if (_api!.accessToken != null) 'Authorization': 'Bearer ${_api!.accessToken}',
        },
      ),
    );
  }

  Future<void> _uploadFile(File localFile, String remoteUri) async {
    if (_api == null) throw Exception('API not initialized');

    final fileName = path.basename(localFile.path);
    final fileSize = await localFile.length();
    final remoteDir = path.dirname(remoteUri).replaceAll('\\', '/');

    final session = await _api!.createUploadSession(remoteDir, fileName, fileSize);
    final uploadUrl = session['url'] as String?;
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw Exception('Failed to create upload session');
    }

    final fullUrl = _buildFullUrl(uploadUrl);

    await _dio.put(
      fullUrl,
      data: localFile.openRead(),
      options: Options(
        headers: {
          if (_api!.accessToken != null) 'Authorization': 'Bearer ${_api!.accessToken}',
          'Content-Length': fileSize.toString(),
          'Content-Type': 'application/octet-stream',
        },
      ),
    );
  }

  String _buildFullUrl(String urlOrPath) {
    if (_api == null) return urlOrPath;
    if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
      return urlOrPath;
    }
    var base = _api!.baseUrl;
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    if (urlOrPath.startsWith('/')) return '$base$urlOrPath';
    return '$base/$urlOrPath';
  }

  @override
  void dispose() {
    for (final timer in _timers.values) {
      timer?.cancel();
    }
    _timers.clear();
    _dio.close();
    super.dispose();
  }
}

class Timer {
  final Duration duration;
  final void Function(Timer) callback;
  DateTime? _nextRun;
  bool _cancelled = false;

  Timer.periodic(this.duration, this.callback) {
    _schedule();
  }

  void _schedule() {
    if (_cancelled) return;
    _nextRun = DateTime.now().add(duration);
    Future.delayed(duration, () {
      if (!_cancelled) {
        callback(this);
        _schedule();
      }
    });
  }

  void cancel() {
    _cancelled = true;
  }

  bool get isActive => !_cancelled;
}
