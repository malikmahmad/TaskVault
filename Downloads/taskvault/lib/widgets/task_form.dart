import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../utils/validators.dart';

/// Value object carrying the form's current input, handed back to the
/// caller on submit.
class TaskFormResult {
  TaskFormResult({
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.dueDate,
  });

  final String title;
  final String description;
  final TaskCategory category;
  final TaskPriority priority;
  final DateTime? dueDate;
}

class TaskForm extends StatefulWidget {
  const TaskForm({
    super.key,
    required this.onSubmit,
    required this.submitLabel,
    this.initialTitle = '',
    this.initialDescription = '',
    this.initialCategory = TaskCategory.other,
    this.initialPriority = TaskPriority.medium,
    this.initialDueDate,
    this.isSubmitting = false,
  });

  final String initialTitle;
  final String initialDescription;
  final TaskCategory initialCategory;
  final TaskPriority initialPriority;
  final DateTime? initialDueDate;
  final String submitLabel;
  final bool isSubmitting;
  final ValueChanged<TaskFormResult> onSubmit;

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late TaskCategory _category;
  late TaskPriority _priority;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController =
        TextEditingController(text: widget.initialDescription);
    _category = widget.initialCategory;
    _priority = widget.initialPriority;
    _dueDate = widget.initialDueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _dueDate ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    setState(() {
      _dueDate = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 23,
        time?.minute ?? 59,
      );
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(TaskFormResult(
      title: _titleController.text,
      description: _descriptionController.text,
      category: _category,
      priority: _priority,
      dueDate: _dueDate,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title *',
              hintText: 'e.g. Finish assignment',
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: Validators.title,
            maxLength: Validators.maxTitleLength,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'Add more detail…',
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            maxLength: Validators.maxDescriptionLength,
            validator: Validators.description,
          ),
          const SizedBox(height: 8),
          const _SectionLabel('Category'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TaskCategory.values.map((c) {
              return ChoiceChip(
                label: Text(c.label),
                selected: _category == c,
                onSelected: (_) => setState(() => _category = c),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Priority'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TaskPriority.values.map((p) {
              return ChoiceChip(
                label: Text(p.label),
                selected: _priority == p,
                onSelected: (_) => setState(() => _priority = p),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Due date & time'),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _dueDate == null
                        ? 'Pick date & time'
                        : DateFormat('MMM d, yyyy · h:mm a').format(_dueDate!),
                  ),
                ),
              ),
              if (_dueDate != null)
                IconButton(
                  tooltip: 'Clear due date',
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _dueDate = null),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: widget.isSubmitting ? null : _submit,
            child: widget.isSubmitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
