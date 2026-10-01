import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';

// Deep-report variant of comment_guard: for files whose token streams differ
// from git HEAD, line-diffs every differing STRING token. Pairs removed and
// added lines into change blocks and compares each pair's code prefix (the
// part before the line's first "//"). Pairs whose code prefixes differ are
// reported as REVIEW; exit 1 if any REVIEW pairs exist or a non-STRING token
// changed (a real code change).
void main(List<String> args) {
  final root = Directory.current.path;
  var failed = false;
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
      print('SKIP (not in HEAD): $rel');
      continue;
    }
    final oldTokens = _tokens(_normalize(git.stdout as String));
    final newTokens = _tokens(_normalize(File(path).readAsStringSync()));
    if (_same(oldTokens, newTokens)) {
      print('OK: $rel');
      continue;
    }
    print('=== DIFFERS: $rel ===');
    if (oldTokens.length != newTokens.length) {
      print('  FATAL: token count changed ${oldTokens.length} -> ${newTokens.length}');
      failed = true;
      continue;
    }
    for (var i = 0; i < oldTokens.length; i++) {
      final o = oldTokens[i];
      final w = newTokens[i];
      if (o.$1 == w.$1 && o.$2 == w.$2) continue;
      if (o.$1 != w.$1) {
        print('  FATAL: token #$i TYPE changed ${o.$1} -> ${w.$1}');
        failed = true;
        continue;
      }
      if (o.$1 != 'STRING') {
        print('  FATAL: token #$i NON-STRING changed: ${_clip(o.$2)} -> ${_clip(w.$2)}');
        failed = true;
        continue;
      }
      print('  -- token #$i STRING line diff --');
      final res = _lineDiff(o.$2, w.$2);
      print(res.$1);
      if (res.$2 > 0) {
        print('  REVIEW: ${res.$2} pair(s) with differing code prefix');
        failed = true;
      }
    }
  }
  exit(failed ? 1 : 0);
}

/// Returns (report, reviewPairCount).
(String, int) _lineDiff(String oldStr, String newStr) {
  final a = oldStr.split('\n');
  final b = newStr.split('\n');
  final lcs = List.generate(a.length + 1, (_) => List<int>.filled(b.length + 1, 0));
  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      lcs[i][j] = a[i] == b[j] ? lcs[i + 1][j + 1] + 1 : (lcs[i + 1][j] >= lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
    }
  }
  final out = StringBuffer();
  var review = 0;
  var i = 0, j = 0;
  var commentPairs = 0, indentOnly = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      i++; j++;
    } else {
      // Collect a change block: consecutive removed then added lines.
      final removed = <String>[];
      final added = <String>[];
      while (i < a.length && j < b.length && a[i] != b[j]) {
        if (lcs[i + 1][j] >= lcs[i][j + 1]) {
          removed.add(a[i++]);
        } else {
          added.add(b[j++]);
        }
      }
      final pairs = removed.length < added.length ? removed.length : added.length;
      for (var p = 0; p < pairs; p++) {
        final r = removed[p];
        final d = added[p];
        final rc = _codePrefix(r);
        final dc = _codePrefix(d);
        if (rc == dc) {
          if (r.trimLeft() == d.trimLeft()) {
            indentOnly++;
            out.writeln('     ~indent  - ${_clip(r)}');
            out.writeln('     ~indent  + ${_clip(d)}');
          } else {
            commentPairs++;
            out.writeln('     comment  - ${_clip(r)}');
            out.writeln('     comment  + ${_clip(d)}');
          }
        } else {
          review++;
          out.writeln('     REVIEW   - ${_clip(r)}');
          out.writeln('     REVIEW   + ${_clip(d)}');
        }
      }
      for (var p = pairs; p < removed.length; p++) {
        // Removed with no paired addition: must be a full-line comment.
        final r = removed[p];
        if (_codePrefix(r).trim().isEmpty) {
          commentPairs++;
          out.writeln('     comment  - ${_clip(r)}');
        } else {
          review++;
          out.writeln('     REVIEW   - ${_clip(r)}');
        }
      }
      for (var p = pairs; p < added.length; p++) {
        final d = added[p];
        if (_codePrefix(d).trim().isEmpty) {
          commentPairs++;
          out.writeln('     comment  + ${_clip(d)}');
        } else {
          review++;
          out.writeln('     REVIEW   + ${_clip(d)}');
        }
      }
    }
  }
  // Trailing block after last common line.
  final removed = <String>[];
  final added = <String>[];
  while (i < a.length) { removed.add(a[i++]); }
  while (j < b.length) { added.add(b[j++]); }
  final pairs = removed.length < added.length ? removed.length : added.length;
  for (var p = 0; p < pairs; p++) {
    final r = removed[p], d = added[p];
    final rc = _codePrefix(r), dc = _codePrefix(d);
    if (rc == dc) {
      commentPairs++;
      out.writeln('     comment  - ${_clip(r)}');
      out.writeln('     comment  + ${_clip(d)}');
    } else {
      review++;
      out.writeln('     REVIEW   - ${_clip(r)}');
      out.writeln('     REVIEW   + ${_clip(d)}');
    }
  }
  for (var p = pairs; p < removed.length; p++) { review++; out.writeln('     REVIEW   - ${_clip(removed[p])}'); }
  for (var p = pairs; p < added.length; p++) { review++; out.writeln('     REVIEW   + ${_clip(added[p])}'); }
  final summary = '     [summary: $commentPairs comment pairs, $indentOnly indent-only, $review review]';
  return ('${out.toString().trimRight()}\n$summary', review);
}

/// Code prefix of a line: everything before the first "//" (approximate but
/// adequate for embedded JS comment verification).
String _codePrefix(String line) {
  final idx = line.indexOf('//');
  return idx < 0 ? line : line.substring(0, idx);
}

String _clip(String s) {
  final flat = s.replaceAll('\r', '');
  return flat.length <= 160 ? flat : '${flat.substring(0, 160)}...[${flat.length} chars]';
}

bool _same(List<(String, String)> a, List<(String, String)> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].$1 != b[i].$1 || a[i].$2 != b[i].$2) return false;
  }
  return true;
}

String _normalize(String source) => source.replaceAll('\r\n', '\n');

List<(String, String)> _tokens(String source) {
  final result = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final list = <(String, String)>[];
  var token = result.unit.beginToken;
  while (true) {
    list.add((token.type.toString(), token.lexeme));
    if (token.isEof) break;
    token = token.next!;
  }
  return list;
}
