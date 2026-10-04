import 'package:flutter/material.dart';

class LocationIconInfo {
  final String key;
  final String label;
  final IconData iconData;

  const LocationIconInfo({
    required this.key,
    required this.label,
    required this.iconData,
  });
}

class AppIcons {
  static const List<LocationIconInfo> allIcons = [
    LocationIconInfo(
      key: 'home',
      label: 'Home',
      iconData: Icons.home_rounded,
    ),
    LocationIconInfo(
      key: 'school',
      label: 'University',
      iconData: Icons.school_rounded,
    ),
    LocationIconInfo(
      key: 'work',
      label: 'Office',
      iconData: Icons.business_center_rounded,
    ),
    LocationIconInfo(
      key: 'gym',
      label: 'Gym',
      iconData: Icons.fitness_center_rounded,
    ),
    LocationIconInfo(
      key: 'travel',
      label: 'Travel',
      iconData: Icons.flight_takeoff_rounded,
    ),
    LocationIconInfo(
      key: 'shopping',
      label: 'Shopping',
      iconData: Icons.shopping_bag_rounded,
    ),
    LocationIconInfo(
      key: 'car',
      label: 'Car',
      iconData: Icons.directions_car_rounded,
    ),
    LocationIconInfo(
      key: 'friends',
      label: "Friend's House",
      iconData: Icons.people_rounded,
    ),
    LocationIconInfo(
      key: 'other',
      label: 'Other',
      iconData: Icons.category_rounded,
    ),
  ];

  static IconData getIconData(String? key) {
    if (key == null) return Icons.place_rounded;
    for (final info in allIcons) {
      if (info.key == key) return info.iconData;
    }
    return Icons.place_rounded;
  }

  static String getIconLabel(String? key) {
    if (key == null) return 'Place';
    for (final info in allIcons) {
      if (info.key == key) return info.label;
    }
    return 'Place';
  }
}
