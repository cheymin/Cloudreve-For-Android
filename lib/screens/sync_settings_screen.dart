import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sync_service.dart';

class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final syncService = Provider.of<SyncService>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('同步设置'),
      ),
      body: ListView(
        children: [
          _SectionHeader(title: '同步状态', theme: theme),
          ListTile(
            leading: const Icon(Icons.sync_outlined),
            title: const Text('同步任务总数'),
            trailing: Text('${syncService.configs.length} 个'),
          ),
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: const Text('已启用任务'),
            trailing: Text(
              '${syncService.configs.where((c) => c.isEnabled).length} 个',
            ),
          ),
          const Divider(),
          _SectionHeader(title: '操作', theme: theme),
          ListTile(
            leading: const Icon(Icons.refresh_outlined),
            title: const Text('同步所有任务'),
            subtitle: const Text('立即同步所有已启用的任务'),
            onTap: () => _syncAll(syncService),
          ),
          ListTile(
            leading: const Icon(Icons.stop_circle_outlined),
            title: const Text('停止所有同步'),
            subtitle: const Text('停止正在进行的同步任务'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已请求停止同步')),
              );
            },
          ),
          const Divider(),
          _SectionHeader(title: '关于', theme: theme),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('同步说明'),
            subtitle: const Text('了解同步功能的使用方式'),
            onTap: () => _showHelpDialog(),
          ),
        ],
      ),
    );
  }

  Future<void> _syncAll(SyncService syncService) async {
    final enabledConfigs = syncService.configs.where((c) => c.isEnabled).toList();
    if (enabledConfigs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有已启用的同步任务')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('开始同步 ${enabledConfigs.length} 个任务...')),
    );

    for (final config in enabledConfigs) {
      await syncService.syncConfig(config.id);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所有任务同步完成')),
      );
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('同步说明'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '同步模式',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• 仅上传：只将本地文件上传到云端'),
              Text('• 仅下载：只将云端文件下载到本地'),
              Text('• 双向同步：本地和云端文件保持一致'),
              SizedBox(height: 16),
              Text(
                '文件过滤',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• 支持使用通配符 * 匹配文件名'),
              Text('• 例如: *.jpg 匹配所有 JPG 图片'),
              Text('• 包含模式：只同步匹配的文件'),
              Text('• 排除模式：跳过匹配的文件'),
              SizedBox(height: 16),
              Text(
                '定时同步',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• 可设置自动同步间隔'),
              Text('• 设置为手动同步则只在点击时同步'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
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
