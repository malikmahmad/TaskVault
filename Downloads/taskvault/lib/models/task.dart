import 'package:hive/hive.dart';

/// Category of a task.
enum TaskCategory { work, study, personal, shopping, other }

/// Priority level of a task.
enum TaskPriority { low, medium, high }

extension TaskCategoryX on TaskCategory {
  String get label {
    switch (this) {
      case TaskCategory.work:
        return 'Work';
      case TaskCategory.study:
        return 'Study';
      case TaskCategory.personal:
        return 'Personal';
      case TaskCategory.shopping:
        return 'Shopping';
      case TaskCategory.other:
        return 'Other';
    }
  }
}

extension TaskPriorityX on TaskPriority {
  String get label {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  /// Higher number = higher priority, used for sorting.
  int get weight {
    switch (this) {
      case TaskPriority.low:
        return 0;
      case TaskPriority.medium:
        return 1;
      case TaskPriority.high:
        return 2;
    }
  }
}

/// Core Task entity persisted in Hive.
///
/// Hive typeId registry (must stay stable across releases):
///   0 -> Task
///   1 -> TaskCategory
///   2 -> TaskPriority
class Task extends HiveObject {
  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.category = TaskCategory.other,
    this.priority = TaskPriority.medium,
    this.dueDate,
    this.isCompleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  String description;
  TaskCategory category;
  TaskPriority priority;

  /// Combined due date + time (nullable — a task may have no due date).
  DateTime? dueDate;

  bool isCompleted;
  final DateTime createdAt;
  DateTime updatedAt;

  Task copyWith({
    String? title,
    String? description,
    TaskCategory? category,
    TaskPriority? priority,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? isCompleted,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.index,
      'priority': priority.index,
      'dueDate': dueDate?.toIso8601String(),
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      category: TaskCategory.values[(map['category'] as int?) ?? 0],
      priority: TaskPriority.values[(map['priority'] as int?) ?? 1],
      dueDate:
          map['dueDate'] != null ? DateTime.parse(map['dueDate'] as String) : null,
      isCompleted: (map['isCompleted'] as bool?) ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

/// Hand-written adapter — avoids a build_runner/codegen dependency while
/// still giving Hive fully type-safe binary serialization.
class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return Task(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      category: TaskCategory.values[fields[3] as int],
      priority: TaskPriority.values[fields[4] as int],
      dueDate: fields[5] as DateTime?,
      isCompleted: fields[6] as bool,
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.category.index)
      ..writeByte(4)
      ..write(obj.priority.index)
      ..writeByte(5)
      ..write(obj.dueDate)
      ..writeByte(6)
      ..write(obj.isCompleted)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }
}
