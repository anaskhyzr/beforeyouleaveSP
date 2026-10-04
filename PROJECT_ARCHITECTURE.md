# Before You Leave — Project Understanding and Architecture

## 1. Project Purpose

Before You Leave is a Flutter mobile application designed to help users prepare before leaving a recurring place such as home, university, office, gym, or another location. The app combines:

- custom location management
- per-location checklist tracking
- GPS-based departure detection
- daily time-based reminders
- local notification actions
- forgotten-item history tracking

The goal is to reduce the chance of forgetting essentials when leaving a place.

This is not a traditional client-server application. The "backend" here is essentially local data storage and system services running within the app itself.

---

## 2. High-Level Product Summary

The app behaves like a location-aware packing assistant:

1. A user creates a place (for example, Home or Office).
2. The user adds items relevant to that place (keys, laptop, charger, notebook, etc.).
3. The app tracks whether each item is checked.
4. The app monitors GPS or reminder timing for departure events.
5. When the user is leaving, the app sends a notification and prompts actions like:
   - Check all items
   - See the checklist
6. Forgotten-item history is logged so the user can see recurring mistakes and improve preparedness.

This makes it a hybrid of a checklist app, a reminder app, and a lightweight geofencing app.

---

## 3. Project Structure

The main project folders are:

- `lib/main.dart` — app bootstrap and root widget
- `lib/models/` — domain models for locations, checklist items, and forgotten records
- `lib/screens/` — major pages/screens of the app
- `lib/services/` — data persistence, GPS, notification services
- `lib/widgets/` — reusable UI components
- `lib/theme/` — app styling and color system
- `test/` — project tests

---

## 4. Frontend (UI Layer)

The UI is built in Flutter using Material 3 design. The app follows a multi-screen navigation structure with a bottom tab bar and card-based dashboard.

### 4.1 Entry Point

File: `lib/main.dart`

This file does the application bootstrap:

- Initializes Flutter bindings
- Initializes Hive storage
- Initializes reminder and notification services
- Starts the periodic GPS departure monitoring service
- Builds the root `MaterialApp`
- Watches the app theme from `HiveService.themeModeNotifier`

The root app is `BeforeYouLeaveApp`, which wraps the app in a `MaterialApp` with:

- custom light and dark themes
- navigator key for notification navigation
- `MainNavigationScreen` as the main screen

### 4.2 Navigation Shell

File: `lib/screens/main_navigation_screen.dart`

This screen contains a bottom navigation bar with three destinations:

- Places / Dashboard
- Forgotten
- Settings

It uses `IndexedStack` so the screens preserve state while switching tabs.

### 4.3 Dashboard Screen

File: `lib/screens/dashboard_screen.dart`

This is the main screen that displays all configured locations.

Responsibilities:

- loads all saved locations from Hive
- creates a Google Keep-inspired card layout
- opens location checklist details
- allows adding, editing, and deleting locations
- manually checks GPS departures
- supports pull-to-refresh

The dashboard uses the `LocationCard` widget to render each place as a stylized card.

The UI logic is built around a list of `Location` objects and is responsive for both mobile and wider layouts.

### 4.4 Checklist Screen

File: `lib/screens/checklist_screen.dart`

This is the heart of the app for each saved place.

Responsibilities:

- load all entries tied to a location
- add new checklist items
- edit an existing item
- delete an item with undo support
- mark items as checked or unchecked
- reset all checks for a new departure
- check all items at once
- confirm leaving the location with warning or success dialogs

The screen tracks a `Location` object and a local list of `ChecklistItem` entries.

Important behaviors:

- if the checklist is empty, it prompts the user to add items
- if all items are checked, the user is congratulated and the checklist is reset for next trip
- if some items remain unchecked, a detailed warning dialog appears before leaving

### 4.5 Location Form Screen

File: `lib/screens/location_form_screen.dart`

Used when creating or editing a saved place.

Allows the user to configure:

- location name
- icon selection
- GPS coordinates
- geofence radius in meters
- reminder time in minutes from midnight
- Keep-style card color

The form includes:

- validation for a required name
- GPS retrieval from device location services
- time picker for daily departure reminders
- schedule update after saving

### 4.6 Forgotten Screen

File: `lib/screens/forgotten_screen.dart`

This is a historical tracking screen for repeated forgotten items.

