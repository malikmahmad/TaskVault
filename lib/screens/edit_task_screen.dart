import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import '../widgets/task_form.dart';

class EditTaskScreen extends StatefulWidget {
  const EditTaskScreen({super.key, required this.task});

  final Task task;

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  bool _submitting = false;

  Future<void> _handleSubmit(TaskFormResult result) async {
    setState(() => _submitting = true);
    final provider = context.read<TaskProvider>();
    final success = await provider.editTask(
      widget.task,
      title: result.title,
      description: result.description,
      category: result.category,
      priority: result.priority,
      dueDate: result.dueDate,
      clearDueDate: result.dueDate == null,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task updated')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Could not update task'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Task')),
      body: TaskForm(
        submitLabel: 'Save Changes',
        isSubmitting: _submitting,
        initialTitle: widget.task.title,
        initialDescription: widget.task.description,
        initialCategory: widget.task.category,
        initialPriority: widget.task.priority,
        initialDueDate: widget.task.dueDate,
        onSubmit: _handleSubmit,
      ),
    );
  }
}
