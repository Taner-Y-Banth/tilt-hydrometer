import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:tilt_app/services/data_service.dart'; // Import DataService

class DataPage extends StatelessWidget {
  const DataPage({super.key});

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
              final Color textColor = getTextColor(cardColor); // Get text color
              final isTiltPro = beacon['isTiltPro'] ?? false;

              return Card(
                margin: const EdgeInsets.all(8),
                color: cardColor,
                child: ListTile(
                  title: Text(
                    isTiltPro
                        ? 'Tilt Pro ${beacon['color']}'
                        : 'Tilt ${beacon['color']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor, // Apply text color
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MAC Address: ${beacon['macAddress']}',
                        style: TextStyle(color: textColor),
                      ),
                      Text(
                        'UUID: ${beacon['uuid']}',
                        style: TextStyle(color: textColor),
                      ),
                      Text(
                        'Raw Gravity: ${_formatGravity(beacon['gravity'], isTiltPro)} (SG)', // Always in SG
                        style: TextStyle(color: textColor),
                      ),
                      Text(
                        'Calibrated Gravity: ${_formatGravity(beacon['calibratedGravity'], isTiltPro)} (SG)', // Always in SG
                        style: TextStyle(color: textColor),
                      ),
                      Text(
                        'Converted Gravity: ${_formatGravity(beacon['convertedGravity'], isTiltPro)} (${beacon['gravityUnit']})',
                        style: TextStyle(color: textColor),
                      ),
                      Text(
                        'Raw Temperature: ${beacon['temperature'].toStringAsFixed(1)} (°F)', // Always in °F
                        style: TextStyle(color: textColor),
                      ),
                      Text(
                        'Calibrated Temperature: ${beacon['calibratedTemperature'].toStringAsFixed(1)} (°F)', // Always in °F
                        style: TextStyle(color: textColor),
                      ),
                      Text(
                        'Converted Temperature: ${beacon['convertedTemperature'].toStringAsFixed(1)} (${beacon['temperatureUnit']})',
                        style: TextStyle(color: textColor),
                      ),
                      Text(
                        'RSSI: ${beacon['rssi']}',
                        style: TextStyle(color: textColor),
                      ),
                      Text(
                        'Distance: ${beacon['distance']} meters',
                        style: TextStyle(color: textColor),
                      ),
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
        return const Color(0xFFFF0000); // Pure red based on image analysis
      case 'green':
        return const Color(
            0xFF00CD66); // Medium Spring Green from image analysis
      case 'blue':
        return const Color(0xFF1E90FF); // Dodger Blue from image analysis
      case 'pink':
        return const Color(0xFFFF69B4); // Hot Pink from image analysis
      case 'orange':
        return const Color(0xFFFF8C00); // Dark Orange from image analysis
      case 'black':
        return const Color(0xFF000000); // Pure black
      case 'purple':
        return const Color(0xFF9932CC); // Dark Orchid from image analysis
      case 'yellow':
        return const Color(0xFFFFFF00); // Pure yellow
      default:
        return const Color(0xFFBDBDBD); // Light gray for unknown beacons
    }
  }

  // Helper function to determine text color based on background color brightness
  Color getTextColor(Color backgroundColor) {
    final brightness = ThemeData.estimateBrightnessForColor(backgroundColor);
    return brightness == Brightness.dark ? Colors.white : Colors.black;
  }
}
