// lib/presentation/screens/ai_config/llm_config_edit_screen.dart
/// LLM 配置编辑页(G-T4:_ConfigEditorDialog 4 字段表单 → push 子页,D-T2 规则 3)
library;

import 'package:drift/drift.dart' as drift;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/kira_components.dart';
import 'package:kirakira/presentation/widgets/common/kira_grouped_tile.dart';
import '../../../data/database/database.dart';
import '../../providers/llm_configs_provider.dart';

class LlmConfigEditScreen extends ConsumerStatefulWidget {
  final LlmConfig? existing;
  const LlmConfigEditScreen({super.key, this.existing});

  @override
  ConsumerState<LlmConfigEditScreen> createState() =>
      _LlmConfigEditScreenState();
}

class _LlmConfigEditScreenState extends ConsumerState<LlmConfigEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _endpoint;
  late final TextEditingController _apiKey;
  late final TextEditingController _model;
  late String _provider;

  static const _providers = ['custom', 'deepseek', 'openai', 'claude'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _endpoint = TextEditingController(text: e?.endpoint ?? '');
    _apiKey = TextEditingController(text: e?.apiKey ?? '');
    _model = TextEditingController(text: e?.model ?? '');
    _provider = e?.provider ?? 'custom';
    if (!_providers.contains(_provider)) _provider = 'custom';
  }

  @override
  void dispose() {
    _name.dispose();
    _endpoint.dispose();
    _apiKey.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final now = DateTime.now();
    final id = widget.existing?.id ?? now.millisecondsSinceEpoch.toString();
    final companion = LlmConfigsCompanion(
      id: drift.Value(id),
      name: drift.Value(
          _name.text.trim().isEmpty ? 'Unnamed' : _name.text.trim()),
      provider: drift.Value(_provider),
      endpoint: drift.Value(_endpoint.text.trim()),
      apiKey: drift.Value(_apiKey.text.trim()),
      model:
          drift.Value(_model.text.trim().isEmpty ? null : _model.text.trim()),
      createdAt: drift.Value(widget.existing?.createdAt ?? now),
      modifiedAt: drift.Value(now),
    );
    await ref.read(llmConfigsProvider.notifier).upsert(companion);
    if (mounted) Navigator.of(context).pop();
  }

  String get _providerLabel => _provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(widget.existing == null ? '新建配置' : '编辑配置'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('保存',
                style: TextStyle(color: theme.colorScheme.primary)),
          ),
          const SizedBox(width: DesignTokens.spaceSm),
        ],
      ),
      body: ListView(
        children: [
          KiraSection.plain(
            title: '基础信息',
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.spaceMd),
              child: Column(
                children: [
                  _field(_name, '名称'),
                  const SizedBox(height: DesignTokens.spaceSm),
                  _field(_endpoint, 'Base URL',
                      placeholder: 'https://api.deepseek.com'),
                  const SizedBox(height: DesignTokens.spaceSm),
                  _field(_apiKey, 'API Key', obscure: true),
                  const SizedBox(height: DesignTokens.spaceSm),
                  _field(_model, '模型(可选)'),
                ],
              ),
            ),
          ),
          KiraSection(
            title: '供应商',
            children: [
              KiraGroupedTile(
                icon: CupertinoIcons.antenna_radiowaves_left_right,
                iconBg:
                    theme.colorScheme.primary.withValues(alpha: 0.12),
                title: 'Provider',
                subtitle: _providerLabel,
                onTap: () {
                  showCupertinoModalPopup<void>(
                    context: context,
                    builder: (sheetCtx) => CupertinoTheme(
                      data: CupertinoThemeData(
                        brightness:
                            isDark ? Brightness.dark : Brightness.light,
                      ),
                      child: CupertinoActionSheet(
                        title: const Text('Provider'),
                        actions: [
                          for (final provider in _providers)
                            CupertinoActionSheetAction(
                              onPressed: () {
                                setState(() => _provider = provider);
                                Navigator.pop(sheetCtx);
                              },
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(provider),
                                  if (provider == _provider) ...[
                                    const SizedBox(width: 6),
                                    const Icon(CupertinoIcons.checkmark,
                                        size: 16),
                                  ],
                                ],
                              ),
                            ),
                        ],
                        cancelButton: CupertinoActionSheetAction(
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: const Text('取消'),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceLg),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {String? placeholder, bool obscure = false}) {
    return CupertinoTextField(
      controller: ctrl,
      obscureText: obscure,
      placeholder: placeholder ?? label,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(DesignTokens.radiusGroupedCard),
      ),
    );
  }
}
