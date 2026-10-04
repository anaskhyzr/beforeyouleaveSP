import 'package:flutter/material.dart';

import '../models/location.dart';
import '../services/hive_service.dart';
import '../services/location_service.dart';
import '../services/reminder_service.dart';
import '../widgets/icon_picker.dart';

class LocationFormScreen extends StatefulWidget {
  final Location? location;

  const LocationFormScreen({super.key, this.location});

  @override
  State<LocationFormScreen> createState() => _LocationFormScreenState();
}

class _LocationFormScreenState extends State<LocationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _selectedIconKey;

  // GPS fields
  double? _latitude;
  double? _longitude;
  double _radiusMeters = 100.0;
  bool _isLoadingGps = false;

  // Time reminder fields
  int? _reminderMinutes; // minutes from midnight

  // Keep note style color
  late int _selectedColorValue;

  static const List<int> _keepColors = [
    0xFFFFFFFF, // Default white / surface
    0xFFFFF9C4, // Pastel Yellow
    0xFFFFCDD2, // Pastel Coral
    0xFFC8E6C9, // Pastel Mint Green
    0xFFBBDEFB, // Pastel Sky Blue
    0xFFE1BEE7, // Pastel Lavender
    0xFFB2DFDB, // Pastel Teal
    0xFFFFE0B2, // Pastel Peach
  ];

  bool get _isEditing => widget.location != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.location?.name ?? '');
    _selectedIconKey = widget.location?.iconKey ?? 'home';
    _latitude = widget.location?.latitude;
    _longitude = widget.location?.longitude;
    _radiusMeters = widget.location?.radiusMeters ?? 100.0;
    _reminderMinutes = widget.location?.reminderMinutes;
    _selectedColorValue = widget.location?.colorValue ?? 0xFFFFFFFF;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentGps() async {
    setState(() => _isLoadingGps = true);
    final position = await LocationService.getCurrentPosition();
    setState(() => _isLoadingGps = false);

    if (position != null) {
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'GPS coordinates set (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not retrieve GPS coordinates. Please ensure location services & permissions are turned on.',
          ),
        ),
      );
    }
  }

  void _clearGps() {
    setState(() {
      _latitude = null;
      _longitude = null;
    });
  }

  Future<void> _pickReminderTime() async {
    final initialTime = _reminderMinutes != null
        ? TimeOfDay(
            hour: _reminderMinutes! ~/ 60,
            minute: _reminderMinutes! % 60,
          )
        : const TimeOfDay(hour: 14, minute: 0);

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Select daily departure reminder time',
    );

    if (picked != null) {
      setState(() {
        _reminderMinutes = picked.hour * 60 + picked.minute;
      });
    }
  }

  void _clearReminderTime() {
    setState(() {
      _reminderMinutes = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    Location locationToSave;

    if (_isEditing) {
      locationToSave = widget.location!
        ..name = name
        ..iconKey = _selectedIconKey
        ..latitude = _latitude
        ..longitude = _longitude
        ..radiusMeters = _radiusMeters
        ..reminderMinutes = _reminderMinutes
        ..colorValue = _selectedColorValue;
      await HiveService.saveLocation(locationToSave);
    } else {
      locationToSave = Location(
        id: HiveService.newId(),
        name: name,
        iconKey: _selectedIconKey,
        createdAt: DateTime.now(),
        latitude: _latitude,
        longitude: _longitude,
        radiusMeters: _radiusMeters,
        reminderMinutes: _reminderMinutes,
        colorValue: _selectedColorValue,
      );
      await HiveService.saveLocation(locationToSave);
    }

    // Schedule or update daily reminder
    await ReminderService.scheduleDailyDepartureReminder(location: locationToSave);

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Location' : 'New Location'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Text(
                'Location Details',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create a checklist for a place you frequently leave (e.g. Home, University, Office).',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Location Name',
                  hintText: 'e.g. Home, University, Gym, Office',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a location name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              IconPicker(
                selectedKey: _selectedIconKey,
                onSelected: (key) => setState(() => _selectedIconKey = key),
              ),
              const SizedBox(height: 28),

              // CARD COLOR (GOOGLE KEEP STYLE)
              Text(
                'Card Color (Keep Style)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pick a color theme for this location card on your dashboard.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _keepColors.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final colorVal = _keepColors[index];
                    final isSelected = _selectedColorValue == colorVal;
                    final displayColor = isDark && colorVal == 0xFFFFFFFF
                        ? colorScheme.surfaceContainerHighest
                        : Color(colorVal);

                    return GestureDetector(
                      onTap: () => setState(() => _selectedColorValue = colorVal),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: displayColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                size: 22,
                                color: isDark
                                    ? Colors.white
                                    : (colorVal == 0xFFFFFFFF
                                        ? colorScheme.primary
                                        : Colors.black87),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),

              // GPS GEOFENCING SECTION
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.near_me_rounded, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'GPS Departure Trigger',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Automatically alerts you when you walk or drive outside this perimeter.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (_latitude != null && _longitude != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'GPS: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                tooltip: 'Remove GPS coordinates',
                                onPressed: _clearGps,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Departure Radius: ${_radiusMeters.round()} meters',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Slider(
                          value: _radiusMeters,
                          min: 50,
                          max: 500,
                          divisions: 9,
                          label: '${_radiusMeters.round()}m',
                          onChanged: (val) => setState(() => _radiusMeters = val),
                        ),
                      ] else ...[
                        FilledButton.tonalIcon(
                          onPressed: _isLoadingGps ? null : _fetchCurrentGps,
                          icon: _isLoadingGps
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.my_location_rounded, size: 18),
                          label: Text(
                            _isLoadingGps
                                ? 'Acquiring GPS fix...'
                                : 'Set Current Location via GPS',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // TIME-BASED REMINDER SECTION (OPTIONAL)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.alarm_rounded, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Daily Departure Time Reminder',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Optional backup reminder (e.g. 2:00 PM) asking "Have you left yet or about to leave?".',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_reminderMinutes != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Daily Reminder at: ${ReminderService.formatMinutes(_reminderMinutes)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _pickReminderTime,
                                child: const Text('Change'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                tooltip: 'Remove reminder time',
                                onPressed: _clearReminderTime,
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        OutlinedButton.icon(
                          onPressed: _pickReminderTime,
                          icon: const Icon(Icons.add_alarm_rounded, size: 18),
                          label: const Text('Set Daily Departure Time'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 36),
              FilledButton(
                onPressed: _save,
                child: Text(_isEditing ? 'Save Changes' : 'Create Location'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
