import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sync_config_model.dart';
import '../services/sync_service.dart';
import '../services/api_service.dart';
import 'sync_settings_screen.dart';

class SyncScreen extends StatefulWidget {
  final CloudreveApi api;

  const SyncScreen({super.key, required this.api});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SyncService.instance.setApi(widget.api);
      SyncService.instance.init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final syncService = SyncService.instance;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: syncService,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('文件同步'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SyncSettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: syncService.configs.isEmpty
              ? _buildEmptyState(theme)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: syncService.configs.length,
                  itemBuilder: (context, index) {
                    final config = syncService.configs[index];
                    return _buildSyncCard(config, theme);
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddEditDialog(),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sync_alt_outlined,
            size: 80,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无同步任务',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角按钮添加同步任务',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncCard(SyncConfig config, ThemeData theme) {
    final progress = config.totalFiles > 0
        ? config.syncedFiles / config.totalFiles
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        config.syncMode.displayName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: config.isEnabled,
                  onChanged: (value) {
                    final updated = config.copyWith(isEnabled: value);
                    SyncService.instance.updateConfig(updated);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '本地路径',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        config.localPath,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '远程路径',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        config.remoteUri,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (config.status == SyncStatus.syncing) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Text(
                '正在同步: ${config.currentFile ?? ''}',
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${config.syncedFiles} / ${config.totalFiles} 个文件',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
            if (config.status != SyncStatus.syncing) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    _getStatusIcon(config.status),
                    size: 16,
                    color: _getStatusColor(config.status, theme),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    config.status.displayName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _getStatusColor(config.status, theme),
                    ),
                  ),
                  if (config.lastSyncTime != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '上次同步: ${DateFormat('MM-dd HH:mm').format(config.lastSyncTime!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
              if (config.lastError != null) ...[
                const SizedBox(height: 4),
                Text(
                  config.lastError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: config.status == SyncStatus.syncing
                      ? null
                      : () => SyncService.instance.syncConfig(config.id),
                  icon: const Icon(Icons.sync),
                  label: const Text('立即同步'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showAddEditDialog(config: config),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('编辑'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _confirmDelete(config),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('删除', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return Icons.pause_circle_outline;
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.success:
        return Icons.check_circle_outline;
      case SyncStatus.failed:
        return Icons.error_outline;
    }
  }

  Color _getStatusColor(SyncStatus status, ThemeData theme) {
    switch (status) {
      case SyncStatus.idle:
        return theme.colorScheme.onSurface.withValues(alpha: 0.6);
      case SyncStatus.syncing:
        return theme.colorScheme.primary;
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.failed:
        return Colors.red;
    }
  }

  Future<void> _showAddEditDialog({SyncConfig? config}) async {
    final isEdit = config != null;
    final nameController = TextEditingController(text: config?.name ?? '');
    final localPathController = TextEditingController(text: config?.localPath ?? '');
    final remoteUriController = TextEditingController(text: config?.remoteUri ?? '/');
    var syncMode = config?.syncMode ?? SyncMode.bidirectional;
    var syncInterval = config?.syncIntervalMinutes ?? 0;
    final includePatternsController = TextEditingController(
      text: config?.includePatterns.join(',') ?? '',
    );
    final excludePatternsController = TextEditingController(
      text: config?.excludePatterns.join(',') ?? '',
    );

    if (!isEdit) {
      final defaultPath = await SyncService.instance.getDefaultLocalPath();
      localPathController.text = defaultPath;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? '编辑同步任务' : '添加同步任务'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '任务名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: localPathController,
                  decoration: const InputDecoration(
                    labelText: '本地路径',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remoteUriController,
                  decoration: const InputDecoration(
                    labelText: '远程路径',
                    border: OutlineInputBorder(),
                    hintText: '例如: /备份/文档',
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '同步模式',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildModeButton(
                        ctx,
                        SyncMode.uploadOnly,
                        syncMode,
                        (mode) => setDialogState(() => syncMode = mode),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildModeButton(
                        ctx,
                        SyncMode.downloadOnly,
                        syncMode,
                        (mode) => setDialogState(() => syncMode = mode),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildModeButton(
                        ctx,
                        SyncMode.bidirectional,
                        syncMode,
                        (mode) => setDialogState(() => syncMode = mode),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '同步间隔',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: syncInterval,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('手动同步')),
                    DropdownMenuItem(value: 15, child: Text('每 15 分钟')),
                    DropdownMenuItem(value: 30, child: Text('每 30 分钟')),
                    DropdownMenuItem(value: 60, child: Text('每小时')),
                    DropdownMenuItem(value: 360, child: Text('每 6 小时')),
                    DropdownMenuItem(value: 720, child: Text('每 12 小时')),
                    DropdownMenuItem(value: 1440, child: Text('每天')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => syncInterval = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: includePatternsController,
                  decoration: const InputDecoration(
                    labelText: '包含文件（逗号分隔，支持通配符*）',
                    border: OutlineInputBorder(),
                    hintText: '例如: *.jpg,*.pdf',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: excludePatternsController,
                  decoration: const InputDecoration(
                    labelText: '排除文件（逗号分隔，支持通配符*）',
                    border: OutlineInputBorder(),
                    hintText: '例如: *.tmp,*.log',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final localPath = localPathController.text.trim();
                final remoteUri = remoteUriController.text.trim();

                if (name.isEmpty || localPath.isEmpty || remoteUri.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('请填写完整信息')),
                  );
                  return;
                }

                final includePatterns = includePatternsController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();

                final excludePatterns = excludePatternsController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();

                if (isEdit) {
                  final updated = config!.copyWith(
                    name: name,
                    localPath: localPath,
                    remoteUri: remoteUri,
                    syncMode: syncMode,
                    syncIntervalMinutes: syncInterval,
                    includePatterns: includePatterns,
                    excludePatterns: excludePatterns,
                  );
                  await SyncService.instance.updateConfig(updated);
                } else {
                  final newConfig = SyncConfig(
                    id: '',
                    name: name,
                    localPath: localPath,
                    remoteUri: remoteUri,
                    syncMode: syncMode,
                    syncIntervalMinutes: syncInterval,
                    includePatterns: includePatterns,
                    excludePatterns: excludePatterns,
                  );
                  await SyncService.instance.addConfig(newConfig);
                }

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(isEdit ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(
    BuildContext ctx,
    SyncMode mode,
    SyncMode selectedMode,
    void Function(SyncMode) onTap,
  ) {
    final isSelected = mode == selectedMode;
    final theme = Theme.of(ctx);

    return GestureDetector(
      onTap: () => onTap(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : null,
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              _getModeIcon(mode),
              color: isSelected ? theme.colorScheme.primary : null,
            ),
            const SizedBox(height: 4),
            Text(
              mode.displayName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isSelected ? theme.colorScheme.primary : null,
                fontWeight: isSelected ? FontWeight.w600 : null,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getModeIcon(SyncMode mode) {
    switch (mode) {
      case SyncMode.uploadOnly:
        return Icons.cloud_upload_outlined;
      case SyncMode.downloadOnly:
        return Icons.cloud_download_outlined;
      case SyncMode.bidirectional:
        return Icons.sync_alt;
    }
  }

  Future<void> _confirmDelete(SyncConfig config) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除同步任务'),
        content: Text('确定要删除同步任务「${config.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok == true) {
      await SyncService.instance.deleteConfig(config.id);
    }
  }
}
