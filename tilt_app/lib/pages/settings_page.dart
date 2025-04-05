import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  final Map<String, Map<String, dynamic>> beacons;

  const SettingsPage({super.key, required this.beacons});

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

  @override
  Widget build(BuildContext context) {
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
                  TextFormField(
                    controller: _macAddressController,
                    decoration: const InputDecoration(labelText: 'MAC Address'),
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
                    onPressed: () {
                      // Save settings logic here
                      print('Settings saved');
                    },
                    child: const Text('Save Settings'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.beacons.length,
                itemBuilder: (context, index) {
                  final beacon = widget.beacons.values.elementAt(index);
                  return ListTile(
                    title: Text('MAC: ${beacon['macAddress']}'),
                    subtitle: Text(
                        'UUID: ${beacon['uuid']}, Color: ${beacon['color']}'),
                    onTap: () {
                      setState(() {
                        _macAddressController.text = beacon['macAddress'];
                      });
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
