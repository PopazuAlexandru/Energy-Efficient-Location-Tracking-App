import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

// The callback function for the task worker.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

class LocationTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    // Logic to execute when service starts
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    // This is where you track location for power-drain measurement
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    
    // Send data back to the UI if needed
    sendPort?.send(position.toJson());
    
    // Update notification to show it's active
    FlutterForegroundTask.updateService(
      notificationTitle: 'Energy Research Active',
      notificationText: 'Tracking: ${position.latitude}, ${position.longitude}',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    // Cleanup
  }
}
