import 'dart:async';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class LoggingPage extends StatefulWidget {
  const LoggingPage({super.key});

  @override
  State<LoggingPage> createState() => _LoggingPageState();
}

class _LoggingPageState extends State<LoggingPage> {
  bool _isLogging = false;
  Timer? _loggingTimer;
  List<List<dynamic>> _csvData = [];

  void _startLogging() {
    setState(() {
      _isLogging = true;
    });

    _loggingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      final now = DateTime.now();
      // Simulate logging data
      _csvData.add([
        now.toIso8601String(),
        'Sample MAC Address',
        'Sample Gravity',
        'Sample Temperature',
      ]);
    });
  }

  Future<void> _stopLogging() async {
    setState(() {
      _isLogging = false;
    });

    _loggingTimer?.cancel();
    _loggingTimer = null;

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/tilt_data.csv';
    final file = File(path);
    final csv = const ListToCsvConverter().convert(_csvData);
    await file.writeAsString(csv);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Data logged to $path')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logging Page'),
        actions: [
          IconButton(
            icon: Icon(_isLogging ? Icons.stop : Icons.play_arrow),
            onPressed: _isLogging ? _stopLogging : _startLogging,
          ),
        ],
      ),
      body: Center(
        child: _isLogging
            ? const Text('Logging in progress...')
            : const Text('Press the play button to start logging.'),
      ),
    );
  }
}
