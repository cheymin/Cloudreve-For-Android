import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'utils/storage.dart';
import 'utils/theme.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider()..init(),
      child: const CloudreveApp(),
    ),
  );
}

class CloudreveApp extends StatelessWidget {
  const CloudreveApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Cloudreve',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.resolve(
        themeProvider.uiStyle,
        Brightness.light,
        customPrimary: themeProvider.customPrimaryColor,
      ),
      darkTheme: AppTheme.resolve(
        themeProvider.uiStyle,
        Brightness.dark,
        customPrimary: themeProvider.customPrimaryColor,
      ),
      themeMode: themeProvider.themeMode,
      home: const _AuthChecker(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/settings':
            return MaterialPageRoute(builder: (_) => const SettingsScreen());
          default:
            return null;
        }
      },
    );
  }
}

class _AuthChecker extends StatelessWidget {
  const _AuthChecker();

  @override
  Widget build(BuildContext context) {
    final token = StorageService.token;
    final baseUrl = StorageService.baseUrl;

    if (token != null && baseUrl != null && token.isNotEmpty && baseUrl.isNotEmpty) {
      final api = CloudreveApi(baseUrl, accessToken: token);
      api.refreshToken = StorageService.refreshToken;
      return HomeScreen(api: api);
    }

    return const LoginScreen();
  }
}
