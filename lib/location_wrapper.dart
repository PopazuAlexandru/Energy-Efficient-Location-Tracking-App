import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class LocationWrapper {
  /// Robustly handles location permission requests for Android 11+
  static Future<bool> requestLocationPermissions() async {
    if (!Platform.isAndroid) return true;

    try {
      var fineStatus = await Permission.location.status;
      if (!fineStatus.isGranted) {
        fineStatus = await Permission.location.request();
      }

      if (fineStatus.isGranted) {
        var bgStatus = await Permission.locationAlways.status;
        if (!bgStatus.isGranted) {
          bgStatus = await Permission.locationAlways.request();
        }
        return bgStatus.isGranted;
      }
      return false;
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_REQUEST_ALREADY_IN_PROGRESS') {
        print('A permission request is already running. Please wait.');
      }
      return false;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  /// Verifies if GPS/Location services are toggled ON in system settings
  static Future<bool> isServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Opens the system location settings page automatically
  static Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  static LocationSettings getLocationSettings(String mode) {
    switch (mode) {
      case 'GPS':
        return AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationText: "Tracking High Accuracy GPS",
            notificationTitle: "Energy Research",
            enableWakeLock: true,
          ),
        );
      case 'Network':
        return AndroidSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 100,
        );
      default:
        return AndroidSettings(accuracy: LocationAccuracy.medium);
    }
  }
}
