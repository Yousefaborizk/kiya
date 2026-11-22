import 'package:easy_localization/easy_localization.dart';

/// Translates common units stored in DB to the current language.
///
/// Usage:
/// - **In UI widgets:** `UnitTranslator.translate(unit)` → uses current locale
/// - **In PDFs:** `UnitTranslator.translateForLocale(unit, langCode)` → no context needed
class UnitTranslator {
  UnitTranslator._();

  /// Maps DB values (Arabic / English / Chinese) → translation keys.
  static const Map<String, String> _unitKeys = {
    // ── Arabic (default in DB) ─────────────────
    'قطعة': 'unit_piece',
    'قطع': 'unit_piece',
    'كيلو': 'unit_kg',
    'كيلوجرام': 'unit_kg',
    'كجم': 'unit_kg',
    'جرام': 'unit_gram',
    'جرامات': 'unit_gram',
    'علبة': 'unit_box',
    'علب': 'unit_box',
    'كرتونة': 'unit_carton',
    'كراتين': 'unit_carton',
    'لتر': 'unit_liter',
    'لترات': 'unit_liter',
    'متر': 'unit_meter',
    'أمتار': 'unit_meter',
    'طن': 'unit_ton',
    'أطنان': 'unit_ton',
    'دستة': 'unit_dozen',
    'حزمة': 'unit_pack',
    'حزم': 'unit_pack',
    'زجاجة': 'unit_bottle',
    'زجاجات': 'unit_bottle',
    'كيس': 'unit_bag',
    'أكياس': 'unit_bag',
    'رول': 'unit_roll',
    'لفة': 'unit_roll',

    // ── English ────────────────────────────────
    'piece': 'unit_piece',
    'pieces': 'unit_piece',
    'pcs': 'unit_piece',
    'pc': 'unit_piece',
    'kg': 'unit_kg',
    'kilogram': 'unit_kg',
    'kilograms': 'unit_kg',
    'gram': 'unit_gram',
    'grams': 'unit_gram',
    'g': 'unit_gram',
    'box': 'unit_box',
    'boxes': 'unit_box',
    'carton': 'unit_carton',
    'cartons': 'unit_carton',
    'liter': 'unit_liter',
    'liters': 'unit_liter',
    'litre': 'unit_liter',
    'l': 'unit_liter',
    'meter': 'unit_meter',
    'meters': 'unit_meter',
    'm': 'unit_meter',
    'ton': 'unit_ton',
    'tons': 'unit_ton',
    'dozen': 'unit_dozen',
    'pack': 'unit_pack',
    'packs': 'unit_pack',
    'bottle': 'unit_bottle',
    'bottles': 'unit_bottle',
    'bag': 'unit_bag',
    'bags': 'unit_bag',
    'roll': 'unit_roll',
    'rolls': 'unit_roll',

    // ── Chinese ────────────────────────────────
    '件': 'unit_piece',
    '个': 'unit_piece',
    '只': 'unit_piece',
    '公斤': 'unit_kg',
    '千克': 'unit_kg',
    '克': 'unit_gram',
    '盒': 'unit_box',
    '箱': 'unit_carton',
    '升': 'unit_liter',
    '米': 'unit_meter',
    '吨': 'unit_ton',
    '打': 'unit_dozen',
    '包': 'unit_pack',
    '瓶': 'unit_bottle',
    '袋': 'unit_bag',
    '卷': 'unit_roll',
  };

  /// Direct translations — used when no BuildContext is available (e.g., PDFs).
  /// These MUST match `assets/translations/*.json`.
  static const Map<String, Map<String, String>> _directTranslations = {
    'ar': {
      'unit_piece': 'قطعة',
      'unit_kg': 'كيلوجرام',
      'unit_gram': 'جرام',
      'unit_box': 'علبة',
      'unit_carton': 'كرتونة',
      'unit_liter': 'لتر',
      'unit_meter': 'متر',
      'unit_ton': 'طن',
      'unit_dozen': 'دستة',
      'unit_pack': 'حزمة',
      'unit_bottle': 'زجاجة',
      'unit_bag': 'كيس',
      'unit_roll': 'رول',
    },
    'en': {
      'unit_piece': 'Piece',
      'unit_kg': 'Kilogram',
      'unit_gram': 'Gram',
      'unit_box': 'Box',
      'unit_carton': 'Carton',
      'unit_liter': 'Liter',
      'unit_meter': 'Meter',
      'unit_ton': 'Ton',
      'unit_dozen': 'Dozen',
      'unit_pack': 'Pack',
      'unit_bottle': 'Bottle',
      'unit_bag': 'Bag',
      'unit_roll': 'Roll',
    },
    'zh': {
      'unit_piece': '件',
      'unit_kg': '公斤',
      'unit_gram': '克',
      'unit_box': '盒',
      'unit_carton': '箱',
      'unit_liter': '升',
      'unit_meter': '米',
      'unit_ton': '吨',
      'unit_dozen': '打',
      'unit_pack': '包',
      'unit_bottle': '瓶',
      'unit_bag': '袋',
      'unit_roll': '卷',
    },
  };

  /// For UI — uses the current app locale via `tr()`.
  ///
  /// If the unit is not recognized, returns it unchanged.
  static String translate(String? unit) {
    if (unit == null || unit.isEmpty) return '';
    final key = _unitKeys[unit.trim()];
    if (key == null) return unit;
    return key.tr();
  }

  /// For PDFs or anywhere a `BuildContext` isn't available.
  ///
  /// Uses a hardcoded lookup table — no I/O, no context needed.
  /// Falls back to English if [langCode] is not found.
  static String translateForLocale(String? unit, String langCode) {
    if (unit == null || unit.isEmpty) return '';
    final key = _unitKeys[unit.trim()];
    if (key == null) return unit;

    final translations =
        _directTranslations[langCode] ?? _directTranslations['en'] ?? const {};
    return translations[key] ?? unit;
  }
}
