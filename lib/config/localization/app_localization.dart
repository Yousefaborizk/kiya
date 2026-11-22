import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AppLocalization {
  AppLocalization._();

  static const List<Locale> supportedLocales = [
    Locale('ar'),
    Locale('en'),
    Locale('zh'),
  ];

  static const Locale fallbackLocale = Locale('ar');

  static const Map<String, String> languageNames = {
    'ar': 'العربية',
    'en': 'English',
    'zh': '中文',
  };

  static const Map<String, String> languageFlags = {
    'ar': '🇪🇬',
    'en': '🇬🇧',
    'zh': '🇨🇳',
  };

  static void changeLanguage(BuildContext context, String languageCode) {
    context.setLocale(Locale(languageCode));
  }
}
