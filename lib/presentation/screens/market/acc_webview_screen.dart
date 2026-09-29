import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/character.dart';
import 'package:kirakira/data/repositories/character_repository.dart';
import 'package:kirakira/data/repositories/regex_script_repository.dart';
import 'package:kirakira/domain/services/import_service.dart';
import 'package:kirakira/presentation/providers/character_providers.dart';
import 'package:kirakira/presentation/providers/world_info_providers.dart';
import 'package:kirakira/presentation/screens/import/import_screen.dart'
    show importServiceProvider, urlImportServiceProvider;
import 'package:kirakira/presentation/theme/design_tokens.dart';

/// AI Character Cards (aicharactercards.com) 全屏沉浸式浏览器
///
/// 国际SFW角色卡社区。系统返回键先返回网页历史，到第一页才退出。
/// 在角色详情页显示「导入到Kira」浮动按钮。
/// 点击网站下载按钮时通过JS拦截自动导入角色卡。
class AccWebViewScreen extends ConsumerStatefulWidget {
  final VoidCallback? onCharacterImported;

  const AccWebViewScreen({super.key, this.onCharacterImported});

  @override
  ConsumerState<AccWebViewScreen> createState() => _AccWebViewScreenState();
}

class _AccWebViewScreenState extends ConsumerState<AccWebViewScreen> {
  InAppWebViewController? _controller;
  double _progress = 0.0;
  bool _isLoading = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentUrl = '';
  String? _currentCharacterUrl; // 记录当前角色页面URL，用于下载fallback
  bool _vpnBannerDismissed = false;
  bool _isImporting = false;
  bool _showControls = false;
  Timer? _hideControlsTimer;

