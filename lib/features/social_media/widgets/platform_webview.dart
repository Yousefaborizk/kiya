import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../models/social_platform.dart';

/// WebView لكل منصة.
/// - Mobile: WebView حقيقي
/// - Web: زر يفتح المنصة في المتصفح (لأن iframe ممنوع على كل المنصات دي)
class PlatformWebView extends StatefulWidget {
  final SocialPlatform platform;

  const PlatformWebView({super.key, required this.platform});

  @override
  State<PlatformWebView> createState() => _PlatformWebViewState();
}

class _PlatformWebViewState extends State<PlatformWebView>
    with AutomaticKeepAliveClientMixin {
  double _progress = 0;

  // Keep WebView alive when switching tabs — WhatsApp session persists,
  // no need to re-scan QR every time.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    if (kIsWeb) return _buildWebFallback();
    return _buildWebView();
  }

  // ══════════════════════════════════════════
  // WEB fallback (Chrome / Edge / Firefox)
  // ══════════════════════════════════════════
  Widget _buildWebFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: widget.platform.brandColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.platform.icon,
                size: 56,
                color: widget.platform.brandColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.platform.name,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'social_open_in_browser_hint'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.platform.brandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
              ),
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(
                'social_open_platform'.tr(args: [widget.platform.name]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.platform.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ══════════════════════════════════════════
  // MOBILE WebView (Android / iOS)
  // ══════════════════════════════════════════
  Widget _buildWebView() {
    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.platform.url)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
            databaseEnabled: true,
            thirdPartyCookiesEnabled: true,
            useHybridComposition: true,
            mediaPlaybackRequiresUserGesture: false,
            userAgent:
                'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
            sharedCookiesEnabled: true,
            allowsInlineMediaPlayback: true,
          ),
          onProgressChanged: (controller, progress) {
            setState(() => _progress = progress / 100);
          },

          // Grant camera/mic permissions inside the WebView
          // (required for WhatsApp Web QR scan)
          onPermissionRequest: (controller, request) async {
            return PermissionResponse(
              resources: request.resources,
              action: PermissionResponseAction.GRANT,
            );
          },

          // NOTE: File uploads (<input type="file">) are handled
          // automatically by flutter_inappwebview 6.1.5 on both Android
          // and iOS via the plugin's built-in file chooser.
          //
          // No onShowFileChooser callback is needed — it was added in
          // 6.2.0-beta and isn't available in the stable 6.1.5 release.
        ),

        // Progress bar at top while loading
        if (_progress < 1.0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: widget.platform.brandColor,
            ),
          ),
      ],
    );
  }
}
