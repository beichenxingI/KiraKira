import 'package:flutter/material.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('LLM Test (Temp)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'e.g. https://api.deepseek.com',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keyController,
            decoration: const InputDecoration(
              labelText: 'API Key',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _runTest,
            child: Text(_loading ? 'Testing...' : 'Test Connection'),
          ),
          const SizedBox(height: 24),
          Text('Status: $_status', style: const TextStyle(fontWeight: FontWeight.bold)),
          if (_latency != null) ...[
            const SizedBox(height: 8),
            Text('Latency: $_latency ms'),
          ],
          const SizedBox(height: 16),
          Text('Models (${_models.length}):', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._models.map((m) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(' $m'),
              )),
        ],
      ),
    );
  }
}
