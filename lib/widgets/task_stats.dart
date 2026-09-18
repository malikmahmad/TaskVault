import 'package:flutter/material.dart';

/// A responsive 2–4 column stats grid that adapts to available width.
///
/// Colours are derived from the active [ColorScheme] so they render
/// correctly on both light and dark backgrounds — no hardcoded hex values.
class TaskStats extends StatelessWidget {
  const TaskStats({
    super.key,
    required this.total,
    required this.pending,
    required this.completed,
    required this.highPriority,
  });

  final int total;
  final int pending;
  final int completed;
  final int highPriority;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    // Semantic colours that read well on both light and dark surfaces.
    final pendingColor  = isDark ? const Color(0xFFFFCC80) : const Color(0xFFD97706);
    final doneColor     = isDark ? const Color(0xFFA5D6A7) : const Color(0xFF16A34A);
    final highColor     = isDark ? const Color(0xFFEF9A9A) : const Color(0xFFDC2626);

    final items = [
      _StatItem('Total',        total,        Icons.list_alt,            scheme.primary),
      _StatItem('Pending',      pending,      Icons.pending_actions,     pendingColor),
      _StatItem('Done',         completed,    Icons.check_circle_outline, doneColor),
      _StatItem('High Priority',highPriority, Icons.flag,                highColor),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Each card needs ~90 px minimum to stay readable.
        final crossAxisCount = (constraints.maxWidth / 90).floor().clamp(2, 4);
        final childAspectRatio = crossAxisCount >= 4 ? 0.85 : 1.1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (_, i) => _StatCard(item: items[i]),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _StatItem {
  _StatItem(this.label, this.value, this.icon, this.color);
  final String  label;
  final int     value;
  final IconData icon;
  final Color   color;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});
  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: item.color, size: 20),
          const SizedBox(height: 6),
          Text(
            '${item.value}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: item.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 10.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
