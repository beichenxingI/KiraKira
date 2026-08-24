// lib/presentation/screens/main_page/daily_oracle_sheet.dart
/// 每日祈愿/今日运势(返工条目9):纯本地,种子随机,同日恒定。
/// 入口按钮在 main_page 公告按钮正上方。
library;

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'daily_oracle_data.dart';

String _todayKey() => DateFormat('yyyyMMdd').format(DateTime.now());

/// 当日运势(种子随机,同一天完全一致)
class DailyOracle {
  final String keyword;
  final String level;
  final String message;
  final List<int> dots; // 五维各亮几个(2-5)
  final String luckyHours;
  final int luckyNumber;
  final String luckyDirection;
  final String luckyColorName;
  final Color luckyColor;
  final Map<String, String> luckyItem;
  final List<String> dos;
  final List<String> donts;
  final OracleHoliday? holiday;

  const DailyOracle({
    required this.keyword,
    required this.level,
    required this.message,
    required this.dots,
    required this.luckyHours,
    required this.luckyNumber,
    required this.luckyDirection,
    required this.luckyColorName,
    required this.luckyColor,
    required this.luckyItem,
    required this.dos,
    required this.donts,
    this.holiday,
  });

  /// 生成当日运势:优先读持久化(防文案池变动),否则种子随机后落盘
  static Future<DailyOracle> loadToday() async {
    final dateKey = _todayKey();
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('daily_oracle_$dateKey');
    if (saved != null) {
      try {
        return _fromJson(jsonDecode(saved) as Map<String, dynamic>, dateKey);
      } catch (_) {/* 落回重新抽取 */}
    }
    final o = _generate(dateKey);
    await prefs.setString('daily_oracle_$dateKey', jsonEncode(o._toJson()));
    await _cleanupOld(prefs);
    return o;
  }

  static DailyOracle _generate(String dateKey) {
    final seed = int.parse(dateKey);
    final rng = math.Random(seed);
    final now = DateTime.parse(
        '${dateKey.substring(0, 4)}-${dateKey.substring(4, 6)}-${dateKey.substring(6)}');
    // 节假日彩蛋命中
    final lunar =
        kLunarHolidayOverrides[now.year * 10000 + now.month * 100 + now.day];
    final solar = kSolarHolidays[now.month * 100 + now.day];
    final holiday = lunar ?? solar;

    final colorIdx = rng.nextInt(kLuckyColors.length);
    return DailyOracle(
      keyword: kOracleKeywords[rng.nextInt(kOracleKeywords.length)],
      level: kOracleLevels[rng.nextInt(kOracleLevels.length)],
      message: holiday != null && holiday.messages.isNotEmpty
          ? holiday.messages[rng.nextInt(holiday.messages.length)]
          : kOracleMessages[rng.nextInt(kOracleMessages.length)],
      dots: List.generate(5, (_) => 2 + rng.nextInt(4)),
      luckyHours: kLuckyHours[rng.nextInt(kLuckyHours.length)],
      luckyNumber: 1 + rng.nextInt(99),
      luckyDirection:
          kLuckyDirections[rng.nextInt(kLuckyDirections.length)],
      luckyColorName: kLuckyColors[colorIdx]['name'] as String,
      luckyColor: kLuckyColors[colorIdx]['color'] as Color,
      luckyItem: kLuckyItems[rng.nextInt(kLuckyItems.length)],
      dos: _pick(rng, kDos, 4),
      donts: _pick(rng, kDonts, 3),
      holiday: holiday,
    );
  }

  static List<String> _pick(math.Random rng, List<String> pool, int n) {
    final copy = [...pool]..shuffle(rng);
    return copy.take(n).toList();
  }

  Map<String, dynamic> _toJson() => {
        'keyword': keyword,
        'level': level,
        'message': message,
        'dots': dots,
        'hours': luckyHours,
        'num': luckyNumber,
        'dir': luckyDirection,
        'color': luckyColorName,
        'item': luckyItem,
        'dos': dos,
        'donts': donts,
        'hol': holiday?.name,
      };

