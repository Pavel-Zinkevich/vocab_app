import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple global language service.
/// Uses SharedPreferences to persist the user's selection.
class LanguageService extends ChangeNotifier {
  static final LanguageService instance = LanguageService._internal();

  String _current = 'fr'; // default

  LanguageService._internal() {
    _load();
  }

  String get currentLang => _current; // 'fr' or 'es'

  bool get isFrench => _current == 'fr';
  bool get isSpanish => _current == 'es';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('app_lang');
      if (s != null && (s == 'fr' || s == 'es')) {
        _current = s;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setLanguage(String lang) async {
    if (lang != 'fr' && lang != 'es') return;
    if (_current == lang) return;
    _current = lang;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_lang', lang);
    } catch (_) {}
    notifyListeners();
  }
}
