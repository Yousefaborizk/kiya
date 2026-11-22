import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/language_provider.dart';
import '../../providers/theme_provider.dart';

class AppBarActions extends ConsumerWidget {
  const AppBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(languageProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Language Switcher ─────────────────────────────
        PopupMenuButton<String>(
          tooltip: 'language'.tr(),
          onSelected: (code) async {
            // 1. نغير الـ Provider عشان نجبر التطبيق يعيد البناء
            await ref.read(languageProvider.notifier).changeLanguage(code);
            // 2. نزامن EasyLocalization
            if (context.mounted) {
              await context.setLocale(Locale(code));
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'ar', child: Text('🇪🇬 العربية')),
            PopupMenuItem(value: 'en', child: Text('🇬🇧 English')),
            PopupMenuItem(value: 'zh', child: Text('🇨🇳 中文')),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language, color: Colors.white, size: 20),
                const SizedBox(width: 4),
                Text(
                  language.languageCode.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Theme Switcher ────────────────────────────────
        IconButton(
          tooltip: themeMode == ThemeMode.dark
              ? 'light_mode'.tr()
              : 'dark_mode'.tr(),
          icon: Icon(
            themeMode == ThemeMode.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
          ),
          onPressed: () {
            ref.read(themeModeProvider.notifier).toggleTheme();
          },
        ),
      ],
    );
  }
}
