import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/database.dart';
import '../../providers/llm_configs_provider.dart';

class LlmConfigListScreen extends ConsumerWidget {
  const LlmConfigListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(llmConfigsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Config Manager')),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.configs.isEmpty
              ? const Center(child: Text('No configs yet. Tap + to create.'))
              : ListView.builder(
                  itemCount: state.configs.length,
                  itemBuilder: (context, i) {
                    final c = state.configs[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: Icon(
                          c.isDefault ? Icons.check_circle : Icons.circle_outlined,
                          color: c.isDefault ? Colors.green : null,
                        ),
                        title: Text(c.name),
                        subtitle: Text(
                          '${c.provider}  ${c.model ?? "no model"}\n${c.endpoint}',
                        ),
                        isThreeLine: true,
                        onTap: () => _openEditor(context, ref, existing: c),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'activate') {
                              await ref.read(llmConfigsProvider.notifier).setActive(c.id);
                            } else if (v == 'edit') {
                              _openEditor(context, ref, existing: c);
                            } else if (v == 'delete') {
                              await ref.read(llmConfigsProvider.notifier).delete(c.id);
                            }
                          },
                          itemBuilder: (_) => [
                            if (!c.isDefault)
                              const PopupMenuItem(value: 'activate', child: Text('Activate')),
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, {LlmConfig? existing}) {
    showDialog(
      context: context,
      builder: (_) => _ConfigEditorDialog(existing: existing),
    );
  }
}

class _ConfigEditorDialog extends ConsumerStatefulWidget {
  final LlmConfig? existing;
  const _ConfigEditorDialog({this.existing});

  @override
  ConsumerState<_ConfigEditorDialog> createState() => _ConfigEditorDialogState();
}

class _ConfigEditorDialogState extends ConsumerState<_ConfigEditorDialog> {
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
      name: drift.Value(_name.text.trim().isEmpty ? 'Unnamed' : _name.text.trim()),
      provider: drift.Value(_provider),
      endpoint: drift.Value(_endpoint.text.trim()),
      apiKey: drift.Value(_apiKey.text.trim()),
      model: drift.Value(_model.text.trim().isEmpty ? null : _model.text.trim()),
      createdAt: drift.Value(widget.existing?.createdAt ?? now),
      modifiedAt: drift.Value(now),
    );
    await ref.read(llmConfigsProvider.notifier).upsert(companion);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New Config' : 'Edit Config'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _provider,
              decoration: const InputDecoration(labelText: 'Provider'),
              items: _providers
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _provider = v ?? 'custom'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _endpoint,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'https://api.deepseek.com',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _apiKey,
              decoration: const InputDecoration(labelText: 'API Key'),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _model,
              decoration: const InputDecoration(labelText: 'Model (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
