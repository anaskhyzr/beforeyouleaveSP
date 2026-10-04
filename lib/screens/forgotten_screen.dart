import 'package:flutter/material.dart';

import '../models/forgotten_record.dart';
import '../services/hive_service.dart';
import '../widgets/empty_state.dart';

class ForgottenScreen extends StatefulWidget {
  const ForgottenScreen({super.key});

  @override
  State<ForgottenScreen> createState() => _ForgottenScreenState();
}

class _ForgottenScreenState extends State<ForgottenScreen> {
  List<ForgottenRecord> _records = [];

  @override
  void initState() {
    super.initState();
    HiveService.dataRevisionNotifier.addListener(_onDataChanged);
    _loadRecords();
  }

  @override
  void dispose() {
    HiveService.dataRevisionNotifier.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final records = await HiveService.getForgottenRecords();
    if (!mounted) return;
    setState(() {
      _records = records;
    });
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Forgotten History?'),
        content: const Text(
          'This will permanently delete all records of forgotten items.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await HiveService.clearForgottenRecords();
      await _loadRecords();
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays == 0) {
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return 'Today at $hour:$min $period';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Forgotten Items'),
            const SizedBox(height: 2),
            Text(
              'Items left behind during past departures',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        toolbarHeight: 68,
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              tooltip: 'Clear history',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: _records.isEmpty
          ? const EmptyState(
              icon: Icons.history_rounded,
              title: 'No forgotten items!',
              description:
                  'You haven\'t left any items behind yet. When you leave a place with unchecked items, they will appear here so you can spot habits.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              itemCount: _records.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final rec = _records[index];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left frequency badge
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: rec.count > 2
                                ? const Color(0xFFFEE2E2) // Soft red
                                : const Color(0xFFFEF3C7), // Soft amber
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${rec.count}x',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: rec.count > 2
                                  ? const Color(0xFFB91C1C)
                                  : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Middle item details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rec.itemName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      rec.locationName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDate(rec.lastForgottenAt),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.outline,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Right tag
                        Text(
                          'Forgotten ${rec.count} ${rec.count == 1 ? 'time' : 'times'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
