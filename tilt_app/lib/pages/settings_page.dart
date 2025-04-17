import 'package:flutter/material.dart';
import 'package:tilt_app/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:tilt_app/services/data_service.dart';

class SettingsPage extends StatefulWidget {
  final DataService dataService; // Add DataService parameter

  const SettingsPage({Key? key, required this.dataService})
      : super(key: key); // Constructor

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _macAddressController = TextEditingController();
  final TextEditingController _calibrationSGController =
      TextEditingController();
  final TextEditingController _calibrationTemperatureController =
      TextEditingController();
  String _gravityUnit = 'SG';
  String _temperatureUnit = 'Fahrenheit';
  final _settingsService = SettingsService();
  String _gravityOffset = '0.0';
  String _temperatureOffset = '0.0';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settingsList = await _settingsService.getSettings();
    if (settingsList.isNotEmpty) {
      final settings = settingsList.first;
      _macAddressController.text = settings['macAddress'] ?? '';
      _calibrationSGController.text = settings['calibrationSG'] ?? '';
      _calibrationTemperatureController.text =
          settings['calibrationTemperature'] ?? '';
      _gravityUnit = settings['gravityUnit'] ?? 'SG';
      _temperatureUnit = settings['temperatureUnit'] ?? 'Fahrenheit';
      setState(() {});
    }
  }

  Future<void> _resetSettings() async {
    final macAddress = _macAddressController.text;

    if (macAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Tilt selected to reset settings.')),
      );
      return;
    }

    // Reset settings for the selected Tilt
    await widget.dataService.updateTiltSettings(macAddress, {
      'calibrationSG': '',
      'calibrationTemperature': '',
      'gravityUnit': 'SG',
      'temperatureUnit': 'Fahrenheit',
      'gravityOffset': '0.0',
      'temperatureOffset': '0.0',
    });

    // Clear local fields
    _calibrationSGController.clear();
    _calibrationTemperatureController.clear();
    _gravityUnit = 'SG';
    _temperatureUnit = 'Fahrenheit';
    _gravityOffset = '0.0';
    _temperatureOffset = '0.0';

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Settings reset for Tilt: $macAddress')),
    );
  }

  Future<void> _saveTiltSpecificSettings(String macAddress) async {
    // Retrieve existing settings
    final existingSettings =
        await _settingsService.getTiltSettings(macAddress) ?? {};

    // Retrieve raw values from the beacon data
    final beacons = await widget.dataService.beaconsStream.first;
    final beacon = beacons.firstWhere(
      (b) => b['macAddress'] == macAddress,
      orElse: () => {},
    );

    if (beacon.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No raw data available for this Tilt.')),
      );
      return;
    }

    final rawGravity = beacon['gravity'] ?? 0.0;
    final rawTemperature = beacon['temperature'] ?? 0.0;

    // Calculate offsets only if calibration values are provided and updated
    final calibrationGravity =
        double.tryParse(_calibrationSGController.text) ?? rawGravity;
    final calibrationTemperature =
        double.tryParse(_calibrationTemperatureController.text) ??
            rawTemperature;

    final gravityOffset = _calibrationSGController.text.isNotEmpty &&
            existingSettings['calibrationSG'] != _calibrationSGController.text
        ? calibrationGravity - rawGravity
        : double.tryParse(existingSettings['gravityOffset'] ?? '0.0') ?? 0.0;

    final temperatureOffset =
        _calibrationTemperatureController.text.isNotEmpty &&
                existingSettings['calibrationTemperature'] !=
                    _calibrationTemperatureController.text
            ? calibrationTemperature - rawTemperature
            : double.tryParse(existingSettings['temperatureOffset'] ?? '0.0') ??
                0.0;

    final settings = {
      'calibrationSG': _calibrationSGController.text,
      'calibrationTemperature': _calibrationTemperatureController.text,
      'gravityUnit': _gravityUnit,
      'temperatureUnit': _temperatureUnit,
      'gravityOffset': gravityOffset.toStringAsFixed(3),
      'temperatureOffset': temperatureOffset.toStringAsFixed(1),
    }.map((key, value) => MapEntry(key, value.toString()));

    await widget.dataService.updateTiltSettings(
        macAddress, settings); // Use DataService to update settings
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Settings saved for Tilt: $macAddress')),
    );
  }

  Future<void> _loadTiltSpecificSettings(String macAddress) async {
    final settings = await _settingsService.getTiltSettings(macAddress);
    if (settings != null) {
      _calibrationSGController.text = settings['calibrationSG'] ?? '';
      _calibrationTemperatureController.text =
          settings['calibrationTemperature'] ?? '';
      _gravityUnit = settings['gravityUnit'] ?? 'SG';
      _temperatureUnit = settings['temperatureUnit'] ?? 'Fahrenheit';

      // Load offsets
      _gravityOffset = double.tryParse(settings['gravityOffset'] ?? '0.0')
              ?.toStringAsFixed(3) ??
          '0.0';
      _temperatureOffset =
          double.tryParse(settings['temperatureOffset'] ?? '0.0')
                  ?.toStringAsFixed(1) ??
              '0.0';

      setState(() {});
    }
  }

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
    final dataService = Provider.of<DataService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings Page'),
      ),
      body: SingleChildScrollView(
        // Wrap content in SingleChildScrollView
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Form(
                child: Column(
                  children: [
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: dataService.beaconsStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }

                        final beacons = snapshot.data!;
                        final currentValue = beacons.any((beacon) =>
                                beacon['macAddress'] ==
                                _macAddressController.text)
                            ? _macAddressController.text
                            : null;

                        return DropdownButtonFormField<String>(
                          decoration:
                              const InputDecoration(labelText: 'Select Tilt'),
                          value: currentValue,
                          items: beacons.map((beacon) {
                            return DropdownMenuItem<String>(
                              value: beacon['macAddress'],
                              child: Text(
                                  '${beacon['color']} - ${beacon['macAddress'].substring(9)}'),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            setState(() {
                              _macAddressController.text = value!;
                            });
                            await _loadTiltSpecificSettings(value!);
                          },
                        );
                      },
                    ),
                    TextFormField(
                      controller: _calibrationSGController,
                      decoration: const InputDecoration(
                          labelText: 'Calibration SG (optional)'),
                      keyboardType: TextInputType.number,
                    ),
                    TextFormField(
                      controller: _calibrationTemperatureController,
                      decoration: const InputDecoration(
                          labelText: 'Calibration Temperature (optional)'),
                      keyboardType: TextInputType.number,
                    ),
                    DropdownButtonFormField<String>(
                      decoration:
                          const InputDecoration(labelText: 'Gravity Unit'),
                      value: _gravityUnit,
                      items: ['SG', 'Plato'].map((String unit) {
                        return DropdownMenuItem<String>(
                          value: unit,
                          child: Text(unit),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _gravityUnit = value!;
                        });
                      },
                    ),
                    DropdownButtonFormField<String>(
                      decoration:
                          const InputDecoration(labelText: 'Temperature Unit'),
                      value: _temperatureUnit,
                      items: ['Celsius', 'Fahrenheit'].map((String unit) {
                        return DropdownMenuItem<String>(
                          value: unit,
                          child: Text(unit),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _temperatureUnit = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Display offsets persistently
                    Text(
                      'Gravity Offset: $_gravityOffset',
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      'Temperature Offset: $_temperatureOffset',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        await _saveTiltSpecificSettings(
                            _macAddressController.text);
                      },
                      child: const Text('Save Settings'),
                    ),
                    ElevatedButton(
                      onPressed: _resetSettings,
                      child: const Text('Reset Settings'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Detected Tilts:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: dataService.beaconsStream,
                initialData: const [],
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  final beacons = snapshot.data!;

                  return ListView.builder(
                    shrinkWrap:
                        true, // Ensure ListView doesn't expand infinitely
                    physics:
                        const NeverScrollableScrollPhysics(), // Disable ListView scrolling
                    itemCount: beacons.length,
                    itemBuilder: (context, index) {
                      final beacon = beacons[index];
                      final isTiltPro = beacon['isTiltPro'] ??
                          false; // Ensure isTiltPro is used

                      // Use offsets to calculate calibrated values
                      final calibratedGravity =
                          (double.tryParse(beacon['gravity'].toString()) ??
                                  0.0) +
                              (double.tryParse(_gravityOffset) ?? 0.0);
                      final calibratedTemperature =
                          (double.tryParse(beacon['temperature'].toString()) ??
                                  0.0) +
                              (double.tryParse(_temperatureOffset) ?? 0.0);

                      return ListTile(
                        title: Text(
                            '${beacon['color']} - ${beacon['macAddress'].substring(9)}'),
                        subtitle: Text(
                          'Original Gravity: ${_formatGravity(beacon['gravity'], isTiltPro)}, '
                          'Calibrated Gravity: ${_formatGravity(calibratedGravity, isTiltPro)}, '
                          'Original Temperature: ${beacon['temperature']}, '
                          'Calibrated Temperature: $calibratedTemperature',
                        ),
                        onTap: () {
                          setState(() {
                            _macAddressController.text = beacon['macAddress'];
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
