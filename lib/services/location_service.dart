import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/location.dart';
import 'hive_service.dart';
import 'reminder_service.dart';

class LocationService {
  static Timer? _periodicCheckTimer;
  static final Set<String> _recentlyTriggeredLocationIds = {};

  /// Check whether device location services are enabled and permissions granted
  static Future<bool> checkAndRequestPermission({bool requestBackground = false}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error checking location permission: $e');
      return false;
    }
  }

  /// Get current GPS position with timeout
  static Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }

  /// Calculate distance in meters between two lat/lng points
  static double getDistanceMeters({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Check if the user has departed from any configured GPS location
  static Future<void> checkDepartures() async {
    final position = await getCurrentPosition();
    if (position == null) return;

    final locations = await HiveService.getLocations();
    for (final loc in locations) {
      if (!loc.hasGps) continue;

      final distance = getDistanceMeters(
        startLatitude: loc.latitude!,
        startLongitude: loc.longitude!,
        endLatitude: position.latitude,
        endLongitude: position.longitude,
      );

      // If user moved outside the radius
      if (distance > loc.radiusMeters) {
        // If not already notified recently in this departure cycle
        if (!_recentlyTriggeredLocationIds.contains(loc.id)) {
          _recentlyTriggeredLocationIds.add(loc.id);

          await ReminderService.showDepartureNotification(
            location: loc,
            distanceMeters: distance.round(),
          );
        }
      } else {
        // User is currently inside the location perimeter
        _recentlyTriggeredLocationIds.remove(loc.id);
      }
    }
  }

  /// Start periodic low-power check (e.g. every 10 minutes) to minimize battery drain
  static void startPeriodicDepartureMonitoring({Duration interval = const Duration(minutes: 10)}) {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = Timer.periodic(interval, (_) async {
      await checkDepartures();
    });
  }

  static void stopPeriodicDepartureMonitoring() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = null;
  }

  /// Manual trigger for testing/simulation purposes
  static Future<void> simulateDeparture(Location location) async {
    await ReminderService.showDepartureNotification(
      location: location,
      distanceMeters: (location.radiusMeters + 25).round(),
    );
  }
}
