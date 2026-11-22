// lib/features/social/screens/social_media_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/social_platform.dart';
import '../widgets/platform_webview.dart';
import 'whatsapp_inbox_screen.dart';
// ✅ 1. استيراد شاشة الفيسبوك
import '../../facebook/screens/facebook_inbox_screen.dart';
// ✅ 2. استيراد شاشة ترجمة جوجل الجديدة
import 'google_translate_screen.dart';

class SocialMediaScreen extends StatefulWidget {
  const SocialMediaScreen({super.key});

  @override
  State<SocialMediaScreen> createState() => _SocialMediaScreenState();
}

class _SocialMediaScreenState extends State<SocialMediaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: SocialPlatform.values.length,
      vsync: this,
      initialIndex: 0, // يبدأ بـ WhatsApp
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('social_media'.tr()),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.secondary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: SocialPlatform.values
              .map(
                (p) => Tab(
                  height: 44,
                  child: Row(
                    children: [
                      Icon(p.icon, size: 16),
                      const SizedBox(width: 6),
                      Text(p.name, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: SocialPlatform.values.map((p) {
          // ✅ الواتساب: شاشة الرسايل الخاصة بينا (Supabase)
          if (p == SocialPlatform.whatsapp) {
            return const WhatsAppInboxScreen();
          }

          // ✅ الفيسبوك: شاشة الرسايل الخاصة بينا (Supabase)
          if (p == SocialPlatform.facebook) {
            return const FacebookInboxScreen();
          }

          // ✅ ترجمة جوجل: الشاشة الجديدة
          if (p == SocialPlatform.googleTranslate) {
            return const GoogleTranslateScreen();
          }

          // ❌ باقي المنصات: WebView زي ما هي
          return PlatformWebView(platform: p);
        }).toList(),
      ),
    );
  }
}
