import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/download_service.dart';
import '../services/upload_service.dart';

class TasksScreen extends StatefulWidget {
  final DownloadService downloadService;
  final UploadService uploadService;
  final String? initialRemotePath;

  const TasksScreen({
    super.key,
    required this.downloadService,
    required this.uploadService,
    this.initialRemotePath,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    widget.downloadService.addListener(_onDataChanged);
    widget.uploadService.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    widget.downloadService.removeListener(_onDataChanged);
    widget.uploadService.removeListener(_onDataChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickAndUpload() async {
    try {
      final tasks = await widget.uploadService.pickAndUpload(
        widget.initialRemotePath ?? '/',
      );
      if (tasks.isNotEmpty && mounted) {
        _tabController.animateTo(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('传输管理'),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: '上传 (${widget.uploadService.tasks.length})'),
              Tab(text: '下载 (${widget.downloadService.tasks.length})'),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'pause_all_upload':
                    widget.uploadService.pauseAll();
                    break;
                  case 'resume_all_upload':
                    widget.uploadService.resumeAll();
                    break;
                  case 'clear_upload':
                    widget.uploadService.clearCompleted();
                    break;
                  case 'pause_all_download':
                    widget.downloadService.pauseAll();
                    break;
                  case 'resume_all_download':
                    widget.downloadService.resumeAll();
                    break;
                  case 'clear_download':
                    widget.downloadService.clearCompleted();
                    break;
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem<String>(
                  value: 'pause_all_upload',
                  child: Text('暂停所有上传'),
                ),
                const PopupMenuItem<String>(
                  value: 'resume_all_upload',
                  child: Text('继续所有上传'),
                ),
                const PopupMenuItem<String>(
                  value: 'clear_upload',
                  child: Text('清除已完成上传'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'pause_all_download',
                  child: Text('暂停所有下载'),
                ),
                const PopupMenuItem<String>(
                  value: 'resume_all_download',
                  child: Text('继续所有下载'),
                ),
                const PopupMenuItem<String>(
                  value: 'clear_download',
                  child: Text('清除已完成下载'),
                ),
              ],
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildUploadList(colorScheme, theme),
            _buildDownloadList(colorScheme, theme),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _pickAndUpload,
          child: const Icon(Icons.upload_file),
        ),
      ),
    );
  }

  Widget _buildUploadList(ColorScheme colorScheme, ThemeData theme) {
    final tasks = widget.uploadService.tasks;
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 64,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无上传任务',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右下角按钮开始上传',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tasks.length,
      itemBuilder: (ctx, i) {
        final task = tasks[i];
        return _buildUploadTaskTile(task, colorScheme, theme);
      },
    );
  }

  Widget _buildUploadTaskTile(UploadTask task, ColorScheme colorScheme, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.upload_file,
                  color: _statusColor(task.status, colorScheme),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _statusText(task.status),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _statusColor(task.status, colorScheme),
                            ),
                          ),
                          Text(
                            ' · ${task.displaySize}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (task.status == TaskStatus.running) ...[
                            Text(
                              ' · ${task.displaySpeed}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                _buildUploadActions(task, colorScheme),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: task.progress.clamp(0.0, 1.0),
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
              color: _statusColor(task.status, colorScheme),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  task.displayTransferred,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  task.progressPercent,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (task.errorMessage != null && task.status == TaskStatus.failed) ...[
              const SizedBox(height: 6),
              Text(
                task.errorMessage!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadActions(UploadTask task, ColorScheme colorScheme) {
    switch (task.status) {
      case TaskStatus.waiting:
      case TaskStatus.running:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.pause),
              onPressed: () => widget.uploadService.pauseTask(task.id),
              color: colorScheme.primary,
              iconSize: 20,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            ),
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () => widget.uploadService.cancelTask(task.id),
              color: colorScheme.error,
              iconSize: 20,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            ),
          ],
        );
      case TaskStatus.paused:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () => widget.uploadService.resumeTask(task.id),
              color: colorScheme.primary,
              iconSize: 20,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => widget.uploadService.removeTask(task.id),
              color: colorScheme.error,
              iconSize: 20,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            ),
          ],
        );
      case TaskStatus.completed:
      case TaskStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.status == TaskStatus.failed)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => widget.uploadService.retryTask(task.id),
                color: colorScheme.primary,
                iconSize: 20,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => widget.uploadService.removeTask(task.id),
              color: colorScheme.onSurfaceVariant,
              iconSize: 20,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            ),
          ],
        );
    }
  }

  Widget _buildDownloadList(ColorScheme colorScheme, ThemeData theme) {
    final tasks = widget.downloadService.tasks;
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_outlined,
              size: 64,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无下载任务',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '从文件列表选择文件开始下载',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tasks.length,
      itemBuilder: (ctx, i) {
        final task = tasks[i];
        return _buildDownloadTaskTile(task, colorScheme, theme);
      },
    );
  }

  Widget _buildDownloadTaskTile(DownloadTask task, ColorScheme colorScheme, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.download,
                  color: _statusColor(task.status, colorScheme),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _statusText(task.status),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _statusColor(task.status, colorScheme),
                            ),
                          ),
                          if (task.size > 0)
                            Text(
                              ' · ${task.displaySize}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          if (task.status == TaskStatus.running) ...[
                            Text(
                              ' · ${task.displaySpeed}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                _buildDownloadActions(task, colorScheme),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: task.progress.clamp(0.0, 1.0),
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
              color: _statusColor(task.status, colorScheme),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  task.displayTransferred,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  task.progressPercent,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (task.errorMessage != null && task.status == TaskStatus.failed) ...[
              const SizedBox(height: 6),
              Text(
                task.errorMessage!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadActions(DownloadTask task, ColorScheme colorScheme) {
    switch (task.status) {
      case TaskStatus.waiting:
      case TaskStatus.running:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.pause),
              onPressed: () => widget.downloadService.pauseTask(task.id),
              color: colorScheme.primary,
              iconSize: 20,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            ),
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () => widget.downloadService.cancelTask(task.id),
              color: colorScheme.error,
              iconSize: 20,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            ),
          ],
        );
      case TaskStatus.paused:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () => widget.downloadService.resumeTask(task.id),
              color: colorScheme.primary,
              iconSize: 20,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => widget.downloadService.removeTask(task.id),
              color: colorScheme.error,
              iconSize: 20,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            ),
          ],
        );
      case TaskStatus.completed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => widget.downloadService.openFile(task),
              color: colorScheme.primary,
              iconSize: 20,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => widget.downloadService.removeTask(task.id),
              color: colorScheme.onSurfaceVariant,
              iconSize: 20,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            ),
          ],
        );
      case TaskStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => widget.downloadService.retryTask(task.id),
              color: colorScheme.primary,
              iconSize: 20,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => widget.downloadService.removeTask(task.id),
              color: colorScheme.onSurfaceVariant,
              iconSize: 20,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            ),
          ],
        );
    }
  }

  Color _statusColor(TaskStatus status, ColorScheme colorScheme) {
    switch (status) {
      case TaskStatus.waiting:
        return colorScheme.onSurfaceVariant;
      case TaskStatus.running:
        return colorScheme.primary;
      case TaskStatus.paused:
        return colorScheme.secondary;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.failed:
        return colorScheme.error;
    }
  }

  String _statusText(TaskStatus status) {
    return status.label;
  }
}
