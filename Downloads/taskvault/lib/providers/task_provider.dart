import 'package:flutter/material.dart';

import '../models/task.dart';
import '../repositories/task_repository.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

enum ViewStatus { loading, ready, error }

/// The single source of truth for task UI state. Widgets read from this
/// provider and call its methods; all persistence goes through
/// [TaskRepository] — no widget or provider method touches Hive directly.
class TaskProvider extends ChangeNotifier {
  TaskProvider({TaskRepository? repository})
      : _repository = repository ?? TaskRepository();

  final TaskRepository _repository;

  List<Task> _tasks = [];
  ViewStatus _status = ViewStatus.loading;
  String? _errorMessage;

  String _searchQuery = '';
  TaskFilter _filter = TaskFilter.all;
  TaskCategory? _categoryFilter;
  TaskSort _sort = TaskSort.newestFirst;
  ThemeMode _themeMode = ThemeMode.system;

  // ---- Read-only state exposed to the UI ----------------------------------

  ViewStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  TaskFilter get filter => _filter;
  TaskCategory? get categoryFilter => _categoryFilter;
  TaskSort get sort => _sort;
  ThemeMode get themeMode => _themeMode;

  List<Task> get tasks => List.unmodifiable(_visibleTasks());

  /// Unfiltered list — used where a screen needs to look up a specific task
  /// by id regardless of the dashboard's current search/filter state.
  List<Task> get allTasks => List.unmodifiable(_tasks);

  int get totalCount => _tasks.length;
  int get pendingCount => _tasks.where((t) => !t.isCompleted).length;
  int get completedCount => _tasks.where((t) => t.isCompleted).length;
  int get highPriorityCount =>
      _tasks.where((t) => t.priority == TaskPriority.high && !t.isCompleted).length;

  // ---- Theme ---------------------------------------------------------------

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  // ---- Lifecycle ------------------------------------------------------------

  Future<void> load({String? testDirectoryPath, List<int>? testEncryptionKey}) async {
    _status = ViewStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.init(
        testDirectoryPath: testDirectoryPath,
        testEncryptionKey: testEncryptionKey,
      );
      _tasks = _repository.getAllTasks();
      _status = ViewStatus.ready;
    } on StorageException catch (e) {
      _status = ViewStatus.error;
      _errorMessage = e.message;
    } catch (e) {
      _status = ViewStatus.error;
      _errorMessage = 'Something went wrong while loading your tasks.';
    }
    notifyListeners();
  }

  Future<void> _reloadFromRepository() async {
    _tasks = _repository.getAllTasks();
  }

  // ---- CRUD ----------------------------------------------------------------

  Future<bool> addTask({
    required String title,
    String description = '',
    TaskCategory category = TaskCategory.other,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
  }) async {
    return _runGuarded(() async {
      await _repository.createTask(
        title: title,
        description: description,
        category: category,
        priority: priority,
        dueDate: dueDate,
      );
      await _reloadFromRepository();
    }, failureMessage: 'Could not save the task. Please try again.');
  }

  Future<bool> editTask(
    Task task, {
    String? title,
    String? description,
    TaskCategory? category,
    TaskPriority? priority,
    DateTime? dueDate,
    bool clearDueDate = false,
  }) async {
    return _runGuarded(() async {
      await _repository.updateTask(
        task,
        title: title,
        description: description,
        category: category,
        priority: priority,
        dueDate: dueDate,
        clearDueDate: clearDueDate,
      );
      await _reloadFromRepository();
    }, failureMessage: 'Could not update the task. Please try again.');
  }

  Future<bool> toggleCompleted(Task task) async {
    return _runGuarded(() async {
      await _repository.toggleCompleted(task);
      await _reloadFromRepository();
    }, failureMessage: 'Could not update task status.');
  }

  Future<bool> deleteTask(String id) async {
    return _runGuarded(() async {
      await _repository.deleteTask(id);
      await _reloadFromRepository();
    }, failureMessage: 'Could not delete the task. Please try again.');
  }

  Future<bool> clearAllTasks() async {
    return _runGuarded(() async {
      await _repository.clearAll();
      await _reloadFromRepository();
    }, failureMessage: 'Could not clear tasks.');
  }

  /// Runs a mutation, swallowing storage errors into a transient
  /// [_errorMessage] (surfaced via a snack-bar by the caller) without
  /// dropping the app into the full-screen error state.
  Future<bool> _runGuarded(
    Future<void> Function() action, {
    required String failureMessage,
  }) async {
    try {
      await action();
      _errorMessage = null;
      notifyListeners();
      return true;
    } on StorageException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = failureMessage;
      notifyListeners();
      return false;
    }
  }

  // ---- Search / filter / sort ---------------------------------------------

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilter(TaskFilter filter, {TaskCategory? category}) {
    _filter = filter;
    _categoryFilter = filter == TaskFilter.category ? category : null;
    notifyListeners();
  }

  void setSort(TaskSort sort) {
    _sort = sort;
    notifyListeners();
  }

  List<Task> _visibleTasks() {
    Iterable<Task> result = _tasks;

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      result = result.where((t) =>
          t.title.toLowerCase().contains(q) ||
          t.description.toLowerCase().contains(q) ||
          t.category.label.toLowerCase().contains(q));
    }

    switch (_filter) {
      case TaskFilter.all:
        break;
      case TaskFilter.pending:
        result = result.where((t) => !t.isCompleted);
        break;
      case TaskFilter.completed:
        result = result.where((t) => t.isCompleted);
        break;
      case TaskFilter.highPriority:
        result = result.where((t) => t.priority == TaskPriority.high);
        break;
      case TaskFilter.category:
        if (_categoryFilter != null) {
          result = result.where((t) => t.category == _categoryFilter);
        }
        break;
    }

    final list = result.toList();
    switch (_sort) {
      case TaskSort.newestFirst:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case TaskSort.oldestFirst:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case TaskSort.dueDate:
        list.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;
      case TaskSort.priority:
        list.sort((a, b) => b.priority.weight.compareTo(a.priority.weight));
        break;
    }
    return list;
  }
}
