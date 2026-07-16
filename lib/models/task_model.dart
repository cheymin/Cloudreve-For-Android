enum TaskStatus { waiting, running, paused, completed, failed }

extension TaskStatusX on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.waiting:
        return '等待中';
      case TaskStatus.running:
        return '进行中';
      case TaskStatus.paused:
        return '已暂停';
      case TaskStatus.completed:
        return '已完成';
      case TaskStatus.failed:
        return '失败';
    }
  }
}

class DownloadTask {
  final String id;
  final String name;
  final String uri;
  String path;
  final int size;
  double progress;
  TaskStatus status;
  double speed;
  int bytesTransferred;
  String? errorMessage;
  DateTime createdAt;
  DateTime? updatedAt;
  String? url;

  DownloadTask({
    required this.id,
    required this.name,
    required this.uri,
    this.path = '',
    this.size = 0,
    this.progress = 0.0,
    this.status = TaskStatus.waiting,
    this.speed = 0.0,
    this.bytesTransferred = 0,
    this.errorMessage,
    DateTime? createdAt,
    this.updatedAt,
    this.url,
  }) : createdAt = createdAt ?? DateTime.now();

  String get displaySize => _formatSize(size);

  String get displayTransferred => _formatSize(bytesTransferred);

  String get displaySpeed {
    if (speed <= 0) return '0 B/s';
    return '${_formatSize(speed.toInt())}/s';
  }

  String get progressPercent => '${(progress * 100).toStringAsFixed(1)}%';

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  DownloadTask copyWith({
    String? id,
    String? name,
    String? uri,
    String? path,
    int? size,
    double? progress,
    TaskStatus? status,
    double? speed,
    int? bytesTransferred,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? url,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      name: name ?? this.name,
      uri: uri ?? this.uri,
      path: path ?? this.path,
      size: size ?? this.size,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      speed: speed ?? this.speed,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      url: url ?? this.url,
    );
  }
}

class UploadTask {
  final String id;
  final String name;
  final String localPath;
  final String remotePath;
  final int size;
  double progress;
  TaskStatus status;
  double speed;
  int bytesTransferred;
  String? errorMessage;
  DateTime createdAt;
  DateTime? updatedAt;
  String? uploadId;
  int chunkSize;
  int totalChunks;
  int uploadedChunks;

  UploadTask({
    required this.id,
    required this.name,
    required this.localPath,
    required this.remotePath,
    this.size = 0,
    this.progress = 0.0,
    this.status = TaskStatus.waiting,
    this.speed = 0.0,
    this.bytesTransferred = 0,
    this.errorMessage,
    DateTime? createdAt,
    this.updatedAt,
    this.uploadId,
    this.chunkSize = 5 * 1024 * 1024,
    this.totalChunks = 0,
    this.uploadedChunks = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  String get displaySize => _formatSize(size);

  String get displayTransferred => _formatSize(bytesTransferred);

  String get displaySpeed {
    if (speed <= 0) return '0 B/s';
    return '${_formatSize(speed.toInt())}/s';
  }

  String get progressPercent => '${(progress * 100).toStringAsFixed(1)}%';

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  UploadTask copyWith({
    String? id,
    String? name,
    String? localPath,
    String? remotePath,
    int? size,
    double? progress,
    TaskStatus? status,
    double? speed,
    int? bytesTransferred,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? uploadId,
    int? chunkSize,
    int? totalChunks,
    int? uploadedChunks,
  }) {
    return UploadTask(
      id: id ?? this.id,
      name: name ?? this.name,
      localPath: localPath ?? this.localPath,
      remotePath: remotePath ?? this.remotePath,
      size: size ?? this.size,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      speed: speed ?? this.speed,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      uploadId: uploadId ?? this.uploadId,
      chunkSize: chunkSize ?? this.chunkSize,
      totalChunks: totalChunks ?? this.totalChunks,
      uploadedChunks: uploadedChunks ?? this.uploadedChunks,
    );
  }
}
