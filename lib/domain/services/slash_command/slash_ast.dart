/// [P6-3] 斜杠命令 AST 节点。
/// 语义对齐 SillyTavern SlashCommandParser 的产物:
/// 根闭包 = 形参表 + 执行器列表;执行器 = 命令名 + 命名/无名参数赋值;
/// 闭包 `{: ... :}` 是一等公民,可作为参数值延迟执行。
library;

/// 参数赋值(命名/无名共用)。
/// [value] 为 String 或 [SlashClosureNode](闭包参数,延迟执行)。
class SlashArgAssignment {
  SlashArgAssignment({
    this.name = '',
    required this.value,
    this.wasQuoted = false,
  });

  /// 命名参数名;无名参数为空串
  final String name;

  /// String | SlashClosureNode
  final Object value;

  /// 值是否来自引号串(决定是否去空白等行为)
  final bool wasQuoted;

  bool get isClosure => value is SlashClosureNode;
}

/// 闭包节点 `{: ... :}` — 内部又是一段完整脚本。
class SlashClosureNode {
  /// 形参 `{: a, b :}`,执行时按位置绑定传入值
  final List<SlashArgAssignment> argumentList = [];

  /// 执行器列表(管道分隔的命令序列)
  final List<SlashExecutorNode> executorList = [];

  /// 原文(供 closure-serialize / 调试)
  String rawText = '';

  /// `{: ... :}()` — 作为参数被解析时立即执行
  bool executeNow = false;
}

/// 一条命令。
class SlashExecutorNode {
  SlashExecutorNode({required this.name, required this.start});

  /// 命令名(不含斜杠)
  String name;

  /// 命名参数
  final List<SlashArgAssignment> namedArgumentList = [];

  /// 无名参数(可含闭包)
  final List<SlashArgAssignment> unnamedArgumentList = [];

  /// 上一个命令的输出是否注入为本命令的无名参数(ST 的 injectPipe,`||` 可抑制)
  bool injectPipe = true;

  final int start;
  int end = 0;
}
