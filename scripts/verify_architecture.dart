// ignore_for_file: avoid_print
//
// 依赖方向校验（架构守护）。
// 用途：阶段1-1.4，自动检查 lib/ 下 import 是否符合分层方向约束。
// 允许方向：presentation → domain → data → core（core 不依赖任何上层）。
// lib/services/ 与 lib/widgets/ 归入 presentation 层。
// lib/l10n/ 归入 core 层（生成资源，可被任意层引用）。
// 生成命令：dart run scripts/verify_architecture.dart
// 退出码：0 = 通过(零违规)，1 = 发现违规。

import 'dart:io';

/// 允许的依赖方向：layer -> 可依赖的下层集合。
/// 方向：presentation → domain → data → core
const allowedDirections = {
  'presentation': ['domain', 'data', 'core', 'l10n'],
  'domain': ['data', 'core', 'l10n'],
  'data': ['core', 'l10n'],
  'core': ['l10n'],
  'l10n': [],
};

/// lib 子目录 -> 所属分层
const layerOf = {
  'presentation': 'presentation',
  'domain': 'domain',
  'data': 'data',
  'core': 'core',
  'services': 'presentation', // lib/services/ 归属 presentation
  'widgets': 'presentation',  // lib/widgets/ 归属 presentation
  'l10n': 'l10n',
};

void main(List<String> args) async {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln('lib/ directory not found. Run from project root.');
    exit(1);
  }

  final files = <File>[];
  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      files.add(entity);
    }
  }

  int violations = 0;
  final violationList = <String>[];

  for (final file in files) {
    final currentLayer = _getLayer(file.path);
    if (currentLayer == null) continue;

    final content = file.readAsStringSync();
    // 仅匹配单引号 import：import 'package:kirakira/xxx';
    // Dart 工程标准用单引号，避免引号转义歧义。
    final imports =
        RegExp(r"import\s+'(package:kirakira/[^']+)';?").allMatches(content);

    for (final m in imports) {
      final importPath = m.group(1)!;
      final targetLayer = _getLayerFromImport(importPath);
      if (targetLayer == null) continue;

      final allowed = allowedDirections[currentLayer]!;
      if (!allowed.contains(targetLayer)) {
        final msg = '  $currentLayer → $targetLayer  ${file.path}  imports  $importPath';
        violationList.add(msg);
        violations++;
      }
    }
  }

  if (violations == 0) {
    print('  架构依赖检查通过：无违规依赖');
    exit(0);
  } else {
    print('  发现 $violations 个违规依赖：');
    for (final v in violationList) {
      print(v);
    }
    exit(1);
  }
}

String? _getLayer(String path) {
  final normalized = path.replaceAll(r'\', '/');
  for (final layer in layerOf.keys) {
    if (normalized.contains('/lib/$layer/') || normalized.startsWith('lib/$layer/')) {
      return layerOf[layer];
    }
  }
  return null;
}

String? _getLayerFromImport(String importPath) {
  for (final seg in [
    'presentation/',
    'domain/',
    'data/',
    'core/',
    'services/',
    'widgets/',
    'l10n/',
  ]) {
    if (importPath.startsWith(seg)) return layerOf[seg.replaceAll('/', '')];
  }
  return null;
}
