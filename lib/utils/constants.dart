/// App-wide constants. Centralised so magic strings don't leak into widgets.
class AppConstants {
  AppConstants._();

  static const String appName = 'TaskVault';
  static const String taskBoxName = 'tasks_box_v1';
  static const String secureKeyStorageKey = 'taskvault_hive_encryption_key';
}

enum TaskFilter { all, pending, completed, highPriority, category }

enum TaskSort { newestFirst, oldestFirst, dueDate, priority }

extension TaskFilterX on TaskFilter {
  String get label {
    switch (this) {
      case TaskFilter.all:
        return 'All';
      case TaskFilter.pending:
        return 'Pending';
      case TaskFilter.completed:
        return 'Completed';
      case TaskFilter.highPriority:
        return 'High Priority';
      case TaskFilter.category:
        return 'Category';
    }
  }
}

extension TaskSortX on TaskSort {
  String get label {
    switch (this) {
      case TaskSort.newestFirst:
        return 'Newest first';
      case TaskSort.oldestFirst:
        return 'Oldest first';
      case TaskSort.dueDate:
        return 'Due date';
      case TaskSort.priority:
        return 'Priority';
    }
  }
}
