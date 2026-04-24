import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';

class LocationWrapper {
  /// Handles the complex permission flow for Android 11+ 
  /// 1. Request Foreground (Fine) Location
  /// 2. Request Background Location (Required to be done separately)
  static Future<bool> requestLocationPermissions() async {
    if (!Platform.isAndroid) return true;

    // 1. Request Fine Location (Foreground)
    PermissionStatus fineLocationStatus = await Permission.location.request();

    if (fineLocationStatus.isGranted) {
      // 2. Request Background Location for Android 11+
      // This will usually trigger a dialog leading to App Settings on Android 11+
      PermissionStatus bgLocationStatus = await Permission.locationAlways.request();
      
      return bgLocationStatus.isGranted;
    }
    
    return false;
  }

  /// Configures location settings based on your research criteria
  static LocationSettings getLocationSettings(String mode) {
    switch (mode) {
      case 'GPS': // High Accuracy
        return AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationText: "Tracking High Accuracy GPS",
            notificationTitle: "Location Research",
            enableWakeLock: true,
          ),
        );
      case 'Network': // Low Power
        return AndroidSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 100,
          intervalDuration: const Duration(minutes: 5),
        );
      default:
        return const AppleSettings(accuracy: LocationAccuracy.balanced);
    }
  }

  /// Check current battery level using battery_plus logic (to be used in your service)
  static Future<int> getBatteryLevel() async {
    // This assumes you have battery_plus imported in your project
    return 0; // Placeholder for actual battery_plus logic
  }
}
