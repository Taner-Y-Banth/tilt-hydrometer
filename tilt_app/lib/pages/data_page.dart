import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  final Map<String, Map<String, dynamic>> beacons = {};
  StreamSubscription<List<ScanResult>>? scanSubscription;
  Timer? scanTimer;

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

  @override
  void initState() {
    super.initState();
    requestPermissions();
    startPeriodicScan();
  }

  Future<void> requestPermissions() async {
    var statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    if (statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted &&
        statuses[Permission.locationWhenInUse]!.isGranted) {
      startPeriodicScan();
    } else {
      print('Permissions not granted.');
    }
  }

  void startPeriodicScan() {
    scanTimer?.cancel();
    scanTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      startScan();
    });
    startScan();
  }

  void startScan() async {
    await FlutterBluePlus.stopScan();
    await Future.delayed(const Duration(seconds: 2));
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    scanSubscription?.cancel();
    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      final Map<String, Map<String, dynamic>> updatedBeacons = {};
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
            final double distance = calculateDistance(txPower, result.rssi);
            final String color =
                tiltColors[rawUuid.substring(0, 8)] ?? "Unknown";
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

      // Remove outdated beacons
      updatedBeacons.removeWhere((macAddress, beacon) =>
          now.difference(beacon['timestamp'] as DateTime).inSeconds > 60);

      // Update the internal state
      setState(() {
        beacons.addAll(updatedBeacons);
      });
    });
  }

  double calculateDistance(int txPower, int rssi) {
    if (rssi == 0) return -1.0;
    final double ratio = rssi / txPower;
    return ratio < 1.0
        ? pow(ratio, 10).toDouble()
        : (0.89976) * pow(ratio, 7.7095) + 0.111;
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    scanTimer?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final List<Map<String, dynamic>> sortedBeacons = beacons.values
        .where((beacon) =>
            now.difference(beacon['timestamp'] as DateTime).inSeconds <= 15)
        .toList()
      ..sort((a, b) => tiltColors.keys
          .toList()
          .indexOf(a['color'])
          .compareTo(tiltColors.keys.toList().indexOf(b['color'])));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Page'),
      ),
      body: sortedBeacons.isEmpty
          ? const Center(
              child: Text('No data available.'),
            )
          : ListView.builder(
              itemCount: sortedBeacons.length,
              itemBuilder: (context, index) {
                final beacon = sortedBeacons[index];
                final String colorName = beacon['color'];
                final Color cardColor = getColorFromName(colorName);

                return Card(
                  margin: const EdgeInsets.all(8),
                  color: cardColor, // Set the card's background color
                  child: ListTile(
                    title: Text(
                      beacon['isTiltPro'] == true
                          ? 'Tilt Pro ${beacon['color']}'
                          : 'Tilt ${beacon['color']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MAC Address: ${beacon['macAddress']}'),
                        Text('UUID: ${beacon['uuid']}'),
                        Text('Gravity: ${beacon['gravity']}'),
                        Text('Temperature: ${beacon['temperature']}'),
                        Text('RSSI: ${beacon['rssi']}'),
                        Text('Distance: ${beacon['distance']} meters'),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // Helper function to get a Color from the color name
  Color getColorFromName(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red':
        return const Color.fromARGB(251, 255, 106, 138);
      case 'green':
        return const Color.fromARGB(255, 93, 179, 95);
      case 'blue':
        return Colors.blue.shade100;
      case 'pink':
        return const Color.fromARGB(255, 255, 162, 195);
      case 'orange':
        return const Color.fromARGB(255, 231, 156, 42);
      case 'black':
        return Colors.grey.shade800;
      case 'purple':
        return const Color.fromARGB(255, 200, 110, 216);
      case 'yellow':
        return const Color.fromARGB(255, 246, 233, 116);
      default:
        return const Color.fromARGB(
            255, 186, 186, 186); // Default color for unknown beacons
    }
  }
}
