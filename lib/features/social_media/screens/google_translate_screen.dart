// lib/features/social_media/screens/google_translate_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Clipboard
import '../services/translation_service.dart';
import '../models/google_translate_languages.dart';

class GoogleTranslateScreen extends StatefulWidget {
  const GoogleTranslateScreen({super.key});

  @override
  State<GoogleTranslateScreen> createState() => _GoogleTranslateScreenState();
}

class _GoogleTranslateScreenState extends State<GoogleTranslateScreen> {
  final TranslationService _translationService = TranslationService();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();

  // ✅ القائمة الكاملة (130+ لغة)
  final Map<String, String> _languages = googleTranslateLanguages;

  String _sourceLang = 'auto';
  String _targetLang = 'ar';
  bool _isLoading = false;

  @override
  void dispose() {
    _sourceController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════
  // الترجمة
  // ══════════════════════════════════════════════════════
  Future<void> _translate() async {
    final text = _sourceController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final result = await _translationService.translate(
        text: text,
        from: _sourceLang,
        to: _targetLang,
      );
      if (!mounted) return;
      setState(() => _targetController.text = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ══════════════════════════════════════════════════════
  // تبديل اللغات
  // ══════════════════════════════════════════════════════
  void _swapLanguages() {
    if (_sourceLang == 'auto') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن التبديل عند اختيار "اكتشاف اللغة"'),
        ),
      );
      return;
    }
    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;

      final tempText = _sourceController.text;
      _sourceController.text = _targetController.text;
      _targetController.text = tempText;
    });
  }

  // ══════════════════════════════════════════════════════
  // نسخ الترجمة (بقت مستخدمة فعلاً في زر نسخ) ✅
  // ══════════════════════════════════════════════════════
  Future<void> _copyTranslation() async {
    final text = _targetController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد نص لنسخه')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ تم نسخ الترجمة'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // Bottom Sheet لاختيار اللغة (مع بحث)
  // ══════════════════════════════════════════════════════
  Future<void> _showLanguagePicker({
    required String title,
    required List<MapEntry<String, String>> items,
    required String currentValue,
    required ValueChanged<String> onChanged,
  }) async {
    String query = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = items
                .where((e) =>
                    e.value.toLowerCase().contains(query.toLowerCase()) ||
                    e.key.toLowerCase().contains(query.toLowerCase()))
                .toList();

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (ctx, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'اختر اللغة ($title)',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'ابحث عن لغة...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (v) => setSheetState(() => query = v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${filtered.length} لغة',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('لا توجد نتائج'))
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final lang = filtered[i];
                                final isSelected = lang.key == currentValue;
                                return ListTile(
                                  dense: true,
                                  title: Text(lang.value),
                                  subtitle: Text(
                                    lang.key,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? Icon(
                                          Icons.check,
                                          color:
                                              Theme.of(ctx).colorScheme.primary,
                                        )
                                      : null,
                                  selected: isSelected,
                                  onTap: () {
                                    onChanged(lang.key);
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════
  // ويدجت اختيار اللغة
  // ══════════════════════════════════════════════════════
  Widget _buildLanguageSelector({
    required String label,
    required String currentValue,
    required List<MapEntry<String, String>> items,
    required ValueChanged<String> onChanged,
  }) {
    final currentName = items
        .firstWhere(
          (e) => e.key == currentValue,
          orElse: () => const MapEntry('auto', 'اكتشاف اللغة'),
        )
        .value;

    return InkWell(
      onTap: () => _showLanguagePicker(
        title: label,
        items: items,
        currentValue: currentValue,
        onChanged: onChanged,
      ),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                currentName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final sourceLanguages = _languages.entries.toList();
    final targetLanguages =
        _languages.entries.where((e) => e.key != 'auto').toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('ترجمة جوجل'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ── اختيار اللغات ──
            Row(
              children: [
                Expanded(
                  child: _buildLanguageSelector(
                    label: 'من',
                    currentValue: _sourceLang,
                    items: sourceLanguages,
                    onChanged: (value) => setState(() => _sourceLang = value),
                  ),
                ),
                IconButton(
                  tooltip: 'تبديل اللغات',
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: _swapLanguages,
                ),
                Expanded(
                  child: _buildLanguageSelector(
                    label: 'إلى',
                    currentValue: _targetLang,
                    items: targetLanguages,
                    onChanged: (value) => setState(() => _targetLang = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── خانة النص المصدر ──
            Expanded(
              flex: 2,
              child: TextField(
                controller: _sourceController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'اكتب النص هنا...',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── زرار الترجمة ──
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _translate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4285F4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.translate),
                label: Text(
                  _isLoading ? 'جاري الترجمة...' : 'ترجمة',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── خانة النص المترجم + زر نسخ ──
            Expanded(
              flex: 2,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SingleChildScrollView(
                      child: _targetController.text.isEmpty
                          ? Text(
                              'الترجمة ستظهر هنا...',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            )
                          : SelectableText(
                              _targetController.text,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                            ),
                    ),
                  ),
                  // ✅ زر النسخ — بقى مستخدم فعلاً
                  if (_targetController.text.isNotEmpty)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 1,
                        child: IconButton(
                          tooltip: 'نسخ الترجمة',
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: _copyTranslation,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
