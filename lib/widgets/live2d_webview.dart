import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class Live2DWebView extends StatefulWidget {
  const Live2DWebView({super.key});
  @override
  State<Live2DWebView> createState() => _Live2DWebViewState();
}

class _Live2DWebViewState extends State<Live2DWebView> {
  final InAppLocalhostServer _localhostServer = InAppLocalhostServer(documentRoot: 'assets', port: 8080);
  bool _serverStarted = false;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  Future<void> _startServer() async {
    if (!_localhostServer.isRunning()) {
      await _localhostServer.start();
    }
    if (mounted) setState(() => _serverStarted = true);
  }

  @override
  void dispose() {
    _localhostServer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_serverStarted) return const SizedBox.shrink();
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri('http://localhost:8080/assets/live2d_web/index.html')),
      initialSettings: InAppWebViewSettings(transparentBackground: true, mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW, isInspectable: true, clearCache: false),
      onConsoleMessage: (controller, msg) => debugPrint('[Live2D WebView] ' + msg.message),
    );
  }
}