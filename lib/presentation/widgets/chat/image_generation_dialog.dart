import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/domain/services/image_generation_service.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/image_gen_providers.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';

/// Dialog for generating images from message content
class ImageGenerationDialog extends ConsumerStatefulWidget {
  /// The base prompt (usually from message content)
  final String basePrompt;
  
  /// Optional character name for context
  final String? characterName;
  
  /// The generation mode
  final ImageGenMode mode;

  const ImageGenerationDialog({
    super.key,
    required this.basePrompt,
    this.characterName,
    this.mode = ImageGenMode.free,
  });

  @override
  ConsumerState<ImageGenerationDialog> createState() => _ImageGenerationDialogState();
  
  /// Show the dialog and return the generated image (if any)
  static Future<ImageGenResult?> show(
    BuildContext context, {
    required String basePrompt,
    String? characterName,
    ImageGenMode mode = ImageGenMode.free,
  }) {
    return showDialog<ImageGenResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ImageGenerationDialog(
        basePrompt: basePrompt,
        characterName: characterName,
        mode: mode,
      ),
    );
  }
}

class _ImageGenerationDialogState extends ConsumerState<ImageGenerationDialog> {
  late TextEditingController _promptController;
  late TextEditingController _negativePromptController;
  bool _isGenerating = false;
  double _progress = 0.0;
  String? _error;
  Uint8List? _generatedImage;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: _buildInitialPrompt());
    _negativePromptController = TextEditingController(
      text: ref.read(imageGenSettingsProvider).defaultNegativePrompt ?? '',
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativePromptController.dispose();
    super.dispose();
  }

  String _buildInitialPrompt() {
    final basePrompt = widget.basePrompt.trim();
    
    switch (widget.mode) {
      case ImageGenMode.character:
        return 'full body portrait, ${widget.characterName ?? "character"}, $basePrompt';
      case ImageGenMode.face:
        return 'close up portrait, ${widget.characterName ?? "character"}, $basePrompt';
      case ImageGenMode.background:
        return 'background, scene, $basePrompt';
      case ImageGenMode.lastMessage:
      case ImageGenMode.scenario:
      case ImageGenMode.free:
        return basePrompt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(imageGenSettingsProvider);

    return AlertDialog(
      backgroundColor: AppTheme.darkCard,
      title: Row(
        children: [
          const Icon(Icons.image, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.generateImagesUsingAi,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ),
          if (!settings.enabled)
            Tooltip(
              message: l10n.notConfigured,
              child: const Icon(Icons.warning, color: Colors.orange, size: 20),
            ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Provider info
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud, size: 16, color: AppTheme.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        settings.provider.displayName,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '${settings.defaultWidth}x${settings.defaultHeight}',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Model selector
              _buildModelSelector(settings),
              const SizedBox(height: 16),

              // Prompt
              Text(
                l10n.prompt,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _promptController,
                maxLines: 4,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: l10n.enterPromptToGenerate,
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.darkBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                enabled: !_isGenerating,
              ),
              const SizedBox(height: 16),

              // Negative prompt (collapsible)
              ExpansionTile(
                title: Text(
                  l10n.negativePrompt,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  TextField(
                    controller: _negativePromptController,
                    maxLines: 2,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: l10n.enterTermsToAvoid,
                      hintStyle: const TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.darkBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    enabled: !_isGenerating,
                  ),
                ],
              ),

              // Progress indicator
              if (_isGenerating) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: AppTheme.darkBackground,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              // Error message
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Generated image preview
              if (_generatedImage != null) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _generatedImage!,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        if (_generatedImage != null)
          ElevatedButton.icon(
            onPressed: () {
              // Return the result with the generated image
              Navigator.of(context).pop(ImageGenResult(
                images: [_generatedImage!],
                prompt: _promptController.text,
                seed: DateTime.now().millisecondsSinceEpoch,
              ));
            },
            icon: const Icon(Icons.check),
            label: Text(l10n.save),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: _isGenerating || !settings.enabled ? null : _generate,
            icon: _isGenerating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_isGenerating ? l10n.generating : l10n.generate),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
          ),
      ],
    );
  }

  Future<void> _generate() async {
    final settings = ref.read(imageGenSettingsProvider);
    final service = ref.read(imageGenServiceProvider);

    setState(() {
      _isGenerating = true;
      _progress = 0.0;
      _error = null;
      _generatedImage = null;
    });

    // Set up progress callback
    service.onProgress = (progress) {
      if (mounted) {
        setState(() => _progress = progress);
      }
    };

    service.onError = (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _isGenerating = false;
        });
      }
    };

    try {
      final result = await service.generate(ImageGenRequest(
        prompt: _promptController.text,
        negativePrompt: _negativePromptController.text.isNotEmpty
            ? _negativePromptController.text
            : null,
        width: settings.defaultWidth,
        height: settings.defaultHeight,
        steps: settings.defaultSteps,
        cfgScale: settings.defaultCfgScale,
        sampler: settings.defaultSampler,
        mode: widget.mode,
        model: settings.model, // Use currently selected model
      ));

      if (mounted) {
        if (result != null && result.images.isNotEmpty) {
          setState(() {
            _generatedImage = result.images.first;
            _isGenerating = false;
          });
        } else {
          setState(() {
            _error = 'No image generated';
            _isGenerating = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isGenerating = false;
        });
      }
    }
  }

  /// Build model selector dropdown
  Widget _buildModelSelector(ImageGenSettings settings) {
    final availableModels = ref.watch(availableModelsProvider);
    final currentModel = settings.model;
    
    return Row(
      children: [
        const Icon(Icons.memory, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        const Text(
          'Model:',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: availableModels.contains(currentModel) ? currentModel : null,
                isExpanded: true,
                isDense: true,
                dropdownColor: AppTheme.darkCard,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                ),
                hint: Text(
                  currentModel,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                items: availableModels.map((model) {
                  return DropdownMenuItem<String>(
                    value: model,
                    child: Text(
                      model,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _isGenerating ? null : (value) {
                  if (value != null) {
                    ref.read(imageGenSettingsProvider.notifier).setModel(value);
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
