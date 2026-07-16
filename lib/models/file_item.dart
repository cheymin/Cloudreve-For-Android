import 'package:intl/intl.dart';

class FileItem {
  final int type;
  final String id;
  final String name;
  final String uri;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int size;
  final String path;
  final Map<String, dynamic>? metadata;
  final String? permission;
  final String? primaryEntity;
  final String? capability;

  FileItem({
    required this.type,
    required this.id,
    required this.name,
    required this.uri,
    this.createdAt,
    this.updatedAt,
    this.size = 0,
    required this.path,
    this.metadata,
    this.permission,
    this.primaryEntity,
    this.capability,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    int parseType(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        if (value == 'dir' || value == 'folder') return 1;
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }

    final id = (json['id'] ?? json['uri'] ?? json['path'] ?? json['name'] ?? '').toString();
    final name = (json['name'] ?? json['display_name'] ?? id).toString();
    final uri = (json['uri'] ?? json['path'] ?? '').toString();
    final path = (json['path'] ?? uri).toString();

    return FileItem(
      type: parseType(json['type']),
      id: id,
      name: name,
      uri: uri,
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDate(json['updated_at'] ?? json['updatedAt'] ?? json['created_at']),
      size: (json['size'] as num?)?.toInt() ?? 0,
      path: path,
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      permission: json['permission']?.toString(),
      primaryEntity: json['primary_entity']?.toString(),
      capability: json['capability']?.toString(),
    );
  }

  bool get isFolder => type == 1;
  bool get isFile => type == 0;

  String get displaySize {
    if (isFolder) return '';
    final s = size;
    if (s < 1024) return '$s B';
    if (s < 1024 * 1024) return '${(s / 1024).toStringAsFixed(1)} KB';
    if (s < 1024 * 1024 * 1024) {
      return '${(s / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(s / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get displayDate {
    final date = updatedAt ?? createdAt;
    if (date == null) return '';
    return DateFormat.yMd().add_Hm().format(date);
  }

  String get extension {
    if (isFolder) return '';
    final idx = name.lastIndexOf('.');
    if (idx == -1 || idx == name.length - 1) return '';
    return name.substring(idx + 1).toLowerCase();
  }

  bool get isImage {
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].contains(extension);
  }

  bool get isVideo {
    return ['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv', 'webm'].contains(extension);
  }

  bool get isAudio {
    return ['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'].contains(extension);
  }

  bool get isDocument {
    return ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'md', 'rtf']
        .contains(extension);
  }
}
