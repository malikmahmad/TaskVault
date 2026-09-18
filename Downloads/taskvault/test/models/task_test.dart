import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:taskvault/models/task.dart';

// ---------------------------------------------------------------------------
// Adapter round-trip helpers.
//
// Hive's concrete BinaryWriterImpl / BinaryReaderImpl are internal (`part of
// hive`) and cannot be imported directly.  The public way to encode/decode a
// single object is to open a real (temp) Hive box, write to it, close it,
// and re-open it — this exercises the full TypeAdapter path including the
// binary frame format that is actually used on disk.
// ---------------------------------------------------------------------------

/// Fixed 32-byte test key — avoids any platform-channel touch
/// (no Keychain / Keystore needed in tests).
final _testKey = List<int>.generate(32, (i) => i);

Future<Task> _adapterRoundTrip(Task task) async {
  final dir = await Directory.systemTemp.createTemp('hive_adapter_test_');
  final boxName = 'adapter_rt_${task.id.hashCode}';
  try {
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TaskAdapter());
    final box = await Hive.openBox<Task>(
      boxName,
      encryptionCipher: HiveAesCipher(_testKey),
    );
    await box.put(task.id, task);
    await box.close();

    final reopened = await Hive.openBox<Task>(
      boxName,
      encryptionCipher: HiveAesCipher(_testKey),
    );
    final result = reopened.get(task.id)!;
    await reopened.close();
    return result;
  } finally {
    await dir.delete(recursive: true);
  }
}

// ---------------------------------------------------------------------------

