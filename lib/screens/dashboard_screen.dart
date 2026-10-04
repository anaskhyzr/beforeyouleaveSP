import 'package:flutter/material.dart';

import '../models/checklist_item.dart';
import '../models/location.dart';
import '../services/hive_service.dart';
import '../services/location_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/location_card.dart';
import 'checklist_screen.dart';
import 'location_form_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Location> _locations = [];
  Map<String, List<ChecklistItem>> _itemsByLocation = {};
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    HiveService.dataRevisionNotifier.addListener(_onDataChanged);
    _loadLocations();
  }

  @override
  void dispose() {
    HiveService.dataRevisionNotifier.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    final generation = ++_loadGeneration;
    final locations = await HiveService.getLocations();
    final entries = await Future.wait(
      locations.map(
        (location) async => MapEntry(
          location.id,
          await HiveService.getItemsForLocation(location.id),
        ),
      ),
    );
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _locations = locations;
      _itemsByLocation = Map.fromEntries(entries);
    });
  }

  Future<void> _addLocation() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LocationFormScreen()),
    );
    if (created == true) {
      await _loadLocations();
    }
  }

  Future<void> _openChecklist(Location location) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChecklistScreen(location: location),
      ),
    );
    await _loadLocations();
  }

  Future<void> _editLocation(Location location) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationFormScreen(location: location),
      ),
    );
    if (updated == true) {
      await _loadLocations();
    }
  }

  Future<void> _deleteLocation(Location location) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Location?'),
        content: Text(
          'This will permanently delete "${location.name}" and all of its items.',
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
      await HiveService.deleteLocation(location.id);
      await _loadLocations();
    }
  }

  Future<void> _manualGpsCheck() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Checking GPS location and departures...'),
        duration: Duration(seconds: 2),
      ),
    );
    await LocationService.checkDepartures();
    await _loadLocations();
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
            const Text('Before You Leave'),
            const SizedBox(height: 2),
            Text(
              'Keep note checklists & departure alerts',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
        toolbarHeight: 68,
        actions: [
          IconButton(
            icon: const Icon(Icons.gps_fixed_rounded),
            tooltip: 'Check GPS & Departures Now',
            onPressed: _manualGpsCheck,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLocation,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Place'),
      ),
      body: _locations.isEmpty
          ? EmptyState(
              icon: Icons.place_outlined,
              title: 'Nothing here yet.',
              description:
                  'Create a checklist for a place you visit regularly (like University, Office, or Home).',
              actionLabel: 'Add your first location',
              onAction: _addLocation,
            )
          : RefreshIndicator(
              onRefresh: () async {
                await LocationService.checkDepartures();
                await _loadLocations();
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 640;

                  if (isWide) {
                    // Google Keep style multi-column layout
                    final col1 = <Location>[];
                    final col2 = <Location>[];
                    for (int i = 0; i < _locations.length; i++) {
                      if (i % 2 == 0) {
                        col1.add(_locations[i]);
                      } else {
                        col2.add(_locations[i]);
                      }
                    }

                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: col1.map((loc) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: LocationCard(
                                    location: loc,
                                    items: _itemsByLocation[loc.id] ?? const [],
                                    onTap: () => _openChecklist(loc),
                                    onEdit: () => _editLocation(loc),
                                    onDelete: () => _deleteLocation(loc),
                                    onRefresh: _loadLocations,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              children: col2.map((loc) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: LocationCard(
                                    location: loc,
                                    items: _itemsByLocation[loc.id] ?? const [],
                                    onTap: () => _openChecklist(loc),
                                    onEdit: () => _editLocation(loc),
                                    onDelete: () => _deleteLocation(loc),
                                    onRefresh: _loadLocations,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: _locations.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final loc = _locations[index];
                      return LocationCard(
                        location: loc,
                        items: _itemsByLocation[loc.id] ?? const [],
                        onTap: () => _openChecklist(loc),
                        onEdit: () => _editLocation(loc),
                        onDelete: () => _deleteLocation(loc),
                        onRefresh: _loadLocations,
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}