  static const _accHomeUrl = 'https://aicharactercards.com/';
  static const _acceptLanguage = 'zh-CN,zh;q=0.9,en;q=0.8';
  static const _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    // 恢复全局沉浸式模式（与 main.dart 一致）
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    _hideControlsTimer?.cancel();
    if (_showControls) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _showControls) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  /// 系统返回键逻辑：先返回网页历史，到第一页才退出
  Future<void> _onPopInvoked(bool didPop) async {
    if (didPop) return;
    final canGoBack = await _controller?.canGoBack() ?? false;
    if (canGoBack) {
      _controller?.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── 全屏 WebView ──
            Positioned.fill(
              child: Listener(
                onPointerDown: (_) => _toggleControls(),
                child: InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(_accHomeUrl),
                    headers: const {'Accept-Language': _acceptLanguage},
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    supportZoom: true,
                    useHybridComposition: true,
                    useShouldOverrideUrlLoading: true,
                    useOnDownloadStart: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    allowFileAccess: true,
                    allowContentAccess: true,
                    transparentBackground: false,
                    mixedContentMode:
                        MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                    userAgent: _desktopUserAgent,
                    allowsBackForwardNavigationGestures: true,
                  ),
                  onWebViewCreated: (c) {
                    _controller = c;
                    _registerDownloadHandler();
                  },
                  onLoadStart: (c, url) {
                    final urlStr = url?.toString() ?? '';
                    setState(() {
                      _isLoading = true;
                      _currentUrl = urlStr;
                    });
                    // 记录角色页面URL
                    if (_isCharacterPageUrl(urlStr)) {
                      _currentCharacterUrl = urlStr;
                      debugPrint('[AccWebView] On character page: $urlStr');
                    }
                  },
                  onLoadStop: (c, url) async {
                    final urlStr = url?.toString() ?? '';
                    setState(() {
                      _isLoading = false;
                      _currentUrl = urlStr;
                    });
                    // 记录角色页面URL
                    if (_isCharacterPageUrl(urlStr)) {
                      _currentCharacterUrl = urlStr;
                    }
                    await _updateNavState();
                    _injectLanguageScript();
                    _injectDownloadInterceptor();
                  },
                  onProgressChanged: (c, progress) {
                    setState(() => _progress = progress / 100.0);
                  },
                  onReceivedError: (c, request, error) {
                    if (request.isForMainFrame != true) return;
                    setState(() => _isLoading = false);
                    final desc = error.description;
                    if (desc.contains('not available') ||
                        desc.contains('403') ||
                        desc.contains('ERR_CONNECTION') ||
                        desc.contains('ERR_NAME_NOT_RESOLVED')) {
                      _showVpnDialog();
                    }
                  },
                  shouldOverrideUrlLoading: (c, navigationAction) async {
                    final url = navigationAction.request.url;
                    if (url == null) return NavigationActionPolicy.ALLOW;
                    final urlStr = url.toString();
                    debugPrint('[AccWebView] Navigation: $urlStr');
                    if (_isCharacterCardUrl(urlStr)) {
                      debugPrint('[AccWebView] Intercepted card URL');
                      _handleDownload(urlStr);
                      return NavigationActionPolicy.CANCEL;
                    }
                    return NavigationActionPolicy.ALLOW;
                  },
                  onDownloadStartRequest: (c, request) async {
                    final urlStr = request.url.toString();
                    debugPrint(
                        '[AccWebView] Download: $urlStr '
                        '(file: ${request.suggestedFilename}, '
                        'mime: ${request.mimeType})');
                    if (_isCharacterCardUrl(urlStr)) {
                      _handleDownload(urlStr);
                    }
                  },
                ),
              ),
            ),

            // ── 顶部进度条 ──
            if (_isLoading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor:
                      const AlwaysStoppedAnimation(DesignTokens.primary),
                ),
              ),

            // ── 顶部控制栏 ──
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopControlBar(context),
              ),

            // ── 底部控制栏 ──
            if (_showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomControlBar(context),
              ),

            // ── 角色详情页导入按钮 ──
            if (_isOnCharacterPage() && !_isImporting && !_showControls)
              Positioned(
                right: DesignTokens.spaceMd,
                bottom: DesignTokens.spaceLg,
                child: FloatingActionButton.extended(
                  onPressed: _importCurrentCharacter,
                  backgroundColor: DesignTokens.primary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.download, size: 22),
                  label: const Text('导入到Kira'),
                  elevation: 4,
                ),
              ),

            // ── VPN 提示横幅 ──
            if (!_vpnBannerDismissed && !_showControls)
              Positioned(
                bottom: DesignTokens.spaceMd,
                left: DesignTokens.spaceMd,
                right: DesignTokens.spaceMd,
                child: _buildVpnBanner(),
              ),
          ],
        ),
      ),
    );
  }

  // ─── UI Builders ───

  Widget _buildTopControlBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + DesignTokens.spaceSm,
        left: DesignTokens.spaceSm,
        right: DesignTokens.spaceSm,
        bottom: DesignTokens.spaceSm,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '关闭',
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
            onPressed: () => _controller?.reload(),
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white, size: 22),
            onPressed: _showHelp,
            tooltip: '帮助',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControlBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + DesignTokens.spaceSm,
        left: DesignTokens.spaceMd,
        right: DesignTokens.spaceMd,
        top: DesignTokens.spaceSm,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios,
                size: 22, color: _canGoBack ? Colors.white : Colors.white24),
            onPressed: _canGoBack ? () => _controller?.goBack() : null,
            tooltip: '后退',
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios,
                size: 22,
                color: _canGoForward ? Colors.white : Colors.white24),
            onPressed: _canGoForward ? () => _controller?.goForward() : null,
            tooltip: '前进',
          ),
          IconButton(
            icon: const Icon(Icons.home, size: 22, color: Colors.white),
            onPressed: () {
              _controller?.loadUrl(
                urlRequest: URLRequest(
                  url: WebUri(_accHomeUrl),
                  headers: const {'Accept-Language': _acceptLanguage},
                ),
              );
            },
            tooltip: '主页',
          ),
        ],
      ),
    );
  }

  Widget _buildVpnBanner() {
    return Container(
      padding: DesignTokens.paddingCard,
      decoration: BoxDecoration(
        color: DesignTokens.statusWarning.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.white, size: 20),
          const SizedBox(width: DesignTokens.spaceSm),
          const Expanded(
            child: Text(
              '如无法访问请检查网络 • 点击屏幕显示控制',
              style:
                  TextStyle(color: Colors.white, fontSize: DesignTokens.fontSizeSm),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _vpnBannerDismissed = true),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: DesignTokens.spaceXs),
              child: Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Logic ───

  /// 判断URL是否是角色详情页
  /// AI Character Cards 角色页格式: https://aicharactercards.com/character-cards/{slug}/
  bool _isCharacterPageUrl(String url) {
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.host != 'aicharactercards.com' &&
        !uri.host.endsWith('.aicharactercards.com')) {
      return false;
    }
    final segments = uri.pathSegments;
    return segments.length >= 2 && segments[0] == 'character-cards';
  }

  bool _isOnCharacterPage() => _isCharacterPageUrl(_currentUrl);

  bool _isCharacterCardUrl(String url) {
    // AI Character Cards 官方PNG卡接口
    if (url.contains('aicharactercards.com/wp-json/pngapi')) {
      return true;
    }
    if (url.endsWith('.png') &&
        (url.contains('character') || url.contains('chara') ||
         url.contains('avatar'))) {
      return true;
    }
    return false;
  }

  Future<void> _importCurrentCharacter() async {
    if (_currentUrl.isEmpty) return;
    await _handleDownload(_currentUrl);
  }

  Future<void> _handleDownload(String url) async {
    if (_isImporting) return;
    setState(() => _isImporting = true);

    if (!mounted) return;
    _showImportingDialog();

    try {
      final urlImportService = ref.read(urlImportServiceProvider);
      final result = await urlImportService.importFromUrl(url);

      final repo = ref.read(characterRepositoryProvider);
      final created = await repo.createCharacter(result.character);

      if (result.character.characterBook != null &&
          result.character.characterBook!.entries.isNotEmpty) {
        final worldInfoRepo = ref.read(worldInfoRepositoryProvider);
        await importEmbeddedLorebook(
          worldInfoRepo,
          created.id,
          result.character.characterBook!,
          created.name,
        );
      }

      ref.read(characterListProvider.notifier).refresh();

      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        _showSuccessDialog(
          created.name,
          result.character.characterBook?.entries.length,
        );
      }
    } catch (e) {
      debugPrint('[AccWebView] Import failed: $e');
      if (mounted) Navigator.of(context).pop();
      final msg = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        String friendly;
        if (msg.contains('403') || msg.contains('not available')) {
          friendly = '无法访问 AI Character Cards。请检查网络后重试。';
        } else if (msg.contains('404') || msg.contains('not found')) {
          friendly = '未找到该角色卡，可能已被作者删除。';
        } else if (msg.contains('No character data') || msg.contains('PNG')) {
          friendly = '角色卡解析失败，文件可能不是有效的角色卡。';
        } else {
          friendly = msg;
        }
        _showErrorDialog(friendly);
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  /// 从字节直接导入（用于 blob URL）
  Future<void> _importFromBytes(Uint8List bytes) async {
    if (_isImporting) return;
    setState(() => _isImporting = true);

    if (!mounted) return;
    _showImportingDialog();

    try {
      final importService = ref.read(importServiceProvider);
      Character? character;
      try {
        character = await importService.importFromPngBytes(bytes);
      } catch (e) {
        final jsonString = utf8.decode(bytes);
        character = await importService.importFromJson(jsonString);
      }

      final repo = ref.read(characterRepositoryProvider);
      final created = await repo.createCharacter(character);

      // [紧急修复-C] 导入时正则写入独立表（与 import_screen 主路径一致）
      try {
        final rawList = character.extensions['regex_scripts'];
        if (rawList is List && rawList.isNotEmpty) {
          await ref
              .read(regexScriptRepositoryProvider)
              .importCharacterScriptsFromRaw(created.id, rawList);
        }
      } catch (e) {
        debugPrint('[Phase2] 市场导入正则写表失败(extensions 保留): $e');
      }

      if (character.characterBook != null &&
          character.characterBook!.entries.isNotEmpty) {
        final worldInfoRepo = ref.read(worldInfoRepositoryProvider);
        await importEmbeddedLorebook(
          worldInfoRepo,
          created.id,
          character.characterBook!,
          created.name,
        );
      }

      ref.read(characterListProvider.notifier).refresh();

      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        _showSuccessDialog(
          created.name,
          character.characterBook?.entries.length,
        );
      }
    } catch (e) {
      debugPrint('[AccWebView] Bytes import failed: $e');
      if (mounted) Navigator.of(context).pop();
      final msg = e.toString().replaceAll('Exception: ', '');
      if (mounted) _showErrorDialog('导入失败：$msg');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _updateNavState() async {
    final back = await _controller?.canGoBack() ?? false;
    final fwd = await _controller?.canGoForward() ?? false;
    if (mounted) {
      setState(() {
        _canGoBack = back;
        _canGoForward = fwd;
      });
    }
  }

  // ─── JS Injection ───

  Future<void> _injectLanguageScript() async {
    try {
      await _controller?.evaluateJavascript(source: '''
        (function() {
          try {
            localStorage.setItem('language', 'zh-CN');
            localStorage.setItem('locale', 'zh-CN');
            localStorage.setItem('i18nextLng', 'zh-CN');
          } catch(e) {}
          try { document.documentElement.lang = 'zh-CN'; } catch(e) {}
        })();
      ''');
    } catch (e) {
      debugPrint('[AccWebView] Language injection failed: $e');
    }
  }

  /// 注册 JS Handler，供网页端调用下载拦截
  void _registerDownloadHandler() {
    _controller?.addJavaScriptHandler(
      handlerName: 'kiraDownloadCharacter',
      callback: (args) {
        String? url;
        if (args.isNotEmpty) {
          url = args[0]?.toString();
        }
        debugPrint('[AccWebView] JS handler called with: $url');
        // URL为空时使用当前角色页面URL
        if (url == null || url.isEmpty || url == 'null') {
          url = _currentCharacterUrl;
          debugPrint('[AccWebView] Fallback to current character URL: $url');
        }
        if (url != null && url.isNotEmpty) {
          _handleDownload(url);
        } else {
          _showErrorDialog('无法获取角色链接，请确保已打开角色详情页');
        }
      },
    );

    // 处理 blob URL（base64 内容）
    _controller?.addJavaScriptHandler(
      handlerName: 'kiraDownloadCharacterBlob',
      callback: (args) async {
        if (args.isEmpty || args[0] == null) {
          if (mounted) _showErrorDialog('下载失败：数据为空');
          return;
        }

        final base64String = args[0].toString();
        debugPrint('[AccWebView] Received base64 blob, length: ${base64String.length}');

        try {
          final bytes = base64Decode(base64String);
          await _importFromBytes(bytes);
        } catch (e) {
          debugPrint('[AccWebView] Blob import failed: $e');
          if (mounted) _showErrorDialog('导入失败：${e.toString().replaceAll('Exception: ', '')}');
        }
      },
    );
  }

  /// 注入下载拦截脚本：检测下载按钮点击，传递当前页面URL
  Future<void> _injectDownloadInterceptor() async {
    try {
      await _controller?.evaluateJavascript(source: r'''
        (function() {
          if (window._kiraDownloadInterceptor) return;
          window._kiraDownloadInterceptor = true;

          // 点击事件监听：检测下载按钮
          document.addEventListener('click', function(e) {
            var el = e.target;
            // 向上查找5层，检测可点击元素是否是下载按钮
            for (var i = 0; i < 5; i++) {
              if (!el || el === document.body) break;

              var isDownloadButton = false;

              // 方法1: 检查 href 是否匹配下载链接
              var href = el.href || el.getAttribute && el.getAttribute('href') || '';
              if (href && (
                href.includes('pngapi') ||
                href.includes('chara_card') ||
                href.includes('/download')
              )) {
                isDownloadButton = true;
              }

              // 方法2: 检查 download 属性
              if (el.getAttribute && el.getAttribute('download')) {
                isDownloadButton = true;
              }

              // 方法3: 检查文本内容是否包含下载相关词汇
              if (el.textContent) {
                var text = el.textContent.toLowerCase().trim();
                if (text === 'download' || text === '下载' ||
                    text.includes('chara_card') || text.includes('.png')) {
                  // 仅当元素是按钮或链接时才匹配（避免误触整页文本）
                  var tag = el.tagName;
                  if (tag === 'A' || tag === 'BUTTON' ||
                      (el.className && typeof el.className === 'string' &&
                       (el.className.includes('btn') || el.className.includes('button')))) {
                    isDownloadButton = true;
                  }
                }
              }

              // 方法4: 检查 class/id 包含 download
              if (el.className && typeof el.className === 'string') {
                if (el.className.toLowerCase().includes('download')) {
                  isDownloadButton = true;
                }
              }
              if (el.id && typeof el.id === 'string') {
                if (el.id.toLowerCase().includes('download')) {
                  isDownloadButton = true;
                }
              }

              if (isDownloadButton) {
                console.log('[Kira] Download button detected, tag:', el.tagName);
                e.preventDefault();
                e.stopPropagation();

                var downloadUrl = el.href || el.getAttribute('href');

                if (downloadUrl && downloadUrl.startsWith('blob:')) {
                  console.log('[Kira] Detected blob URL, fetching content...');
                  fetch(downloadUrl)
                    .then(response => response.blob())
                    .then(blob => {
                      var reader = new FileReader();
                      reader.onloadend = function() {
                        var base64 = reader.result.split(',')[1];
                        console.log('[Kira] Blob read success, size:', base64.length);
                        window.flutter_inappwebview.callHandler('kiraDownloadCharacterBlob', base64);
                      };
                      reader.readAsDataURL(blob);
                    })
                    .catch(err => {
                      console.error('[Kira] Blob fetch failed:', err);
                      var currentUrl = window.location.href;
                      window.flutter_inappwebview.callHandler('kiraDownloadCharacter', currentUrl);
                    });
                  return false;
                }

                // 传递当前页面URL（而非href），由Flutter端构造CDN链接
                var currentUrl = window.location.href;
                console.log('[Kira] Passing page URL:', currentUrl);
                try {
                  window.flutter_inappwebview.callHandler('kiraDownloadCharacter', currentUrl);
                } catch(err) {
                  console.error('[Kira] Handler call failed:', err);
                }
                return false;
              }

              el = el.parentElement;
            }
          }, true);

          // [暴力兜底] 拦截所有 blob URL 点击（不判断是否为下载按钮）
          document.addEventListener('click', function(e) {
            var el = e.target;
            for (var i = 0; i < 5; i++) {
              if (!el) break;
              var href = el.href || (el.getAttribute && el.getAttribute('href')) || '';
              if (href.startsWith('blob:')) {
                console.log('[Kira Fallback] Blob URL clicked:', href);
                e.preventDefault();
                e.stopPropagation();
                
                fetch(href)
                  .then(response => response.blob())
                  .then(blob => {
                    var reader = new FileReader();
                    reader.onloadend = function() {
                      var base64 = reader.result.split(',')[1];
                      console.log('[Kira Fallback] Blob read OK, size:', base64.length);
                      window.flutter_inappwebview.callHandler('kiraDownloadCharacterBlob', base64);
                    };
                    reader.readAsDataURL(blob);
                  })
                  .catch(err => {
                    console.error('[Kira Fallback] Blob fetch error:', err);
                  });
                
                return false;
              }
              el = el.parentElement;
            }
          }, true);

          // 拦截编程式 <a>.click() 触发的下载
          var origClick = HTMLAnchorElement.prototype.click;
          HTMLAnchorElement.prototype.click = function() {
            var href = this.href || '';
            var dl = this.getAttribute('download') || '';
            if (href.includes('pngapi') || href.includes('chara_card') ||
                dl.includes('chara_card') || dl.includes('.png') ||
                dl.includes('download')) {
              console.log('[Kira] Programmatic download click intercepted');
              var currentUrl = window.location.href;
              if (window.flutter_inappwebview) {
                window.flutter_inappwebview.callHandler('kiraDownloadCharacter', currentUrl);
                return;
              }
            }
            return origClick.call(this);
          };

          console.log('[Kira] Download interceptor installed');
        })();
      ''');
      debugPrint('[AccWebView] Download interceptor injected');
    } catch (e) {
      debugPrint('[AccWebView] Failed to inject interceptor: $e');
    }
  }

  // ─── Dialogs ───

  void _showImportingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusDialog),
          ),
          content: const Row(
            children: [
              SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: DesignTokens.spaceMd),
              Text('正在导入角色卡…'),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(String name, int? lorebookEntries) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusDialog),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: DesignTokens.statusSuccess),
            SizedBox(width: DesignTokens.spaceSm),
            Text('导入成功'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('角色 "$name" 已成功导入'),
            if (lorebookEntries != null && lorebookEntries > 0) ...[
              const SizedBox(height: DesignTokens.spaceXs),
              Text(
                '✓ 包含世界书（$lorebookEntries 条目）',
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeSm,
                  color: DesignTokens.darkTextSecondary,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('继续浏览',
                style: TextStyle(color: DesignTokens.primary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              widget.onCharacterImported?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('查看角色'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusDialog),
        ),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: DesignTokens.statusError),
            SizedBox(width: DesignTokens.spaceSm),
            Text('导入失败'),
          ],
        ),
        content: Text(message,
            style: const TextStyle(fontSize: DesignTokens.fontSizeSm)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('确定',
                style: TextStyle(color: DesignTokens.primary)),
          ),
        ],
      ),
    );
  }

  void _showVpnDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusDialog),
        ),
        title: const Row(
          children: [
            Icon(Icons.cloud_off, color: DesignTokens.statusWarning),
            SizedBox(width: DesignTokens.spaceSm),
            Text('无法访问'),
          ],
        ),
        content: const Text(
          'AI Character Cards 在当前网络环境下无法访问。\n\n'
          '请检查网络（或启用 VPN）后点击「刷新」重新加载。',
          style: TextStyle(fontSize: DesignTokens.fontSizeSm),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('返回',
                style: TextStyle(color: DesignTokens.darkTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _controller?.reload();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('刷新'),
          ),
        ],
      ),
    );
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusDialog),
        ),
        title: const Text('使用说明'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('浏览角色：'),
              SizedBox(height: DesignTokens.spaceXs),
              Text('在页面中搜索、浏览角色，进入角色详情页。',
                  style: TextStyle(fontSize: DesignTokens.fontSizeSm)),
              SizedBox(height: DesignTokens.spaceMd),
              Text('导入角色：'),
              SizedBox(height: DesignTokens.spaceXs),
              Text(
                '方式一：在角色详情页点击「导入到Kira」按钮\n'
                '方式二：点击网站下载按钮，自动拦截导入',
                style: TextStyle(fontSize: DesignTokens.fontSizeSm),
              ),
              SizedBox(height: DesignTokens.spaceMd),
              Text('返回：'),
              SizedBox(height: DesignTokens.spaceXs),
              Text(
                '系统返回键：先返回上一页，到第一页再退出\n'
                '点击屏幕：显示/隐藏控制按钮',
                style: TextStyle(fontSize: DesignTokens.fontSizeSm),
              ),
              SizedBox(height: DesignTokens.spaceMd),
              Text('注意事项：'),
              SizedBox(height: DesignTokens.spaceXs),
              Text(
                '• 国际SFW角色卡社区，无需担心内容合规\n'
                '• 在浏览器内直接浏览、搜索角色\n'
                '• 点击下载自动导入到 Kira\n'
                '• 支持包含世界书自动导入\n'
                '• 如无法访问请检查网络（部分地区或需VPN）',
                style: TextStyle(fontSize: DesignTokens.fontSizeSm),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了',
                style: TextStyle(color: DesignTokens.primary)),
          ),
        ],
      ),
    );
  }
}
