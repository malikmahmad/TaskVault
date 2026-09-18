import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import 'edit_task_screen.dart';

class TaskDetailsScreen extends StatelessWidget {
  const TaskDetailsScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, provider, _) {
        final task = _findTask(provider, taskId);

        if (task == null) {
          // Task was deleted elsewhere; leave the details screen.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        return _TaskDetailsBody(task: task);
      },
    );
  }

  Task? _findTask(TaskProvider provider, String id) {
    try {
      return provider.allTasks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}

class _TaskDetailsBody extends StatelessWidget {
  const _TaskDetailsBody({required this.task});

  final Task task;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('"${task.title}" will be permanently removed. '
            'This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final provider = context.read<TaskProvider>();
    final success = await provider.deleteTask(task.id);
    if (!context.mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task deleted')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'Could not delete task')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final priorityColor = AppTheme.priorityColor(context, task.priority.weight);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EditTaskScreen(task: task)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            task.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(task.category.label)),
              Chip(
                label: Text(task.priority.label),
                backgroundColor: priorityColor.withValues(alpha: 0.14),
                labelStyle: TextStyle(color: priorityColor),
              ),
              Chip(
                label: Text(task.isCompleted ? 'Completed' : 'Pending'),
                backgroundColor: task.isCompleted
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
              ),
            ],
          ),
          if (task.description.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Description',
                style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text(task.description, style: const TextStyle(fontSize: 15, height: 1.4)),
          ],
          const SizedBox(height: 20),
          _InfoRow(
            icon: Icons.event_outlined,
            label: 'Due date',
            value: task.dueDate == null
                ? 'No due date set'
                : DateFormat('EEEE, MMM d, yyyy · h:mm a').format(task.dueDate!),
          ),
          _InfoRow(
            icon: Icons.add_circle_outline,
            label: 'Created',
            value: DateFormat('MMM d, yyyy · h:mm a').format(task.createdAt),
          ),
          _InfoRow(
            icon: Icons.update,
            label: 'Last updated',
            value: DateFormat('MMM d, yyyy · h:mm a').format(task.updatedAt),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => context.read<TaskProvider>().toggleCompleted(task),
            icon: Icon(task.isCompleted ? Icons.replay : Icons.check),
            label: Text(task.isCompleted ? 'Mark as Pending' : 'Mark as Completed'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Text('$label: ', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13.5))),
        ],
      ),
    );
  }
}
