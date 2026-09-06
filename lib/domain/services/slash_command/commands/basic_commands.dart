/// [P6-3] 基础命令:输出/管道控制。语义对齐 ST variables.js / slash-commands.js。
///
/// - /echo   : 输出到管道(ST 语义:显示 toast,平台简化为纯管道透传)
/// - /pass   : 原样透传
/// - /return : 返回值并断当前闭包执行
/// - /abort  : 中止整条脚本
/// - /break  : 断当前循环/闭包
library;

import '../slash_command.dart';

export '../slash_runner.dart' show SlashResult, SlashRunner, SlashMacroResolver;

/// 注册基础命令(幂等,可重复调用)。
void registerBasicSlashCommands() {
  SlashCommandRegistry.register(SlashCommand(
    name: 'echo',
    aliases: ['e'],
    callback: (args) async {
      // ST 的 /echo 弹 toast;平台无 toast 通道时保持管道语义
      return args.unnamedAsString();
    },
  ));

  SlashCommandRegistry.register(SlashCommand(
    name: 'pass',
    callback: (args) async {
      // 有参透传参数,无参透传 pipe(解析层 injectPipe 已注入)
      return args.unnamedAsString();
    },
  ));

  SlashCommandRegistry.register(SlashCommand(
    name: 'return',
    callback: (args) async {
      args.ctx.breakRequested = true;
      if (args.hasUnnamedArg) {
        final v = args.unnamedAsString();
        args.scope.pipe = v;
        return v;
      }
      return args.scope.pipe;
    },
  ));

  SlashCommandRegistry.register(SlashCommand(
    name: 'abort',
    callback: (args) async {
      args.ctx.abortController
          .abort(args.hasUnnamedArg ? args.unnamedAsString() : 'aborted');
      return '';
    },
  ));

  SlashCommandRegistry.register(SlashCommand(
    name: 'break',
    callback: (args) async {
      args.ctx.breakRequested = true;
      if (args.hasUnnamedArg) {
        final v = args.unnamedAsString();
        args.scope.pipe = v;
        return v;
      }
      return args.scope.pipe;
    },
  ));
}
