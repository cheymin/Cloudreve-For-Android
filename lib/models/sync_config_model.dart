import 'dart:convert';

enum SyncMode {
  uploadOnly,
  downloadOnly,
  bidirectional,
}

extension SyncModeExtension on SyncMode {
  String get displayName {
    switch (this) {
      case SyncMode.uploadOnly:
        return '仅上传';
      case SyncMode.downloadOnly:
        return '仅下载';
      case SyncMode.bidirectional:
        return '双向同步';
    }
  }

  String get value {
    switch (this) {
      case SyncMode.uploadOnly:
        return 'upload_only';
      case SyncMode.downloadOnly:
        return 'download_only';
      case SyncMode.bidirectional:
        return 'bidirectional';
    }
  }

  static SyncMode fromValue(String value) {
    switch (value) {
      case 'upload_only':
        return SyncMode.uploadOnly;
      case 'download_only':
        return SyncMode.downloadOnly;
      case 'bidirectional':
      default:
        return SyncMode.bidirectional;
    }
  }
}

enum SyncStatus {
  idle,
  syncing,
  success,
  failed,
}

extension SyncStatusExtension on SyncStatus {
  String get displayName {
    switch (this) {
      case SyncStatus.idle:
        return '空闲';
      case SyncStatus.syncing:
        return '同步中';
      case SyncStatus.success:
        return '成功';
      case SyncStatus.failed:
        return '失败';
    }
  }
}

class SyncConfig {
  final String id;
  String name;
  String localPath;
  String remoteUri;
  SyncMode syncMode;
  DateTime? lastSyncTime;
  bool isEnabled;
  List<String> includePatterns;
  List<String> excludePatterns;
  int syncIntervalMinutes;
  SyncStatus status;
  String? lastError;
  int totalFiles;
  int syncedFiles;
  String? currentFile;

  SyncConfig({
    required this.id,
    required this.name,
    required this.localPath,
    required this.remoteUri,
    this.syncMode = SyncMode.bidirectional,
    this.lastSyncTime,
    this.isEnabled = true,
    this.includePatterns = const [],
    this.excludePatterns = const [],
    this.syncIntervalMinutes = 0,
    this.status = SyncStatus.idle,
    this.lastError,
    this.totalFiles = 0,
    this.syncedFiles = 0,
    this.currentFile,
  });

  factory SyncConfig.fromJson(Map<String, dynamic> json) {
    return SyncConfig(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      localPath: json['localPath'] as String? ?? '',
      remoteUri: json['remoteUri'] as String? ?? '/',
      syncMode: SyncModeExtension.fromValue(json['syncMode'] as String? ?? 'bidirectional'),
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.tryParse(json['lastSyncTime'] as String)
          : null,
      isEnabled: json['isEnabled'] as bool? ?? true,
      includePatterns: (json['includePatterns'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      excludePatterns: (json['excludePatterns'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      syncIntervalMinutes: json['syncIntervalMinutes'] as int? ?? 0,
      status: SyncStatus.values[json['status'] as int? ?? 0],
      lastError: json['lastError'] as String?,
      totalFiles: json['totalFiles'] as int? ?? 0,
      syncedFiles: json['syncedFiles'] as int? ?? 0,
      currentFile: json['currentFile'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'localPath': localPath,
      'remoteUri': remoteUri,
      'syncMode': syncMode.value,
      'lastSyncTime': lastSyncTime?.toIso8601String(),
      'isEnabled': isEnabled,
      'includePatterns': includePatterns,
      'excludePatterns': excludePatterns,
      'syncIntervalMinutes': syncIntervalMinutes,
      'status': status.index,
      'lastError': lastError,
      'totalFiles': totalFiles,
      'syncedFiles': syncedFiles,
      'currentFile': currentFile,
    };
  }

  static String listToJson(List<SyncConfig> configs) {
    return jsonEncode(configs.map((e) => e.toJson()).toList());
  }

  static List<SyncConfig> listFromJson(String jsonStr) {
    final List<dynamic> list = jsonDecode(jsonStr);
    return list.map((e) => SyncConfig.fromJson(e as Map<String, dynamic>)).toList();
  }

  SyncConfig copyWith({
    String? id,
    String? name,
    String? localPath,
    String? remoteUri,
    SyncMode? syncMode,
    DateTime? lastSyncTime,
    bool? isEnabled,
    List<String>? includePatterns,
    List<String>? excludePatterns,
    int? syncIntervalMinutes,
    SyncStatus? status,
    String? lastError,
    int? totalFiles,
    int? syncedFiles,
    String? currentFile,
  }) {
    return SyncConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      localPath: localPath ?? this.localPath,
      remoteUri: remoteUri ?? this.remoteUri,
      syncMode: syncMode ?? this.syncMode,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isEnabled: isEnabled ?? this.isEnabled,
      includePatterns: includePatterns ?? this.includePatterns,
      excludePatterns: excludePatterns ?? this.excludePatterns,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
      totalFiles: totalFiles ?? this.totalFiles,
      syncedFiles: syncedFiles ?? this.syncedFiles,
      currentFile: currentFile ?? this.currentFile,
    );
  }
}
