import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/file_item.dart';
import '../models/user.dart';

class CloudreveApi {
  final String baseUrl;
  String? token;
  String? refreshToken;

  CloudreveApi(this.baseUrl, {this.token});

  String get _base => baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  Map<String, String> get _headers {
    final h = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token!.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response res) async {
    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) {
      throw Exception('Invalid response format');
    }
    final code = body['code'];
    if (code != 0 && code != null) {
      throw Exception(body['msg'] ?? 'Request failed (code: $code)');
    }
    return body;
  }

  // ========== Auth ==========

  Future<Map<String, dynamic>> login(String email, String password, {String? captcha}) async {
    final res = await http.post(
      Uri.parse('$_base/api/v4/session/signin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_name': email,
        'password': password,
        if (captcha != null) 'captcha': captcha,
      }),
    );
    final data = await _handleResponse(res);
    final tokenData = data['data']?['token'];
    if (tokenData != null) {
      token = tokenData['access_token'];
      refreshToken = tokenData['refresh_token'];
    }
    return data;
  }

  Future<bool> refreshAccessToken() async {
    if (refreshToken == null || refreshToken!.isEmpty) return false;
    try {
      final res = await http.post(
        Uri.parse('$_base/api/v4/session/token/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
      final data = await _handleResponse(res);
      final tokenData = data['data'];
      if (tokenData != null) {
        token = tokenData['access_token'];
        refreshToken = tokenData['refresh_token'];
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('$_base/api/v4/session/signout'),
        headers: _headers,
      );
    } catch (_) {}
    token = null;
    refreshToken = null;
  }

  // ========== User ==========

  Future<User> getUserInfo() async {
    final res = await http.get(
      Uri.parse('$_base/api/v4/user/storage'),
      headers: _headers,
    );
    final data = await _handleResponse(res);
    return User.fromJson(data['data'] ?? {});
  }

  // ========== File ==========

  Future<List<FileItem>> listFiles(String path, {int page = 1, int pageSize = 50}) async {
    final query = {
      'path': path,
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    final uri = Uri.parse('$_base/api/v4/file/list').replace(queryParameters: query);
    final res = await http.get(uri, headers: _headers);
    final data = await _handleResponse(res);
    final items = data['data']?['items'] ?? data['data']?['objects'] ?? [];
    if (items is List) {
      return items.map((e) => FileItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<FileItem> getFileInfo(String uri) async {
    final res = await http.get(
      Uri.parse('$_base/api/v4/file/info').replace(queryParameters: {'uri': uri}),
      headers: _headers,
    );
    final data = await _handleResponse(res);
    return FileItem.fromJson(data['data'] ?? {});
  }

  Future<void> createFolder(String path, String name) async {
    await http.post(
      Uri.parse('$_base/api/v4/file/create'),
      headers: _headers,
      body: jsonEncode({
        'path': path,
        'name': name,
        'type': 'dir',
      }),
    );
  }

  Future<void> rename(String uri, String newName) async {
    await http.post(
      Uri.parse('$_base/api/v4/file/rename'),
      headers: _headers,
      body: jsonEncode({
        'uri': uri,
        'new_name': newName,
      }),
    );
  }

  Future<void> delete(List<String> uris) async {
    await http.post(
      Uri.parse('$_base/api/v4/file/delete'),
      headers: _headers,
      body: jsonEncode({'uris': uris}),
    );
  }

  Future<void> move(String uri, String destination) async {
    await http.post(
      Uri.parse('$_base/api/v4/file/move'),
      headers: _headers,
      body: jsonEncode({
        'uri': uri,
        'destination': destination,
      }),
    );
  }

  Future<void> copy(String uri, String destination) async {
    await http.post(
      Uri.parse('$_base/api/v4/file/copy'),
      headers: _headers,
      body: jsonEncode({
        'uri': uri,
        'destination': destination,
      }),
    );
  }

  Future<String> getDownloadUrl(String uri) async {
    final res = await http.get(
      Uri.parse('$_base/api/v4/file/download').replace(queryParameters: {'uri': uri}),
      headers: _headers,
    );
    final data = await _handleResponse(res);
    return data['data']?['url'] ?? '';
  }

  Future<String> createUploadSession(String path, String name, int size) async {
    final res = await http.post(
      Uri.parse('$_base/api/v4/file/upload'),
      headers: _headers,
      body: jsonEncode({
        'path': path,
        'name': name,
        'size': size,
      }),
    );
    final data = await _handleResponse(res);
    return data['data']?['session_id'] ?? '';
  }
}
