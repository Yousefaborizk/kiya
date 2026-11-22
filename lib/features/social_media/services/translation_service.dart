// lib/features/social_media/services/translation_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class TranslationService {
  /// دالة الترجمة المباشرة عبر HTTP
  /// [text]: النص المراد ترجمته
  /// [to]: اللغة الهدف (مثل 'ar', 'en', 'zh-CN')
  /// [from]: اللغة المصدر (الافتراضي 'auto' للاكتشاف التلقائي)
  Future<String> translate({
    required String text,
    required String to,
    String from = 'auto',
  }) async {
    // 1. التأكد من أن النص ليس فارغاً
    if (text.trim().isEmpty) return '';

    try {
      // 2. تجهيز الرابط (نستخدم واجهة جوجل المخفية client=gtx لأنها سريعة ومجانية)
      final String url = 'https://translate.googleapis.com/translate_a/single'
          '?client=gtx&sl=$from&tl=$to&dt=t&q=${Uri.encodeComponent(text.trim())}';

      // 3. إرسال الطلب مع مهلة زمنية 10 ثوانٍ لمنع التعليق
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // 4. تحليل استجابة جوجل (تكون على شكل مصفوفة معقدة)
        final data = jsonDecode(response.body);
        final List<dynamic> segments = data[0];

        // 5. دمج أجزاء الترجمة (لأن جوجل قد يقسم النص الطويل إلى أجزاء)
        final StringBuffer translatedText = StringBuffer();
        for (var segment in segments) {
          if (segment[0] != null) {
            translatedText.write(segment[0]);
          }
        }

        return translatedText.toString();
      } else {
        throw Exception(
            'فشل الاتصال بخادم الترجمة (كود: ${response.statusCode})');
      }
    } on TimeoutException {
      // 6. معالجة خطأ انتهاء المهلة
      throw Exception(
          'استغرق الاتصال بالخادم وقتاً طويلاً. يرجى المحاولة مرة أخرى.');
    } on SocketException {
      // 7. معالجة خطأ انقطاع الإنترنت
      throw Exception('تعذر الاتصال بالإنترنت. يرجى التحقق من الشبكة.');
    } on FormatException {
      // 8. معالجة خطأ في قراءة البيانات (في حال تغيرت استجابة جوجل)
      throw Exception('حدث خطأ في استجابة الخادم. يرجى المحاولة لاحقاً.');
    } catch (e) {
      // 9. أي خطأ آخر غير متوقع
      if (e.toString().contains('SocketException')) {
        throw Exception('تعذر الاتصال بالإنترنت. يرجى التحقق من الشبكة.');
      }
      throw Exception('حدث خطأ أثناء الترجمة. يرجى المحاولة لاحقاً.');
    }
  }
}
