import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SettingsService {
  static const String _settingsKey = 'device_settings';

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    final settingsList = await getSettings();
    settingsList.removeWhere((s) => s['macAddress'] == settings['macAddress']);
    settingsList.add(settings);
    final settingsJson = jsonEncode(settingsList);
    await prefs.setString(_settingsKey, settingsJson);
  }

  Future<List<Map<String, dynamic>>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);
    if (settingsJson == null) {
      return [];
    }
    final settingsList = jsonDecode(settingsJson) as List;
    return settingsList.cast<Map<String, dynamic>>();
  }
}
