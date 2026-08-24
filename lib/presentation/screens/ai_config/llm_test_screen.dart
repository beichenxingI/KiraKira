// lib/presentation/screens/ai_config/llm_test_screen.dart
/// LLM Test 调试页(G-T4.2:保留,外观跟随主题即可)
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/kira_button.dart';
import '../../../domain/providers/llm_provider.dart';
import '../../../domain/providers/llm_provider_registry.dart';

class LlmTestScreen extends StatefulWidget {
  const LlmTestScreen({super.key});

  @override
  State<LlmTestScreen> createState() => _LlmTestScreenState();
}

class _LlmTestScreenState extends State<LlmTestScreen> {
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  String _status = 'Not tested';
  int? _latency;
  List<String> _models = [];
  bool _loading = false;

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _runTest() async {
    setState(() {
      _loading = true;
      _status = 'Testing...';
      _latency = null;
      _models = [];
    });

    final provider = LlmProviderRegistry.get('custom');
    if (provider == null) {
      setState(() {
        _loading = false;
        _status = 'Error: custom provider not registered';
      });
      return;
    }

    final credential = ApiCredential(
      baseUrl: _urlController.text.trim(),
      apiKey: _keyController.text.trim(),
    );

    try {
      final result = await provider.testConnection(credential);
      setState(() {
        _loading = false;
        _status = result.success ? 'OK' : 'Failed: ${result.errorMessage ?? "unknown"}';
        _latency = result.latencyMs;
        _models = result.models;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'Exception: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              'LLM 测试(临时)',
              style: theme.textTheme.displayLarge,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: DesignTokens.paddingScreen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CupertinoTextField(
                    controller: _urlController,
                    placeholder: 'Base URL',
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusGroupedCard),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: _keyController,
                    placeholder: 'API Key',
                    obscureText: true,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusGroupedCard),
                    ),
                  ),
                  const SizedBox(height: 16),
                  KiraButton(
                    onPressed: _loading ? null : _runTest,
                    child: Text(_loading ? '测试中…' : '测试连接'),
                  ),
                  const SizedBox(height: 24),
                  Text('状态:$_status',
                      style: theme.textTheme.titleMedium),
                  if (_latency != null) ...[
                    const SizedBox(height: 8),
                    Text('延迟:$_latency ms', style: theme.textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 16),
                  Text('模型(${_models.length}):',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ..._models.map((m) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child:
                            Text(' $m', style: theme.textTheme.bodySmall),
                      )),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
