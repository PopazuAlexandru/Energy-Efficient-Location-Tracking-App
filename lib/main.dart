import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'foreground_service_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initForegroundTask();
  runApp(const EnergyResearchApp());
}

void initForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'energy_tracking_channel',
      channelName: 'Energy Tracking Service',
      channelDescription: 'Used for research on battery drain.',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      iconData: const NotificationIconData(
        resType: ResourceType.mipmap,
        resPrefix: ResourcePrefix.ic,
        name: 'launcher',
      ),
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 5000, // Update every 5 seconds for granular data
      isOnceEvent: false,
      autoRunOnBoot: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

class EnergyResearchApp extends StatelessWidget {
  const EnergyResearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Energy Tracking Research')),
        body: Center(
          child: ElevatedButton(
            onPressed: () => startLocationService(),
            child: const Text('Start Power Drain Test'),
          ),
        ),
      ),
    );
  }

  Future<void> startLocationService() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    } else {
      await FlutterForegroundTask.startService(
        notificationTitle: 'Tracking Active',
        notificationText: 'Collecting energy usage data...',
        callback: startCallback,
      );
    }
  }
}
