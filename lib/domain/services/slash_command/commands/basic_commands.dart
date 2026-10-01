/// Basic commands: output/pipe control. Semantics match ST variables.js / slash-commands.js.
///
/// - /echo   : output to the pipe (ST semantics: show a toast; the platform simplifies this to plain pipe passthrough)
/// - /pass   : pass through as-is
/// - /return : return a value and stop the current closure
/// - /abort  : abort the whole script
/// - /break  : stop the current loop/closure
library;

import '../slash_command.dart';

export '../slash_runner.dart' show SlashResult, SlashRunner, SlashMacroResolver;

/// Registers basic commands (idempotent, safe to call repeatedly).
void registerBasicSlashCommands() {
  SlashCommandRegistry.register(SlashCommand(
    name: 'echo',
    aliases: ['e'],
    callback: (args) async {
      // ST's /echo shows a toast; the platform keeps pipe semantics when there is no toast channel
      return args.unnamedAsString();
    },
  ));

  SlashCommandRegistry.register(SlashCommand(
    name: 'pass',
    callback: (args) async {
      // Passes arguments when given, otherwise passes the pipe through (parser-level injectPipe already injected)
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
