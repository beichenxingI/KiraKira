import 'llm_provider.dart';

class LlmProviderRegistry {
  static final Map<String, LlmProvider> _providers = {};

  static void register(LlmProvider provider) {
    _providers[provider.id] = provider;
  }

  static LlmProvider? get(String id) => _providers[id];
  static List<LlmProvider> get all => _providers.values.toList();
  static void clear() => _providers.clear();
}
