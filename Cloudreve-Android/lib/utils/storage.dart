import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String? get token => _prefs.getString('token');
  static set token(String? value) {
    if (value == null) {
      _prefs.remove('token');
    } else {
      _prefs.setString('token', value);
    }
  }

  static String? get baseUrl => _prefs.getString('baseUrl');
  static set baseUrl(String? value) {
    if (value == null) {
      _prefs.remove('baseUrl');
    } else {
      _prefs.setString('baseUrl', value);
    }
  }

  static String? get refreshToken => _prefs.getString('refreshToken');
  static set refreshToken(String? value) {
    if (value == null) {
      _prefs.remove('refreshToken');
    } else {
      _prefs.setString('refreshToken', value);
    }
  }

  static String? get themeMode => _prefs.getString('themeMode');
  static set themeMode(String? value) {
    if (value == null) {
      _prefs.remove('themeMode');
    } else {
      _prefs.setString('themeMode', value);
    }
  }

  static String? get uiStyle => _prefs.getString('uiStyle') ?? 'google';
  static set uiStyle(String? value) {
    if (value == null) {
      _prefs.remove('uiStyle');
    } else {
      _prefs.setString('uiStyle', value);
    }
  }

  static int? get customPrimaryColor => _prefs.getInt('customPrimaryColor');
  static set customPrimaryColor(int? value) {
    if (value == null) {
      _prefs.remove('customPrimaryColor');
    } else {
      _prefs.setInt('customPrimaryColor', value);
    }
  }

  static Future<void> clearAuth() async {
    await _prefs.remove('token');
    await _prefs.remove('refreshToken');
    await _prefs.remove('baseUrl');
  }
}
