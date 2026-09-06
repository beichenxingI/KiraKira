/// [P6-3] 闭包作用域:栈式变量域,支撑 /let /var 与闭包嵌套。
/// 语义对齐 ST SlashCommandScope:
/// - letVariable: 在当前域定义(已存在则容忍覆盖,ST 会抛错)
/// - setVariable: 沿父链找到定义域并更新;找不到则落到链根(容错)
/// - getVariable: 沿父链查找;找不到返回空串(容错)
class SlashScope {
  SlashScope({this.parent});

  SlashScope? parent;

  /// 管道值(上一命令的输出)
  Object? pipe;

  /// 闭包局部变量
  final Map<String, Object?> variables = {};

  /// 域内宏(如 /times 的 {{timesIndex}})
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
    // 链上没有:落到链根定义(容错;ST 抛 VariableNotFound)
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