It likely loads and summarizes item records such as:

- item name
- location name
- number of times forgotten
- most recent forgotten date

This is important because it shows the user patterns like “you forget your charger at work after 3 times.”

### 4.7 Settings Screen

File: `lib/screens/settings_screen.dart`

This is the control center for app-wide preferences and maintenance tasks.

Features include:

- theme selection: system, light, dark
- loading sample data into the app
- clearing forgotten history
- deleting all data
- testing local notifications
- testing departure notifications
- checking location permission status

This screen is one of the most important user-facing control panels for app configuration.

### 4.8 Reusable Widgets

#### `LocationCard`
File: `lib/widgets/location_card.dart`

This widget renders each saved place with:

- icon
- name
- GPS and reminder badges
- checklist progress status
- preview of items
- actions: edit, delete, simulate departure alert

It uses a Google Keep-like aesthetic with pastel colors.

#### `ChecklistItemTile`
File: `lib/widgets/checklist_item_tile.dart`

This widget renders each checklist item row with:

- checkbox state
- item name with strikethrough when checked
- edit action
- delete action

#### `RemainingItemsWarning`
File: `lib/widgets/remaining_items_warning.dart`

This widget visualizes whether a user still has items unchecked. It has two states:

- remaining items are present
- everything has been packed

#### `EmptyState`
File: `lib/widgets/empty_state.dart`

A reusable empty-state component for empty checklists or empty dashboard states.

#### `IconPicker`
File: `lib/widgets/icon_picker.dart`

Lets the user choose a location icon from a list of predefined options.

### 4.9 Theme System

File: `lib/theme/app_theme.dart`

Defines custom light and dark theme data using Material 3 and color seeds. It gives the app a consistent visual style with:

- soft surface colors
- pill-shaped controls and rounded cards
- modern Material design styling
- separate themes for dark and light modes

---

## 5. Backend / Local Services Layer

There is no external backend server or database. The app uses local persistence and device services to simulate backend behavior.

### 5.1 Data Model Layer

Files:

- `lib/models/location.dart`
- `lib/models/checklist_item.dart`
- `lib/models/forgotten_record.dart`

#### `Location`
Represents a place the user creates.

Fields include:

- `id`
- `name`
- `iconKey`
- `createdAt`
- `lastLeftAt`
- `latitude`
- `longitude`
- `radiusMeters`
- `reminderMinutes`
- `colorValue`

Key computed getter:

- `hasGps` — true when coordinates exist
- `hasReminder` — true when reminder time is active

#### `ChecklistItem`
Represents a single item in a checklist.

Fields:

- `id`
- `locationId`
- `name`
- `isChecked`
- `createdAt`

#### `ForgottenRecord`
Represents a forgotten-item occurrence.

Fields:

- `id`
- `itemName`
- `locationId`
- `locationName`
- `count`
- `lastForgottenAt`

This is used for analytics / history of repeated mistakes.

### 5.2 Hive Persistence Service

File: `lib/services/hive_service.dart`

This is the main local storage service and the app’s effective backend system.

It uses Hive, a lightweight local NoSQL database, to store:

- locations
- checklist items
- forgotten records
- settings such as theme mode

Responsibilities:

- initialize boxes and adapters
- save and read locations
- save and read category checklist items
- update progress state
- store forgotten-item history
- clear/reset all app data
- seed sample data when the user chooses

Important features:

- `saveLocation()` / `deleteLocation()`
- `saveItem()` / `deleteItem()`
- `toggleItemCheck()`
- `resetAllChecksForLocation()`
- `checkAllItemsForLocation()`
- `recordForgottenItems()`
- `getForgottenRecords()`
- `clearForgottenRecords()`
- `seedSampleData(force: true)`

Because the app is offline-first, this service is the primary persistence layer for all state.

#### Hive Adapters
Each model is registered with a custom `TypeAdapter`:

- `LocationAdapter` with `typeId = 10`
- `ChecklistItemAdapter` with `typeId = 11`
- `ForgottenRecordAdapter` with `typeId = 12`

This allows Hive to serialize data reliably on disk.

### 5.3 Location Service

File: `lib/services/location_service.dart`

This service handles all geolocation-related logic.

Responsibilities:

- check whether device location services are enabled
- request and validate location permissions
- get current GPS position with timeout
- calculate distance between two coordinates
- check whether the user has left a configured place
- trigger departure notifications when they cross a geofence radius
- manage periodic departure monitoring via a timer

