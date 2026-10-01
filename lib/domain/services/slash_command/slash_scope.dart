/// Closure scope: a stack of variable scopes supporting /let, /var and nested closures.
/// Semantics match ST SlashCommandScope:
/// - letVariable: defines in the current scope (overwrites silently; ST throws)
/// - setVariable: walks the parent chain to the defining scope and updates it;
///   falls back to the chain root if not found
/// - getVariable: walks the parent chain; returns an empty string if not found
class SlashScope {
  SlashScope({this.parent});

  SlashScope? parent;

  /// Pipe value (output of the previous command)
  Object? pipe;

  /// Closure-local variables
  final Map<String, Object?> variables = {};

  /// Scope-local macros (e.g. {{timesIndex}} from /times)
  final Map<String, Object?> macros = {};

  bool existsInScope(String key) => variables.containsKey(key);

  bool existsVariable(String key) =>
      existsInScope(key) || (parent?.existsVariable(key) ?? false);

  void letVariable(String key, [Object? value]) {
    variables[key] = value;
  }

  Object? setVariable(String key, Object? value) {
    if (existsInScope(key)) {
      variables[key] = value;
      return value;
    }
    if (parent != null) return parent!.setVariable(key, value);
    // Not found on the chain: fall back to defining at the chain root (ST throws VariableNotFound)
    SlashScope root = this;
    while (root.parent != null) {
      root = root.parent!;
    }
    root.variables[key] = value;
    return value;
  }

  Object? getVariable(String key) {
    if (existsInScope(key)) return variables[key];
    if (parent != null) return parent!.getVariable(key);
    return '';
  }

  Object? getMacro(String key) {
    if (macros.containsKey(key)) return macros[key];
    if (parent != null) return parent!.getMacro(key);
    return null;
  }

  void setMacro(String key, Object? value) {
    macros[key] = value;
  }
}
