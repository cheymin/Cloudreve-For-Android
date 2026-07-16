class FileItem {
  final String uri;
  final String name;
  final bool isDir;
  final int? size;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? thumbnail;
  final String? path;

  FileItem({
    required this.uri,
    required this.name,
    required this.isDir,
    this.size,
    this.createdAt,
    this.updatedAt,
    this.thumbnail,
    this.path,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      uri: json['uri'] ?? json['path'] ?? '',
      name: json['name'] ?? '',
      isDir: json['type'] == 'dir' || json['is_dir'] == true,
      size: json['size'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      thumbnail: json['thumbnail'],
      path: json['path'],
    );
  }

  String get displaySize {
    if (size == null) return '';
    final s = size!;
    if (s < 1024) return '$s B';
    if (s < 1024 * 1024) return '${(s / 1024).toStringAsFixed(1)} KB';
    if (s < 1024 * 1024 * 1024) return '${(s / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(s / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get extension {
    if (isDir) return '';
    final idx = name.lastIndexOf('.');
    if (idx == -1 || idx == name.length - 1) return '';
    return name.substring(idx + 1).toLowerCase();
  }

  bool get isImage {
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].contains(extension);
  }

  bool get isVideo {
    return ['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv'].contains(extension);
  }

  bool get isAudio {
    return ['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'].contains(extension);
  }
}
