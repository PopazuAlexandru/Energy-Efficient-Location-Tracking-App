import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TrackingMode { continuous, balanced, geofencing }

class TrackingManager extends ChangeNotifier {
  TrackingMode _currentMode = TrackingMode.balanced;
  TrackingMode get currentMode => _currentMode;

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  Future<void> setTrackingMode(TrackingMode mode) async {
    _currentMode = mode;
    notifyListeners();

    // Save mode to SharedPreferences so the background task can read it
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tracking_mode', mode.name);
  }

  void _updatePosition(Position position) {
    _currentPosition = position;
    notifyListeners();
  }
}
