import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskvault/models/task.dart';
import 'package:taskvault/repositories/task_repository.dart';
import 'package:taskvault/services/storage_service.dart';

/// A fixed 32-byte key so tests never touch real secure storage /
/// platform channels — Hive still encrypts the box exactly as it would
/// in production, just with a test-only key.
final _testKey = List<int>.generate(32, (i) => i);

void main() {
  late Directory tempDir;
  late TaskRepository repository;
  late String boxNameForTest;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('taskvault_test_');
    boxNameForTest = 'tasks_box_test_${DateTime.now().microsecondsSinceEpoch}';
    repository = TaskRepository(
      storageService: StorageService(boxName: boxNameForTest),
    );
    await repository.init(
      testDirectoryPath: tempDir.path,
      testEncryptionKey: _testKey,
    );
  });

  tearDown(() async {
    await repository.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('TaskRepository CRUD', () {
    test('starts empty', () {
      expect(repository.getAllTasks(), isEmpty);
    });

    test('create adds a task that can be read back', () async {
      final created = await repository.createTask(title: 'Buy groceries');

      final all = repository.getAllTasks();
      expect(all, hasLength(1));
      expect(all.first.id, created.id);
      expect(all.first.title, 'Buy groceries');
    });

    test('update changes fields and bumps updatedAt', () async {
      final task = await repository.createTask(title: 'Draft');
      await Future<void>.delayed(const Duration(milliseconds: 2));

      final updated = await repository.updateTask(
        task,
        title: 'Final',
        priority: TaskPriority.high,
      );

      expect(updated.title, 'Final');
      expect(updated.priority, TaskPriority.high);
      expect(updated.updatedAt.isAfter(task.updatedAt), true);
      expect(repository.getAllTasks().first.title, 'Final');
    });

    test('toggleCompleted flips completion state', () async {
      final task = await repository.createTask(title: 'Task');
      expect(task.isCompleted, false);

      final toggled = await repository.toggleCompleted(task);
      expect(toggled.isCompleted, true);

      final toggledAgain = await repository.toggleCompleted(toggled);
      expect(toggledAgain.isCompleted, false);
    });

    test('delete removes the task permanently', () async {
      final task = await repository.createTask(title: 'Temp task');
      expect(repository.getAllTasks(), hasLength(1));

      await repository.deleteTask(task.id);
      expect(repository.getAllTasks(), isEmpty);
    });

    test('clearAll empties the store', () async {
      await repository.createTask(title: 'One');
      await repository.createTask(title: 'Two');
      expect(repository.getAllTasks(), hasLength(2));

      await repository.clearAll();
      expect(repository.getAllTasks(), isEmpty);
    });

    test('data persists across close + re-open with the same key', () async {
      await repository.createTask(title: 'Persisted task');
      await repository.close();

      final reopened = TaskRepository(
        storageService: StorageService(boxName: boxNameForTest),
      );
      await reopened.init(
        testDirectoryPath: tempDir.path,
        testEncryptionKey: _testKey,
      );

      final all = reopened.getAllTasks();
      expect(all, hasLength(1));
      expect(all.first.title, 'Persisted task');

      await reopened.close();
    });
  });
}
