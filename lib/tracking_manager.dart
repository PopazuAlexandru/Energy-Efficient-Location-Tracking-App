import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geofencing_2/geofencing_2.dart';

enum TrackingMode { continuous, balanced, geofencing }

class TrackingManager extends ChangeNotifier {
  TrackingMode _currentMode = TrackingMode.balanced;
  TrackingMode get currentMode => _currentMode;

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  /// Update the tracking mode and reconfigure the location settings
  Future<void> setTrackingMode(TrackingMode mode) async {
    _currentMode = mode;
    notifyListeners();

    switch (mode) {
      case TrackingMode.continuous:
        _startContinuousTracking();
        break;
      case TrackingMode.balanced:
        _startBalancedTracking();
        break;
      case TrackingMode.geofencing:
        _startGeofencing();
        break;
    }
  }

  void _startContinuousTracking() {
    const settings = AppleSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
    // For Android-specific settings, use AndroidSettings
    Geolocator.getPositionStream(
      locationSettings: const AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: Duration(seconds: 1),
      ),
    ).listen(_updatePosition);
  }

  void _startBalancedTracking() {
    Geolocator.getPositionStream(
      locationSettings: const AndroidSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 50,
        intervalDuration: Duration(seconds: 30),
      ),
    ).listen(_updatePosition);
  }

  Future<void> _startGeofencing() async {
    // Current location for the center of the geofence
    Position pos = await Geolocator.getCurrentPosition();
    
    // Register a geofence with 200m radius
    await GeofencingManager.registerGeofence(
      Geofence(
        id: 'research_region',
        latitude: pos.latitude,
        longitude: pos.longitude,
        radius: 200.0,
        expirationDuration: 60 * 60 * 1000, // 1 hour
        eventPeriodInMs: 5000,
      ),
      _geofenceCallback,
    );
  }

  static void _geofenceCallback(List<String> ids, Location location, GeofenceEvent event) {
    print('Geofence Event: $event for IDs: $ids');
    // In a real app, you would use a Port to send this back to the main isolate
  }

  void _updatePosition(Position position) {
    _currentPosition = position;
    notifyListeners();
  }
}