Important logic:

- `checkAndRequestPermission()` ensures location permission is granted before accessing GPS
- `getCurrentPosition()` returns the current coordinates with a 12-second timeout
- `checkDepartures()` loops through all saved locations and compares distance from the user’s current position to the configured radius
- if distance exceeds the radius, a departure notification is shown
- `_recentlyTriggeredLocationIds` prevents repeated notifications for the same place during a single cycle

This is the app's geofencing logic.

### 5.4 Reminder Service

File: `lib/services/reminder_service.dart`

This is the notification and scheduling service using `flutter_local_notifications` and timezone scheduling.

Responsibilities:

- initialize local notifications for Android/iOS
- show a departure alert with action buttons
- schedule daily reminder notifications for each location
- handle tap actions from notifications
- navigate to the checklist screen or reset the app flow when a user taps a notification

Notification actions include:

- `check_all` — marks all checklist items as checked
- `see_list` — opens the checklist screen for that location

This service acts as the app’s push-notification / reminder backend, even though it runs locally rather than from a remote server.

---

## 6. Data Flow and App Logic

The application works as follows:

1. The user creates a `Location` in `LocationFormScreen`.
2. The location is saved to Hive via `HiveService.saveLocation()`.
3. The user adds checklist items, each a `ChecklistItem` saved to Hive.
4. The user sets GPS coordinates and/or a reminder time.
5. `LocationService` monitors departure conditions.
6. If the user leaves the area or it is time to leave, `ReminderService` fires a local notification.
7. The user may tap the notification action to check all items or open the checklist.
8. If a user leaves with unchecked items, the app logs forgotten items using `HiveService.recordForgottenItems()`.
9. This creates a forgotten history that can be reviewed later.

This is a full local workflow without a network API.

---

## 7. Current Status of the Project

The project has already implemented a substantial functional app with the following capabilities:

### Implemented features

- Add/edit/delete locations
- Create custom location details
- Assign icons and card colors
- Configure GPS radius and reminder time
- Save all data locally with Hive
- Add/edit/delete checklist items
- Track completion state of items
- Reset or check all items for a departing trip
- Show progress statuses on dashboard cards
- Notify the user when they leave a place
- Schedule daily reminder notifications
- Show forgotten-item history and counts
- Support both light and dark themes
- Allow explicit loading of sample data for demo/testing use

### Non-server architecture

This app does not currently have:

- a backend API
- database server
- authentication system
- cloud sync
- remote user accounts

Instead, it is an offline-first local application that stores everything directly on the device.

---

## 8. What the "Backend" Really Is in This Project

In a typical app, “backend” means server-side logic and database services. In this project, the equivalent is:

- data persistence layer (`HiveService`)
- notification engine (`ReminderService`)
- geolocation and departure logic (`LocationService`)
- local business rules enforced in the app code

So the app is a full-stack local application, where the Flutter app itself holds UI, domain logic, and data services.

---

## 9. Technical Notes and Design Patterns

The project uses several standard app patterns:

- Stateful widgets for dynamic screen logic
- service layer separation for responsibilities
- local database persistence using Hive
- Material 3 design components
- notification-driven interaction model
- model-driven UI with plain Dart classes
- local state + disk persistence without remote API calls

---

## 10. Areas Already Completed vs. Future Work

### Completed

- App shell and navigation
- Dashboard, settings, checklist, and form screens
- Core reminder and geolocation service logic
- Local persistence and models
- Notification system with actions
- Forgotten-item tracking
- Theme customization
- Test coverage for models and widgets

### Likely future improvements

- cloud backup/sync
- user authentication
- export/import of data
- richer analytics on forgotten items
- smarter geofence logic or map-based location selection
- remote notification support or server synchronization
- improved onboarding flow

---

## 11. Summary

This project is a complete local-first Flutter app for departure preparation and checklist management. It already includes:

- well-structured UI screens
- custom app theme
- persistent local data using Hive
- GPS departure detection
- scheduled and instant notifications
- forgotten-item tracking and dashboard insights

The app is effectively built as a front-end application with a device-local backend layer rather than a cloud backend.

This means the current state is already a functional proof of concept / near-complete app for the intended use case, but it is not yet a server-based multi-user system.
