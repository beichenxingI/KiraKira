import 'dart:async';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Widget that renders HTML content using a WebView for full CSS support
// Global serial queue: prevents multiple WebViews initializing at once, which crashes the renderer process
class _WebViewLoadQueue {
  static final _WebViewLoadQueue _instance = _WebViewLoadQueue._();
  _WebViewLoadQueue._();

  bool _busy = false;
  final _pending = <Completer<void>>[];

  Future<void> waitTurn() {
    if (!_busy) {
      _busy = true;
      return Future.value();
    }
    final c = Completer<void>();
    _pending.add(c);
    return c.future;
  }

  void done() {
    if (_pending.isNotEmpty) {
      final next = _pending.removeAt(0);
      Future.microtask(() => next.complete());
    } else {
      _busy = false;
    }
  }
}
class HtmlWebViewWidget extends StatefulWidget {
  final String htmlContent;
  final Color backgroundColor;
  final Color textColor;
  final double? fontSize;
  final VoidCallback? onLongPress;
  final String? contentKey;
  final int initDelay;

  const HtmlWebViewWidget({
    super.key,
    required this.htmlContent,
    this.backgroundColor = Colors.transparent,
    this.textColor = AppTheme.textPrimary,
    this.fontSize,
    this.onLongPress,
    this.contentKey,
    this.initDelay = 0,
  });

  @override
  State<HtmlWebViewWidget> createState() => _HtmlWebViewWidgetState();
}