void main() {
  group('Task model', () {
    test('creates a task with expected defaults', () {
      final task = Task(id: '1', title: 'Buy milk');

      expect(task.title, 'Buy milk');
      expect(task.description, '');
      expect(task.category, TaskCategory.other);
      expect(task.priority, TaskPriority.medium);
      expect(task.isCompleted, false);
      expect(task.dueDate, isNull);
      expect(task.createdAt, isNotNull);
      expect(task.updatedAt, isNotNull);
    });

    test('copyWith updates only provided fields and bumps updatedAt', () async {
      final original = Task(id: '1', title: 'Original');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final updated = original.copyWith(title: 'Changed', isCompleted: true);

      expect(updated.id, original.id);
      expect(updated.title, 'Changed');
      expect(updated.isCompleted, true);
      expect(updated.description, original.description);
      expect(updated.createdAt, original.createdAt);
      expect(updated.updatedAt.isAfter(original.updatedAt), true);
    });

    test('copyWith preserves every unset field', () {
      final due = DateTime(2027, 6, 1, 9, 0);
      final original = Task(
        id: 'x',
        title: 'Original',
        description: 'Desc',
        category: TaskCategory.work,
        priority: TaskPriority.high,
        dueDate: due,
        isCompleted: false,
      );

      // Only change isCompleted — everything else must stay identical.
      final copy = original.copyWith(isCompleted: true);

      expect(copy.id, original.id);
      expect(copy.title, original.title);
      expect(copy.description, original.description);
      expect(copy.category, original.category);
      expect(copy.priority, original.priority);
      expect(copy.dueDate, original.dueDate);
      expect(copy.createdAt, original.createdAt);
      expect(copy.isCompleted, true);
    });

    test('copyWith with clearDueDate removes the due date', () {
      final original = Task(
        id: '1',
        title: 'Task',
        dueDate: DateTime(2026, 1, 1),
      );
      final updated = original.copyWith(clearDueDate: true);
      expect(updated.dueDate, isNull);
    });

    test('toMap/fromMap round-trip preserves all fields', () {
      final task = Task(
        id: 'abc-123',
        title: 'Write report',
        description: 'Quarterly report',
        category: TaskCategory.work,
        priority: TaskPriority.high,
        dueDate: DateTime(2026, 3, 15, 9, 30),
        isCompleted: true,
      );

      final map = task.toMap();
      final restored = Task.fromMap(map);

      expect(restored.id, task.id);
      expect(restored.title, task.title);
      expect(restored.description, task.description);
      expect(restored.category, task.category);
      expect(restored.priority, task.priority);
      expect(restored.dueDate, task.dueDate);
      expect(restored.isCompleted, task.isCompleted);
      expect(restored.createdAt, task.createdAt);
      expect(restored.updatedAt, task.updatedAt);
    });

    test('fromMap handles a null dueDate', () {
      final task = Task(id: '1', title: 'No due date');
      final restored = Task.fromMap(task.toMap());
      expect(restored.dueDate, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // TaskAdapter — binary serialisation round-trip via a real encrypted Hive
  // box (temp directory, fixed test key — no platform channels needed).
  // -------------------------------------------------------------------------

  group('TaskAdapter (Hive binary)', () {
    test('typeId is 0', () {
      expect(TaskAdapter().typeId, 0);
    });

    test('round-trip preserves all 9 fields for a fully-populated task',
        () async {
      final task = Task(
        id: 'adapter-full',
        title: 'Adapter task',
        description: 'Some details',
        category: TaskCategory.study,
        priority: TaskPriority.high,
        dueDate: DateTime(2026, 12, 31, 23, 59),
        isCompleted: true,
        createdAt: DateTime(2026, 1, 1, 8, 0),
        updatedAt: DateTime(2026, 6, 15, 12, 0),
      );

      final restored = await _adapterRoundTrip(task);

      expect(restored.id, task.id);
      expect(restored.title, task.title);
      expect(restored.description, task.description);
      expect(restored.category, task.category);
      expect(restored.priority, task.priority);
      expect(restored.dueDate, task.dueDate);
      expect(restored.isCompleted, task.isCompleted);
      expect(restored.createdAt, task.createdAt);
      expect(restored.updatedAt, task.updatedAt);
    });

    test('round-trip preserves a null dueDate', () async {
      final task = Task(id: 'adapter-no-date', title: 'No due date');
      final restored = await _adapterRoundTrip(task);
      expect(restored.dueDate, isNull);
    });

    test('round-trip works for every TaskCategory value', () async {
      for (final cat in TaskCategory.values) {
        final task = Task(
          id: 'cat-${cat.index}',
          title: 'Cat test',
          category: cat,
        );
        final restored = await _adapterRoundTrip(task);
        expect(restored.category, cat,
            reason: 'Category $cat did not survive binary round-trip');
      }
    });

    test('round-trip works for every TaskPriority value', () async {
      for (final pri in TaskPriority.values) {
        final task = Task(
          id: 'pri-${pri.index}',
          title: 'Pri test',
          priority: pri,
        );
        final restored = await _adapterRoundTrip(task);
        expect(restored.priority, pri,
            reason: 'Priority $pri did not survive binary round-trip');
      }
    });
  });

  // -------------------------------------------------------------------------
  // TaskPriority semantics
  // -------------------------------------------------------------------------

  group('TaskPriority', () {
    test('weight ordering: high > medium > low', () {
      expect(
          TaskPriority.high.weight, greaterThan(TaskPriority.medium.weight));
      expect(
          TaskPriority.medium.weight, greaterThan(TaskPriority.low.weight));
    });

    test('labels are non-empty strings', () {
      for (final p in TaskPriority.values) {
        expect(p.label, isNotEmpty);
      }
    });
  });

  // -------------------------------------------------------------------------
  // TaskCategory semantics
  // -------------------------------------------------------------------------

  group('TaskCategory', () {
    test('labels are non-empty strings', () {
      for (final c in TaskCategory.values) {
        expect(c.label, isNotEmpty);
      }
    });

    test('every value has a distinct label', () {
      final labels = TaskCategory.values.map((c) => c.label).toList();
      expect(labels.toSet().length, labels.length);
    });
  });
}
