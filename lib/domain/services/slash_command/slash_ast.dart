/// Slash command AST nodes.
/// Semantics match SillyTavern SlashCommandParser output:
/// root closure = formal parameter list + executor list; an executor is a
/// command name plus named/unnamed argument assignments; closures `{: ... :}`
/// are first-class citizens usable as lazily-executed argument values.
library;

/// Argument assignment (shared by named/unnamed arguments).
/// [value] is a String or [SlashClosureNode] (closure argument, lazily executed).
class SlashArgAssignment {
  SlashArgAssignment({
    this.name = '',
    required this.value,
    this.wasQuoted = false,
  });

  /// Named argument name; empty string for unnamed arguments
  final String name;

  /// String | SlashClosureNode
  final Object value;

  /// Whether the value came from a quoted string (affects trimming etc.)
  final bool wasQuoted;

  bool get isClosure => value is SlashClosureNode;
}

/// Closure node `{: ... :}` — contains another complete script.
class SlashClosureNode {
  /// Formal parameters `{: a, b :}`; incoming values are bound by position at execution
  final List<SlashArgAssignment> argumentList = [];

  /// Executor list (pipe-separated command sequence)
  final List<SlashExecutorNode> executorList = [];

  /// Raw text (for closure-serialize / debugging)
  String rawText = '';

  /// `{: ... :}()` — executes immediately when parsed as an argument
  bool executeNow = false;
}

/// A single command.
class SlashExecutorNode {
  SlashExecutorNode({required this.name, required this.start});

  /// Command name (without the slash)
  String name;

  /// Named arguments
  final List<SlashArgAssignment> namedArgumentList = [];

  /// Unnamed arguments (may contain closures)
  final List<SlashArgAssignment> unnamedArgumentList = [];

  /// Whether the previous command's output is injected as this command's
  /// unnamed argument (ST injectPipe; `||` suppresses it)
  bool injectPipe = true;

  final int start;
  int end = 0;
}
