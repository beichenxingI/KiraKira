import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../providers/quote_color_providers.dart';

/// 诊断版:合并成一条 syntax,用 visitText 染色,加可视标记验证
class _DiagQuoteSyntax extends md.InlineSyntax {
  static const tag = 'quote_color';
  _DiagQuoteSyntax()
      : super(
          r'(?:'
          r'「[^「」\r\n]*」'
          r'|『[^『』\r\n]*』'
          r'|“[^“”\r\n]*”'
          r'|"[^"\r\n]*"'
          r'|（[^（）\r\n]*）'
          r'|\([^()\r\n]*\)'
          r'|【[^【】\r\n]*】'
          r'|《[^《》\r\n]*》'
          r')',
        );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final value = match.group(0)!;
    debugPrint('【引号诊断】matched: "$value"');
    debugPrint('【引号诊断】码点: '
        '${value.runes.map((r) => "U+${r.toRadixString(16).padLeft(4, "0")}").join(" ")}');
    parser.addNode(md.Element(tag, [md.Text(value)]));
    return true;
  }
}

class _DiagQuoteBuilder extends MarkdownElementBuilder {
  final Color color;
  _DiagQuoteBuilder(this.color);

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    debugPrint('【引号诊断】visitText 收到: "${text.text}"');
    return Text.rich(
      TextSpan(
        text: 'X${text.text}Y',
        style: (preferredStyle ?? const TextStyle()).copyWith(
          color: Colors.red,
          backgroundColor: Colors.yellow,
        ),
      ),
    );
  }

  @override
  bool isBlockElement() => false;
}

class QuoteHighlight {
  final List<md.InlineSyntax> syntaxes;
  final Map<String, MarkdownElementBuilder> builders;
  const QuoteHighlight(this.syntaxes, this.builders);

  static QuoteHighlight build(QuoteColorState state) {
    // 诊断阶段:忽略配置,统一一条 syntax + 红字黄底
    return QuoteHighlight(
      [_DiagQuoteSyntax()],
      {_DiagQuoteSyntax.tag: _DiagQuoteBuilder(state.primaryA)},
    );
  }
}