import 'dart:async';
import 'dart:math' as math; // For rotation angle
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert'; // Import for utf8
import 'package:tilt_app/services/data_service.dart'; // Assuming this path is correct
import 'package:open_filex/open_filex.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // For date formatting

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

  @override
  void initState() {
    super.initState();
    _loadLogFiles();
  }

  @override
  void dispose() {
    _stopLogging();
    super.dispose();
  }

  Future<void> _loadLogFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();
      _logFiles = files
          .whereType<File>()
          .where((file) => file.path.endsWith('.csv'))
          .map((file) => file.uri.pathSegments.last)
          .toList();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print("Error loading log files: $e");
      // Optionally show a snackbar or handle error
    }
  }

  void _startLogging() {
    if (_isLogging || _selectedMacAddress == null) return;
    _isLogging = true;
    _logData.clear();
    _gravityData.clear();
    _startLoggingTimer();
    if (mounted) {
      setState(() {});
    }
  }

  void _updateGraphData(double gravity) {
    if (mounted) {
      setState(() {
        final now = DateTime.now();
        _gravityData
            .add(FlSpot(now.millisecondsSinceEpoch.toDouble(), gravity));
      });
    }
  }

  void _startLoggingTimer() {
    _loggingTimer?.cancel(); // Cancel any existing timer
    _loggingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted || !_isLogging) {
        timer.cancel();
        return;
      }
      if (_selectedMacAddress != null) {
        try {
          // It's generally safer to listen to a stream rather than awaiting .first
          // if the stream is continuous and might not emit immediately or if you need ongoing updates.
          // However, if DataService.beaconsStream is a BehaviorSubject or similar that holds the last value,
          // .first might be okay for getting the current state.
          // For robustness with a general Stream, a StreamSubscription would be better if you need to react to multiple emissions.
          final latestBeacons = await widget.dataService.beaconsStream.first;
          final beaconData = latestBeacons.firstWhere(
            (beacon) => beacon['macAddress'] == _selectedMacAddress,
            orElse: () => {}, // Return an empty map if not found
          );

          if (beaconData.isNotEmpty) {
            final calibratedGravity =
                beaconData['calibratedGravity'] as double? ?? 0.0;
            final calibratedTemperature =
                beaconData['calibratedTemperature'] as double? ?? 0.0;
            _updateGraphData(calibratedGravity);
            _logData.add([
              DateTime.now().toIso8601String(),
              calibratedGravity.toStringAsFixed(4),
              calibratedTemperature.toStringAsFixed(1),
              beaconData['rssi']?.toString() ?? 'N/A',
              beaconData['distance']?.toString() ?? 'N/A',
              _applyGravityConversion(calibratedGravity).toStringAsFixed(4),
              _applyTemperatureConversion(calibratedTemperature)
                  .toStringAsFixed(1),
            ]);
          }
        } catch (e) {
          print("Error in logging timer: $e");
          // Consider how to handle errors, e.g., if the stream closes unexpectedly
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
      try {
        final directory = await getApplicationDocumentsDirectory();
        final fileName =
            'tilt_data_${DateTime.now().millisecondsSinceEpoch}.csv';
        final path = '${directory.path}/$fileName';
        final file = File(path);
        final header = [
          'Timestamp (ISO8601)',
          'Calibrated Gravity (SG)',
          'Calibrated Temperature (°F)',
          'RSSI',
          'Distance (m)',
          'Converted Gravity',
          'Converted Temperature'
        ];
        final csvData = [header, ..._logData];
        final csv =
            '\uFEFF${const ListToCsvConverter(eol: '\n').convert(csvData)}';
        await file.writeAsString(csv, encoding: utf8);
        _logFiles.add(fileName);
        if (mounted) setState(() {});
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Log saved as $fileName')));
      } catch (e) {
        print("Error saving log file: $e");
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving log file: $e')));
      }
    }
    if (mounted) {
      setState(() {}); // Update button states
    }
  }

  double _applyGravityConversion(dynamic gravity) =>
      gravity is num ? gravity.toDouble() : 0.0;
  double _applyTemperatureConversion(dynamic temperature) =>
      temperature is num ? temperature.toDouble() : 0.0;

  Future<void> _openFile(String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/$fileName';
      final result =
          await OpenFilex.open(path, type: 'text/csv'); // Specify MIME type
      if (result.type != ResultType.done) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Could not open file: ${result.message}')));
      }
    } catch (e) {
      print("Error opening file: $e");
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error opening file: $e')));
    }
  }

  String _formatTimestampForAxis(
      double timestamp, double minTimestamp, double maxTimestamp) {
    final DateTime utcDateTime =
        DateTime.fromMillisecondsSinceEpoch(timestamp.toInt(), isUtc: true);
    final DateTime localDateTime = utcDateTime.toLocal();
    final double timeRangeMinutes = (maxTimestamp - minTimestamp) / (60 * 1000);

    if (timeRangeMinutes.isNaN || timeRangeMinutes.isInfinite) {
      // Handle empty or single point data
      return DateFormat('HH:mm:ss').format(localDateTime);
    }
    if (timeRangeMinutes < 2) {
      return DateFormat('mm:ss').format(localDateTime);
    } else if (timeRangeMinutes < 120) {
      // Less than 2 hours
      return DateFormat('HH:mm').format(localDateTime);
    } else if (timeRangeMinutes < (24 * 60 * 2)) {
      // Less than 2 days
      return DateFormat('MM/dd HH:mm').format(localDateTime);
    } else {
      // More than 2 days
      return DateFormat('MM/dd').format(localDateTime);
    }
  }

  double _calculateXAxisInterval(List<FlSpot> data) {
    if (data.length < 2) return 30000; // 30 seconds
    final double timeRange = data.last.x - data.first.x;
    if (timeRange <= 0)
      return 30000; // Avoid division by zero or negative if data is weird

    final int maxLabels = 6; // Aim for this many labels on screen
    double interval = timeRange / maxLabels;

    // Snap to reasonable intervals (in milliseconds)
    if (interval <= 1000)
      interval = 1000; // 1s
    else if (interval <= 5000)
      interval = 5000; // 5s
    else if (interval <= 10000)
      interval = 10000; // 10s
    else if (interval <= 30000)
      interval = 30000; // 30s
    else if (interval <= 60000)
      interval = 60000; // 1m
    else if (interval <= 2 * 60000)
      interval = 2 * 60000; // 2m
    else if (interval <= 5 * 60000)
      interval = 5 * 60000; // 5m
    else if (interval <= 10 * 60000)
      interval = 10 * 60000; // 10m
    else if (interval <= 15 * 60000)
      interval = 15 * 60000; // 15m
    else if (interval <= 30 * 60000)
      interval = 30 * 60000; // 30m
    else if (interval <= 60 * 60000)
      interval = 60 * 60000; // 1h
    else {
      // For very long ranges, round to a multiple of a larger unit
      final double hours = interval / (60 * 60000);
      if (hours <= 2)
        interval = 2 * 60 * 60000; // 2h
      else if (hours <= 3)
        interval = 3 * 60 * 60000; // 3h
      else if (hours <= 6)
        interval = 6 * 60 * 60000; // 6h
      else if (hours <= 12)
        interval = 12 * 60 * 60000; // 12h
      else
        interval = 24 * 60 * 60000; // 24h
    }
    return interval;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logging Page')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(children: [
              const Text('Select Tilt:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: widget.dataService.beaconsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !_isLogging) {
                      return const Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              )));
                    }
                    if (snapshot.hasError)
                      return const Text('Error loading devices');
                    if (!snapshot.hasData || snapshot.data!.isEmpty)
                      return const Text('No devices found');

                    final beacons = snapshot.data!;
                    // Ensure _selectedMacAddress is valid or null
                    if (_selectedMacAddress != null &&
                        !beacons.any(
                            (b) => b['macAddress'] == _selectedMacAddress)) {
                      _selectedMacAddress = null;
                    }

                    return DropdownButton<String>(
                        value: _selectedMacAddress,
                        isExpanded: true,
                        hint: const Text('Select a device'),
                        items: beacons
                            .map((beacon) => DropdownMenuItem<String>(
                                  value: beacon['macAddress'] as String?,
                                  child: Text(
                                      '${beacon['color']} - ${beacon['macAddress']}'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (mounted) {
                            setState(() {
                              _selectedMacAddress = value;
                              if (_isLogging) {
                                _stopLogging(); // Stop current logging
                                _gravityData
                                    .clear(); // Clear data for the new device
                              }
                            });
                          }
                        });
                  },
                ),
              ),
            ]),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
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
            ]),
            const Divider(),
            const Text('Live Gravity (SG):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(
              height: 250,
              child: _gravityData.isEmpty
                  ? Center(
                      child: Text(_isLogging
                          ? "Waiting for data..."
                          : "No data. Start logging."))
                  : LineChart(
                      LineChartData(
                        lineBarsData: [
                          LineChartBarData(
                            spots: _gravityData,
                            isCurved: true,
                            gradient: const LinearGradient(
                                colors: [Colors.blue, Colors.lightBlueAccent]),
                            barWidth: 2.5,
                            isStrokeCapRound: true,
                            dotData: FlDotData(show: _gravityData.length < 60),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blueAccent.withOpacity(0.2),
                                  Colors.transparent.withOpacity(0.1)
                                ],
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
                              reservedSize: 48,
                              getTitlesWidget: (value, meta) => Text(
                                  value.toStringAsFixed(3),
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.black87)),
                              interval:
                                  0.01, // Adjust Y-axis interval as needed
                            ),
                            axisNameWidget: const Text('Gravity (SG)',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                            axisNameSize: 20,
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 48,
                              getTitlesWidget: (value, meta) {
                                if (_gravityData.isEmpty &&
                                    _gravityData.length < 2)
                                  return const SizedBox.shrink();
                                final String formattedTime =
                                    _formatTimestampForAxis(
                                        value,
                                        _gravityData.first.x,
                                        _gravityData.last.x);
                                return SideTitleWidget(
                                  meta: meta,
                                  space: 2.0,
                                  angle: -math.pi / 4, // -45 degrees rotation
                                  child: Text(formattedTime,
                                      style: const TextStyle(
                                          fontSize: 9, color: Colors.black87)),
                                );
                              },
                              interval: _calculateXAxisInterval(_gravityData),
                            ),
                            axisNameWidget: const Text('Time (Local)',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                            axisNameSize: 24,
                          ),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(
                            show: true,
                            border: Border.all(
                                color: Colors.grey.shade300, width: 1)),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          drawHorizontalLine: true,
                          horizontalInterval: 0.005,
                          getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.grey.shade200, strokeWidth: 0.8),
                          getDrawingVerticalLine: (value) => FlLine(
                              color: Colors.grey.shade200, strokeWidth: 0.8),
                        ),
                        backgroundColor: Colors.white,
                        minX: _gravityData.isNotEmpty
                            ? _gravityData.first.x
                            : DateTime.now()
                                .subtract(const Duration(minutes: 1))
                                .millisecondsSinceEpoch
                                .toDouble(),
                        maxX: _gravityData.isNotEmpty
                            ? _gravityData.last.x
                            : DateTime.now().millisecondsSinceEpoch.toDouble(),
                        minY: _gravityData.isNotEmpty
                            ? (_gravityData
                                        .map((e) => e.y)
                                        .reduce((a, b) => math.min(a, b)) -
                                    0.01)
                                .clamp(0.900, 2.000)
                            : 0.980,
                        maxY: _gravityData.isNotEmpty
                            ? (_gravityData
                                        .map((e) => e.y)
                                        .reduce((a, b) => math.max(a, b)) +
                                    0.01)
                                .clamp(0.900, 2.000)
                            : 1.120,
                        clipData: const FlClipData.all(),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (LineBarSpot touchedSpot) {
                            // Corrected parameter name
                            return Colors.blueGrey.withOpacity(0.8);
                          }, getTooltipItems:
                                  (List<LineBarSpot> touchedBarSpots) {
                            return touchedBarSpots.map((barSpot) {
                              final flSpot = barSpot;
                              final dt = DateTime.fromMillisecondsSinceEpoch(
                                      flSpot.x.toInt(),
                                      isUtc: true)
                                  .toLocal();
                              return LineTooltipItem(
                                '${flSpot.y.toStringAsFixed(4)} SG\n',
                                const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                                children: [
                                  TextSpan(
                                    text: DateFormat('HH:mm:ss').format(dt),
                                    style: TextStyle(
                                      color: Colors.grey[
                                          200], // Lighter for better contrast
                                      fontSize: 10,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                                textAlign: TextAlign.left, // Align text left
                              );
                            }).toList();
                          }),
                          handleBuiltInTouches: true,
                        ),
                      ),
                    ),
            ),
            const Divider(),
            const Text('Log Files:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Expanded(
              child: _logFiles.isEmpty
                  ? const Center(child: Text("No log files yet."))
                  : ListView.builder(
                      itemCount: _logFiles.length,
                      itemBuilder: (context, index) {
                        final fileName = _logFiles[index];
                        return ListTile(
                          title: Text(fileName,
                              style: const TextStyle(fontSize: 14)),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              final directory =
                                  await getApplicationDocumentsDirectory();
                              final path = '${directory.path}/$fileName';
                              final file = File(path);
                              if (value == 'delete') {
                                try {
                                  if (await file.exists()) await file.delete();
                                  _logFiles.removeAt(index);
                                  if (mounted) setState(() {});
                                  if (mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('$fileName deleted')));
                                } catch (e) {
                                  print("Error deleting file: $e");
                                  if (mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Error deleting file: $e')));
                                }
                              } else if (value == 'rename') {
                                final TextEditingController controller =
                                    TextEditingController(text: fileName);
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Rename File'),
                                    content: TextField(
                                        controller: controller,
                                        decoration: const InputDecoration(
                                            labelText: 'New file name')),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: const Text('Cancel')),
                                      TextButton(
                                        onPressed: () async {
                                          final newFileName =
                                              controller.text.trim();
                                          if (newFileName.isNotEmpty &&
                                              newFileName != fileName &&
                                              newFileName.endsWith('.csv')) {
                                            final newPath =
                                                '${directory.path}/$newFileName';
                                            try {
                                              await file.rename(newPath);
                                              _logFiles[index] = newFileName;
                                              if (mounted) setState(() {});
                                              if (mounted)
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                        content: Text(
                                                            '$fileName renamed to $newFileName')));
                                            } catch (e) {
                                              print("Error renaming file: $e");
                                              if (mounted)
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                        content: Text(
                                                            'Error renaming file: $e')));
                                            }
                                          } else if (!newFileName
                                              .endsWith('.csv')) {
                                            if (mounted)
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          'File name must end with .csv')));
                                          }
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text('Rename'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                  value: 'delete', child: Text('Delete')),
                              const PopupMenuItem(
                                  value: 'rename', child: Text('Rename')),
                            ],
                          ),
                          onTap: () async => await _openFile(fileName),
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
