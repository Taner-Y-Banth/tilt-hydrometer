import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class DataService extends ChangeNotifier {
  final StreamController<List<Map<String, dynamic>>> _beaconsController =
      StreamController.broadcast();
  final Map<String, Map<String, dynamic>> _beacons = {};
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _scanTimer;
  final List<List<dynamic>> _logData = [];
  String? _loggingMacAddress;
  Timer? _loggingTimer;

  final Map<String, String> tiltColors = {
    'a495bb10': 'Red',
    'a495bb20': 'Green',
    'a495bb30': 'Blue',
    'a495bb40': 'Pink',
    'a495bb50': 'Orange',
    'a495bb60': 'Black',
    'a495bb70': 'Purple',
    'a495bb80': 'Yellow',
  };

  Stream<List<Map<String, dynamic>>> get beaconsStream =>
      _beaconsController.stream;

  List<List<dynamic>> get logData => _logData;

  String? get loggingMacAddress => _loggingMacAddress;

  DataService() {
    _init();
  }

  Future<void> _init() async {
    print('DataService: Initializing...');
    await requestPermissions();
    startScanning();
  }

  void startScanning() {
    print('DataService: Starting scanning...');
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _startScan();
    });
    _startScan();
  }

  void stopScanning() {
    print('DataService: Stopping scanning.');
    _scanSubscription?.cancel();
    _scanTimer?.cancel();
    FlutterBluePlus.stopScan();
    stopLogging();
  }

  Future<void> _startScan() async {
    print('DataService: Starting scan...');
    try {
      await FlutterBluePlus.stopScan();
      await Future.delayed(const Duration(seconds: 2));
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        print('DataService: Scan results received: ${results.length}');
        _processScanResults(results);
      }, onError: (e) {
        print('DataService: Error during scan: $e');
      });
    } catch (e) {
      print('DataService: Error starting scan: $e');
    }
  }

  void _processScanResults(List<ScanResult> results) {
    final Map<String, Map<String, dynamic>> updatedBeacons =
        {}; // Temporary map
    final DateTime now = DateTime.now();

    for (ScanResult result in results) {
      final manufacturerData = result.advertisementData.manufacturerData;

      if (manufacturerData.containsKey(0x004C)) {
        final rawData = manufacturerData[0x004C]!;
        if (rawData.length >= 23) {
          final String rawUuid = rawData
              .sublist(2, 18)
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join();
          final String uuid =
              "${rawUuid.substring(0, 8)}-${rawUuid.substring(8, 12)}-${rawUuid.substring(12, 16)}-${rawUuid.substring(16, 20)}-${rawUuid.substring(20)}";
          final int major = (rawData[18] << 8) | rawData[19];
          final int minor = (rawData[20] << 8) | rawData[21];
          final int txPower = rawData[22].toSigned(8);
          final double distance = _calculateDistance(txPower, result.rssi);
          final String color = tiltColors[rawUuid.substring(0, 8)] ?? "Unknown";
          final bool isTiltPro = major > 212 || minor > 5000;

          if (color != "Unknown") {
            final String macAddress = result.device.id.toString();

            updatedBeacons[macAddress] = {
              'uuid': uuid,
              'color': color,
              'macAddress': macAddress,
              'gravity': isTiltPro ? minor / 10000.0 : minor / 1000.0,
              'temperature': isTiltPro ? major / 10.0 : major,
              'rssi': result.rssi,
              'txPower': txPower,
              'distance': distance.toStringAsFixed(2),
              'isTiltPro': isTiltPro,
              'timestamp': now,
            };
          }
        }
      }
    }

    // Update existing beacons with new data, keep existing if not updated
    updatedBeacons.forEach((key, value) {
      if (_beacons.containsKey(key)) {
        _beacons[key]!.addAll(value); // Update existing data
      } else {
        _beacons[key] = value; // Add new beacon
      }
    });

    // Remove outdated beacons (older than 15 seconds)
    _beacons.removeWhere((key, beacon) =>
        now.difference(beacon['timestamp'] as DateTime).inSeconds > 15);

    // Prepare sorted list for UI
    final List<Map<String, dynamic>> sortedBeacons = _beacons.values.toList()
      ..sort((a, b) => tiltColors.keys
          .toList()
          .indexOf(a['color'])
          .compareTo(tiltColors.keys.toList().indexOf(b['color'])));

    _beaconsController.add(sortedBeacons);
    notifyListeners();
    print('DataService: Beacons updated: ${_beacons.length}');
  }

  double _calculateDistance(int txPower, int rssi) {
    if (rssi == 0) return -1.0;
    final double ratio = rssi / txPower;
    return ratio < 1.0
        ? pow(ratio, 10).toDouble()
        : (0.89976) * pow(ratio, 7.7095) + 0.111;
  }

  // --- Logging Functionality ---

  void startLogging(String macAddress) {
    _loggingMacAddress = macAddress;
    _logData.clear();
    _loggingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _logDataPoint(macAddress);
    });
    notifyListeners();
  }

  void stopLogging() {
    _loggingTimer?.cancel();
    _loggingMacAddress = null;
    notifyListeners();
  }

  void _logDataPoint(String macAddress) {
    if (_beacons.containsKey(macAddress)) {
      final beacon = _beacons[macAddress]!;
      final now = DateTime.now();
      _logData.add([
        now.toIso8601String(),
        beacon['gravity'],
        beacon['temperature'],
        beacon['rssi'],
        beacon['distance'],
      ]);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    print('DataService: Disposing...');
    _scanSubscription?.cancel();
    _scanTimer?.cancel();
    _loggingTimer?.cancel();
    _beaconsController.close();
    super.dispose();
  }

  Future<void> requestPermissions() async {
    print('DataService: Requesting permissions...');
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
      Permission.storage,
    ].request();

    if (statuses[Permission.bluetooth]!.isGranted &&
        statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted &&
        statuses[Permission.locationWhenInUse]!.isGranted &&
        statuses[Permission.storage]!.isGranted) {
      print('DataService: All permissions granted.');
    } else {
      print('DataService: Some permissions not granted: $statuses');
    }
  }
}
