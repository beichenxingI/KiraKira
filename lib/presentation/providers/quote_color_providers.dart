import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_providers.dart';

/// Quote and bracket tint configuration.
/// Two primary colors: double quotes (") use primary A, parentheses () use primary B.
/// All other symbols follow primary A by default and can be overridden individually.

// Default colors
const int _defaultPrimaryA = 0xFFFFA726; // Double quotes: warm orange
const int _defaultPrimaryB = 0xFF29B6F6; // Parentheses: azure blue

// Symbol types
enum QuoteSymbol {
  doubleQuote, // "" double quotes (primary A)
  parenthesis, // () parentheses (primary B)
  cornerBracket, // 「」 corner brackets
  doubleCorner, // 『』 double corner brackets
  blackLenticular, // 【】 black lenticular brackets
  bookTitle, // 《》 book title marks
  squareBracket, // [] square brackets (disabled by default)
}

/// Configuration for a single symbol
class QuoteSymbolConfig {
  final bool enabled;
  final int? customColorValue; // null = follow primary A

  const QuoteSymbolConfig({this.enabled = true, this.customColorValue});

  QuoteSymbolConfig copyWith({bool? enabled, int? customColorValue, bool clearCustom = false}) {
    return QuoteSymbolConfig(
      enabled: enabled ?? this.enabled,
      customColorValue: clearCustom ? null : (customColorValue ?? this.customColorValue),
    );
  }
}

/// Overall tint state
class QuoteColorState {
  final int primaryAValue; // Primary color for double quotes
  final int primaryBValue; // Primary color for parentheses
  final Map<QuoteSymbol, QuoteSymbolConfig> configs;

  const QuoteColorState({
    required this.primaryAValue,
    required this.primaryBValue,
    required this.configs,
  });

  Color get primaryA => Color(primaryAValue);
  Color get primaryB => Color(primaryBValue);

  /// Resolved render color for a symbol
  Color colorFor(QuoteSymbol s) {
    if (s == QuoteSymbol.doubleQuote) return Color(primaryAValue);
    if (s == QuoteSymbol.parenthesis) return Color(primaryBValue);
    final cfg = configs[s];
    if (cfg?.customColorValue != null) return Color(cfg!.customColorValue!);
    return Color(primaryAValue); // Falls back to primary A
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

/// Backward-compatibility shim for legacy code (WebView): returns primary A
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
      final defaultEnabled = s != QuoteSymbol.squareBracket; // [] disabled by default
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