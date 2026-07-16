import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/task_model.dart';
import 'api_service.dart';

class UploadService extends ChangeNotifier {
  final CloudreveApi api;
  final List<UploadTask> _tasks = [];
  final int _maxConcurrent = 3;
  final Map<String, bool> _cancelFlags = {};
  final Map<String, bool> _pauseFlags = {};
  final _uuid = const Uuid();

  List<UploadTask> get tasks => List.unmodifiable(_tasks);

  List<UploadTask> get runningTasks =>
      _tasks.where((t) => t.status == TaskStatus.running).toList();

  List<UploadTask> get waitingTasks =>
      _tasks.where((t) => t.status == TaskStatus.waiting).toList();

  UploadService(this.api);

  Future<List<UploadTask>> pickAndUpload(String remotePath) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      withReadStream: false,
    );

    if (result == null || result.files.isEmpty) return [];

    final uploaded = <UploadTask>[];
    for (final file in result.files) {
      if (file.path != null) {
        final task = await addUpload(file.path!, file.name, remotePath, file.size);
        uploaded.add(task);
      }
    }
    return uploaded;
  }

  Future<UploadTask> addUpload(
      String localPath, String fileName, String remotePath, int size) async {
    final id = _uuid.v4();
    final chunkSize = 5 * 1024 * 1024;
    final totalChunks = (size / chunkSize).ceil();

    final task = UploadTask(
      id: id,
      name: fileName,
      localPath: localPath,
      remotePath: remotePath,
      size: size,
      chunkSize: chunkSize,
      totalChunks: totalChunks,
    );

    _tasks.insert(0, task);
    notifyListeners();
    _processQueue();
    return task;
  }

  void _processQueue() {
    final running = runningTasks.length;
    final available = _maxConcurrent - running;
    if (available <= 0) return;

    final waiting = waitingTasks;
    for (int i = 0; i < available && i < waiting.length; i++) {
      _startUpload(waiting[i]);
    }
  }

  Future<void> _startUpload(UploadTask task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) return;

    _tasks[index] = task.copyWith(status: TaskStatus.running);
    notifyListeners();

    try {
      final file = File(task.localPath);
      if (!await file.exists()) {
        throw Exception('本地文件不存在');
      }

      final fileSize = await file.length();
      if (fileSize != task.size) {
        _tasks[index] = _tasks[index].copyWith(size: fileSize);
      }

      final session = await api.createUploadSession(
        task.remotePath,
        task.name,
        fileSize,
      );

      final uploadUrl = session['upload_url'] ?? session['url'] ?? '';
      final uploadId = session['upload_id']?.toString();

      if (uploadUrl.isEmpty) {
        throw Exception('获取上传地址失败');
      }

      _tasks[index] = _tasks[index].copyWith(
        uploadId: uploadId,
        size: fileSize,
        totalChunks: (fileSize / task.chunkSize).ceil(),
      );
      notifyListeners();

      final chunkSize = task.chunkSize;
      final totalChunks = (fileSize / chunkSize).ceil();

      int uploadedChunks = 0;
      int bytesUploaded = 0;
      int lastBytes = 0;
      DateTime lastTime = DateTime.now();

      for (int i = 0; i < totalChunks; i++) {
        if (_cancelFlags[task.id] == true) {
          _cancelFlags.remove(task.id);
          _pauseFlags.remove(task.id);
          _tasks[index] = _tasks[index].copyWith(
            status: TaskStatus.failed,
            errorMessage: '已取消',
            speed: 0,
          );
          notifyListeners();
          _processQueue();
          return;
        }

        if (_pauseFlags[task.id] == true) {
          _pauseFlags.remove(task.id);
          _tasks[index] = _tasks[index].copyWith(
            status: TaskStatus.paused,
            speed: 0,
            uploadedChunks: uploadedChunks,
            bytesTransferred: bytesUploaded,
            progress: fileSize > 0 ? bytesUploaded / fileSize : 0,
          );
          notifyListeners();
          _processQueue();
          return;
        }

        final start = i * chunkSize;
        final end = (i + 1) * chunkSize < fileSize ? (i + 1) * chunkSize : fileSize;
        final length = end - start;

        final chunk = await _readChunk(file, start, length);
        await _uploadChunk(uploadUrl, chunk, i, totalChunks, task, start, end, fileSize);

        uploadedChunks++;
        bytesUploaded += length;

        final now = DateTime.now();
        final elapsed = now.difference(lastTime).inMilliseconds;
        if (elapsed >= 500 || uploadedChunks == totalChunks) {
          final delta = bytesUploaded - lastBytes;
          final speed = elapsed > 0 ? (delta / elapsed) * 1000 : 0.0;
          _tasks[index] = _tasks[index].copyWith(
            bytesTransferred: bytesUploaded,
            progress: fileSize > 0 ? bytesUploaded / fileSize : 0,
            speed: speed,
            uploadedChunks: uploadedChunks,
            updatedAt: now,
          );
          notifyListeners();
          lastBytes = bytesUploaded;
          lastTime = now;
        }
      }

      _tasks[index] = _tasks[index].copyWith(
        status: TaskStatus.completed,
        progress: 1.0,
        speed: 0,
        uploadedChunks: totalChunks,
        bytesTransferred: fileSize,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      _processQueue();
    } catch (e) {
      _cancelFlags.remove(task.id);
      _pauseFlags.remove(task.id);
      final idx = _tasks.indexWhere((t) => t.id == task.id);
      if (idx != -1) {
        _tasks[idx] = _tasks[idx].copyWith(
          status: TaskStatus.failed,
          errorMessage: e.toString(),
          speed: 0,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
      _processQueue();
    }
  }

  Future<List<int>> _readChunk(File file, int start, int length) async {
    final raf = await file.open();
    try {
      await raf.setPosition(start);
      return await raf.read(length);
    } finally {
      await raf.close();
    }
  }

  Future<void> _uploadChunk(
    String uploadUrl,
    List<int> chunk,
    int chunkIndex,
    int totalChunks,
    UploadTask task,
    int start,
    int end,
    int totalSize,
  ) async {
    final uri = Uri.parse(uploadUrl);
    final request = http.Request('PUT', uri);
    request.bodyBytes = chunk;
    request.headers['Content-Type'] = 'application/octet-stream';
    request.headers['Content-Range'] = 'bytes $start-${end - 1}/$totalSize';

    if (totalChunks > 1) {
      request.headers['X-Chunk-Index'] = chunkIndex.toString();
      request.headers['X-Total-Chunks'] = totalChunks.toString();
    }

    final response = await request.send();
    final responseBody = await http.Response.fromStream(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? errorMsg;
      try {
        final data = jsonDecode(responseBody.body);
        errorMsg = data['msg']?.toString() ?? data['message']?.toString();
      } catch (_) {}
      throw Exception(errorMsg ?? '上传失败: HTTP ${response.statusCode}');
    }
  }

  void pauseTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    final task = _tasks[index];
    if (task.status == TaskStatus.running) {
      _pauseFlags[taskId] = true;
    } else if (task.status == TaskStatus.waiting) {
      _tasks[index] = task.copyWith(status: TaskStatus.paused);
      notifyListeners();
    }
  }

  void resumeTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    final task = _tasks[index];
    if (task.status == TaskStatus.paused) {
      _tasks[index] = task.copyWith(status: TaskStatus.waiting);
      notifyListeners();
      _processQueue();
    }
  }

  void cancelTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    final task = _tasks[index];
    if (task.status == TaskStatus.running) {
      _cancelFlags[taskId] = true;
    } else {
      _tasks.removeAt(index);
      notifyListeners();
    }
  }

  void removeTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    final task = _tasks[index];
    if (task.status == TaskStatus.running) {
      cancelTask(taskId);
    }
    _tasks.removeAt(index);
    notifyListeners();
  }

  void retryTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    final task = _tasks[index];
    if (task.status == TaskStatus.failed || task.status == TaskStatus.paused) {
      _tasks[index] = task.copyWith(
        status: TaskStatus.waiting,
        progress: 0,
        bytesTransferred: 0,
        speed: 0,
        errorMessage: null,
        uploadedChunks: 0,
        uploadId: null,
      );
      notifyListeners();
      _processQueue();
    }
  }

  void pauseAll() {
    for (final task in _tasks) {
      if (task.status == TaskStatus.running || task.status == TaskStatus.waiting) {
        pauseTask(task.id);
      }
    }
  }

  void resumeAll() {
    for (final task in _tasks) {
      if (task.status == TaskStatus.paused) {
        resumeTask(task.id);
      }
    }
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.status == TaskStatus.completed || t.status == TaskStatus.failed);
    notifyListeners();
  }

  UploadTask? getTask(String id) {
    try {
      return _tasks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}
