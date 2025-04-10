import 'dart:async';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert'; // Import for utf8
import 'package:tilt_app/services/data_service.dart';
import 'package:open_filex/open_filex.dart'; // Import open_filex
import 'package:fl_chart/fl_chart.dart';

class LoggingPage extends StatefulWidget {
  final DataService dataService;

  const LoggingPage({Key? key, required this.dataService}) : super(key: key);

  @override
  _LoggingPageState createState() => _LoggingPageState();
}

class _LoggingPageState extends State<LoggingPage> {
  String? _selectedMacAddress;
  Timer? _loggingTimer;
  List<List<dynamic>> _logData = [];
  List<String> _logFiles = [];
  bool _isLogging = false;

  List<FlSpot> _gravityData = [];
  int _dataIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadLogFiles();
  }

  @override
  void dispose() {
    _stopLogging(); // Ensure logging is stopped
    super.dispose();
  }

  Future<void> _loadLogFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync();
    _logFiles = files
        .whereType<File>()
        .where((file) => file.path.endsWith('.csv'))
        .map((file) => file.uri.pathSegments.last)
        .toList();
    setState(() {});
  }

  void _startLogging() {
    if (_isLogging || _selectedMacAddress == null) return;
    _isLogging = true;
    _logData.clear();
    _gravityData.clear(); // Clear graph data
    _dataIndex = 0; // Reset data index
    _startLoggingTimer();
    setState(() {});
  }

  void _updateGraphData(double gravity) {
    setState(() {
      _gravityData.add(FlSpot(_dataIndex.toDouble(), gravity));
      _dataIndex++;
      if (_gravityData.length > 20)
        _gravityData.removeAt(0); // Keep last 20 points
    });
  }

  void _startLoggingTimer() {
    _loggingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_selectedMacAddress != null) {
        final List<Map<String, dynamic>> samples = [];
        final stream = widget.dataService.beaconsStream;

        // Take exactly 5 samples
        final subscription = stream.listen((beacons) {
          if (samples.length < 5) {
            final beaconData = beacons.firstWhere(
              (beacon) => beacon['macAddress'] == _selectedMacAddress,
              orElse: () => {},
            );
            if (beaconData.isNotEmpty) {
              samples.add(beaconData);
            }
          }
        });

        try {
          await Future.delayed(const Duration(seconds: 5));
        } finally {
          await subscription.cancel(); // Ensure subscription is canceled
        }

        if (samples.isNotEmpty) {
          // Calculate averages
          final avgGravity = samples
                  .map((sample) => sample['gravity'] ?? 0.0)
                  .reduce((a, b) => a + b) /
              samples.length;

          // Update graph data
          _updateGraphData(avgGravity); // Ensure graph is updated

          // Log the averaged data
          final avgTemperature = samples
                  .map((sample) => sample['temperature'] ?? 0.0)
                  .reduce((a, b) => a + b) /
              samples.length;
          final avgRssi = samples
                  .map((sample) => sample['rssi'] ?? 0)
                  .reduce((a, b) => a + b) /
              samples.length;
          final avgDistance = samples
                  .map((sample) =>
                      double.tryParse(
                          sample['distance']?.toString() ?? '0.0') ??
                      0.0)
                  .reduce((a, b) => a + b) /
              samples.length;

          _logData.add([
            DateTime.now().toIso8601String(),
            avgGravity.toStringAsFixed(4),
            avgTemperature.toStringAsFixed(1),
            avgRssi.toInt(),
            avgDistance.toStringAsFixed(2),
          ]);

          if (mounted) {
            setState(() {}); // Update UI if widget is still in the tree
          }
        }
      }
    });
  }

  void _stopLogging() async {
    if (!_isLogging) return;
    _isLogging = false;
    _loggingTimer?.cancel();
    _loggingTimer = null;

    if (_logData.isNotEmpty) {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'tilt_data_${DateTime.now().millisecondsSinceEpoch}.csv';
      final path = '${directory.path}/$fileName';
      final file = File(path);

      try {
        // Add a header row to the CSV
        final header = [
          'Timestamp',
          'Gravity (SG)',
          'Temperature (°F)',
          'RSSI',
          'Distance',
          'Converted Gravity (SG)',
          'Converted Temperature (°F)'
        ];

        // Sanitize each cell without wrapping in quotes
        final sanitizedData = _logData.map((row) {
          final timestamp = row.isNotEmpty ? row[0].toString() : 'N/A';
          final gravity = row.length > 1 ? row[1].toString() : 'N/A';
          final temperature = row.length > 2 ? row[2].toString() : 'N/A';
          final rssi = row.length > 3 ? row[3].toString() : 'N/A';
          final distance = row.length > 4 ? row[4].toString() : 'N/A';

          // Apply conversions if settings are enabled
          final convertedGravity =
              row.length > 1 ? _applyGravityConversion(row[1]) : 0.0;
          final convertedTemperature =
              row.length > 2 ? _applyTemperatureConversion(row[2]) : 0.0;

          return [
            timestamp,
            gravity,
            temperature,
            rssi,
            distance,
            convertedGravity.toStringAsFixed(4),
            convertedTemperature.toStringAsFixed(1)
          ];
        }).toList();

        // Combine header and data
        final csvData = [header, ...sanitizedData];

        // Include UTF-8 BOM for Excel compatibility
        final csv =
            '\uFEFF' + const ListToCsvConverter(eol: '\n').convert(csvData);
        await file.writeAsString(csv, encoding: utf8);

        _logFiles.add(fileName);
        if (mounted) {
          setState(() {});
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Log saved as $fileName')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving log file: $e')),
        );
      }
    }
  }

  double _applyGravityConversion(dynamic gravity) {
    // Example conversion logic for gravity
    // Replace with actual conversion logic based on settings
    return gravity is double ? gravity * 1.01 : 0.0;
  }

  double _applyTemperatureConversion(dynamic temperature) {
    // Example conversion logic for temperature
    // Replace with actual conversion logic based on settings
    return temperature is double ? (temperature - 32) * 5 / 9 : 0.0;
  }

  Future<void> _openFile(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$fileName';
    try {
      final result =
          await OpenFilex.open(path, type: 'text/csv'); // Explicit MIME type
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: ${result.message}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logging Page'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Dropdown for selecting a Tilt device
            Row(
              children: [
                const Text(
                  'Select Tilt:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: widget.dataService.beaconsStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Text('No devices found');
                      }

                      final beacons = snapshot.data!;
                      return DropdownButton<String>(
                        value: _selectedMacAddress,
                        isExpanded: true,
                        hint: const Text('Select a device'),
                        items: beacons.map((beacon) {
                          return DropdownMenuItem<String>(
                            value: beacon['macAddress'],
                            child: Text(
                                '${beacon['color']} - ${beacon['macAddress']}'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedMacAddress = value;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isLogging || _selectedMacAddress == null
                      ? null
                      : _startLogging,
                  child: const Text('Start Logging'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isLogging ? _stopLogging : null,
                  child: const Text('Stop Logging'),
                ),
              ],
            ),
            const Divider(),
            const Text(
              'Live Graph:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: _gravityData,
                      isCurved: true,
                      gradient: const LinearGradient(
                        colors: [Colors.blue, Colors.lightBlueAccent],
                      ),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: const LinearGradient(
                          colors: [Colors.blueAccent, Colors.transparent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(4), // Gravity in SG
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54),
                          );
                        },
                      ),
                      axisNameWidget: const Text(
                        'Gravity (SG)',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      axisNameSize: 20,
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(), // Time index
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54),
                          );
                        },
                      ),
                      axisNameWidget: const Text(
                        'Time (Index)',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      axisNameSize: 20,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: const Border(
                      left: BorderSide(color: Colors.black26, width: 1),
                      bottom: BorderSide(color: Colors.black26, width: 1),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    drawHorizontalLine: true,
                    horizontalInterval: 0.002, // Adjust for SG range
                    verticalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.black12,
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.black12,
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      );
                    },
                  ),
                  backgroundColor: Colors.white,
                  minX: 0,
                  maxX: _dataIndex.toDouble(),
                  minY: _gravityData.isNotEmpty
                      ? (_gravityData
                                  .map((e) => e.y)
                                  .reduce((a, b) => a < b ? a : b) -
                              0.02)
                          .clamp(
                              1.000, 1.050) // Ensure minimum zoom-out of 0.05
                      : 1.000, // Default
                  maxY: _gravityData.isNotEmpty
                      ? (_gravityData
                                  .map((e) => e.y)
                                  .reduce((a, b) => a > b ? a : b) +
                              0.02) // Add buffer
                          .clamp(
                              1.070,
                              double
                                  .infinity) // Ensure minimum zoom-out of 0.05
                      : 1.100, // Default
                ),
              ),
            ),
            const Divider(),
            const Text(
              'Log Files:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _logFiles.length,
                itemBuilder: (context, index) {
                  final fileName = _logFiles[index];
                  return ListTile(
                    title: Text(fileName),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        final directory =
                            await getApplicationDocumentsDirectory();
                        final path = '${directory.path}/$fileName';
                        final file = File(path);

                        if (value == 'delete') {
                          try {
                            if (await file.exists()) {
                              await file.delete();
                              _logFiles.removeAt(index);
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$fileName deleted')),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Error deleting file: $e')),
                            );
                          }
                        } else if (value == 'rename') {
                          final TextEditingController controller =
                              TextEditingController(text: fileName);
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Rename File'),
                                content: TextField(
                                  controller: controller,
                                  decoration: const InputDecoration(
                                    labelText: 'New file name',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final newFileName =
                                          controller.text.trim();
                                      if (newFileName.isNotEmpty &&
                                          newFileName != fileName) {
                                        final newPath =
                                            '${directory.path}/$newFileName';
                                        try {
                                          await file.rename(newPath);
                                          _logFiles[index] = newFileName;
                                          setState(() {});
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    '$fileName renamed to $newFileName')),
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    'Error renaming file: $e')),
                                          );
                                        }
                                      }
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('Rename'),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                        const PopupMenuItem(
                          value: 'rename',
                          child: Text('Rename'),
                        ),
                      ],
                    ),
                    onTap: () async {
                      await _openFile(fileName); // Call _openFile when tapped
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
