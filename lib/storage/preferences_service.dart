import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _predictionsKey = 'predictions';
  static const _themeDarkKey   = 'theme_dark';

  static Future<List<String>> getPredictions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_predictionsKey) ?? [];
  }

  static Future<void> setPredictions(List<String> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_predictionsKey, list);
  }

  static Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeDarkKey) ?? false;
  }

  static Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeDarkKey, value);
  }
}
