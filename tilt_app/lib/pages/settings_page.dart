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

  Future<void> _saveSettings() async {
    final settings = {
      'macAddress': _macAddressController.text,
      'calibrationSG': _calibrationSGController.text,
      'calibrationTemperature': _calibrationTemperatureController.text,
      'gravityUnit': _gravityUnit,
      'temperatureUnit': _temperatureUnit,
    };
    await _settingsService.saveSettings(settings);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<DataService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings Page'),
      ),
      body: Padding(
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
                        onChanged: (value) {
                          setState(() {
                            _macAddressController.text = value!;
                          });
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
                    items: ['SG', 'Plato', 'Brix'].map((String unit) {
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
                    onPressed: _saveSettings,
                    child: const Text('Save Settings'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Detected Tilts:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: dataService.beaconsStream,
                initialData: const [],
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  final beacons = snapshot.data!;

                  return ListView.builder(
                    itemCount: beacons.length,
                    itemBuilder: (context, index) {
                      final beacon = beacons[index];
                      return ListTile(
                        title: Text(
                            '${beacon['color']} - ${beacon['macAddress'].substring(9)}'),
                        subtitle: Text('UUID: ${beacon['uuid']}'),
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
            ),
          ],
        ),
      ),
    );
  }
}
