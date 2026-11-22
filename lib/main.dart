import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/localization/app_localization.dart';
import 'core/constants/app_constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================
  // Initialize Supabase
  // ============================================
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    publishableKey: AppConstants.supabaseAnonKey,
  );

  // ============================================
  // 🔑 TEMP: Print JWT for testing Edge Functions
  // ============================================
  // assert() block => runs only in debug, stripped in release.
  // debugPrint   => not flagged by `avoid_print` lint.
  assert(() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      debugPrint('🔑 USER_JWT: ${session.accessToken}');
      debugPrint('👤 User: ${session.user.email}');
      debugPrint('⏰ Expires: ${session.expiresAt}');
    } else {
      debugPrint('⚠️ No active session — user is not logged in.');
      debugPrint('   Log in from the app, then hot-restart to get a JWT.');
    }
    return true;
  }());

  // ============================================
  // Initialize Localization
  // ============================================
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: AppLocalization.supportedLocales,
      path: 'assets/translations',
      fallbackLocale: AppLocalization.fallbackLocale,
      child: const ProviderScope(
        child: SiExporterApp(),
      ),
    ),
  );
}
