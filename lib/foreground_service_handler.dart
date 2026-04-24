import 'dart:isolate';
import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

class LocationTaskHandler extends TaskHandler {
  final Battery _battery = Battery();
  String _currentMode = 'balanced';
  Position? _lastResearchPosition;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    final prefs = await SharedPreferences.getInstance();
    _currentMode = prefs.getString('tracking_mode') ?? 'balanced';
  }

  @override
  void onReceiveData(Object data) {
    if (data is String) {
      _currentMode = data;
    }
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      final prefs = await SharedPreferences.getInstance();
      _currentMode = prefs.getString('tracking_mode') ?? _currentMode;

      final int batteryLevel = await _battery.batteryLevel;
      bool shouldRequestHighAccuracy = false;
      LocationAccuracy accuracy = LocationAccuracy.medium;

      if (_currentMode == 'continuous') {
        shouldRequestHighAccuracy = true;
        accuracy = LocationAccuracy.best;
      } else if (_currentMode == 'balanced') {
        shouldRequestHighAccuracy = true;
        accuracy = LocationAccuracy.low;
      } else if (_currentMode == 'geofencing') {
        Position? lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown == null || _lastResearchPosition == null) {
          shouldRequestHighAccuracy = true;
        } else {
          double distance = Geolocator.distanceBetween(
            _lastResearchPosition!.latitude, _lastResearchPosition!.longitude,
            lastKnown.latitude, lastKnown.longitude
          );
          if (distance > 200) shouldRequestHighAccuracy = true;
        }
        accuracy = LocationAccuracy.low;
      }

      if (shouldRequestHighAccuracy) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: accuracy,
          timeLimit: const Duration(seconds: 10),
        );
        _lastResearchPosition = position;

        // 1. Create the Pulse Log with Longitude
        String logEntry = "[RESEARCH LOG] Mode: $_currentMode | Battery: $batteryLevel% | Lat: ${position.latitude} | Lon: ${position.longitude}";
        print(logEntry);

        // 2. Save to CSV
        await _saveToCSV(position, batteryLevel);
        
        // 3. Send to UI
        sendPort?.send({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'battery': batteryLevel,
        });

        FlutterForegroundTask.updateService(
          notificationTitle: 'Mode: ${_currentMode.toUpperCase()}',
          notificationText: 'Battery: $batteryLevel% | Lat: ${position.latitude.toStringAsFixed(4)}',
        );
      }

    } catch (e) {
      print('[RESEARCH ERROR] $e');
    }
  }

  Future<void> _saveToCSV(Position pos, int battery) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/battery_study.csv');
      
      final timestamp = DateTime.now().toIso8601String();
      final csvLine = "$timestamp, $_currentMode, $battery, ${pos.latitude}, ${pos.longitude}\n";

      // Append to the file (creates it if it doesn't exist)
      await file.writeAsString(csvLine, mode: FileMode.append);
    } catch (e) {
      print('Error saving to CSV: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {}
}
