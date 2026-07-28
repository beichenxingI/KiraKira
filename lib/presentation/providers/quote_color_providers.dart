import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_providers.dart';

/// 引号/括号染色配置
/// 台面主色两个：双引号("")= 主色A，圆括号（()）= 主色B。
/// 其余符号默认跟随主色A，用户可单独覆盖。

// ── 默认颜色 ──
const int _defaultPrimaryA = 0xFFFFA726; // 双引号：暖橙
const int _defaultPrimaryB = 0xFF29B6F6; // 圆括号：碧蓝

// ── 符号类型 ──
enum QuoteSymbol {
  doubleQuote, // "" ""  双引号（主色A）
  parenthesis, // （） () 圆括号（主色B）
  cornerBracket, // 「」 直角引号
  doubleCorner, // 『』 双直角引号
  blackLenticular, // 【】 方头括号
  bookTitle, // 《》 书名号
  squareBracket, // [] 英文方括号（默认关）
}

/// 单个符号的配置
class QuoteSymbolConfig {
  final bool enabled;
  final int? customColorValue; // null = 跟随主色A

  const QuoteSymbolConfig({this.enabled = true, this.customColorValue});

  QuoteSymbolConfig copyWith({bool? enabled, int? customColorValue, bool clearCustom = false}) {
    return QuoteSymbolConfig(
      enabled: enabled ?? this.enabled,
      customColorValue: clearCustom ? null : (customColorValue ?? this.customColorValue),
    );
  }
}

/// 整体染色状态
class QuoteColorState {
  final int primaryAValue; // 双引号主色
  final int primaryBValue; // 圆括号主色
  final Map<QuoteSymbol, QuoteSymbolConfig> configs;

  const QuoteColorState({
    required this.primaryAValue,
    required this.primaryBValue,
    required this.configs,
  });

  Color get primaryA => Color(primaryAValue);
  Color get primaryB => Color(primaryBValue);

  /// 取某符号的实际渲染颜色
  Color colorFor(QuoteSymbol s) {
    if (s == QuoteSymbol.doubleQuote) return Color(primaryAValue);
    if (s == QuoteSymbol.parenthesis) return Color(primaryBValue);
    final cfg = configs[s];
    if (cfg?.customColorValue != null) return Color(cfg!.customColorValue!);
    return Color(primaryAValue); // 默认跟随主色A
  }

  bool enabledFor(QuoteSymbol s) => configs[s]?.enabled ?? true;

  QuoteColorState copyWith({
    int? primaryAValue,
    int? primaryBValue,
    Map<QuoteSymbol, QuoteSymbolConfig>? configs,
  }) {
    return QuoteColorState(
      primaryAValue: primaryAValue ?? this.primaryAValue,
      primaryBValue: primaryBValue ?? this.primaryBValue,
      configs: configs ?? this.configs,
    );
  }
}

final quoteColorStateProvider =
    StateNotifierProvider<QuoteColorNotifier, QuoteColorState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return QuoteColorNotifier(prefs);
});

/// 兼容旧代码（WebView 用）：返回主色A
final quoteColorProvider = Provider<Color>((ref) {
  return ref.watch(quoteColorStateProvider).primaryA;
});

class QuoteColorNotifier extends StateNotifier<QuoteColorState> {
  final SharedPreferences _prefs;

  QuoteColorNotifier(this._prefs) : super(_load(_prefs));

  static const _kPrimaryA = 'quote_primary_a';
  static const _kPrimaryB = 'quote_primary_b';
  static String _kEnabled(QuoteSymbol s) => 'quote_${s.name}_enabled';
  static String _kColor(QuoteSymbol s) => 'quote_${s.name}_color';

  static QuoteColorState _load(SharedPreferences p) {
    final configs = <QuoteSymbol, QuoteSymbolConfig>{};
    for (final s in QuoteSymbol.values) {
      if (s == QuoteSymbol.doubleQuote || s == QuoteSymbol.parenthesis) continue;
      final defaultEnabled = s != QuoteSymbol.squareBracket; // []默认关
      configs[s] = QuoteSymbolConfig(
        enabled: p.getBool(_kEnabled(s)) ?? defaultEnabled,
        customColorValue: p.getInt(_kColor(s)),
      );
    }
    return QuoteColorState(
      primaryAValue: p.getInt(_kPrimaryA) ?? _defaultPrimaryA,
      primaryBValue: p.getInt(_kPrimaryB) ?? _defaultPrimaryB,
      configs: configs,
    );
  }

  Future<void> setPrimaryA(Color c) async {
    state = state.copyWith(primaryAValue: c.value);
    await _prefs.setInt(_kPrimaryA, c.value);
  }

  Future<void> setPrimaryB(Color c) async {
    state = state.copyWith(primaryBValue: c.value);
    await _prefs.setInt(_kPrimaryB, c.value);
  }

  Future<void> setEnabled(QuoteSymbol s, bool enabled) async {
    final newConfigs = Map<QuoteSymbol, QuoteSymbolConfig>.from(state.configs);
    newConfigs[s] = (newConfigs[s] ?? const QuoteSymbolConfig()).copyWith(enabled: enabled);
    state = state.copyWith(configs: newConfigs);
    await _prefs.setBool(_kEnabled(s), enabled);
  }

  Future<void> setCustomColor(QuoteSymbol s, Color? c) async {
    final newConfigs = Map<QuoteSymbol, QuoteSymbolConfig>.from(state.configs);
    if (c == null) {
      newConfigs[s] = (newConfigs[s] ?? const QuoteSymbolConfig()).copyWith(clearCustom: true);
      await _prefs.remove(_kColor(s));
    } else {
      newConfigs[s] = (newConfigs[s] ?? const QuoteSymbolConfig()).copyWith(customColorValue: c.value);
      await _prefs.setInt(_kColor(s), c.value);
    }
    state = state.copyWith(configs: newConfigs);
  }

  Future<void> resetAll() async {
    for (final s in QuoteSymbol.values) {
      await _prefs.remove(_kEnabled(s));
      await _prefs.remove(_kColor(s));
    }
    await _prefs.remove(_kPrimaryA);
    await _prefs.remove(_kPrimaryB);
    state = _load(_prefs);
  }
}