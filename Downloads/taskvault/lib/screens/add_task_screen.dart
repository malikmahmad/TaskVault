import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/task_provider.dart';
import '../widgets/task_form.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  bool _submitting = false;

  Future<void> _handleSubmit(TaskFormResult result) async {
    setState(() => _submitting = true);
    final provider = context.read<TaskProvider>();
    final success = await provider.addTask(
      title: result.title,
      description: result.description,
      category: result.category,
      priority: result.priority,
      dueDate: result.dueDate,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task created')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Could not save task'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Task')),
      body: TaskForm(
        submitLabel: 'Save Task',
        isSubmitting: _submitting,
        onSubmit: _handleSubmit,
      ),
    );
  }
}
