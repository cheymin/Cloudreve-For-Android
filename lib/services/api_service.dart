import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/file_item.dart';
import '../models/user.dart';

class CloudreveApi {
  String baseUrl;
  String? accessToken;
  String? refreshToken;

  CloudreveApi(this.baseUrl, {this.accessToken});

  String get _base {
    var url = baseUrl;
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (!url.endsWith('/api/v4')) {
      url = '$url/api/v4';
    }
    return url;
  }

  Map<String, String> get _headers {
    final h = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (accessToken != null && accessToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer $accessToken';
    }
    return h;
  }

  Map<String, dynamic> _parseResponse(http.Response res) {
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    final data = body is Map<String, dynamic> ? body : <String, dynamic>{};
    final code = data['code'];
    if (code != null && code != 0 && code != 203) {
      throw Exception(data['msg'] ?? data['message'] ?? 'Request failed (code: $code)');
    }
    return data;
  }

  // ========== Auth ==========

  Future<Map<String, dynamic>> login(String email, String password,
      {String? captcha, String? ticket}) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      if (captcha != null && captcha.isNotEmpty) 'captcha': captcha,
      if (ticket != null && ticket.isNotEmpty) 'ticket': ticket,
    };

    final res = await http.post(
      Uri.parse('$_base/session/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final data = _parseResponse(res);
    final tokenData = data['data']?['token'];
    if (tokenData != null) {
      accessToken = tokenData['access_token'];
      refreshToken = tokenData['refresh_token'];
    }
    return data;
  }

  Future<bool> refreshAccessToken() async {
    if (refreshToken == null || refreshToken!.isEmpty) return false;
    try {
      final res = await http.post(
        Uri.parse('$_base/session/token/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
      final data = _parseResponse(res);
      final tokenData = data['data'];
      if (tokenData != null) {
        accessToken = tokenData['access_token'] ?? accessToken;
        refreshToken = tokenData['refresh_token'] ?? refreshToken;
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> logout() async {
    try {
      await http.delete(
        Uri.parse('$_base/session/token'),
        headers: _headers,
        body: jsonEncode({}),
      );
    } catch (_) {}
    accessToken = null;
    refreshToken = null;
  }

  // ========== User ==========

  Future<User> getUserInfo() async {
    final res = await http.get(
      Uri.parse('$_base/user/me'),
      headers: _headers,
    );
    final data = _parseResponse(res);
    return User.fromJson(data['data'] ?? {});
  }

  Future<CapacityInfo> getCapacity() async {
    final res = await http.get(
      Uri.parse('$_base/user/capacity'),
      headers: _headers,
    );
    final data = _parseResponse(res);
    return CapacityInfo.fromJson(data['data'] ?? {});
  }

  // ========== Site ==========

  Future<Map<String, dynamic>> getBasicConfig() async {
    final res = await http.get(
      Uri.parse('$_base/site/config/basic'),
      headers: {'Content-Type': 'application/json'},
    );
    final data = _parseResponse(res);
    return data['data'] is Map
        ? Map<String, dynamic>.from(data['data'])
        : <String, dynamic>{};
  }

  Future<Map<String, String>> getCaptcha() async {
    final res = await http.get(
      Uri.parse('$_base/site/captcha'),
      headers: {'Content-Type': 'application/json'},
    );
    final data = _parseResponse(res);
    final d = data['data'] is Map
        ? Map<String, dynamic>.from(data['data'])
        : data;
    return {
      'image': (d['image'] as String?) ?? '',
      'ticket': (d['ticket'] as String?) ?? '',
    };
  }

  // ========== File ==========

  Future<FileListResponse> listFiles(String uri,
      {int page = 1, int? pageSize, String? orderBy, String? orderDirection}) async {
    final params = <String, String>{
      'uri': uri,
      'page': page.toString(),
      if (pageSize != null) 'page_size': pageSize.toString(),
      if (orderBy != null) 'order_by': orderBy,
      if (orderDirection != null) 'order_direction': orderDirection,
    };
    final url = Uri.parse('$_base/file').replace(queryParameters: params);
    final res = await http.get(url, headers: _headers);
    final data = _parseResponse(res);
    return FileListResponse.fromJson(data['data'] ?? {});
  }

  Future<FileItem> getFileInfo(String uri) async {
    final res = await http.get(
      Uri.parse('$_base/file/$uri?uri=$uri'),
      headers: _headers,
    );
    final data = _parseResponse(res);
    return FileItem.fromJson(data['data'] ?? {});
  }

  Future<void> createFolder(String uri, String name) async {
    final newFolderUri = uri.endsWith('/') ? '$uri$name' : '$uri/$name';
    final res = await http.post(
      Uri.parse('$_base/file/create'),
      headers: _headers,
      body: jsonEncode({
        'uri': newFolderUri,
        'type': 'dir',
      }),
    );
    _parseResponse(res);
  }

  Future<void> rename(String uri, String newName) async {
    final res = await http.post(
      Uri.parse('$_base/file/rename'),
      headers: _headers,
      body: jsonEncode({
        'uri': uri,
        'new_name': newName,
      }),
    );
    _parseResponse(res);
  }

  Future<void> deleteFiles(List<String> uris) async {
    final res = await http.delete(
      Uri.parse('$_base/file'),
      headers: _headers,
      body: jsonEncode({'uris': uris}),
    );
    _parseResponse(res);
  }

  Future<void> moveFiles(List<String> uris, String dst) async {
    final res = await http.post(
      Uri.parse('$_base/file/move'),
      headers: _headers,
      body: jsonEncode({
        'uris': uris,
        'dst': dst,
        'copy': false,
      }),
    );
    _parseResponse(res);
  }

  Future<void> copyFiles(List<String> uris, String dst) async {
    final res = await http.post(
      Uri.parse('$_base/file/move'),
      headers: _headers,
      body: jsonEncode({
        'uris': uris,
        'dst': dst,
        'copy': true,
      }),
    );
    _parseResponse(res);
  }

  Future<String> getDownloadUrl(String uri) async {
    final res = await http.post(
      Uri.parse('$_base/file/url'),
      headers: _headers,
      body: jsonEncode({
        'uris': [uri],
        'download': true,
      }),
    );
    final data = _parseResponse(res);
    final items = data['data'];
    if (items is List && items.isNotEmpty) {
      return items[0]['url'] ?? '';
    }
    return '';
  }

  Future<List<Map<String, dynamic>>> getDownloadUrls(List<String> uris) async {
    final res = await http.post(
      Uri.parse('$_base/file/url'),
      headers: _headers,
      body: jsonEncode({
        'uris': uris,
        'download': true,
      }),
    );
    final data = _parseResponse(res);
    final items = data['data'];
    if (items is List) {
      return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> createUploadSession(
      String path, String name, int size) async {
    final res = await http.post(
      Uri.parse('$_base/file/upload'),
      headers: _headers,
      body: jsonEncode({
        'path': path,
        'name': name,
        'size': size,
      }),
    );
    final data = _parseResponse(res);
    return Map<String, dynamic>.from(data['data'] ?? {});
  }
}

class FileListResponse {
  final List<FileItem> items;
  final String? nextPageToken;
  final int? total;

  FileListResponse({
    required this.items,
    this.nextPageToken,
    this.total,
  });

  factory FileListResponse.fromJson(Map<String, dynamic> json) {
    final objects = json['objects'] ?? json['items'] ?? [];
    return FileListResponse(
      items: (objects is List)
          ? objects.map((e) => FileItem.fromJson(e as Map<String, dynamic>)).toList()
          : <FileItem>[],
      nextPageToken: json['next_page_token'],
      total: json['total'],
    );
  }
}

class CapacityInfo {
  final int used;
  final int total;

  CapacityInfo({required this.used, required this.total});

  factory CapacityInfo.fromJson(Map<String, dynamic> json) {
    return CapacityInfo(
      used: (json['used'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }

  double get percent => total <= 0 ? 0 : (used / total).clamp(0.0, 1.0);

  String get displayUsed => '${_formatSize(used)} / ${_formatSize(total)}';

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
