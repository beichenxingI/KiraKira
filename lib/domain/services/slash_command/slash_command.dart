/// Slash commands and the command registry.
/// Command callbacks receive [SlashArgs]; the return value becomes the pipe
/// output (ST's callback(args, value) to pipe).
library;

import 'slash_ast.dart';
import 'slash_scope.dart';

/// Command callback signature. Return value: any object; the runner stringifies it into the pipe.
typedef SlashCommandCallback = Future<Object?> Function(SlashArgs args);

/// Command definition.
class SlashCommand {
  const SlashCommand({
    required this.name,
    required this.callback,
    this.aliases = const [],
    this.splitUnnamedArgument = false,
    this.splitUnnamedArgumentCount,
  });

  /// Command name (without the slash)
  final String name;

  /// Aliases (also registered for lookup)
  final List<String> aliases;

  final SlashCommandCallback callback;

  /// Whether unnamed arguments are passed to the callback as a list of values
  /// (/if /while /times /let /var are true)
  final bool splitUnnamedArgument;

  /// Used with splitUnnamedArgument: the first N values stand alone, the rest are merged into one
  final int? splitUnnamedArgumentCount;
}

/// Argument bundle passed to command callbacks.
class SlashArgs {
  SlashArgs({
    required this.scope,
    required this.ctx,
    this.env,
  });

  /// Named arguments (key to value; value is a String or SlashClosureNode)
  final Map<String, Object?> named = {};

  /// Unnamed argument list (String | SlashClosureNode)
  List<Object?> unnamed = [];

  /// Current scope
  final SlashScope scope;

  /// Execution context (abort/break)
  final SlashExecContext ctx;

  /// Platform service bridge (send/generation etc.), injected by the host; may be null for pure logic commands
  final SlashEnv? env;

  /// Whether there is an actual unnamed argument (including injected pipe)
  bool hasUnnamedArg = false;

  // Convenience accessors

  String? namedString(String name) {
    final v = named[name];
    if (v == null) return null;
    if (v is SlashClosureNode) return null;
    return v.toString();
  }

  String namedStringOr(String name, String fallback) =>
      namedString(name) ?? fallback;

  /// Unnamed arguments as a single string (parts joined by spaces, closures use raw text)
  String unnamedAsString() {
    if (unnamed.isEmpty) return '';
    return unnamed.map(_valueToString).join(' ');
  }

  static String _valueToString(Object? v) {
    if (v is SlashClosureNode) return v.rawText;
    return v?.toString() ?? '';
  }
}

/// Execution context: abort propagates globally, break only stops the current closure/loop body.
class SlashExecContext {
  SlashExecContext([SlashAbortController? controller])
      : abortController = controller ?? SlashAbortController();

  final SlashAbortController abortController;

  /// /break request: stops execution of the current closure
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

/// Platform service bridge: injected when a command needs to reach host capabilities.
/// Constructed by webview_chat_stage when registering platform commands.
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
    this.messageCount,
    this.setMessageHidden,
    this.swipeTo,
  });

  final String? chatId;
  final Future<void> Function(String text)? sendMessage;
  final Future<void> Function()? triggerGeneration;
  final Future<void> Function()? continueGeneration;
  final Future<void> Function()? regenerateLast;
  final void Function(String text)? setInput;
  final void Function(String command)? onUnsupported;

  /// Writes a single variable (the host handles persistence and engine sync).
  /// type: 'global' | 'chat'; empty name clears the whole bucket (flushvar semantics).
  final Future<void> Function(
          String type, String name, Object? value,
          {String? index, String? asType})?
      onSetVar;

  /// Deletes a variable (empty name clears the whole bucket).
  final Future<void> Function(String type, String name)? onDeleteVar;

  /// /genraw silent generation: sends one request and returns the text.
  final Future<String> Function(String prompt)? generateRaw;

  /// /buttons selection dialog: returns the selected item, or null on cancel.
  final Future<String?> Function(List<String> labels)? showButtons;

  /// Message operations: message count / hide & show / swipe switching
  final int Function()? messageCount;
  final Future<void> Function(int index, bool hidden)? setMessageHidden;
  final Future<void> Function(int index, int swipeIndex)? swipeTo;
}

/// Global command registry. Keys are lowercase; lookups are case-insensitive.
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
