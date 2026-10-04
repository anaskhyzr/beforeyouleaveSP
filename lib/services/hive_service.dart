import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/checklist_item.dart';
import '../models/forgotten_record.dart';
import '../models/location.dart';

class HiveService {
  static const String _locationsBoxName = 'locations_v2';
  static const String _itemsBoxName = 'checklist_items_v2';
  static const String _forgottenBoxName = 'forgotten_records_v2';
  static const String _settingsBoxName = 'settings_v2';

  static late IsolatedBox<Location> _locationsBox;
  static late IsolatedBox<ChecklistItem> _itemsBox;
  static late IsolatedBox<ForgottenRecord> _forgottenBox;
  static late IsolatedBox<dynamic> _settingsBox;
  static bool _initialized = false;
  static final List<StreamSubscription<BoxEvent>> _boxSubscriptions = [];

  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);
  static final ValueNotifier<int> dataRevisionNotifier = ValueNotifier<int>(0);

  static Future<void> init({String? path}) async {
    if (_initialized) return;

    await IsolatedHive.initFlutter(subDirectory: path);

    if (!IsolatedHive.isAdapterRegistered(10)) {
      IsolatedHive.registerAdapter(LocationAdapter());
    }
    if (!IsolatedHive.isAdapterRegistered(11)) {
      IsolatedHive.registerAdapter(ChecklistItemAdapter());
    }
    if (!IsolatedHive.isAdapterRegistered(12)) {
      IsolatedHive.registerAdapter(ForgottenRecordAdapter());
    }

    _locationsBox = await IsolatedHive.openBox<Location>(_locationsBoxName);
    _itemsBox = await IsolatedHive.openBox<ChecklistItem>(_itemsBoxName);
    _forgottenBox = await IsolatedHive.openBox<ForgottenRecord>(
      _forgottenBoxName,
    );
    _settingsBox = await IsolatedHive.openBox<dynamic>(_settingsBoxName);

    await _loadThemeMode();
    _listenForBoxChanges();
    _initialized = true;
  }

  static void _listenForBoxChanges() {
    for (final box in [_locationsBox, _itemsBox, _forgottenBox]) {
      _boxSubscriptions.add(
        box.watch().listen(
          (_) => dataRevisionNotifier.value++,
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Hive box change stream failed: $error\n$stackTrace');
          },
        ),
      );
    }
  }

  // --- THEME & SETTINGS ---

  static Future<void> _loadThemeMode() async {
    final modeStr = await _settingsBox.get(
      'theme_mode',
      defaultValue: 'system',
    );
    switch (modeStr) {
      case 'light':
        themeModeNotifier.value = ThemeMode.light;
        break;
      case 'dark':
        themeModeNotifier.value = ThemeMode.dark;
        break;
      default:
        themeModeNotifier.value = ThemeMode.system;
    }
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    String modeStr = 'system';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    await _settingsBox.put('theme_mode', modeStr);
  }

  // --- LOCATIONS ---

  static Future<List<Location>> getLocations() async {
    final list = (await _locationsBox.values).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Future<Location?> getLocation(String id) {
    return _locationsBox.get(id);
  }

  static Future<void> saveLocation(Location location) async {
    await _locationsBox.put(location.id, location);
  }

  static Future<void> deleteLocation(String locationId) async {
    // Also delete all items associated with this location
    final itemsToDelete = (await _itemsBox.values)
        .where((item) => item.locationId == locationId)
        .map((item) => item.id)
        .toList();

    for (final itemId in itemsToDelete) {
      await _itemsBox.delete(itemId);
    }

    await _locationsBox.delete(locationId);
  }

  static Future<void> updateLocationLastLeft(
    String locationId,
    DateTime leftAt,
  ) async {
    final location = await _locationsBox.get(locationId);
    if (location != null) {
      location.lastLeftAt = leftAt;
      await _locationsBox.put(location.id, location);
    }
  }

  // --- CHECKLIST ITEMS ---

  static Future<List<ChecklistItem>> getItemsForLocation(
    String locationId,
  ) async {
    final list = (await _itemsBox.values)
        .where((item) => item.locationId == locationId)
        .toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  static Future<({int total, int checked})> getLocationProgress(
    String locationId,
  ) async {
    final items = (await _itemsBox.values).where(
      (item) => item.locationId == locationId,
    );
    final total = items.length;
    final checked = items.where((i) => i.isChecked).length;
    return (total: total, checked: checked);
  }

  static Future<void> saveItem(ChecklistItem item) async {
    await _itemsBox.put(item.id, item);
  }

  static Future<void> deleteItem(String itemId) async {
    await _itemsBox.delete(itemId);
  }

  static Future<void> toggleItemCheck(String itemId, bool isChecked) async {
    final item = await _itemsBox.get(itemId);
    if (item != null) {
      item.isChecked = isChecked;
      await _itemsBox.put(item.id, item);
    }
  }

  static Future<void> resetAllChecksForLocation(String locationId) async {
    final items = (await _itemsBox.values).where(
      (item) => item.locationId == locationId,
    );
    for (final item in items) {
      if (item.isChecked) {
        item.isChecked = false;
        await _itemsBox.put(item.id, item);
      }
    }
  }

  static Future<void> checkAllItemsForLocation(String locationId) async {
    final items = (await _itemsBox.values).where(
      (item) => item.locationId == locationId,
    );
    for (final item in items) {
      if (!item.isChecked) {
        item.isChecked = true;
        await _itemsBox.put(item.id, item);
      }
    }
  }

  // --- FORGOTTEN RECORDS ---

  static Future<List<ForgottenRecord>> getForgottenRecords() async {
    final list = (await _forgottenBox.values).toList();
    list.sort((a, b) {
      final countComp = b.count.compareTo(a.count);
      if (countComp != 0) return countComp;
      return b.lastForgottenAt.compareTo(a.lastForgottenAt);
    });
    return list;
  }

  static Future<void> recordForgottenItems(
    List<ChecklistItem> uncheckedItems,
    Location location,
  ) async {
    final now = DateTime.now();

    for (final item in uncheckedItems) {
      // Find matching item record by name and locationId
      ForgottenRecord? existing;
      for (final rec in await _forgottenBox.values) {
        if (rec.itemName.trim().toLowerCase() ==
                item.name.trim().toLowerCase() &&
            rec.locationId == location.id) {
          existing = rec;
          break;
        }
      }

      if (existing != null) {
        existing.count += 1;
        existing.lastForgottenAt = now;
        existing.locationName = location.name; // Keep name updated
        await _forgottenBox.put(existing.id, existing);
      } else {
        final record = ForgottenRecord(
          id: newId(),
          itemName: item.name.trim(),
          locationId: location.id,
          locationName: location.name,
          count: 1,
          lastForgottenAt: now,
        );
        await _forgottenBox.put(record.id, record);
      }
    }
  }

  static Future<void> clearForgottenRecords() async {
    await _forgottenBox.clear();
  }

  // --- SAMPLE DATA & SYSTEM RESET ---

  static Future<void> seedSampleData({bool force = false}) async {
    if (!force &&
        (await _locationsBox.isNotEmpty || await _itemsBox.isNotEmpty)) {
      return;
    }

    if (force) {
      await _locationsBox.clear();
      await _itemsBox.clear();
      await _forgottenBox.clear();
    }

    final home = Location(
      id: newId(),
      name: 'Home',
      iconKey: 'home',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      colorValue: 0xFFFFF9C4, // Pastel Yellow
      radiusMeters: 100.0,
      reminderMinutes: 480, // 8:00 AM
    );
    await saveLocation(home);

    final homeItems = ['Wallet', 'Keys', 'Phone', 'Charger'];
    for (final name in homeItems) {
      await saveItem(
        ChecklistItem(
          id: newId(),
          locationId: home.id,
          name: name,
          isChecked: false,
        ),
      );
    }

    final university = Location(
      id: newId(),
      name: 'University',
      iconKey: 'school',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      colorValue: 0xFFBBDEFB, // Pastel Sky Blue
      radiusMeters: 150.0,
      reminderMinutes: 840, // 2:00 PM
    );
    await saveLocation(university);

    final uniItems = [
      'Laptop',
      'Charger',
      'ID Card',
      'Notebook',
      'Water Bottle',
    ];
    for (final name in uniItems) {
      await saveItem(
        ChecklistItem(
          id: newId(),
          locationId: university.id,
          name: name,
          isChecked: false,
        ),
      );
    }

    final office = Location(
      id: newId(),
      name: 'Office',
      iconKey: 'work',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      colorValue: 0xFFC8E6C9, // Pastel Mint Green
      radiusMeters: 100.0,
      reminderMinutes: 1020, // 5:00 PM
    );
    await saveLocation(office);

    final officeItems = ['Laptop', 'ID Card', 'Notebook'];
    for (final name in officeItems) {
      await saveItem(
        ChecklistItem(
          id: newId(),
          locationId: office.id,
          name: name,
          isChecked: false,
        ),
      );
    }

    await _settingsBox.put('sample_data_loaded', true);
  }

  static Future<void> clearAllData() async {
    await _locationsBox.clear();
    await _itemsBox.clear();
    await _forgottenBox.clear();
    await _settingsBox.delete('sample_data_loaded');
  }

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
