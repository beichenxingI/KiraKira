import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/services/model_fingerprint_service.dart';
import '../../providers/fingerprint_providers.dart';
import '../../providers/llm_configs_provider.dart';
import 'fingerprint_result_widget.dart';
import 'package:kirakira/presentation/widgets/common/kira_button.dart';

/// GeekProbe - model deep detection screen
class ModelDetectionScreen extends ConsumerStatefulWidget {
  const ModelDetectionScreen({super.key});

  @override
  ConsumerState<ModelDetectionScreen> createState() =>
      _ModelDetectionScreenState();
}

/// Level gradient colors: quick = accent teal / normal = primary purple / deep = AF52DE.
/// Gradient endpoints come in pairs; exempt from the palette rules (brand gradients, not theme colors).
List<Color> _gradientFor(DetectionLevel level) {
  switch (level) {
    case DetectionLevel.quick:
      return const [DesignTokens.accent, Color(0xFF7FE0D8)];
    case DetectionLevel.normal:
      return const [DesignTokens.primary, Color(0xFF9F9DF8)];
    case DetectionLevel.deep:
      return const [Color(0xFFAF52DE), Color(0xFFC97BEB)];
  }
}

class _ModelDetectionScreenState extends ConsumerState<ModelDetectionScreen> {
  DetectionLevel _selectedLevel = DetectionLevel.normal;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fingerprintProvider);

    return Scaffold(
      // Uses the shared background token (pure black to near-black)
      backgroundColor: DesignTokens.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '极客Probe',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              '模型深度检测',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeSm,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: state.isRunning
              ? _buildRunningView(state)
              : state.error != null
                  ? _buildErrorView(state.error!)
                  : state.result != null
                      ? _buildResultView(state)
                      : _buildIdleView(),
        ),
      ),
    );
  }

  // Idle: judge config + level selection + start button
  Widget _buildIdleView() {
    return SingleChildScrollView(
      key: const ValueKey('idle'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildJudgeSelector(),
          const SizedBox(height: 24),
          _buildLevelSelector(),
          const SizedBox(height: 32),
          _buildStartButton(),
          const SizedBox(height: 24),
          _buildInfoSection(),
        ],
      ),
    );
  }

  // Collapsible info section
  Widget _buildInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.darkCard.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: Colors.white.withValues(alpha: 0.5),
          collapsedIconColor: Colors.white.withValues(alpha: 0.5),
          title: Text(
            '检测原理与声明',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              '极客Probe 通过一组精心设计的题目探测模型的能力特征与家族倾向。'
              '设置裁判模型可对被测模型的回答独立打分，比自评更可信。'
              '深度档会额外发送掺假一致性检测，用于识别中转商偷换模型，'
              '会多消耗少量额度。检测结果仅供参考，不构成对模型真实身份的断言。',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Running: progress view
  Widget _buildRunningView(FingerprintState state) {
    final gradient = _gradientFor(_selectedLevel);
    final progress = state.total > 0 ? state.current / state.total : 0.0;

    return Center(
      key: const ValueKey('running'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.science_rounded,
                size: 48, color: gradient[1].withValues(alpha: 0.9)),
            const SizedBox(height: 24),
            _ScanningProgressBar(progress: progress, gradient: gradient),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                state.total > 0
                    ? '正在检测（${state.current}/${state.total}）'
                    : '正在准备…',
                key: ValueKey(state.current),
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeBodyLarge,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Judge model entry
  Widget _buildJudgeSelector() {
    final judgeId = ref.watch(judgeConfigIdProvider);
    final judgeModel = ref.watch(judgeModelProvider);
    final configs = ref.watch(llmConfigsProvider).configs;
    final judgeConfig = judgeId == null
        ? null
        : configs.where((c) => c.id == judgeId).firstOrNull;
    final judgeName = judgeConfig == null
        ? null
        : (judgeModel != null && judgeModel.isNotEmpty)
            ? '${judgeConfig.name} · $judgeModel'
            : judgeConfig.name;

    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.darkCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: ListTile(
        leading:
            Icon(Icons.gavel_rounded, color: Colors.white.withValues(alpha: 0.6)),
        title: const Text(
          '裁判模型',
          style: TextStyle(
              color: Colors.white, fontSize: DesignTokens.fontSizeBodyLarge, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          judgeName ?? '未设置（自评模式，可信度低）',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5), fontSize: DesignTokens.fontSizeSm),
        ),
        trailing:
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3)),
        onTap: _pickJudge,
      ),
    );
  }

  Future<void> _pickJudge() async {
    final configs = ref.read(llmConfigsProvider).configs;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: DesignTokens.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 16),
              const Text('选择裁判模型',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: DesignTokens.fontSizeXl,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.person_off_rounded,
                    color: Colors.white.withValues(alpha: 0.6)),
                title: const Text('不使用裁判（自评）',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  ref.read(judgeConfigIdProvider.notifier).state = null;
                  ref.read(judgeModelProvider.notifier).state = null;
                  Navigator.pop(ctx);
                },
              ),
              const Divider(color: Colors.white24, height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: configs
                      .map((c) => ListTile(
                            leading: Icon(Icons.smart_toy_rounded,
                                color: Colors.white.withValues(alpha: 0.6)),
                            title: Text(c.name,
                                style:
                                    const TextStyle(color: Colors.white)),
                            subtitle: Text(c.model ?? '',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 12)),
                            onTap: () {
                              ref
                                  .read(judgeConfigIdProvider.notifier)
                                  .state = c.id;
                              ref
                                  .read(judgeModelProvider.notifier)
                                  .state = null;
                              Navigator.pop(ctx);
                              _pickJudgeModel(c.id);
                            },
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // Second-level judge model picker
  Future<void> _pickJudgeModel(String configId) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: DesignTokens.darkSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Consumer(
            builder: (context, ref, _) {
              final modelsAsync = ref.watch(judgeModelsProvider(configId));
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('选择裁判使用的模型',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: DesignTokens.fontSizeXl,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Flexible(
                    child: modelsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('拉取模型失败：$e',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6))),
                      ),
                      data: (models) {
                        if (models.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text('该配置未返回任何模型',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6))),
                          );
                        }
                        return ListView(
                          shrinkWrap: true,
                          children: models
                              .map((m) => ListTile(
                                    leading: Icon(Icons.memory_rounded,
                                        color: Colors.white.withValues(alpha: 0.6)),
                                    title: Text(m,
                                        style: const TextStyle(
                                            color: Colors.white)),
                                    onTap: () {
                                      ref
                                          .read(judgeModelProvider.notifier)
                                          .state = m;
                                      Navigator.pop(ctx);
                                    },
                                  ))
                              .toList(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // Three-level selection
  Widget _buildLevelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '检测档位',
          style: TextStyle(
            fontSize: DesignTokens.fontSizeBodyLarge,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildLevelCard(
                level: DetectionLevel.quick,
                title: '快速',
                subtitle: '10题 · 约2分钟',
                icon: Icons.bolt_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLevelCard(
                level: DetectionLevel.normal,
                title: '正常',
                subtitle: '25题 · 约5分钟',
                icon: Icons.speed_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLevelCard(
                level: DetectionLevel.deep,
                title: '深度',
                subtitle: '37题 · 约8分钟',
                icon: Icons.science_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLevelCard({
    required DetectionLevel level,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedLevel == level;
    final gradient = _gradientFor(level);

    return GestureDetector(
      onTap: () => setState(() => _selectedLevel = level),
      child: AnimatedScale(
        scale: isSelected ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: DesignTokens.curveStandard,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: DesignTokens.curveStandard,
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: gradient.map((c) => c.withValues(alpha: 0.85)).toList(),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : DesignTokens.darkCard.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.1),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: gradient[0].withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            children: [
              Icon(icon,
                  size: 32,
                  color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.6)),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: isSelected ? 0.85 : 0.5),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: DesignTokens.curveStandard,
                child: isSelected
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _getLevelDescription(level),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: DesignTokens.fontSizeCaption,
                            height: 1.4,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLevelDescription(DetectionLevel level) {
    switch (level) {
      case DetectionLevel.quick:
        return '覆盖全部7个能力维度，快速了解模型特征';
      case DetectionLevel.normal:
        return '标准测试，兼顾速度与准确度';
      case DetectionLevel.deep:
        return '全量题目 + 掺假一致性检测，最高可信度';
    }
  }

  Widget _buildStartButton() {
    // Replaced the default ElevatedButton (iOS blue) with KiraButton (filled, primary purple)
    return KiraButton(
      onPressed: () {
        ref
            .read(fingerprintProvider.notifier)
            .start(level: _selectedLevel);
      },
      child: const Text(
        '开始检测',
        style: TextStyle(fontSize: DesignTokens.fontSizeXl, fontWeight: FontWeight.w600),
      ),
    );
  }

  // Result state: report reveal
  Widget _buildResultView(FingerprintState state) {
    return _RevealWrapper(
      key: const ValueKey('result'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FingerprintResultWidget(
              result: state.result,
              onClose: () =>
                  ref.read(fingerprintProvider.notifier).reset(),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () =>
                  ref.read(fingerprintProvider.notifier).reset(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusLg)),
              ),
              child: const Text(
                '重新检测',
                style: TextStyle(fontSize: DesignTokens.fontSizeXl, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Error state
  Widget _buildErrorView(String error) {
    return Center(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.redAccent.withValues(alpha: 0.8)),
            const SizedBox(height: 20),
            const Text(
              '检测失败',
              style: TextStyle(
                  fontSize: DesignTokens.fontSizeXl,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: DesignTokens.fontSizeSm,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () =>
                  ref.read(fingerprintProvider.notifier).reset(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusLg)),
              ),
              child: const Text('返回重试'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Report reveal animation: scale 0.96 to 1.0 plus fade-in
class _RevealWrapper extends StatefulWidget {
  final Widget child;
  const _RevealWrapper({super.key, required this.child});

  @override
  State<_RevealWrapper> createState() => _RevealWrapperState();
}

class _RevealWrapperState extends State<_RevealWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _controller, curve: DesignTokens.curveFade);
    _scale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: DesignTokens.curveStandard),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// Scanning progress bar (restrained version: 3-second slow breathing, no flicker)
class _ScanningProgressBar extends StatefulWidget {
  final double progress;
  final List<Color> gradient;
  const _ScanningProgressBar({required this.progress, required this.gradient});

  @override
  State<_ScanningProgressBar> createState() => _ScanningProgressBarState();
}

class _ScanningProgressBarState extends State<_ScanningProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          color: DesignTokens.darkSurface,
          borderRadius: BorderRadius.circular(4),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fullWidth = constraints.maxWidth;
            return Stack(
              children: [
                // Fill
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: DesignTokens.curveFade,
                  width: fullWidth * widget.progress.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: widget.gradient),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Breathing shimmer
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final fillWidth =
                        fullWidth * widget.progress.clamp(0.0, 1.0);
                    if (fillWidth <= 0) return const SizedBox.shrink();
                    final shimmerX =
                        (_controller.value * 2 - 0.5) * fillWidth;
                    return Positioned(
                      left: shimmerX,
                      child: Container(
                        width: fillWidth * 0.3,
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: 0.45),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}