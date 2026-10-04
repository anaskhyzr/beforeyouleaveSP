import 'package:flutter/material.dart';

import '../models/checklist_item.dart';
import '../models/location.dart';
import '../services/hive_service.dart';
import '../services/location_service.dart';
import '../services/reminder_service.dart';
import '../theme/app_icons.dart';

class LocationCard extends StatelessWidget {
  final Location location;
  final List<ChecklistItem> items;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onRefresh;

  const LocationCard({
    super.key,
    required this.location,
    required this.items,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final total = items.length;
    final checked = items.where((i) => i.isChecked).length;
    final remaining = total - checked;

    final bool isEmpty = total == 0;
    final bool isAllChecked = !isEmpty && remaining == 0;

    // Card background color (Google Keep style)
    Color cardBg;
    if (isDark) {
      if (location.colorValue == 0xFFFFFFFF) {
        cardBg = colorScheme.surfaceContainer;
      } else {
        // Darken the pastel color slightly for dark theme
        cardBg = Color(location.colorValue).withValues(alpha: 0.22);
      }
    } else {
      cardBg = location.colorValue == 0xFFFFFFFF
          ? colorScheme.surface
          : Color(location.colorValue);
    }

    final Color statusColor = isEmpty
        ? colorScheme.outline
        : isAllChecked
        ? const Color(0xFF2E7D32)
        : const Color(0xFFD97706);

    final Color statusBg = isEmpty
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
        : isAllChecked
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFEF3C7);

    final String statusText = isEmpty
        ? 'No items'
        : isAllChecked
        ? 'Ready to leave ✓'
        : '$remaining remaining';

    final double progressFraction = total == 0 ? 0.0 : checked / total;

    // Show up to 4 preview items
    const maxPreviewCount = 4;
    final previewItems = items.take(maxPreviewCount).toList();
    final hiddenCount = total - previewItems.length;

    return Card(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? colorScheme.outlineVariant.withValues(alpha: 0.5)
              : Colors.black.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // HEADER ROW: Icon + Title + GPS/Time badges + Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark
                          ? colorScheme.primaryContainer.withValues(alpha: 0.7)
                          : colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      AppIcons.getIconData(location.iconKey),
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Badges for GPS and Time
                        Row(
                          children: [
                            if (location.hasGps) ...[
                              Icon(
                                Icons.near_me_rounded,
                                size: 12,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${location.radiusMeters.round()}m GPS',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (location.hasReminder) ...[
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: colorScheme.secondary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                ReminderService.formatMinutes(
                                  location.reminderMinutes,
                                ),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    padding: EdgeInsets.zero,
                    onSelected: (value) async {
                      if (value == 'simulate') {
                        await LocationService.simulateDeparture(location);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Simulated leaving "${location.name}"! Notification sent.',
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'simulate',
                        child: Row(
                          children: [
                            Icon(Icons.directions_run_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('Test Departure Alert'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Edit location'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red,
                            ),
                            SizedBox(width: 10),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // INLINE CHECKLIST PREVIEW (GOOGLE KEEP STYLE)
              if (isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No items yet. Tap to add checklist...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else ...[
                Column(
                  children: previewItems.map((item) {
                    return _InlineCheckItem(
                      item: item,
                      onToggle: (newVal) async {
                        await HiveService.toggleItemCheck(item.id, newVal);
                        onRefresh?.call();
                      },
                    );
                  }).toList(),
                ),
                if (hiddenCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 32, top: 4, bottom: 4),
                    child: Text(
                      '+ $hiddenCount more items...',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 10),

              // PROGRESS BAR (if not empty)
              if (!isEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressFraction,
                    minHeight: 4,
                    backgroundColor: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isAllChecked
                          ? const Color(0xFF2E7D32)
                          : colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // STATUS ROW
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? statusBg.withValues(alpha: 0.2)
                          : statusBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  if (!isEmpty)
                    Text(
                      '$checked/$total',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineCheckItem extends StatelessWidget {
  final ChecklistItem item;
  final ValueChanged<bool> onToggle;

  const _InlineCheckItem({required this.item, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: Checkbox(
              value: item.isChecked,
              onChanged: (val) {
                if (val != null) onToggle(val);
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                decoration: item.isChecked ? TextDecoration.lineThrough : null,
                color: item.isChecked
                    ? colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
                    : colorScheme.onSurface,
                fontWeight: item.isChecked
                    ? FontWeight.normal
                    : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
