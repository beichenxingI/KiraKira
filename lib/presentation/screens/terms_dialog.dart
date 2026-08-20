import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const String _kTermsAgreedKey = 'agreed_terms_v1';
bool _termsDialogShowing = false;

/// 首次启动强制显示免责声明。已同意过则不显示。
Future<void> maybeShowTermsDialog(
    BuildContext context, SharedPreferences prefs) async {
  if (prefs.getBool(_kTermsAgreedKey) == true) return;
  if (_termsDialogShowing) return;
  _termsDialogShowing = true;

  try {
    await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: _TermsDialogContent(prefs: prefs),
    ),
    );
  } finally {
    _termsDialogShowing = false; // 无论如何都复位，杜绝卡死
  }
}

enum _Lang { zhHans, zhHant, en }

class _TermsDialogContent extends StatefulWidget {
  final SharedPreferences prefs;
  const _TermsDialogContent({required this.prefs});

  @override
  State<_TermsDialogContent> createState() => _TermsDialogContentState();
}

class _TermsDialogContentState extends State<_TermsDialogContent> {
  _Lang _lang = _Lang.zhHans;
  bool _agreed = false;

  static const _accent = Color(0xFFC0654A);
  static const _cardBg = Color(0xFF2A2320);

  @override
  Widget build(BuildContext context) {
    final t = _texts[_lang]!;
    return Dialog(
      backgroundColor: const Color(0xFF1C1917),
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('KiraKira',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: DesignTokens.fontSizeSm,
                      letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Text(t.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(t.subtitle,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14)),
              const SizedBox(height: 20),
              // 语言切换
              Row(
                children: [
                  Text('${t.language} ',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14)),
                  const Spacer(),
                  _langSeg(),
                ],
              ),
              const SizedBox(height: 20),
              // 三张卡片
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (var i = 0; i < t.cards.length; i++) ...[
                        _card(i + 1, t.cards[i].$1, t.cards[i].$2),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 4),
                      Text(t.warning,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: DesignTokens.fontSizeSm,
                              height: 1.6)),
                      const SizedBox(height: 12),
                      _licenseLine(t),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 复选框
              InkWell(
                onTap: () => setState(() => _agreed = !_agreed),
                child: Row(
                  children: [
                    Icon(
                      _agreed
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: _agreed ? _accent : Colors.white54,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(t.checkbox,
                          style: const TextStyle(
                              color: Colors.white, fontSize: DesignTokens.fontSizeBodyLarge)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 同意按钮
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    disabledBackgroundColor: _accent.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _agreed
                      ? () async {
                          await widget.prefs
                              .setBool(_kTermsAgreedKey, true);
                          if (context.mounted) Navigator.of(context).pop();
                        }
                      : null,
                  child: Text(t.agree,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => SystemNavigator.pop(),
                  child: Text(t.disagree,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: DesignTokens.fontSizeSm)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langSeg() {
    Widget seg(String label, _Lang l) {
      final on = _lang == l;
      return GestureDetector(
        onTap: () => setState(() => _lang = l),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: on ? _accent : Colors.transparent,
            borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          ),
          child: Text(label,
              style: TextStyle(
                  color: on ? Colors.white : Colors.white60,
                  fontSize: 14,
                  fontWeight: on ? FontWeight.w600 : FontWeight.normal)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('简', _Lang.zhHans),
        seg('繁', _Lang.zhHant),
        seg('EN', _Lang.en),
      ]),
    );
  }

  Widget _card(int n, String title, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: _accent.withValues(alpha: 0.2),
            child: Text('$n',
                style: const TextStyle(
                    color: _accent, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(body,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: DesignTokens.fontSizeSm,
                        height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _licenseLine(_TermsText t) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: DesignTokens.fontSizeSm,
                  height: 1.6),
              children: [
                TextSpan(text: t.licensePrefix),
                TextSpan(
                  text: t.licenseLink,
                  style: const TextStyle(
                      color: _accent,
                      decoration: TextDecoration.underline),
                  recognizer: null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TermsText {
  final String title,
      subtitle,
      language,
      warning,
      checkbox,
      agree,
      disagree,
      licensePrefix,
      licenseLink;
  final List<(String, String)> cards;
  const _TermsText({
    required this.title,
    required this.subtitle,
    required this.language,
    required this.cards,
    required this.warning,
    required this.checkbox,
    required this.agree,
    required this.disagree,
    required this.licensePrefix,
    required this.licenseLink,
  });
}

const _licenseUrl =
    'https://github.com/beichenxingI/KiraKira';

final Map<_Lang, _TermsText> _texts = {
  _Lang.zhHans: const _TermsText(
    title: '免责声明',
    subtitle: '使用本软件前，请阅读并确认以下内容',
    language: '语言 / Language',
    cards: [
      ('平台立场',
          '本软件仅提供人工智能内容生成与交互工具，不主动提供、推荐或传播 NSFW、色情、暴力、违法及其他不适宜内容。'),
      ('用户责任',
          '用户通过自行输入、导入或配置所生成的内容，均由用户独立发起并承担相应责任。请确保使用行为及生成内容符合所在地法律法规、平台规则与社会公序良俗。'),
      ('内容风险',
          '人工智能生成内容可能存在虚构、错误、偏见或令人不适的信息，不代表本软件立场，也不构成任何专业建议。请自行判断、核实并谨慎使用。'),
    ],
    warning:
        '严禁利用本软件生成、发布或传播违法违规、侵害他人权益或涉及未成年人的不当内容。如发现相关内容，请立即停止使用并向开发者反馈。本软件不设服务器，不收集上传任何数据，所有内容仅存于本地设备。',
    checkbox: '我已阅读并理解上述免责声明',
    agree: '我已知悉并同意',
    disagree: '不同意并退出',
    licensePrefix: '本软件基于 AGPL-3.0 开源协议发布，完整协议与源码请见：',
    licenseLink: _licenseUrl,
  ),
  _Lang.zhHant: const _TermsText(
    title: '免責聲明',
    subtitle: '使用本軟體前，請閱讀並確認以下內容',
    language: '語言 / Language',
    cards: [
      ('平台立場',
          '本軟體僅提供人工智慧內容生成與互動工具，不主動提供、推薦或傳播 NSFW、色情、暴力、違法及其他不適宜內容。'),
      ('使用者責任',
          '使用者透過自行輸入、匯入或設定所生成的內容，均由使用者獨立發起並承擔相應責任。請確保使用行為及生成內容符合所在地法律法規、平台規則與社會公序良俗。'),
      ('內容風險',
          '人工智慧生成內容可能存在虛構、錯誤、偏見或令人不適的資訊，不代表本軟體立場，也不構成任何專業建議。請自行判斷、核實並謹慎使用。'),
    ],
    warning:
        '嚴禁利用本軟體生成、發布或傳播違法違規、侵害他人權益或涉及未成年人的不當內容。如發現相關內容，請立即停止使用並向開發者回饋。本軟體不設伺服器，不收集上傳任何資料，所有內容僅存於本機裝置。',
    checkbox: '我已閱讀並理解上述免責聲明',
    agree: '我已知悉並同意',
    disagree: '不同意並退出',
    licensePrefix: '本軟體基於 AGPL-3.0 開源協議發布，完整協議與原始碼請見：',
    licenseLink: _licenseUrl,
  ),
  _Lang.en: const _TermsText(
    title: 'Disclaimer',
    subtitle: 'Please read and confirm before using this app',
    language: 'Language',
    cards: [
      ('Platform Position',
          'This app only provides AI content generation and interaction tools. It does not actively provide, recommend, or distribute NSFW, pornographic, violent, illegal, or otherwise inappropriate content.'),
      ('User Responsibility',
          'Content generated through your own input, imports, or configurations is initiated by you and is your sole responsibility. Please ensure your usage and generated content comply with local laws, platform rules, and social norms.'),
      ('Content Risk',
          'AI-generated content may contain fictional, erroneous, biased, or disturbing information. It does not represent the position of this app, nor does it constitute professional advice. Use your own judgment and verify carefully.'),
    ],
    warning:
        'It is strictly forbidden to use this app to generate, publish, or distribute illegal content, content that infringes on others\' rights, or content involving minors. If found, stop using immediately and report to the developer. This app has no server and collects/uploads no data; all content stays on your local device.',
    checkbox: 'I have read and understood the disclaimer above',
    agree: 'I acknowledge and agree',
    disagree: 'Disagree and exit',
    licensePrefix:
        'This app is released under the AGPL-3.0 open-source license. Full license and source:',
    licenseLink: _licenseUrl,
  ),
};