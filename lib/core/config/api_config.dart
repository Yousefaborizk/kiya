import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  ApiConfig._();

  // ── Resolve host per platform ─────────────
  static String get _host {
    if (kIsWeb) return 'localhost';
    if (Platform.isAndroid) return '10.0.2.2';
    return 'localhost';
  }

  // ── Ports ─────────────────────────────────
  // بورت السيرفر بتاع البايثون (WhatsApp + Facebook)
  static const int serverPort = 8000;

  // ── Gateway base URLs ─────────────────────
  // بنوجه الطلبات كلها للسيرفر بتاعنا
  static String get whatsappGateway => 'http://$_host:$serverPort';
  static String get facebookGateway => 'http://$_host:$serverPort';

  // ── Full endpoints ────────────────────────
  static Uri get whatsappSendUri => Uri.parse('$whatsappGateway/send');

  // (مؤقتاً هنستخدم نفس endpoint الواتساب للفيسبوك لحد ما نضيفه)
  static Uri get facebookSendUri => Uri.parse('$facebookGateway/send');

  // ── Health check endpoints ────────────────
  static Uri get whatsappHealthUri => Uri.parse('$whatsappGateway/health');
  static Uri get facebookHealthUri => Uri.parse('$facebookGateway/health');
}
