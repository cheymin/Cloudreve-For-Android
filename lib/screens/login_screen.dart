import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/storage.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _baseUrlCtrl = TextEditingController(text: '');
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _captchaCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _needsCaptcha = false;
  String? _captchaImage;
  String? _captchaTicket;

  @override
  void initState() {
    super.initState();
    final savedUrl = StorageService.baseUrl;
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrlCtrl.text = savedUrl.replaceAll(RegExp(r'/api/v4/?$'), '');
    }
  }

  Future<void> _loadCaptcha() async {
    try {
      final api = CloudreveApi(_baseUrlCtrl.text.trim());
      final captcha = await api.getCaptcha();
      setState(() {
        _captchaImage = captcha['image'];
        _captchaTicket = captcha['ticket'];
        _needsCaptcha = true;
      });
    } catch (_) {
      setState(() => _needsCaptcha = false);
    }
  }

  Future<void> _login() async {
    final baseUrl = _baseUrlCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (baseUrl.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnack('请填写完整信息');
      return;
    }

    setState(() => _loading = true);

    try {
      final api = CloudreveApi(baseUrl);
      final res = await api.login(
        email,
        password,
        captcha: _captchaCtrl.text.trim().isNotEmpty ? _captchaCtrl.text.trim() : null,
        ticket: _captchaTicket,
      );

      final tokenData = res['data']?['token'];
      if (tokenData != null) {
        final cleanUrl = baseUrl.replaceAll(RegExp(r'/$'), '');
        StorageService.baseUrl = cleanUrl;
        StorageService.token = api.accessToken;
        StorageService.refreshToken = api.refreshToken;

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomeScreen(api: api)),
          );
        }
      } else {
        _showSnack('登录失败，请检查账号密码');
        await _loadCaptcha();
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      _showSnack('登录失败: $msg');
      await _loadCaptcha();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.cloud_outlined,
                  size: 80,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Cloudreve',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '连接你的私有云存储',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _baseUrlCtrl,
                  decoration: InputDecoration(
                    labelText: '服务器地址',
                    hintText: 'https://cloud.example.com',
                    prefixIcon: const Icon(Icons.link),
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(
                    labelText: '邮箱',
                    hintText: 'user@example.com',
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordCtrl,
                  decoration: InputDecoration(
                    labelText: '密码',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  obscureText: _obscure,
                  textInputAction: _needsCaptcha ? TextInputAction.next : TextInputAction.done,
                  onSubmitted: (_) {
                    if (!_needsCaptcha) _login();
                  },
                ),
                if (_needsCaptcha && _captchaImage != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _captchaCtrl,
                          decoration: const InputDecoration(
                            labelText: '验证码',
                            prefixIcon: Icon(Icons.verified_user_outlined),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _login(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _loadCaptcha,
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: colorScheme.outline),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _captchaImage!.startsWith('data:')
                              ? Image.memory(
                                  _decodeCaptchaImage(_captchaImage!),
                                  fit: BoxFit.contain,
                                )
                              : const Icon(Icons.refresh),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('登录', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<int> _decodeCaptchaImage(String dataUrl) {
    if (dataUrl.startsWith('data:image/')) {
      final base64 = dataUrl.split(',').last;
      return base64Decode(base64);
    }
    return [];
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _captchaCtrl.dispose();
    super.dispose();
  }
}
