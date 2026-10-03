import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class PngCharacterCardParser {
  static Future<Map<String, dynamic>?> parse(Uint8List bytes, {String? sourcePath}) async {
    final report = StringBuffer();
    final now = DateTime.now();
    report.writeln('========================================');
    report.writeln('KiraKira PNG 导入诊断报告');
    report.writeln('时间: $now');
    if (sourcePath != null) report.writeln('文件: $sourcePath');
    report.writeln('文件大小: ${bytes.length} 字节');
    report.writeln('PNG 签名: ${bytes.take(8).toList()}');
    report.writeln('========================================');

    if (bytes.length < 8) {
      report.writeln('【错误】文件太小，不是有效的 PNG');
      await _saveReport(report.toString());
      return null;
    }

    int off = 8; int n = 0; final chunks = <_ChunkInfo>[];
    while (off + 8 <= bytes.length) {
      final len = (bytes[off] << 24) | (bytes[off + 1] << 16) | (bytes[off + 2] << 8) | bytes[off + 3]; off += 4;
      final tp = _safeDecodeText(bytes.sublist(off, off + 4)); off += 4; n++;
      if (tp == 'tEXt' || tp == 'iTXt' || tp == 'zTXt') {
        int ke = off; while (ke < off + len && bytes[ke] != 0) { ke++; }
        final key = _safeDecodeText(bytes.sublist(off, ke));
        if (ke + 1 < off + len) {
          final data = bytes.sublist(ke + 1, off + len);
          final first50 = data.take(50).toList();
          String textPreview = '';
          try { textPreview = _safeDecodeText(data); if (textPreview.length > 50) textPreview = textPreview.substring(0, 50); } catch (e) { textPreview = e.toString(); }
          chunks.add(_ChunkInfo(tp, key, data.length, first50));

          // Try to decode character data
          final val = _safeDecodeText(data);
          try { final j = jsonDecode(val) as Map<String, dynamic>; if (_hasCharFields(j)) { return j; } } catch (_) {}
          try { final d = _safeDecodeText(base64Decode(val.trim())); final j = jsonDecode(d) as Map<String, dynamic>; if (_hasCharFields(j)) { return j; } } catch (_) {}
        }
      }
      off += len + 4;
    }

    report.writeln('【文本块信息】');
    report.writeln('找到的文本块数量: ${chunks.length}');
    for (final c in chunks) {
      report.writeln('  - 块类型: ${c.type}, 键名: ${c.keyword}, 数据长度: ${c.dataLength}, 前50个字符: ${c.first50}');
    }
    report.writeln('========================================');
    report.writeln('【解码尝试】');
    for (final c in chunks) {
      final val = _safeDecodeText(Uint8List.fromList(c.first50));
      report.writeln('UTF-8(${c.keyword}): ${_tryUtf8(val) ? 'success' : 'failed'}');
      report.writeln('Latin-1(${c.keyword}): ${_tryLatin1(val) ? 'success' : 'failed'}');
      report.writeln('Base64+UTF-8(${c.keyword}): ${_tryBase64(val) ? 'success' : 'failed'}');
    }
    report.writeln('========================================');
    report.writeln('【最终错误】');
    report.writeln('No character data found in any PNG text chunk');
    report.writeln('========================================');

    await _saveReport(report.toString());
    return null;
  }

  static bool _tryUtf8(String s) { try { utf8.decode(utf8.encode(s)); return true; } catch (_) { return false; } }
  static bool _tryLatin1(String s) { try { latin1.decode(latin1.encode(s)); return true; } catch (_) { return false; } }
  static bool _tryBase64(String s) { try { base64Decode(s.trim()); return true; } catch (_) { return false; } }

  static String _safeDecodeText(List<int> bytes) {
    try { return utf8.decode(bytes); } catch (_) {}
    try { return latin1.decode(bytes); } catch (_) {}
    try { return utf8.decode(base64.decode(utf8.decode(bytes).trim())); } catch (_) {}
    return String.fromCharCodes(bytes);
  }

  static bool _hasCharFields(Map<String, dynamic> j) {
    return j.containsKey('name') || j.containsKey('data') || j.containsKey('description') || j.containsKey('spec');
  }

  static Future<void> _saveReport(String report) async {
    // Diagnostic report only: debug builds. In production it accumulated a
    // timestamped .txt in Downloads on every failed parse.
    if (!kDebugMode) return;
    debugPrint(report);
    try {
      final dir = await getDownloadsDirectory();
      if (dir != null) {
        final ts = DateTime.now().toIso8601String().replaceAll(':', '').replaceAll('.', '');
        final file = File('${dir.path}/kirakira_diagnostic_$ts.txt');
        await file.writeAsString(report);
        debugPrint('[PNG-DIAG] Report saved to: ${file.path}');
      } else {
        debugPrint('[PNG-DIAG] Downloads directory not available');
      }
    } catch (e) {
      debugPrint('[PNG-DIAG] Failed to save report: $e');
    }
  }
}

class _ChunkInfo {
  final String type; final String keyword; final int dataLength; final List<int> first50;
  _ChunkInfo(this.type, this.keyword, this.dataLength, this.first50);
}