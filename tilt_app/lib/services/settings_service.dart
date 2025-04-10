import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  Future<List<Map<String, String>>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsList = prefs.getStringList('settings') ?? [];
    return settingsList
        .map((s) => Map<String, String>.from(_decode(s)))
        .toList();
  }

  Future<void> saveSettings(Map<String, String> settings) async {
    final prefs = await SharedPreferences.getInstance();
    final settingsList = prefs.getStringList('settings') ?? [];
    settingsList.clear();
    settingsList.add(_encode(settings));
    await prefs.setStringList('settings', settingsList);
  }

  Future<Map<String, String>?> getTiltSettings(String macAddress) async {
    final prefs = await SharedPreferences.getInstance();
    final tiltSettings = prefs.getString('tilt_settings_$macAddress');
    return tiltSettings != null
        ? Map<String, String>.from(_decode(tiltSettings))
        : null;
  }

  Future<void> saveTiltSettings(
      String macAddress, Map<String, String> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tilt_settings_$macAddress', _encode(settings));
  }

  String _encode(Map<String, String> map) {
    return map.entries.map((e) => '${e.key}=${e.value}').join(';');
  }

  Map<String, String> _decode(String encoded) {
    return Map.fromEntries(
      encoded.split(';').map((entry) {
        final parts = entry.split('=');
        return MapEntry(parts[0], parts.length > 1 ? parts[1] : '');
      }),
    );
  }
}