  static DailyOracle _fromJson(Map<String, dynamic> j, String dateKey) {
    final hol = j['hol'] as String?;
    OracleHoliday? h;
    for (final v in kSolarHolidays.values) {
      if (v.name == hol) h = v;
    }
    for (final v in kLunarHolidayOverrides.values) {
      if (v.name == hol) h = v;
    }
    final colorName = j['color'] as String? ?? '';
    var color = const Color(0xFFB39DDB);
    for (final c in kLuckyColors) {
      if (c['name'] == colorName) color = c['color'] as Color;
    }
    return DailyOracle(
      keyword: j['keyword'] as String,
      level: j['level'] as String,
      message: j['message'] as String,
      dots: (j['dots'] as List).cast<int>(),
      luckyHours: j['hours'] as String,
      luckyNumber: j['num'] as int,
      luckyDirection: j['dir'] as String,
      luckyColorName: colorName,
      luckyColor: color,
      luckyItem: (j['item'] as Map).cast<String, String>(),
      dos: (j['dos'] as List).cast<String>(),
      donts: (j['donts'] as List).cast<String>(),
      holiday: h,
    );
  }

  /// 只留最近 3 天的 oracle/wish/star 键
  static Future<void> _cleanupOld(SharedPreferences prefs) async {
    final today = DateTime.now();
    final keep = <String>{};
    for (var i = 0; i < 3; i++) {
      keep.add(DateFormat('yyyyMMdd')
          .format(today.subtract(Duration(days: i))));
    }
    for (final key in prefs.getKeys()) {
      final m = RegExp(r'^(daily_oracle|oracle_wish|oracle_star)_(\d{8})$')
          .firstMatch(key);
      if (m != null && !keep.contains(m.group(2))) {
        await prefs.remove(key);
      }
    }
  }
}

/// 入口圆钮(main_page 公告按钮正上方)
class DailyOracleEntry extends StatelessWidget {
  const DailyOracleEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDailyOracleSheet(context),
      child: Container(
        padding: DesignTokens.paddingCard,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: const Icon(
          CupertinoIcons.sparkles,
          color: Color(0xFFE1BEE7),
          size: 22,
        ),
      ),
    );
  }
}

/// 运势面板(modal 底部抽屉,竖版卡片)
Future<void> showDailyOracleSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _OracleSheet(),
  );
}

class _OracleSheet extends StatefulWidget {
  const _OracleSheet();

  @override
  State<_OracleSheet> createState() => _OracleSheetState();
}

