import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Reads a cited article without leaving the app.
///
/// Everything opens inside this page: a citation points at one page, and
/// following links out of it into a browser would lose the way back to the
/// answer that raised the question.
class ArticleWebView extends StatefulWidget {
  const ArticleWebView({super.key, required this.url, required this.title});

  final String url;

  /// Shown in the bar until the page says what it is called.
  final String title;

  @override
  State<ArticleWebView> createState() => _ArticleWebViewState();
}

class _ArticleWebViewState extends State<ArticleWebView> {
  static const _background = Color(0xFF050505);
  static const _surface = Color(0xFF141414);
  static const _border = Color(0x1AFFFFFF);

  late final WebViewController _controller;

  /// Progress of the current load, 0 to 1. Complete pages sit at 1.
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // The page is dark; a white canvas behind it flashes on every load.
      ..setBackgroundColor(_background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress / 100);
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _progress = 0;
                _error = null;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _progress = 1);
          },
          onWebResourceError: (error) {
            // Sub-resources fail all the time — an image, a font — and only a
            // failed main document is worth taking the page over.
            if (!mounted || error.isForMainFrame == false) return;
            setState(() {
              _progress = 1;
              _error =
                  'Halaman rujukan tidak bisa dimuat. Periksa koneksi '
                  'internet Anda lalu coba lagi.';
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _reload() async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: _border)),
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: _reload,
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
        bottom: _progress >= 1
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
      ),
      // Going back should walk the page's own history first, and only leave
      // once there is nothing left to go back to.
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final navigator = Navigator.of(context);
          if (await _controller.canGoBack()) {
            await _controller.goBack();
            return;
          }
          navigator.pop();
        },
        child: _error == null
            ? WebViewWidget(controller: _controller)
            : _Failure(message: _error!, onRetry: _reload),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 34,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Coba lagi'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
