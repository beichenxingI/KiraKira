// ignore_for_file: avoid_print
//
// 生成 Provider 注册清单文档。
// 用途：阶段1-1.2，扫描 lib/ 下所有 .dart，提取 Riverpod Provider 定义，
//       生成 providers_registry.dart 聚合 export 文件，便于追踪依赖。
// 生成命令：dart run scripts/generate_provider_registry.dart
//
// 此文件为重构期工具脚本，不参与 Flutter 工程编译（位于 scripts/，不被 lib/ 引用）。

import 'dart:io';

/// 匹配 Riverpod 顶层 Provider 定义。
/// 要求：final <name>Provider = <家族构造>(...)
/// 家族：Provider / StateNotifierProvider / FutureProvider / NotifierProvider /
///       StateProvider / StreamProvider。
/// 这样可排除方法体内的局部变量（如 final targetProvider = LLMProvider.values...），
/// 因为 = 后紧跟的是表达式而非家族构造关键字。
final _providerRegExp = RegExp(
  r'^\s*final\s+(\w+Provider)\s*=\s*(Provider|StateNotifierProvider|FutureProvider|NotifierProvider|StateProvider|StreamProvider)\b',
  multiLine: true,
);

void main(List<String> args) async {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln('lib/ directory not found. Run from project root.');
    exit(1);
  }

  // 收集所有 .dart 文件
  final files = <File>[];
  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      files.add(entity);
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));

  // 按文件分组统计 Provider
  final grouped = <String, List<String>>{}; // 导出文件 -> provider名列表
  final seen = <String, String>{}; // provider名 -> 首次出现的export路径
  final duplicates = <String, List<String>>{}; // 重复名 -> 冲突文件列表
  int total = 0;

  for (final file in files) {
    final content = file.readAsStringSync();
    final matches = _providerRegExp.allMatches(content);
    if (matches.isEmpty) continue;

    // 将绝对/Windows 路径规范为 package:kirakira/... 形式
    final normalized = file.path.replaceAll(r'\', '/');
    String exprPath;
    final libIdx = normalized.indexOf('lib/');
    if (libIdx >= 0) {
      exprPath = normalized.substring(libIdx);
    } else {
      exprPath = normalized;
    }
    final exportPath = 'package:kirakira/${exprPath.replaceFirst('lib/', '')}';

    final names = <String>[];
    for (final m in matches) {
      final name = m.group(1);
      if (name == null) continue;
      // 跳过私有符号（以下划线开头）——无法被 export
      if (name.startsWith('_')) continue;
      // 同名去重：保留首次出现的文件，其余记录为冲突
      if (seen.containsKey(name)) {
        (duplicates[name] ??= [seen[name]!]).add(exportPath);
        continue;
      }
      seen[name] = exportPath;
      names.add(name);
      total++;
    }
    if (names.isNotEmpty) {
      grouped[exportPath] = names;
    }
  }

  // 生成文件内容
  final buffer = StringBuffer();
  buffer.writeln('// ignore_for_file: library_private_types_in_public_api, type_alias_equality');
  buffer.writeln('// 此文件由脚本生成，勿手动编辑');
  buffer.writeln('// 生成命令: dart run scripts/generate_provider_registry.dart');
  buffer.writeln('//');
  buffer.writeln('// Provider 注册清单（阶段1-1.2 自动生成）');
  buffer.writeln('// 扫描 lib/ 下所有 Riverpod Provider 定义并聚合导出，便于追踪依赖。');
  if (duplicates.isNotEmpty) {
    buffer.writeln('//');
    buffer.writeln('// 注意：以下同名 Provider 在多个文件中重复定义，已仅保留首个出现文件，');
    buffer.writeln('// 其余定义未导出。源码层的重复属架构隐患，已记入重构遗留清单。');
    for (final entry in duplicates.entries) {
      buffer.writeln('//   ${entry.key}: ${entry.value.join(' / ')}');
    }
  }
  buffer.writeln('');

  final sortedExportPaths = grouped.keys.toList()..sort();
  for (final exportPath in sortedExportPaths) {
    final names = grouped[exportPath]!;
    buffer.writeln('// ${names.length} provider(s)');
    buffer.writeln("export '$exportPath' show");
    for (var i = 0; i < names.length; i++) {
      buffer.writeln('    ${names[i]}${i == names.length - 1 ? ';' : ','}');
    }
    buffer.writeln('');
  }

  buffer.writeln('/// 统计信息（脚本自动生成）');
  buffer.writeln('const int kTotalProviders = $total;');
  buffer.writeln(
      "const String kRegistryGeneratedAt = '${DateTime.now().toIso8601String().split('T').first}';");

  final outFile = File('lib/presentation/providers/providers_registry.dart');
  await outFile.writeAsString(buffer.toString());
  print('Generated providers_registry.dart with $total providers from ${grouped.length} files');
  if (duplicates.isNotEmpty) {
    print('Duplicate provider names (kept first, rest skipped):');
    for (final entry in duplicates.entries) {
      print('  ${entry.key}: ${entry.value.join(' / ')}');
    }
  }
}
