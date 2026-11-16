import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme.dart';

/// 内嵌网页：加载「天启系统网」。
class ForumWebScreen extends StatefulWidget {
  const ForumWebScreen({super.key});

  static const String url = 'http://121.43.108.53';

  @override
  State<ForumWebScreen> createState() => _ForumWebScreenState();
}

class _ForumWebScreenState extends State<ForumWebScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _failed = false;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame == false) return;
            setState(() {
              _loading = false;
              _failed = true;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(ForumWebScreen.url));
  }

  Future<void> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _buildBar(),
            if (_loading)
              LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: AppColors.divider,
                color: AppColors.accent,
              ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: WebViewWidget(controller: _controller)),
                  if (_failed) Positioned.fill(child: _buildFailed()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 46,
          child: Row(
            children: [
              const SizedBox(width: 4),
              IconButton(
                onPressed: _handleBack,
                splashRadius: 18,
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '天启系统网',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'EXTERNAL NODE',
                style: TextStyle(
                  fontSize: 8,
                  letterSpacing: 1.1,
                  fontFamily: 'monospace',
                  color: AppColors.techLabel,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  setState(() => _failed = false);
                  _controller.reload();
                },
                splashRadius: 18,
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFailed() {
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '页面加载失败',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ForumWebScreen.url,
              style: TextStyle(
                fontSize: 9,
                fontFamily: 'monospace',
                color: AppColors.techLabel,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                setState(() => _failed = false);
                _controller.reload();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: BorderSide(
                  color: AppColors.accent.withValues(alpha: 0.75),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text(
                '重新加载',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
