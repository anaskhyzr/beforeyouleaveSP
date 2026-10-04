import 'package:flutter/material.dart';

import '../models/checklist_item.dart';
import '../models/location.dart';
import '../services/hive_service.dart';
import '../services/location_service.dart';
import '../services/reminder_service.dart';
import '../theme/app_icons.dart';
import '../widgets/checklist_item_tile.dart';
import '../widgets/empty_state.dart';
import '../widgets/remaining_items_warning.dart';
import 'location_form_screen.dart';

class ChecklistScreen extends StatefulWidget {
  final Location location;

  const ChecklistScreen({super.key, required this.location});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  late Location _location;
  List<ChecklistItem> _items = [];
  final TextEditingController _addItemController = TextEditingController();
  final FocusNode _addItemFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _location = widget.location;
    HiveService.dataRevisionNotifier.addListener(_onDataChanged);
    _loadItems();
  }

  @override
  void dispose() {
    _addItemController.dispose();
    _addItemFocusNode.dispose();
    HiveService.dataRevisionNotifier.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await HiveService.getItemsForLocation(_location.id);
    if (!mounted) return;
    setState(() {
      _items = items;
    });
  }

  Future<void> _addItem() async {
    final text = _addItemController.text.trim();
    if (text.isEmpty) return;

    final newItem = ChecklistItem(
      id: HiveService.newId(),
      locationId: _location.id,
      name: text,
      isChecked: false,
    );

    await HiveService.saveItem(newItem);
    _addItemController.clear();
    await _loadItems();
    _addItemFocusNode.requestFocus();
  }

  Future<void> _toggleItem(ChecklistItem item, bool isChecked) async {
    setState(() {
      item.isChecked = isChecked;
    });
    await HiveService.toggleItemCheck(item.id, isChecked);
  }

  Future<void> _editItem(ChecklistItem item) async {
    final controller = TextEditingController(text: item.name);
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Item'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Item Name'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Item name cannot be empty' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated == true) {
      item.name = controller.text.trim();
      await HiveService.saveItem(item);
      await _loadItems();
    }
  }

  Future<void> _deleteItem(ChecklistItem item) async {
    final removedItem = item;
    await HiveService.deleteItem(item.id);
    await _loadItems();

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "${removedItem.name}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await HiveService.saveItem(removedItem);
            await _loadItems();
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _resetChecks() async {
    await HiveService.resetAllChecksForLocation(_location.id);
    await _loadItems();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Checklist reset for a new departure.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _checkAll() async {
    await HiveService.checkAllItemsForLocation(_location.id);
    await _loadItems();
  }

  Future<void> _editLocation() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationFormScreen(location: _location),
      ),
    );
    if (result == true) {
      final updated = await HiveService.getLocation(_location.id);
      if (updated != null) {
        setState(() => _location = updated);
      }
    }
  }

  Future<void> _deleteLocation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Location?'),
        content: Text(
          'This will permanently delete "${_location.name}" and all its checklist items.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await HiveService.deleteLocation(_location.id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _onLeave() async {
    final unchecked = _items.where((i) => !i.isChecked).toList();

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checklist is empty. Add items first.')),
      );
      return;
    }

    if (unchecked.isEmpty) {
      // Everything is checked!
      await HiveService.updateLocationLastLeft(_location.id, DateTime.now());
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_outline_rounded,
            size: 48,
            color: Color(0xFF2E7D32),
          ),
          title: const Text('Everything Checked!'),
          content: const Text(
            'Everything is packed. Have a safe and productive day!',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );

      // Auto-reset checks for next time
      await HiveService.resetAllChecksForLocation(_location.id);
      if (mounted) Navigator.pop(context, true);
    } else {
      // Some items unchecked! Show confirmation warning dialog
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            size: 44,
            color: Color(0xFFD97706),
          ),
          title: Text(
            'You still have ${unchecked.length} unchecked ${unchecked.length == 1 ? 'item' : 'items'}',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The following items are not checked yet:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 10),
                ...unchecked.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD97706),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'If you leave anyway, these items will be recorded in your Forgotten History.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'review'),
              child: const Text('Review items'),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFEF3C7),
                foregroundColor: const Color(0xFF92400E),
              ),
              onPressed: () => Navigator.pop(context, 'leave_anyway'),
              child: const Text('Leave anyway'),
            ),
          ],
        ),
      );

      if (result == 'leave_anyway') {
        await HiveService.recordForgottenItems(unchecked, _location);
        await HiveService.updateLocationLastLeft(_location.id, DateTime.now());
        // Reset checklist for next time
        await HiveService.resetAllChecksForLocation(_location.id);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recorded ${unchecked.length} forgotten ${unchecked.length == 1 ? 'item' : 'items'} in history.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final uncheckedItems = _items.where((i) => !i.isChecked).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              AppIcons.getIconData(_location.iconKey),
              size: 22,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _location.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Options',
            onSelected: (value) async {
              if (value == 'test_alert') {
                await LocationService.simulateDeparture(_location);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Simulated departure alert sent for "${_location.name}"!'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
              if (value == 'reset') await _resetChecks();
              if (value == 'check_all') await _checkAll();
              if (value == 'edit') await _editLocation();
              if (value == 'delete') await _deleteLocation();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'test_alert',
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
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Uncheck all items'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'check_all',
                child: Row(
                  children: [
                    Icon(Icons.done_all_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Check all items'),
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
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Delete location', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Subtitle banner with GPS & Reminder badges
            Container(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _items.isEmpty
                        ? 'Checklist is empty'
                        : '${_items.length} ${_items.length == 1 ? 'thing' : 'things'} to remember',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_location.hasGps || _location.hasReminder) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (_location.hasGps)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.near_me_rounded, size: 12, color: colorScheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'GPS Radius: ${_location.radiusMeters.round()}m',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_location.hasReminder)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time_rounded, size: 12, color: colorScheme.secondary),
                                const SizedBox(width: 4),
                                Text(
                                  'Daily Reminder: ${ReminderService.formatMinutes(_location.reminderMinutes)}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: _items.isEmpty
                  ? EmptyState(
                      icon: Icons.checklist_rounded,
                      title: 'Your checklist is empty',
                      description:
                          'Add the things you usually take with you when leaving ${_location.name}.',
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      children: [
                        ..._items.map(
                          (item) => ChecklistItemTile(
                            key: ValueKey(item.id),
                            item: item,
                            onToggle: (val) => _toggleItem(item, val),
                            onEdit: () => _editItem(item),
                            onDelete: () => _deleteItem(item),
                          ),
                        ),
                        RemainingItemsWarning(
                          uncheckedItems: uncheckedItems,
                          totalCount: _items.length,
                        ),
                      ],
                    ),
            ),

            // Quick Add Input Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addItemController,
                      focusNode: _addItemFocusNode,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _addItem(),
                      decoration: InputDecoration(
                        hintText: '+ Add item (e.g. Keys, Charger)',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: theme.cardTheme.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Add item',
                    onPressed: _addItem,
                    icon: const Icon(Icons.add_rounded, size: 20),
                  ),
                ],
              ),
            ),

            // Leave / Complete Action Bottom Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              color: theme.scaffoldBackgroundColor,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _items.isEmpty ? null : _onLeave,
                  icon: const Icon(Icons.exit_to_app_rounded, size: 20),
                  label: Text(
                    uncheckedItems.isEmpty
                        ? 'Done — Leave'
                        : 'Leave (${uncheckedItems.length} unchecked)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: uncheckedItems.isEmpty
                        ? const Color(0xFF2E7D32)
                        : colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}