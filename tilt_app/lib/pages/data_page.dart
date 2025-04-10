import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:tilt_app/services/data_service.dart'; // Import DataService

class DataPage extends StatelessWidget {
  const DataPage({Key? key}) : super(key: key);

  String _formatGravity(dynamic gravity, bool isTiltPro) {
    final double parsedGravity = gravity is String
        ? double.tryParse(gravity) ?? 0.0
        : gravity is double
            ? gravity
            : gravity.toDouble(); // Ensure gravity is a double
    final precision = isTiltPro ? 4 : 3; // Use 4 decimals for Tilt Pro
    return parsedGravity.toStringAsFixed(precision);
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<DataService>(context); // Get DataService

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Page'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: dataService.beaconsStream, // Use the stream from DataService
        initialData: const [],
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No data available.'));
          }

          final sortedBeacons = snapshot.data!;

          return ListView.builder(
            itemCount: sortedBeacons.length,
            itemBuilder: (context, index) {
              final beacon = sortedBeacons[index];
              final String colorName = beacon['color'];
              final Color cardColor = getColorFromName(colorName);
              final isTiltPro = beacon['isTiltPro'] ?? false;

              return Card(
                margin: const EdgeInsets.all(8),
                color: cardColor,
                child: ListTile(
                  title: Text(
                    isTiltPro
                        ? 'Tilt Pro ${beacon['color']}'
                        : 'Tilt ${beacon['color']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MAC Address: ${beacon['macAddress']}'),
                      Text('UUID: ${beacon['uuid']}'),
                      Text(
                          'Gravity: ${_formatGravity(beacon['convertedGravity'], isTiltPro)} (${beacon['gravityUnit']})'),
                      Text(
                          'Temperature: ${beacon['convertedTemperature'].toStringAsFixed(1)} (${beacon['temperatureUnit']})'),
                      Text('RSSI: ${beacon['rssi']}'),
                      Text('Distance: ${beacon['distance']} meters'),
                    ],
                  ),
                ),
              );
            },
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
