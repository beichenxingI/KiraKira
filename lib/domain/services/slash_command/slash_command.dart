/// [P6-3] 斜杠命令与注册表。
/// 命令回调收到 [SlashArgs],返回值成为管道输出(ST 的 callback(args, value) → pipe)。
library;

import 'slash_ast.dart';
import 'slash_scope.dart';

/// 命令回调签名。返回值:任意对象,runner 会字符串化进管道。
typedef SlashCommandCallback = Future<Object?> Function(SlashArgs args);

/// 命令定义。
class SlashCommand {
  const SlashCommand({
    required this.name,
    required this.callback,
    this.aliases = const [],
    this.splitUnnamedArgument = false,
    this.splitUnnamedArgumentCount,
  });

  /// 命令名(不含斜杠)
  final String name;

  /// 别名(同样可注册查找)
  final List<String> aliases;

  final SlashCommandCallback callback;

  /// 无名参数是否按值列表传给回调(/if /while /times /let /var 为 true)
  final bool splitUnnamedArgument;

  /// 配合 splitUnnamedArgument:前 N 个各自成值,其余合并成一个
  final int? splitUnnamedArgumentCount;
}

/// 命令回调的参数包。
class SlashArgs {
  SlashArgs({
    required this.scope,
    required this.ctx,
    this.env,
  });

  /// 命名参数(key → 值;值为 String 或 SlashClosureNode)
  final Map<String, Object?> named = {};

  /// 无名参数列表(String | SlashClosureNode)
  List<Object?> unnamed = [];

  /// 当前作用域
  final SlashScope scope;

  /// 执行上下文(abort/break)
  final SlashExecContext ctx;

  /// 平台服务桥(发送/生成等),由宿主注入;纯逻辑命令可为 null
  final SlashEnv? env;

  /// 是否有实际无名参数(含注入的 pipe)
  bool hasUnnamedArg = false;

  // ── 便捷取值 ──

  String? namedString(String name) {
    final v = named[name];
    if (v == null) return null;
    if (v is SlashClosureNode) return null;
    return v.toString();
  }

  String namedStringOr(String name, String fallback) =>
      namedString(name) ?? fallback;

  /// 无名参数转单个字符串(多段按空格连接,闭包取原文)
  String unnamedAsString() {
    if (unnamed.isEmpty) return '';
    return unnamed.map(_valueToString).join(' ');
  }

  static String _valueToString(Object? v) {
    if (v is SlashClosureNode) return v.rawText;
    return v?.toString() ?? '';
  }
}

/// 执行上下文:abort 全局传播,break 只断当前闭包/循环体。
class SlashExecContext {
  SlashExecContext([SlashAbortController? controller])
      : abortController = controller ?? SlashAbortController();

  final SlashAbortController abortController;

  /// /break 请求:断掉当前闭包的执行
  bool breakRequested = false;
}

class SlashAbortController {
  bool aborted = false;
  String abortReason = '';

  void abort(String reason) {
    aborted = true;
    abortReason = reason;
  }
}

/// 平台服务桥:命令需要触达宿主能力时经此注入。
/// 由 webview_chat_stage 在注册平台命令时构造。
class SlashEnv {
  SlashEnv({
    this.chatId,
    this.sendMessage,
    this.triggerGeneration,
    this.continueGeneration,
    this.regenerateLast,
    this.setInput,
    this.onUnsupported,
    this.onSetVar,
    this.onDeleteVar,
    this.generateRaw,
    this.showButtons,
  });

  final String? chatId;
  final Future<void> Function(String text)? sendMessage;
  final Future<void> Function()? triggerGeneration;
  final Future<void> Function()? continueGeneration;
  final Future<void> Function()? regenerateLast;
  final void Function(String text)? setInput;
  final void Function(String command)? onUnsupported;

  /// [P6-4] 写单个变量(宿主负责持久化+引擎同步)。
  /// type: 'global' | 'chat';name 空 = 清空整桶(flushvar 语义)。
  final Future<void> Function(
          String type, String name, Object? value,
          {String? index, String? asType})?
      onSetVar;

  /// [P6-4] 删变量(name 空 = 清空整桶)。
  final Future<void> Function(String type, String name)? onDeleteVar;

  /// [P6-4] /genraw 静默生成:发一次请求回文本。
  final Future<String> Function(String prompt)? generateRaw;

  /// [P6-5.1] /buttons 按钮选择弹窗:返回选中项,取消返回 null。
  final Future<String?> Function(List<String> labels)? showButtons;
}

/// 全局命令注册表。key 全小写,查找不区分大小写。
class SlashCommandRegistry {
  static final Map<String, SlashCommand> _commands = {};

  static void register(SlashCommand cmd) {
    _commands[cmd.name.toLowerCase()] = cmd;
    for (final alias in cmd.aliases) {
      _commands[alias.toLowerCase()] = cmd;
    }
  }

  static SlashCommand? get(String name) => _commands[name.toLowerCase()];

  static bool has(String name) => _commands.containsKey(name.toLowerCase());

  static List<String> get names => _commands.keys.toSet().toList();
}
