import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import '../services/upload_service.dart';
import 'file_manager_screen.dart';
import 'tasks_screen.dart';
import 'sync_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final CloudreveApi api;

  const HomeScreen({super.key, required this.api});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late DownloadService _downloadService;
  late UploadService _uploadService;
  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _downloadService = DownloadService(widget.api);
    _uploadService = UploadService(widget.api);
    _screens.addAll([
      FileManagerScreen(api: widget.api),
      TasksScreen(
        downloadService: _downloadService,
        uploadService: _uploadService,
      ),
      SyncScreen(api: widget.api),
      ProfileScreen(api: widget.api),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: '文件',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download),
            label: '传输',
          ),
          NavigationDestination(
            icon: Icon(Icons.sync_outlined),
            selectedIcon: Icon(Icons.sync),
            label: '同步',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
