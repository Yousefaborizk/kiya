import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/localization/app_localization.dart';
import 'config/routes/app_router.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';

class SiExporterApp extends ConsumerWidget {
  const SiExporterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    // ⚠️ السطر ده هو السر: بنستخدم context.locale عشان نغير الـ Key
    // لما اللغة تتغير، الـ Key يتغير، و MaterialApp يعيد بناء الشجرة كلها
    return MaterialApp.router(
      key: ValueKey(context.locale.languageCode),
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: context.locale,
      supportedLocales: AppLocalization.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      routerConfig: router,
    );
  }
}
