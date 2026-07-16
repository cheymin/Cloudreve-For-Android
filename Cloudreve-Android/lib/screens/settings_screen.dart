import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme.dart';
import '../utils/storage.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // Appearance
          _SectionHeader(title: '外观', theme: theme),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('主题模式'),
            subtitle: Text(
              themeProvider.themeMode == ThemeMode.system
                  ? '跟随系统'
                  : themeProvider.themeMode == ThemeMode.light
                      ? '浅色'
                      : '深色',
            ),
            onTap: () => _showThemeModePicker(themeProvider),
          ),
          ListTile(
            leading: const Icon(Icons.style_outlined),
            title: const Text('界面风格'),
            subtitle: Text(themeProvider.isGoogle ? 'Material You' : 'Apple'),
            onTap: () => _showStylePicker(themeProvider),
          ),
          ListTile(
            leading: const Icon(Icons.color_lens_outlined),
            title: const Text('主题色'),
            trailing: themeProvider.customPrimaryColor != null
                ? CircleAvatar(
                    radius: 14,
                    backgroundColor: themeProvider.customPrimaryColor,
                  )
                : const Text('默认'),
            onTap: () => _showColorPicker(themeProvider),
          ),
          const Divider(),
          // Account
          _SectionHeader(title: '账户', theme: theme),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('退出登录', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmLogout(),
          ),
          const Divider(),
          // About
          _SectionHeader(title: '关于', theme: theme),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Cloudreve Android'),
            subtitle: const Text('版本 1.0.0'),
          ),
        ],
      ),
    );
  }

  void _showThemeModePicker(ThemeProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('跟随系统'),
              trailing: provider.themeMode == ThemeMode.system
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                provider.setThemeMode(ThemeMode.system);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('浅色'),
              trailing: provider.themeMode == ThemeMode.light
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                provider.setThemeMode(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('深色'),
              trailing: provider.themeMode == ThemeMode.dark
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                provider.setThemeMode(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showStylePicker(ThemeProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Material You (Google)'),
              trailing: provider.isGoogle ? const Icon(Icons.check) : null,
              onTap: () {
                provider.setUiStyle(UiStyle.google);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('Apple 风格'),
              trailing: provider.isApple ? const Icon(Icons.check) : null,
              onTap: () {
                provider.setUiStyle(UiStyle.apple);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(ThemeProvider provider) {
    final colors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.blueGrey,
    ];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('选择主题色', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ActionChip(
                    label: const Text('默认'),
                    onPressed: () {
                      provider.setCustomPrimaryColor(null);
                      Navigator.pop(ctx);
                    },
                  ),
                  ...colors.map((c) => GestureDetector(
                        onTap: () {
                          provider.setCustomPrimaryColor(c);
                          Navigator.pop(ctx);
                        },
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: c,
                          child: provider.customPrimaryColor == c
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账户吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok == true) {
      await StorageService.clearAuth();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeData theme;

  const _SectionHeader({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
