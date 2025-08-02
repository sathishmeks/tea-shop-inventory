import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class LanguageService {
  static const String _languageKey = 'selected_language';
  static const String _boxName = 'settings';
  
  static Box? _box;
  
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }
  
  static String get currentLanguage {
    return _box?.get(_languageKey, defaultValue: 'en') ?? 'en';
  }
  
  static Future<void> setLanguage(String languageCode) async {
    await _box?.put(_languageKey, languageCode);
  }
  
  static Locale get currentLocale {
    final languageCode = currentLanguage;
    return Locale(languageCode, '');
  }
  
  static List<Locale> get supportedLocales => const [
    Locale('en', ''), // English
    Locale('ta', ''), // Tamil
  ];
  
  static String getLanguageName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'ta':
        return 'தமிழ்';
      default:
        return 'English';
    }
  }
}
