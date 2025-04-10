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
    _macAddressController.clear();
    _calibrationSGController.clear();
    _calibrationTemperatureController.clear();
    _gravityUnit = 'SG';
    _temperatureUnit = 'Fahrenheit';
    await _settingsService.saveSettings({
      'macAddress': '',
      'calibrationSG': '',
      'calibrationTemperature': '',
      'gravityUnit': _gravityUnit,
      'temperatureUnit': _temperatureUnit,
    });
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings reset to default')),
    );
  }

  Future<void> _saveTiltSpecificSettings(String macAddress) async {
    final settings = {
      'calibrationSG': _calibrationSGController.text,
      'calibrationTemperature': _calibrationTemperatureController.text,
      'gravityUnit': _gravityUnit,
      'temperatureUnit': _temperatureUnit,
    };
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
      setState(() {});
    }
  }

  String _applyCalibration(dynamic value, String calibrationValue) {
    if (calibrationValue.isEmpty) return value.toString();
    final calibration = double.tryParse(calibrationValue) ?? 0.0;
    return (value + calibration).toStringAsFixed(3);
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
                      final calibratedGravity = _applyCalibration(
                          beacon['gravity'], _calibrationSGController.text);
                      final calibratedTemperature = _applyCalibration(
                          beacon['temperature'],
                          _calibrationTemperatureController.text);

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
