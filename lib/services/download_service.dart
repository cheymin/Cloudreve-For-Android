import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../models/task_model.dart';
import 'api_service.dart';

class DownloadService extends ChangeNotifier {
  final CloudreveApi api;
  final List<DownloadTask> _tasks = [];
  final int _maxConcurrent = 3;
  final Map<String, http.StreamedResponse> _activeResponses = {};
  final Map<String, bool> _pauseFlags = {};
  final Map<String, bool> _cancelFlags = {};
  bool _initialized = false;
  String? _downloadDir;

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  List<DownloadTask> get runningTasks =>
      _tasks.where((t) => t.status == TaskStatus.running).toList();

  List<DownloadTask> get waitingTasks =>
      _tasks.where((t) => t.status == TaskStatus.waiting).toList();

  DownloadService(this.api);

  Future<void> init() async {
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    _downloadDir = path.join(dir.path, 'Downloads');
    final downloadDir = Directory(_downloadDir!);
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    _initialized = true;
  }

  String? get downloadDir => _downloadDir;

  Future<DownloadTask> addDownload(String uri, String name, {int size = 0}) async {
    await init();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final task = DownloadTask(
      id: id,
      name: name,
      uri: uri,
      size: size,
      path: path.join(_downloadDir!, name),
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
      _startDownload(waiting[i]);
    }
  }

  Future<void> _startDownload(DownloadTask task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) return;

    _tasks[index] = task.copyWith(status: TaskStatus.running);
    notifyListeners();

    try {
      final url = await api.getDownloadUrl(task.uri);
      if (url.isEmpty) {
        throw Exception('获取下载链接失败');
      }

      final filePath = path.join(_downloadDir!, task.name);
      final file = File(filePath);
      int existingBytes = 0;

      if (await file.exists()) {
        existingBytes = await file.length();
      }

      final uri = Uri.parse(url);
      final request = http.Request('GET', uri);

      if (existingBytes > 0) {
        request.headers['Range'] = 'bytes=$existingBytes-';
      }

      final response = await request.send();
      _activeResponses[task.id] = response;

      if (response.statusCode == 200 || response.statusCode == 206) {
        final totalBytes = response.contentLength ?? task.size;
        if (response.statusCode == 200) {
          existingBytes = 0;
        }

        _tasks[index] = _tasks[index].copyWith(
          size: totalBytes + existingBytes,
          bytesTransferred: existingBytes,
          progress: totalBytes > 0 ? existingBytes / (totalBytes + existingBytes) : 0,
          url: url,
          path: filePath,
        );
        notifyListeners();

        final sink = await file.openWrite(
          mode: existingBytes > 0 ? FileMode.append : FileMode.write,
        );

        int bytesReceived = existingBytes;
        int lastBytes = existingBytes;
        DateTime lastTime = DateTime.now();
        final completer = Completer<void>();

        late StreamSubscription<List<int>> subscription;
        subscription = response.stream.listen(
          (chunk) {
            if (_cancelFlags[task.id] == true) {
              subscription.cancel();
              sink.close();
              _activeResponses.remove(task.id);
              _cancelFlags.remove(task.id);
              _pauseFlags.remove(task.id);
              file.delete();
              _tasks[index] = _tasks[index].copyWith(
                status: TaskStatus.failed,
                errorMessage: '已取消',
              );
              notifyListeners();
              _processQueue();
              completer.complete();
              return;
            }

            if (_pauseFlags[task.id] == true) {
              subscription.pause();
              sink.flush();
              _activeResponses.remove(task.id);
              _tasks[index] = _tasks[index].copyWith(
                status: TaskStatus.paused,
              );
              notifyListeners();
              _processQueue();
              completer.complete();
              return;
            }

            sink.add(chunk);
            bytesReceived += chunk.length;

            final now = DateTime.now();
            final elapsed = now.difference(lastTime).inMilliseconds;
            if (elapsed >= 500 || bytesReceived == totalBytes + existingBytes) {
              final delta = bytesReceived - lastBytes;
              final speed = elapsed > 0 ? (delta / elapsed) * 1000 : 0.0;
              final total = totalBytes + existingBytes;
              _tasks[index] = _tasks[index].copyWith(
                bytesTransferred: bytesReceived,
                progress: total > 0 ? bytesReceived / total : 0,
                speed: speed,
                updatedAt: now,
              );
              notifyListeners();
              lastBytes = bytesReceived;
              lastTime = now;
            }
          },
          onDone: () async {
            await sink.close();
            _activeResponses.remove(task.id);
            _pauseFlags.remove(task.id);
            _cancelFlags.remove(task.id);

            if (_tasks[index].status == TaskStatus.running) {
              _tasks[index] = _tasks[index].copyWith(
                status: TaskStatus.completed,
                progress: 1.0,
                speed: 0,
                updatedAt: DateTime.now(),
              );
              notifyListeners();
            }
            _processQueue();
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
          onError: (error) async {
            await sink.close();
            _activeResponses.remove(task.id);
            _pauseFlags.remove(task.id);
            _cancelFlags.remove(task.id);
            _tasks[index] = _tasks[index].copyWith(
              status: TaskStatus.failed,
              errorMessage: error.toString(),
              speed: 0,
              updatedAt: DateTime.now(),
            );
            notifyListeners();
            _processQueue();
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          },
          cancelOnError: true,
        );

        await completer.future;
      } else {
        _activeResponses.remove(task.id);
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      _activeResponses.remove(task.id);
      _pauseFlags.remove(task.id);
      _cancelFlags.remove(task.id);
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

  Future<void> openFile(DownloadTask task) async {
    if (task.status != TaskStatus.completed) return;
    if (task.path.isEmpty) return;
    final file = File(task.path);
    if (!await file.exists()) return;
    await OpenFile.open(task.path);
  }

  DownloadTask? getTask(String id) {
    try {
      return _tasks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}
