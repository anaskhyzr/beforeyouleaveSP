import 'package:flutter/material.dart';

import '../models/location.dart';
import '../services/hive_service.dart';
import '../services/location_service.dart';
import '../services/reminder_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _changeTheme(ThemeMode mode) async {
    await HiveService.setThemeMode(mode);
    setState(() {});
  }

  Future<void> _resetToSampleData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load Sample Data?'),
        content: const Text(
          'This will reset your checklists with default sample places (Home, University, Office). Any existing data will be replaced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Load Sample Data'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await HiveService.seedSampleData(force: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sample data loaded successfully.')),
      );
    }
  }

  Future<void> _clearForgottenHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Forgotten History?'),
        content: const Text(
          'This will delete all logs of forgotten items. Your locations and checklists will remain intact.',
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
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await HiveService.clearForgottenRecords();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Forgotten history cleared.')),
      );
    }
  }

  Future<void> _clearAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all locations, checklist items, and forgotten history.',
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
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await HiveService.clearAllData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data has been cleared.')),
      );
    }
  }

  Future<void> _testNotification() async {
    try {
      await ReminderService.showInstantTestNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification sent!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send notification: $e')),
      );
    }
  }

  Future<void> _testDepartureNotification() async {
    try {
      final dummyLoc = Location(
        id: 'test_departure_sample',
        name: 'Home (Sample)',
        iconKey: 'home',
        createdAt: DateTime.now(),
        radiusMeters: 100,
      );
      await ReminderService.showDepartureNotification(
        location: dummyLoc,
        distanceMeters: 125,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Departure notification sent with "Check All" & "See List" actions!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send notification: $e')),
      );
    }
  }

  Future<void> _checkLocationPermissions() async {
    final granted = await LocationService.checkAndRequestPermission();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'GPS Location permissions are active and granted!'
              : 'GPS Location permissions are denied or disabled.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentThemeMode = HiveService.themeModeNotifier.value;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Settings'),
            const SizedBox(height: 2),
            Text(
              'Preferences & Storage',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        toolbarHeight: 68,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // APPEARANCE SECTION
          _SectionHeader(title: 'Appearance', icon: Icons.palette_outlined),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode, size: 16),
                      ),
                    ],
                    selected: {currentThemeMode},
                    onSelectionChanged: (selected) {
                      _changeTheme(selected.first);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // NOTIFICATIONS SECTION
          _SectionHeader(
            title: 'Notifications',
            icon: Icons.notifications_outlined,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Icon(
                    Icons.near_me_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('Test Departure Alert'),
                  subtitle: const Text('Simulates leaving radius with "Check All" & "See List" buttons'),
                  trailing: FilledButton.tonal(
                    onPressed: _testDepartureNotification,
                    child: const Text('Send Alert'),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Icon(
                    Icons.notification_important_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('Test Simple Reminder'),
                  subtitle: const Text('Verify that basic reminder alerts work on this device'),
                  trailing: FilledButton.tonal(
                    onPressed: _testNotification,
                    child: const Text('Send Test'),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Icon(
                    Icons.location_on_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('GPS Location Permissions'),
                  subtitle: const Text('Check and grant device location access'),
                  trailing: OutlinedButton(
                    onPressed: _checkLocationPermissions,
                    child: const Text('Check'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // DATA MANAGEMENT SECTION
          _SectionHeader(
            title: 'Data Management',
            icon: Icons.storage_outlined,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.restore_page_outlined),
                  title: const Text('Load Sample Data'),
                  subtitle: const Text('Pre-populates Home, University, and Office checklists'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _resetToSampleData,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.history_toggle_off_rounded),
                  title: const Text('Clear Forgotten History'),
                  subtitle: const Text('Deletes all history records without removing checklists'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _clearForgottenHistory,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                  title: const Text(
                    'Clear All Data',
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: const Text('Wipes all locations, items, and settings'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.red),
                  onTap: _clearAllData,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ABOUT SECTION
          _SectionHeader(title: 'About', icon: Icons.info_outline_rounded),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.checklist_rtl_rounded,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Before You Leave',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Version 1.0.0 • Offline Utility',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A simple offline checklist app designed to prevent you from forgetting important belongings before leaving a place.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
