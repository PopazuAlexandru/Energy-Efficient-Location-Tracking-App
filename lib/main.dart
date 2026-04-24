import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'foreground_service_handler.dart';
import 'tracking_manager.dart';
import 'location_wrapper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => TrackingManager(),
      child: const EnergyResearchApp(),
    ),
  );
}

class EnergyResearchApp extends StatelessWidget {
  const EnergyResearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const EnergyResearchHomePage(),
    );
  }
}

class EnergyResearchHomePage extends StatefulWidget {
  const EnergyResearchHomePage({super.key});

  @override
  State<EnergyResearchHomePage> createState() => _EnergyResearchHomePageState();
}

class _EnergyResearchHomePageState extends State<EnergyResearchHomePage> {
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  ReceivePort? _receivePort;
  String _latestLog = "Waiting for data...";

  @override
  void initState() {
    super.initState();
    _initForegroundTask();
    _subscribeToServiceStatus();
  }

  @override
  void dispose() {
    _serviceStatusSubscription?.cancel();
    _closeReceivePort();
    super.dispose();
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'energy_tracking_channel',
        channelName: 'Energy Tracking Service',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  void _initReceivePort() {
    _closeReceivePort();
    _receivePort = FlutterForegroundTask.receivePort;
    _receivePort?.listen((data) {
      if (data is Map) {
        if (!mounted) return;
        setState(() {
          _latestLog = "Battery: ${data['battery']}% | Lat: ${data['latitude'].toStringAsFixed(4)}";
        });
      }
    });
  }

  void _closeReceivePort() {
    _receivePort?.close();
    _receivePort = null;
  }

  void _subscribeToServiceStatus() {
    _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen(
      (ServiceStatus status) {
        if (!mounted) return;
        if (status == ServiceStatus.disabled) {
          _handleDisabledLocation();
        } else {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GPS Enabled!'), backgroundColor: Colors.green),
          );
        }
      },
    );
  }

  void _handleDisabledLocation() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('GPS is disabled! Enable it to continue research.'),
        duration: const Duration(days: 1), 
        action: SnackBarAction(
          label: 'SETTINGS',
          onPressed: () => LocationWrapper.openLocationSettings(),
        ),
      ),
    );
  }

  Future<void> _toggleService(TrackingManager manager) async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
        _closeReceivePort();
      } else {
        bool serviceEnabled = await LocationWrapper.isServiceEnabled();
        if (!serviceEnabled) {
          _handleDisabledLocation();
          return;
        }

        bool granted = await LocationWrapper.requestLocationPermissions();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are required.')),
            );
          }
          return;
        }

        final result = await FlutterForegroundTask.startService(
          notificationTitle: 'Research Active: ${manager.currentMode.name}',
          notificationText: 'Tracking location...',
          callback: startCallback,
        );

        if (result) {
          _initReceivePort();
          // We rely on SharedPreferences for communication now,
          // so we don't need direct isolate messaging here.
        }
      }
    } catch (e) {
      debugPrint('Error toggling service: $e');
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<TrackingManager>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Location Energy Research')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Select Tracking Strategy:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...TrackingMode.values.map((mode) => RadioListTile<TrackingMode>(
              title: Text(mode.name.toUpperCase()),
              value: mode,
              groupValue: manager.currentMode,
              onChanged: (val) {
                if (val != null) {
                  manager.setTrackingMode(val);
                }
              },
            )),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                _latestLog,
                style: const TextStyle(fontSize: 16, color: Colors.blueGrey, fontWeight: FontWeight.w500),
              ),
            ),
            const Spacer(),
            FutureBuilder<bool>(
              future: FlutterForegroundTask.isRunningService,
              builder: (context, snapshot) {
                final isRunning = snapshot.data ?? false;
                return ElevatedButton.icon(
                  onPressed: () => _toggleService(manager),
                  icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
                  label: Text(isRunning ? 'Stop Measurement' : 'Start Measurement'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: isRunning ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