class _HtmlWebViewWidgetState extends State<HtmlWebViewWidget> with AutomaticKeepAliveClientMixin {
  double _contentHeight = 100;
  bool _isReady = false;
  double _lastWidth = 0;
  bool _hasReleasedQueue = false;
  final double _minHeight = 50;
  bool _isLoading = true;
  InAppWebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });
    _initSequenced();
  }

  Future<void> _initSequenced() async {
    await _WebViewLoadQueue._instance.waitTurn();
    if (!mounted) {
      _WebViewLoadQueue._instance.done();
      return;
    }
    setState(() => _isReady = true);
    // Safety fallback: force-release the queue if no contentHeight arrives within 5 seconds
    Future.delayed(const Duration(seconds: 5), _releaseQueue);
  }

  void _releaseQueue() {
    if (!_hasReleasedQueue) {
      _hasReleasedQueue = true;
      _WebViewLoadQueue._instance.done();
    }
  }

  @override
  bool get wantKeepAlive => false;

  @override
  void dispose() {
    _releaseQueue(); // Release the queue if the WebView is destroyed while still holding it
    _webViewController = null;
    super.dispose();
  }
  Future<void> _recheckHeight() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted && _webViewController != null) {
      await _webViewController!.evaluateJavascript(source: 'sendHeight();');
    }
  }

  @override
  void didUpdateWidget(HtmlWebViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final contentChanged = widget.htmlContent != oldWidget.htmlContent;
    final keyChanged = widget.contentKey != oldWidget.contentKey &&
        widget.contentKey != null;
    if (contentChanged || keyChanged) {
      _reloadContent();
    }
  }

  bool _isReloading = false;

  void _reloadContent() async {
    if (_isReloading) return;
    _isReloading = true;
    setState(() {
      _isLoading = true;
    });
    await Future.delayed(const Duration(milliseconds: 50));
    if (mounted && _webViewController != null) {
      await _webViewController!.loadData(
        data: _buildHtml(),
        mimeType: 'text/html',
        encoding: 'utf-8',
        baseUrl: null,
      );
    }
    _isReloading = false;
  }

  String _buildHtml() {
    final effectiveFontSize = widget.fontSize ?? 14.0;
    final textColorHex = _colorToHex(widget.textColor);
    final htmlContent = widget.htmlContent;

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    html, body {
      min-height: 0 !important;
      height: auto !important;
    }
    * {
      box-sizing: border-box;
      -webkit-tap-highlight-color: transparent;
    }
    html, body {
      margin: 0;
      padding: 8px;
      background-color: transparent;
      color: $textColorHex;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      font-size: ${effectiveFontSize}px;
      line-height: 1.5;
      overflow-x: hidden;
      overflow-y: hidden;
      word-wrap: break-word;
    }
    img {
      max-width: 100%;
      height: auto;
      border-radius: 8px;
      display: block;
    }
    a {
      color: #7C4DFF;
      text-decoration: underline;
    }
    h1, h2, h3, h4, h5, h6 {
      margin-top: 0.5em;
      margin-bottom: 0.3em;
      font-weight: bold;
    }
    h1 { font-size: 1.8em; }
    h2 { font-size: 1.5em; }
    h3 { font-size: 1.3em; }
    h4 { font-size: 1.1em; }
    p { margin: 0 0 0.5em 0; }
    ::-webkit-scrollbar { width: 6px; height: 6px; }
    ::-webkit-scrollbar-track { background: transparent; }
    ::-webkit-scrollbar-thumb {
      background: rgba(255,255,255,0.2);
      border-radius: 3px;
    }
  </style>
</head>
<body>
$htmlContent
<script>
  function debounce(fn, delay) {
    var timer = null;
    return function() {
      clearTimeout(timer);
      timer = setTimeout(fn, delay);
    };
  }

  function getContentHeight() {
    var body = document.body;
    var rects = [];
    Array.from(body.children).forEach(function(el) {
      var pos = window.getComputedStyle(el).position;
      if (pos !== 'absolute' && pos !== 'fixed') {
        rects.push(el.getBoundingClientRect().bottom);
      }
    });
    if (rects.length > 0) {
      return Math.max.apply(null, rects) + 8;
    }
    return Math.max(
      document.body.scrollHeight,
      document.documentElement.scrollHeight
    );
  }
  function sendHeight() {
    try {
      var height = getContentHeight();
      if (height > 10 && height < 50000 && window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('contentHeight', height);
      }
    } catch(e) {}
  }

  // After interactions such as expand/collapse, measure several times to obtain a stable final height
  function measureAfterInteraction() {
    sendHeight();
    setTimeout(sendHeight, 50);
    setTimeout(sendHeight, 200);
    setTimeout(sendHeight, 400);
  }

  var debouncedSendHeight = debounce(sendHeight, 200);

  // Clicks trigger panel expansion (instant, no transition); re-measure height after the click
  document.addEventListener('click', function() {
    measureAfterInteraction();
  }, true);

  function watchImages() {
    var images = document.querySelectorAll('img');
    images.forEach(function(img) {
      if (!img.complete) {
        img.addEventListener('load', debouncedSendHeight);
        img.addEventListener('error', debouncedSendHeight);
      }
    });
  }

  function init() {
    watchImages();
    sendHeight();
    setTimeout(sendHeight, 300);
    setTimeout(sendHeight, 800);
    setTimeout(sendHeight, 2000);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  window.addEventListener('load', function() {
    setTimeout(sendHeight, 100);
    setTimeout(sendHeight, 1500);
  });
</script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final currentWidth = constraints.maxWidth;
        if (_lastWidth > 0 && (currentWidth - _lastWidth).abs() > 10) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _lastWidth = currentWidth;
            _recheckHeight();
          });
        } else if (_lastWidth == 0) {
          _lastWidth = currentWidth;
        }
        
        if (!_isReady) {
          return const SizedBox(height: 100);
        }
        return GestureDetector(
      onLongPress: widget.onLongPress,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: DesignTokens.curveEmphasized,
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: _contentHeight,
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: widget.backgroundColor)),
            InAppWebView(
              initialData: InAppWebViewInitialData(
                data: _buildHtml(),
                mimeType: 'text/html',
                encoding: 'utf-8',
                baseUrl: null,
              ),
              initialSettings: InAppWebViewSettings(
                transparentBackground: true,
                disableHorizontalScroll: true,
                disableVerticalScroll: true,
                supportZoom: false,
                javaScriptEnabled: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                useShouldOverrideUrlLoading: true,
                allowsBackForwardNavigationGestures: false,
                iframeAllowFullscreen: false,
                allowUniversalAccessFromFileURLs: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                databaseEnabled: true,
                domStorageEnabled: true,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
                controller.addJavaScriptHandler(
                  handlerName: 'contentHeight',
                  callback: (args) {
                    if (args.isNotEmpty && mounted) {
                      final height = (args[0] as num).toDouble();
                      if (height > 10 && height < 50000) {
                        final newHeight = height + 24;
                        if ((newHeight - _contentHeight).abs() > 5) {
                          setState(() {
                            _contentHeight = newHeight;
                            _isLoading = false;
                          });
                        }
                        _releaseQueue();
                      }
                    }
                  },
                );
              },
              onLoadStop: (controller, url) async {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
                await controller.evaluateJavascript(source: '''
                    document.body.style.minHeight = 'auto';
                    document.documentElement.style.minHeight = 'auto';
                    sendHeight();
                    if (!window._moAttached) {
                      window._moAttached = true;
                      var _mo = new MutationObserver(function() {
                        setTimeout(function(){ debouncedSendHeight(); }, 150);
                      });
                      _mo.observe(document.body, { childList: true, subtree: true });
                    }
                  ''');
                Future.delayed(const Duration(milliseconds: 400), () {
                  if (mounted && _webViewController != null) {
                    _webViewController!.evaluateJavascript(source: 'sendHeight();');
                  }
                });
              },
              onReceivedError: (controller, request, error) {
                debugPrint('WebView error: ${error.type} - ${error.description}');
              },
              onConsoleMessage: (controller, consoleMessage) {
                debugPrint('Console: ${consoleMessage.message}');
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final url = navigationAction.request.url;
                if (url != null && url.toString() != 'about:blank') {
                  final uri = Uri.tryParse(url.toString());
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                  return NavigationActionPolicy.CANCEL;
                }
                return NavigationActionPolicy.ALLOW;
              },
            ),
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: AppTheme.darkCard,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(height: 8),
                        Text(
                          'Loading...',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        ),
      ),
        );
      },
    );
  }

  String _colorToHex(Color color) {
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    return 'rgba($r, $g, $b, ${color.a})';
  }
}

/// Check if HTML content is complex enough to warrant WebView rendering
bool isComplexHtml(String html) {
  final complexPatterns = [
    RegExp(r'display:\s*flex', caseSensitive: false),
    RegExp(r'display:\s*grid', caseSensitive: false),
    RegExp(r'box-shadow:', caseSensitive: false),
    RegExp(r'transition:', caseSensitive: false),
    RegExp(r'transform:', caseSensitive: false),
    RegExp(r'animation:', caseSensitive: false),
    RegExp(r'@keyframes', caseSensitive: false),
    RegExp(r'object-fit:', caseSensitive: false),
    RegExp(r'background:\s*linear-gradient', caseSensitive: false),
    RegExp(r'background:\s*radial-gradient', caseSensitive: false),
  ];

  for (final pattern in complexPatterns) {
    if (pattern.hasMatch(html)) {
      return true;
    }
  }
  return false;
}