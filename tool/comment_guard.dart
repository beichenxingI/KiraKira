import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';

// Compares each changed .dart file against its git HEAD version using
// token streams (comments are excluded from the token chain), so any
// difference means non-comment code was modified.
void main(List<String> args) {
  final root = Directory.current.path;
  final bad = <String>[];
  for (final path in args) {
    final rel = path.replaceAll('\\', '/');
    final git = Process.runSync(
      'git',
      ['show', 'HEAD:$rel'],
      workingDirectory: root,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (git.exitCode != 0) {
      stdout.writeln('SKIP (not in HEAD): $rel');
      continue;
    }
    final oldDump = _dump(_normalize(git.stdout as String));
    final newSource = File(path).readAsStringSync();
    final newDump = _dump(_normalize(newSource));
    if (oldDump != newDump) {
      bad.add(rel);
    } else {
      stdout.writeln('OK: $rel');
    }
  }
  if (bad.isNotEmpty) {
    stderr.writeln('CODE CHANGES DETECTED IN:');
    for (final f in bad) {
      stderr.writeln('  $f');
    }
    exit(1);
  }
  stdout.writeln('All ${args.length} files: comment-only changes verified.');
}

String _normalize(String source) => source.replaceAll('\r\n', '\n');

String _dump(String source) {
  final result = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final sb = StringBuffer();
  var token = result.unit.beginToken;
  while (true) {
    sb.writeln('${token.type}: ${token.lexeme}');
    if (token.isEof) break;
    token = token.next!;
  }
  return sb.toString();
}
