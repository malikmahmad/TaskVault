import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import '../utils/constants.dart';
import '../widgets/empty_state.dart';
import '../widgets/task_card.dart';
import '../widgets/task_search_bar.dart';
import '../widgets/task_stats.dart';
import 'add_task_screen.dart';
import 'settings_screen.dart';
import 'task_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<bool?> _confirmDelete(BuildContext context, Task task) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text(
          '"${task.title}" will be permanently removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          // Sort menu
          PopupMenuButton<TaskSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onSelected: (s) => context.read<TaskProvider>().setSort(s),
            itemBuilder: (context) => TaskSort.values
                .map((s) => PopupMenuItem(value: s, child: Text(s.label)))
                .toList(),
          ),
          // Settings
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddTaskScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
      body: Consumer<TaskProvider>(
        builder: (context, provider, _) {
          if (provider.status == ViewStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.status == ViewStatus.error) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load your tasks',
              message: provider.errorMessage ?? 'Please try again.',
              action: FilledButton(
                onPressed: () => provider.load(),
                child: const Text('Retry'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.load,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: TaskStats(
                      total: provider.totalCount,
                      pending: provider.pendingCount,
                      completed: provider.completedCount,
                      highPriority: provider.highPriorityCount,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: TaskSearchBar(
                      controller: _searchController,
                      onChanged: (v) {
                        provider.setSearchQuery(v);
                        setState(() {});
                      },
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _FilterRow(provider: provider),
                  ),
                ),
                if (provider.tasks.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: provider.totalCount == 0
                          ? Icons.checklist_rtl
                          : Icons.search_off,
                      title: provider.totalCount == 0
                          ? 'No tasks yet'
                          : 'No matching tasks found',
                      message: provider.totalCount == 0
                          ? 'Create your first task to get started.'
                          : 'Try a different search term or filter.',
                      action: provider.totalCount == 0
                          ? FilledButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const AddTaskScreen()),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Task'),
                            )
                          : null,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    sliver: SliverList.separated(
                      itemCount: provider.tasks.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final task = provider.tasks[index];
                        return _SwipableTaskCard(
                          key: ValueKey(task.id),
                          task: task,
                          onConfirmDelete: () =>
                              _confirmDelete(context, task),
                          onDeleted: () async {
                            final ok =
                                await provider.deleteTask(task.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? 'Task deleted'
                                    : provider.errorMessage ??
                                        'Could not delete task'),
                              ),
                            );
                          },
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  TaskDetailsScreen(taskId: task.id),
                            ),
                          ),
                          onToggleCompleted: () =>
                              provider.toggleCompleted(task),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Swipable wrapper — slides the card left to reveal a red delete background.
// ---------------------------------------------------------------------------

class _SwipableTaskCard extends StatelessWidget {
  const _SwipableTaskCard({
    super.key,
    required this.task,
    required this.onConfirmDelete,
    required this.onDeleted,
    required this.onTap,
    required this.onToggleCompleted,
  });

  final Task task;
  final Future<bool?> Function() onConfirmDelete;
  final VoidCallback onDeleted;
  final VoidCallback onTap;
  final VoidCallback onToggleCompleted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      // Ask for confirmation before the card flies away.
      confirmDismiss: (_) => onConfirmDelete(),
      onDismissed: (_) => onDeleted(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      child: TaskCard(
        task: task,
        onTap: onTap,
        onToggleCompleted: onToggleCompleted,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chip row
// ---------------------------------------------------------------------------

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.provider});
  final TaskProvider provider;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ...TaskFilter.values.where((f) => f != TaskFilter.category).map(
                (f) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f.label),
                    selected: provider.filter == f,
                    onSelected: (_) => provider.setFilter(f),
                  ),
                ),
              ),
          PopupMenuButton<TaskCategory>(
            tooltip: 'Filter by category',
            onSelected: (c) =>
                provider.setFilter(TaskFilter.category, category: c),
            itemBuilder: (context) => TaskCategory.values
                .map((c) =>
                    PopupMenuItem(value: c, child: Text(c.label)))
                .toList(),
            child: ChoiceChip(
              label: Text(
                provider.filter == TaskFilter.category &&
                        provider.categoryFilter != null
                    ? provider.categoryFilter!.label
                    : 'Category',
              ),
              selected: provider.filter == TaskFilter.category,
              onSelected: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}
