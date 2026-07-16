import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/file_item.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/storage.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class FileManagerScreen extends StatefulWidget {
  final CloudreveApi api;

  const FileManagerScreen({super.key, required this.api});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  String _currentPath = '/';
  List<FileItem> _files = [];
  bool _loading = false;
  User? _user;
  final List<String> _pathStack = ['/'];
  FileItem? _selectedItem;
  bool _selectionMode = false;
  final Set<String> _selectedUris = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final files = await widget.api.listFiles(_currentPath);
      final user = await widget.api.getUserInfo();
      if (mounted) {
        setState(() {
          _files = files;
          _user = user;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  void _enterFolder(FileItem folder) {
    _pathStack.add(folder.uri);
    setState(() {
      _currentPath = folder.uri;
      _selectedItem = null;
      _selectionMode = false;
      _selectedUris.clear();
    });
    _loadData();
  }

  void _goBack() {
    if (_pathStack.length > 1) {
      _pathStack.removeLast();
      setState(() {
        _currentPath = _pathStack.last;
        _selectedItem = null;
        _selectionMode = false;
        _selectedUris.clear();
      });
      _loadData();
    }
  }

  void _navigateToPath(int index) {
    while (_pathStack.length > index + 1) {
      _pathStack.removeLast();
    }
    setState(() {
      _currentPath = _pathStack.last;
      _selectedItem = null;
      _selectionMode = false;
      _selectedUris.clear();
    });
    _loadData();
  }

  Future<void> _createFolder() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建文件夹'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: '文件夹名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (name != null && name.isNotEmpty) {
      try {
        await widget.api.createFolder(_currentPath, name);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('创建失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _rename(FileItem item) async {
    final ctrl = TextEditingController(text: item.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: '新名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (name != null && name.isNotEmpty && name != item.name) {
      try {
        await widget.api.rename(item.uri, name);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('重命名失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteItems(List<String> uris) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${uris.length} 个项目吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await widget.api.delete(uris);
        setState(() {
          _selectionMode = false;
          _selectedUris.clear();
        });
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _download(FileItem item) async {
    try {
      final url = await widget.api.getDownloadUrl(item.uri);
      if (url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取下载链接失败: $e')),
        );
      }
    }
  }

  void _showItemMenu(FileItem item) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('下载'),
              onTap: () {
                Navigator.pop(ctx);
                _download(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(ctx);
                _rename(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteItems([item.uri]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await widget.api.logout();
    await StorageService.clearAuth();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  IconData _fileIcon(FileItem item) {
    if (item.isDir) return Icons.folder;
    if (item.isImage) return Icons.image;
    if (item.isVideo) return Icons.video_file;
    if (item.isAudio) return Icons.audio_file;
    return Icons.insert_drive_file;
  }

  Color _fileColor(FileItem item, ColorScheme scheme) {
    if (item.isDir) return const Color(0xFFFFB300);
    if (item.isImage) return const Color(0xFF4CAF50);
    if (item.isVideo) return const Color(0xFFF44336);
    if (item.isAudio) return const Color(0xFF9C27B0);
    return scheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isApple = theme.appBarTheme.titleTextStyle?.fontSize == 34;

    return Scaffold(
      appBar: AppBar(
        leading: _currentPath != '/'
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              )
            : null,
        title: _selectionMode
            ? Text('已选择 ${_selectedUris.length} 项')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isApple)
                    Text('Cloudreve', style: theme.textTheme.titleMedium)
                  else
                    Text('Cloudreve', style: theme.textTheme.titleLarge),
                  if (_user != null)
                    Text(
                      _user!.usageText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _selectedUris.isEmpty ? null : () => _deleteItems(_selectedUris.toList()),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _selectionMode = false;
                _selectedUris.clear();
              }),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Breadcrumb
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _pathStack.length,
              separatorBuilder: (_, __) => const Icon(Icons.chevron_right, size: 18),
              itemBuilder: (ctx, i) {
                final name = _pathStack[i] == '/' ? '首页' : _pathStack[i].split('/').last;
                final isLast = i == _pathStack.length - 1;
                return TextButton(
                  onPressed: isLast ? null : () => _navigateToPath(i),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isLast ? colorScheme.onSurface : colorScheme.primary,
                      fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          // File list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _files.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 64,
                              color: colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '文件夹为空',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _files.length,
                        itemBuilder: (ctx, i) {
                          final item = _files[i];
                          final selected = _selectedUris.contains(item.uri);

                          return ListTile(
                            leading: Icon(
                              _fileIcon(item),
                              color: _fileColor(item, colorScheme),
                            ),
                            title: Text(item.name),
                            subtitle: item.isDir
                                ? null
                                : Text(
                                    '${item.displaySize} · ${DateFormat.yMd().add_Hm().format(item.updatedAt ?? item.createdAt ?? DateTime.now())}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                            trailing: _selectionMode
                                ? Checkbox(
                                    value: selected,
                                    onChanged: (v) {
                                      setState(() {
                                        if (v == true) {
                                          _selectedUris.add(item.uri);
                                        } else {
                                          _selectedUris.remove(item.uri);
                                        }
                                      });
                                    },
                                  )
                                : null,
                            onTap: () {
                              if (_selectionMode) {
                                setState(() {
                                  if (selected) {
                                    _selectedUris.remove(item.uri);
                                  } else {
                                    _selectedUris.add(item.uri);
                                  }
                                });
                              } else if (item.isDir) {
                                _enterFolder(item);
                              } else {
                                _showItemMenu(item);
                              }
                            },
                            onLongPress: () {
                              if (!_selectionMode) {
                                setState(() {
                                  _selectionMode = true;
                                  _selectedUris.add(item.uri);
                                });
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: !_selectionMode
          ? FloatingActionButton(
              onPressed: _createFolder,
              child: const Icon(Icons.create_new_folder),
            )
          : null,
    );
  }
}