class _OracleSheetState extends State<_OracleSheet> {
  DailyOracle? _oracle;
  bool _wishDone = false;
  bool _starDrawn = false;
  String? _drawnSign;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final oracle = await DailyOracle.loadToday();
    final prefs = await SharedPreferences.getInstance();
    final d = _todayKey();
    if (!mounted) return;
    setState(() {
      _oracle = oracle;
      _wishDone = prefs.getBool('oracle_wish_$d') ?? false;
      _starDrawn = prefs.getBool('oracle_star_$d') ?? false;
      if (_starDrawn) {
        _drawnSign = prefs.getString('oracle_star_text_$d');
      }
    });
  }

  Future<void> _toggleWish() async {
    final prefs = await SharedPreferences.getInstance();
    final d = _todayKey();
    if (_wishDone) {
      await prefs.setBool('oracle_wish_$d', false);
      setState(() => _wishDone = false);
      return;
    }
    await prefs.setBool('oracle_wish_$d', true);
    setState(() => _wishDone = true);
  }

  Future<void> _drawStar() async {
    if (_starDrawn) return;
    // 签文由当日种子决定(同日一致;三张牌只是仪式感)
    final seed = int.parse(_todayKey());
    final sign = kStarSigns[math.Random(seed).nextInt(kStarSigns.length)];
    final prefs = await SharedPreferences.getInstance();
    final d = _todayKey();
    await prefs.setBool('oracle_star_$d', true);
    await prefs.setString('oracle_star_text_$d', sign);
    setState(() {
      _starDrawn = true;
      _drawnSign = sign;
    });
  }

  @override
  Widget build(BuildContext context) {
    final o = _oracle;
    if (o == null) {
      return const SizedBox(
        height: 320,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? DesignTokens.darkSurface : DesignTokens.lightSurface;
    final cardBg = isDark ? DesignTokens.darkCard : Colors.white;
    final accent = o.holiday?.accent ?? DesignTokens.primary;
    final tertiary = theme.textTheme.bodySmall?.color;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusBottomSheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              DesignTokens.spaceLg, DesignTokens.spaceLg, DesignTokens.spaceLg, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── 1 标题区 ──
              Row(
                children: [
                  Icon(o.holiday?.emoji != null
                      ? CupertinoIcons.sparkles
                      : CupertinoIcons.moon_stars_fill,
                      size: 18, color: accent),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'KIRAKIRA DAILY WISH',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeXs,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('yyyy/MM/dd').format(DateTime.now()),
                style: TextStyle(fontSize: DesignTokens.fontSizeSm, color: tertiary),
              ),

              // ── 2 关键词 + 等级 ──
              const SizedBox(height: DesignTokens.spaceLg),
              Text(
                '今日关键词 · ${o.keyword}',
                style: TextStyle(fontSize: DesignTokens.fontSizeSm, color: tertiary),
              ),
              const SizedBox(height: 8),
              Text(
                '${o.holiday?.emoji ?? "🌙"} ${o.level}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: DesignTokens.weightBold,
                  color: accent,
                ),
              ),

              // ── 3 寄语 ──
              const SizedBox(height: DesignTokens.spaceMd),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(DesignTokens.spaceMd),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
                child: Text(
                  o.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeBodyLarge,
                    height: 1.5,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),

              // ── 4 五维运势条 ──
              const SizedBox(height: DesignTokens.spaceMd),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 5; i++)
                    Expanded(
                      child: Column(
                        children: [
                          Text(kOracleDims[i],
                              style: TextStyle(
                                  fontSize: DesignTokens.fontSizeXs,
                                  color: tertiary)),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var d = 0; d < 5; d++)
                                Container(
                                  width: 7,
                                  height: 7,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 1.5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: d < o.dots[i]
                                        ? accent
                                        : accent.withValues(alpha: 0.15),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // ── 5 幸运信息区 ──
              const SizedBox(height: DesignTokens.spaceMd),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(DesignTokens.spaceMd),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _luckyCell('幸运时段', o.luckyHours, tertiary),
                        ),
                        Expanded(
                          child: _luckyCell('幸运数字', '${o.luckyNumber}', tertiary),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignTokens.spaceSm),
                    Row(
                      children: [
                        Expanded(
                          child: _luckyCell('幸运方位', o.luckyDirection, tertiary),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(right: 5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: o.luckyColor,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  o.luckyColorName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: DesignTokens.fontSizeSm,
                                      color:
                                          theme.textTheme.bodyMedium?.color),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignTokens.spaceSm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '幸运物:${o.luckyItem['emoji']} ${o.luckyItem['name']}',
                        style: TextStyle(
                            fontSize: DesignTokens.fontSizeSm,
                            color: theme.textTheme.bodyMedium?.color),
                      ),
                    ),
                  ],
                ),
              ),

              // ── 6 宜 / 忌 ──
              const SizedBox(height: DesignTokens.spaceMd),
              _yiJiRow(true, o.dos.join(' · '), cardBg),
              const SizedBox(height: 6),
              _yiJiRow(false, o.donts.join(' · '), cardBg),

              // ── 7 双按钮 ──
              const SizedBox(height: DesignTokens.spaceLg),
              Row(
                children: [
                  Expanded(
                    child: _actionCard(
                      title: _starDrawn ? '已抽星签' : '查看今日星签',
                      subtitle: _starDrawn
                          ? (_drawnSign ?? '今日份好运已领取')
                          : '三选一 · 每日一次',
                      icon: CupertinoIcons.ticket_fill,
                      enabled: !_starDrawn,
                      onTap: () => _showStarPick(o),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceSm),
                  Expanded(
                    child: _actionCard(
                      title: _wishDone ? '心愿已完成' : '许个愿',
                      subtitle: _wishDone ? '明天再来哦' : '轻任务 · 好心情',
                      icon: _wishDone
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.heart_circle_fill,
                      enabled: true,
                      onTap: _toggleWish,
                      highlight: _wishDone,
                    ),
                  ),
                ],
              ),

              // ── 8 尾注 ──
              const SizedBox(height: DesignTokens.spaceLg),
              Text(
                '每日 0 点自动更新 · 记得来看看哦',
                style: TextStyle(
                    fontSize: DesignTokens.fontSizeXs, color: tertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _luckyCell(String label, String value, Color? tertiary) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: DesignTokens.fontSizeXs, color: tertiary)),
          const SizedBox(height: 2),
          Text(value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: DesignTokens.fontSizeSm,
                  fontWeight: FontWeight.w600)),
        ],
      );

  Widget _yiJiRow(bool isYi, String text, Color cardBg) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMd, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(DesignTokens.radiusGroupedCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isYi ? DesignTokens.statusSuccess : DesignTokens.statusWarning)
                  .withValues(alpha: 0.14),
            ),
            alignment: Alignment.center,
            child: Text(
              isYi ? '宜' : '忌',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeSm,
                fontWeight: FontWeight.w600,
                color: isYi
                    ? DesignTokens.statusSuccess
                    : DesignTokens.statusWarning,
              ),
            ),
          ),
          const SizedBox(width: DesignTokens.spaceSm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text,
                  style: TextStyle(
                      fontSize: DesignTokens.fontSizeSm,
                      height: 1.4,
                      color: theme.textTheme.bodyMedium?.color)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    final theme = Theme.of(context);
    final accent = _oracle?.holiday?.accent ?? DesignTokens.primary;
    return Material(
      color: highlight
          ? accent.withValues(alpha: 0.12)
          : theme.cardColor,
      borderRadius: BorderRadius.circular(DesignTokens.radiusGroupedCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusGroupedCard),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceMd, vertical: 12),
          child: Column(
            children: [
              Icon(icon,
                  size: 22,
                  color: enabled || highlight
                      ? accent
                      : theme.textTheme.bodySmall?.color),
              const SizedBox(height: 6),
              Text(title,
                  style: TextStyle(
                      fontSize: DesignTokens.fontSizeSm,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      height: 1.3,
                      fontSize: DesignTokens.fontSizeXs,
                      color: theme.textTheme.bodySmall?.color)),
            ],
          ),
        ),
      ),
    );
  }

  /// 星签三选一覆盖层
  void _showStarPick(DailyOracle o) {
    if (_starDrawn) {
      setState(() {}); // 已抽过:面板上显示结果即可
      return;
    }
    showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Container(
        color: Theme.of(ctx).scaffoldBackgroundColor,
        padding: const EdgeInsets.all(DesignTokens.spaceLg),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('深呼吸,凭直觉选一张',
                  style: TextStyle(
                      fontSize: DesignTokens.fontSizeHeadline,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: DesignTokens.spaceLg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _drawStar();
                      },
                      child: Container(
                        width: 88,
                        height: 128,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              (o.holiday?.accent ?? DesignTokens.primary)
                                  .withValues(alpha: 0.25),
                              DesignTokens.accent.withValues(alpha: 0.12),
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(DesignTokens.radiusCard),
                          border: Border.all(
                            color: (o.holiday?.accent ?? DesignTokens.primary)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text('✨', style: TextStyle(fontSize: 30)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: DesignTokens.spaceLg),
              CupertinoButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('再想想'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
