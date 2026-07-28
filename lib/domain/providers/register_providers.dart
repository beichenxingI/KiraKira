import 'llm_provider_registry.dart';
import 'openai_provider.dart';
import 'claude_provider.dart';
import 'deepseek_provider.dart';
import 'custom_provider.dart';

/// Registers all built-in LLM providers into the registry.
/// Called once during app startup, before runApp.
void registerLlmProviders() {
  LlmProviderRegistry.clear();
  LlmProviderRegistry.register(OpenAIProvider());
  LlmProviderRegistry.register(ClaudeProvider());
  LlmProviderRegistry.register(DeepSeekProvider());
  LlmProviderRegistry.register(CustomProvider());
}
