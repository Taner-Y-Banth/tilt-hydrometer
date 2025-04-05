import 'dart:async';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:tilt_app/services/data_service.dart';
import 'package:open_filex/open_filex.dart'; // Import open_filex

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
    _startLoggingTimer();
    setState(() {});
  }

  void _startLoggingTimer() {
    _loggingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_selectedMacAddress != null) {
        //  CORRECT WAY TO GET BEACON DATA
        widget.dataService.beaconsStream.listen((beacons) {
          final beaconData = beacons.firstWhere(
            (beacon) => beacon['macAddress'] == _selectedMacAddress,
            orElse: () => {},
          );
          if (beaconData.isNotEmpty) {
            _logData.add([
              DateTime.now().toIso8601String(),
              beaconData['gravity'] ?? 0.0,
              beaconData['temperature'] ?? 0.0,
              beaconData['rssi'] ?? 0,
              beaconData['distance'] ?? 0.0,
            ]);
            if (mounted) {
              // Check if widget is still in the tree
              setState(() {});
            }
          }
        });
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
        // Ensure all rows have consistent column counts
        final sanitizedData = _logData.map((row) {
          return row.map((cell) => cell.toString()).toList();
        }).toList();

        final csv = const ListToCsvConverter().convert(sanitizedData);
        await file.writeAsString(csv);
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

  Future<void> _openFile(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$fileName';
    final result =
        await OpenFilex.open(path, type: 'text/csv'); // Explicit MIME type
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: ${result.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logging Page'),
      ),
      body: Column(
        children: [
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
          const Text('Log Files:'),
          Expanded(
            child: ListView.builder(
              itemCount: _logFiles.length,
              itemBuilder: (context, index) {
                final fileName = _logFiles[index];
                return ListTile(
                  title: Text(fileName),
                  onTap: () async {
                    await _openFile(fileName);
                  },
                );
              },
            ),
          ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: widget.dataService.beaconsStream,
            initialData: const [],
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const CircularProgressIndicator();
              }

              final beacons = snapshot.data!;

              // Ensure selected value is valid
              if (_selectedMacAddress != null &&
                  !beacons.any((beacon) =>
                      beacon['macAddress'] == _selectedMacAddress)) {
                _selectedMacAddress = null;
              }

              return DropdownButton<String>(
                value: _selectedMacAddress,
                hint: const Text('Select Tilt to Log'),
                items: beacons.map((beacon) {
                  return DropdownMenuItem<String>(
                    value: beacon['macAddress'],
                    child: Text(
                      '${beacon['color']} - ${beacon['macAddress'].substring(9)}',
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMacAddress = value;
                    _logData.clear();
                    _stopLogging();
                    if (value != null) {
                      _startLogging();
                    }
                  });
                },
              );
            },
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _logData.length,
              itemBuilder: (context, index) {
                final data = _logData[index];
                return ListTile(
                  title: Text('Time: ${data[0]}'),
                  subtitle: Text(
                    'Gravity: ${data[1]}, Temperature: ${data[2]}, RSSI: ${data[3]}, Distance: ${data[4]}',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
