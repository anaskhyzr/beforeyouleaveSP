import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/location.dart';
import 'package:flutter_application_1/models/checklist_item.dart';
import 'package:flutter_application_1/models/forgotten_record.dart';
import 'package:flutter_application_1/services/hive_service.dart';
import 'package:flutter_application_1/theme/app_icons.dart';
import 'package:flutter_application_1/widgets/empty_state.dart';
import 'package:flutter_application_1/widgets/remaining_items_warning.dart';
import 'package:flutter_application_1/widgets/checklist_item_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory testDataDirectory;

  setUpAll(() async {
    testDataDirectory = await Directory.systemTemp.createTemp(
      'before_you_leave_tests_',
    );
    await HiveService.init(path: testDataDirectory.path);
  });

  setUp(() async {
    await HiveService.clearAllData();
  });

  group('Data Storage Tests', () {
    test('Fresh app starts with no sample locations', () async {
      expect(await HiveService.getLocations(), isEmpty);
      expect(await HiveService.getForgottenRecords(), isEmpty);
    });

    test('Sample data can be loaded explicitly by the user', () async {
      await HiveService.seedSampleData(force: true);

      final locations = await HiveService.getLocations();
      expect(locations, isNotEmpty);
      expect(
        locations.map((location) => location.name),
        containsAll(['Home', 'University', 'Office']),
      );
      expect(
        await HiveService.getItemsForLocation(locations.first.id),
        isNotEmpty,
      );
    });
  });

  group('Models Unit Tests', () {
    test('Location creation and default values', () {
      final now = DateTime.now();
      final loc = Location(
        id: 'loc-1',
        name: 'University',
        iconKey: 'school',
        createdAt: now,
      );

      expect(loc.id, 'loc-1');
      expect(loc.name, 'University');
      expect(loc.iconKey, 'school');
      expect(loc.createdAt, now);
      expect(loc.lastLeftAt, isNull);
      expect(loc.isPinned, isFalse);
      expect(loc.isArchived, isFalse);
      expect(loc.colorKey, isNull);
    });

    test('ChecklistItem creation and defaults', () {
      final item = ChecklistItem(
        id: 'item-1',
        locationId: 'loc-1',
        name: 'Laptop Charger',
      );

      expect(item.id, 'item-1');
      expect(item.locationId, 'loc-1');
      expect(item.name, 'Laptop Charger');
      expect(item.isChecked, isFalse);
    });

    test('ForgottenRecord creation and frequency increment', () {
      final now = DateTime.now();
      final record = ForgottenRecord(
        id: 'rec-1',
        itemName: 'Keys',
        locationId: 'loc-1',
        locationName: 'Home',
        count: 1,
        lastForgottenAt: now,
      );

      expect(record.count, 1);
      record.count += 1;
      expect(record.count, 2);
    });
  });

  group('AppIcons Tests', () {
    test('Returns correct icon for known keys', () {
      expect(AppIcons.getIconData('home'), Icons.home_rounded);
      expect(AppIcons.getIconData('school'), Icons.school_rounded);
      expect(AppIcons.getIconData('work'), Icons.business_center_rounded);
      expect(AppIcons.getIconData('gym'), Icons.fitness_center_rounded);
      expect(AppIcons.getIconData('travel'), Icons.flight_takeoff_rounded);
    });

    test('Falls back to default icon for unknown key', () {
      expect(AppIcons.getIconData('unknown_xyz'), Icons.place_rounded);
      expect(AppIcons.getIconData(null), Icons.place_rounded);
    });
  });

  group('Widget Tests', () {
    testWidgets('EmptyState displays title, description, and action button', (
      tester,
    ) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.place_outlined,
              title: 'Nothing here yet.',
              description: 'Create a checklist for a place.',
              actionLabel: 'Add location',
              onAction: () {
                actionTriggered = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Nothing here yet.'), findsOneWidget);
      expect(find.text('Create a checklist for a place.'), findsOneWidget);
      expect(find.text('Add location'), findsOneWidget);

      await tester.tap(find.text('Add location'));
      expect(actionTriggered, isTrue);
    });

    testWidgets('RemainingItemsWarning shows alert when items are unchecked', (
      tester,
    ) async {
      final unchecked = [
        ChecklistItem(id: '1', locationId: 'loc1', name: 'Notebook'),
        ChecklistItem(id: '2', locationId: 'loc1', name: 'Earphones'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemainingItemsWarning(
              uncheckedItems: unchecked,
              totalCount: 2,
            ),
          ),
        ),
      );

      expect(
        find.textContaining('You still have 2 items remaining:'),
        findsOneWidget,
      );
      expect(find.text('Notebook'), findsOneWidget);
      expect(find.text('Earphones'), findsOneWidget);
    });

    testWidgets(
      'RemainingItemsWarning shows success when all items are checked',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: RemainingItemsWarning(uncheckedItems: [], totalCount: 3),
            ),
          ),
        );

        expect(find.text('✓ Everything is packed'), findsOneWidget);
        expect(
          find.text('You are all set and ready to leave.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('ChecklistItemTile toggles check and calls callbacks', (
      tester,
    ) async {
      final item = ChecklistItem(
        id: '1',
        locationId: 'loc1',
        name: 'Water Bottle',
        isChecked: false,
      );

      bool toggled = false;
      bool edited = false;
      bool deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChecklistItemTile(
              item: item,
              onToggle: (val) => toggled = val,
              onEdit: () => edited = true,
              onDelete: () => deleted = true,
            ),
          ),
        ),
      );

      expect(find.text('Water Bottle'), findsOneWidget);

      // Tap tile to toggle
      await tester.tap(find.text('Water Bottle'));
      expect(toggled, isTrue);

      // Tap edit button
      await tester.tap(find.byTooltip('Edit item'));
      expect(edited, isTrue);

      // Tap delete button
      await tester.tap(find.byTooltip('Delete item'));
      expect(deleted, isTrue);
    });
  });
}
