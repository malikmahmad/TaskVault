import 'package:uuid/uuid.dart';

import '../models/task.dart';
import '../services/storage_service.dart';

/// Mediates between the provider (view-model) layer and the storage
/// service. This is the only place that knows how a "task operation"
/// maps onto storage calls — providers never touch [StorageService]
/// directly, and widgets never touch either.
class TaskRepository {
  TaskRepository({StorageService? storageService, Uuid? uuid})
      : _storage = storageService ?? StorageService(),
        _uuid = uuid ?? const Uuid();

  final StorageService _storage;
  final Uuid _uuid;

  Future<void> init({String? testDirectoryPath, List<int>? testEncryptionKey}) =>
      _storage.init(
        testDirectoryPath: testDirectoryPath,
        testEncryptionKey: testEncryptionKey,
      );

  List<Task> getAllTasks() => _storage.getAll();

  Future<Task> createTask({
    required String title,
    String description = '',
    TaskCategory category = TaskCategory.other,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
  }) async {
    final task = Task(
      id: _uuid.v4(),
      title: title.trim(),
      description: description.trim(),
      category: category,
      priority: priority,
      dueDate: dueDate,
    );
    await _storage.put(task);
    return task;
  }

  Future<Task> updateTask(Task existing, {
    String? title,
    String? description,
    TaskCategory? category,
    TaskPriority? priority,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? isCompleted,
  }) async {
    final updated = existing.copyWith(
      title: title?.trim(),
      description: description?.trim(),
      category: category,
      priority: priority,
      dueDate: dueDate,
      clearDueDate: clearDueDate,
      isCompleted: isCompleted,
    );
    await _storage.put(updated);
    return updated;
  }

  Future<Task> toggleCompleted(Task task) async {
    final updated = task.copyWith(isCompleted: !task.isCompleted);
    await _storage.put(updated);
    return updated;
  }

  Future<void> deleteTask(String id) => _storage.delete(id);

  Future<void> clearAll() => _storage.clearAll();

  Future<void> close() => _storage.close();

  int get storedTaskCount => _storage.storedTaskCount;
}
