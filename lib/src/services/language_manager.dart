import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageManager extends ChangeNotifier {
  static final LanguageManager instance = LanguageManager._internal();

  LanguageManager._internal();

  static const String _keyLanguage = 'selected_language';
  String _currentLanguageCode = 'en';
  final bool _isDownloadingModel = false;
  Map<String, Map<String, String>> _translations = {};

  String get currentLanguageCode => _currentLanguageCode;
  bool get isDownloadingModel => _isDownloadingModel;

  /// Initialize and load saved language or fallback to detected system language
  Future<void> initialize() async {
    // Load local JSON translations
    try {
      final jsonString = await rootBundle.loadString('assets/translations.json');
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      _translations = jsonMap.map((key, value) {
        return MapEntry(
          key,
          Map<String, String>.from(value as Map),
        );
      });
    } catch (e) {
      debugPrint('Error loading translations: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString(_keyLanguage);
    
    if (savedLang != null && savedLang.isNotEmpty) {
      _currentLanguageCode = savedLang;
    } else {
      // Detect system language
      final systemLocale = PlatformDispatcher.instance.locale;
      final sysLang = systemLocale.languageCode.toLowerCase();
      
      if (sysLang == 'hi' || sysLang == 'ta') {
        _currentLanguageCode = sysLang;
      } else {
        _currentLanguageCode = 'en'; // Default fallback
      }
    }
    notifyListeners();
  }

  /// Check if a language model is downloaded (always true for local JSON translations)
  Future<bool> isModelDownloaded(String langCode) async {
    return true;
  }

  /// Change the app language
  Future<bool> setLanguage(String langCode) async {
    if (langCode == _currentLanguageCode) return true;

    _currentLanguageCode = langCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, langCode);
    
    notifyListeners();
    return true;
  }

  /// Translate the given text using local JSON map lookups
  Future<String> translate(String text) async {
    final lang = _currentLanguageCode;
    if (lang == 'en' || text.trim().isEmpty) {
      return text;
    }
    
    final trimmedText = text.trim();
    final translated = _translations[trimmedText]?[lang];
    
    return translated ?? text; // Fallback to original text if not found in JSON
  }

  /// Synchronously translate the given text using the already loaded JSON map
  String translateSync(String text) {
    final lang = _currentLanguageCode;
    if (lang == 'en' || text.trim().isEmpty) {
      return text;
    }
    
    final trimmedText = text.trim();
    final translated = _translations[trimmedText]?[lang];
    
    return translated ?? text;
  }
}
