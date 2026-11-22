// lib/features/social/models/social_platform.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// المنصات المدعومة. الترتيب هنا = ترتيب التابات في الشاشة.
enum SocialPlatform {
  whatsapp(
    name: 'WhatsApp',
    url: 'https://web.whatsapp.com',
    icon: FontAwesomeIcons.whatsapp,
    brandColor: Color(0xFF25D366),
    needsCamera: true, // QR scan
  ),
  facebook(
    name: 'Facebook',
    url: 'https://www.facebook.com/messages',
    icon: FontAwesomeIcons.facebook,
    brandColor: Color(0xFF1877F2),
  ),
  instagram(
    name: 'Instagram',
    url: 'https://www.instagram.com/direct/inbox/',
    icon: FontAwesomeIcons.instagram,
    brandColor: Color(0xFFE1306C),
  ),
  twitter(
    name: 'X',
    url: 'https://x.com/messages',
    icon: FontAwesomeIcons.xTwitter,
    brandColor: Color(0xFF000000),
  ),
  telegram(
    name: 'Telegram',
    url: 'https://web.telegram.org/a/',
    icon: FontAwesomeIcons.telegram,
    brandColor: Color(0xFF26A5E4),
  ),
  linkedin(
    name: 'LinkedIn',
    url: 'https://www.linkedin.com/messaging/',
    icon: FontAwesomeIcons.linkedin,
    brandColor: Color(0xFF0A66C2),
  ),
  tiktok(
    name: 'TikTok',
    url: 'https://www.tiktok.com/messages',
    icon: FontAwesomeIcons.tiktok,
    brandColor: Color(0xFF000000),
  ),
  youtube(
    name: 'YouTube',
    url: 'https://studio.youtube.com',
    icon: FontAwesomeIcons.youtube,
    brandColor: Color(0xFFFF0000),
  ),

  /// ✅ التاب الجديد: ترجمة جوجل
  googleTranslate(
    name: 'ترجمة',
    url: 'https://translate.google.com',
    icon: FontAwesomeIcons.language,
    brandColor: Color(0xFF4285F4), // أزرق جوجل
  );

  const SocialPlatform({
    required this.name,
    required this.url,
    required this.icon,
    required this.brandColor,
    this.needsCamera = false,
  });

  final String name;
  final String url;
  final IconData icon;
  final Color brandColor;
  final bool needsCamera;
}
