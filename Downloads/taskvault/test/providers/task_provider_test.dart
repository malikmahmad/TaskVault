import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskvault/models/task.dart';
import 'package:taskvault/providers/task_provider.dart';
import 'package:taskvault/repositories/task_repository.dart';
import 'package:taskvault/services/storage_service.dart';
import 'package:taskvault/utils/constants.dart';

final _testKey = List<int>.generate(32, (i) => i * 2 % 256);

void main() {
  late Directory tempDir;
  late TaskProvider provider;
  late TaskRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('taskvault_provider_test_');
    final boxName = 'tasks_box_provider_test_${DateTime.now().microsecondsSinceEpoch}';
    repository = TaskRepository(storageService: StorageService(boxName: boxName));
    provider = TaskProvider(repository: repository);
    await provider.load(
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

  group('TaskProvider', () {
    test('loads into ready state with no tasks', () {
      expect(provider.status, ViewStatus.ready);
      expect(provider.tasks, isEmpty);
      expect(provider.totalCount, 0);
    });

    test('addTask adds and is reflected in tasks + stats', () async {
      final ok = await provider.addTask(
        title: 'Write tests',
        priority: TaskPriority.high,
      );

      expect(ok, true);
      expect(provider.tasks, hasLength(1));
      expect(provider.totalCount, 1);
      expect(provider.pendingCount, 1);
      expect(provider.highPriorityCount, 1);
    });

    test('editTask updates the underlying task', () async {
      await provider.addTask(title: 'Original');
      final task = provider.tasks.first;

      final ok = await provider.editTask(task, title: 'Updated');
      expect(ok, true);
      expect(provider.tasks.first.title, 'Updated');
    });

    test('toggleCompleted updates pending/completed counts', () async {
      await provider.addTask(title: 'Task A');
      final task = provider.tasks.first;

      await provider.toggleCompleted(task);
      expect(provider.completedCount, 1);
      expect(provider.pendingCount, 0);
    });

    test('deleteTask removes the task', () async {
      await provider.addTask(title: 'To delete');
      final task = provider.tasks.first;

      final ok = await provider.deleteTask(task.id);
      expect(ok, true);
      expect(provider.tasks, isEmpty);
    });

    test('search filters by title, description, and category', () async {
      await provider.addTask(title: 'Buy milk', description: 'From the store');
      await provider.addTask(title: 'Write report', category: TaskCategory.work);

      provider.setSearchQuery('milk');
      expect(provider.tasks, hasLength(1));
      expect(provider.tasks.first.title, 'Buy milk');

      provider.setSearchQuery('work');
      expect(provider.tasks, hasLength(1));
      expect(provider.tasks.first.title, 'Write report');

      provider.setSearchQuery('');
      expect(provider.tasks, hasLength(2));
    });

    test('filter: pending vs completed vs high priority', () async {
      await provider.addTask(title: 'Pending one');
      await provider.addTask(title: 'High one', priority: TaskPriority.high);
      await provider.addTask(title: 'Completed one');
      final toComplete =
          provider.tasks.firstWhere((t) => t.title == 'Completed one');
      await provider.toggleCompleted(toComplete);

      provider.setFilter(TaskFilter.pending);
      expect(provider.tasks.every((t) => !t.isCompleted), true);

      provider.setFilter(TaskFilter.completed);
      expect(provider.tasks.every((t) => t.isCompleted), true);

      provider.setFilter(TaskFilter.highPriority);
      expect(provider.tasks.every((t) => t.priority == TaskPriority.high), true);

      provider.setFilter(TaskFilter.all);
      expect(provider.tasks, hasLength(3));
    });

    test('filter: by category', () async {
      await provider.addTask(title: 'Work task', category: TaskCategory.work);
      await provider.addTask(title: 'Study task', category: TaskCategory.study);

      provider.setFilter(TaskFilter.category, category: TaskCategory.work);
      expect(provider.tasks, hasLength(1));
      expect(provider.tasks.first.category, TaskCategory.work);
    });

    test('sort: priority high to low', () async {
      await provider.addTask(title: 'Low', priority: TaskPriority.low);
      await provider.addTask(title: 'High', priority: TaskPriority.high);
      await provider.addTask(title: 'Medium', priority: TaskPriority.medium);

      provider.setSort(TaskSort.priority);
      final priorities = provider.tasks.map((t) => t.priority).toList();
      expect(priorities, [TaskPriority.high, TaskPriority.medium, TaskPriority.low]);
    });

    test('sort: due date, tasks without a due date sort last', () async {
      await provider.addTask(title: 'No date');
      await provider.addTask(title: 'Later', dueDate: DateTime(2027, 1, 1));
      await provider.addTask(title: 'Sooner', dueDate: DateTime(2026, 1, 1));

      provider.setSort(TaskSort.dueDate);
      final titles = provider.tasks.map((t) => t.title).toList();
      expect(titles, ['Sooner', 'Later', 'No date']);
    });
  });
}
