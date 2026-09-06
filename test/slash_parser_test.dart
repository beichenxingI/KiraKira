import 'package:flutter_test/flutter_test.dart';
import 'package:kirakira/domain/services/slash_command/commands/basic_commands.dart';
import 'package:kirakira/domain/services/slash_command/commands/control_flow_commands.dart';
import 'package:kirakira/domain/services/slash_command/commands/math_commands.dart';
import 'package:kirakira/domain/services/slash_command/commands/variable_commands.dart';
import 'package:kirakira/domain/services/slash_command/slash_ast.dart';
import 'package:kirakira/domain/services/slash_command/slash_command.dart';
import 'package:kirakira/domain/services/slash_command/slash_parser.dart';
import 'package:kirakira/domain/services/slash_command/slash_runner.dart';
import 'package:kirakira/domain/services/variables_service.dart';

/// [P6-3] 斜杠命令解析器/执行器单测。

SlashClosureNode p(String text) => SlashParser(text).parse();

SlashExecutorNode first(String text) => p(text).executorList.first;

/// 测试命令:/add1 — 把无名参数数字 +1 回管道
Future<Object?> add1(SlashArgs args) async {
  final n = int.tryParse(args.unnamedAsString().trim()) ?? 0;
  return n + 1;
}

/// 测试命令:/join — 无名参数用 - 连接
Future<Object?> join(SlashArgs args) async {
  return args.unnamed.map((e) => e is SlashClosureNode ? '<闭包>' : e.toString()).join('-');
}

/// 测试命令:/peek — 报告无名参数形态(类型:内容)
Future<Object?> peek(SlashArgs args) async {
  return args.unnamed
      .map((e) => e is SlashClosureNode ? 'closure' : 'str:${e.toString()}')
      .join('|');
}

void registerTestCommands() {
  if (SlashCommandRegistry.has('add1')) return;
  SlashCommandRegistry.register(const SlashCommand(name: 'add1', callback: add1));
  SlashCommandRegistry.register(const SlashCommand(name: 'join', callback: join));
  SlashCommandRegistry.register(const SlashCommand(name: 'peek', callback: peek));
}

void main() {
  setUp(() {
    registerBasicSlashCommands();
    registerVariableSlashCommands();
    registerControlFlowSlashCommands();
    registerMathSlashCommands();
    registerTestCommands();
  });

  group('SlashParser', () {
    test('单命令+无名参数', () {
      final c = first('/echo hello');
      expect(c.name, 'echo');
      expect(c.unnamedArgumentList.length, 1);
      expect(c.unnamedArgumentList.first.value, 'hello');
    });

    test('多值无名参数整段吞并保留空白', () {
      final c = first('/echo   hello   world  ');
      expect(c.unnamedArgumentList.single.value, 'hello   world');
    });

    test('管道分隔多命令', () {
      final c = p('/echo a | /echo b | /echo c');
      expect(c.executorList.length, 3);
      expect(c.executorList[1].name, 'echo');
      expect(c.executorList[2].unnamedArgumentList.single.value, 'c');
    });

    test('引号内竖线不是分隔符', () {
      final c = first('/echo "a | b"');
      expect(c.unnamedArgumentList.single.value, 'a | b');
    });

    test('转义竖线为字面', () {
      final c = first(r'/echo a \| b');
      expect(c.unnamedArgumentList.single.value, 'a | b');
    });

    test('命名参数', () {
      final c = first('/setvar key=x index=2 1');
      expect(c.namedArgumentList.length, 2);
      expect(c.namedArgumentList[0].name, 'key');
      expect(c.namedArgumentList[0].value, 'x');
      expect(c.namedArgumentList[1].name, 'index');
      expect(c.namedArgumentList[1].value, '2');
      expect(c.unnamedArgumentList.single.value, '1');
    });

    test('闭包参数(延迟执行)', () {
      final c = first('/run {: /echo yes :}');
      final v = c.unnamedArgumentList.single.value;
      expect(v, isA<SlashClosureNode>());
      final cl = v as SlashClosureNode;
      expect(cl.executeNow, false);
      expect(cl.executorList.single.name, 'echo');
    });

    test('闭包 () 立即执行标记', () {
      final c = first('/pass {: /echo x :}()');
      final v = c.unnamedArgumentList.single.value as SlashClosureNode;
      expect(v.executeNow, true);
    });

    test('嵌套闭包', () {
      final c = first('/run {: /run {: /echo deep :} :}');
      final outer = c.unnamedArgumentList.single.value as SlashClosureNode;
      final inner = outer.executorList.single.unnamedArgumentList.single.value;
      expect(inner, isA<SlashClosureNode>());
    });

    test('行注释到管道止', () {
      final c = p('/echo a | // 注释 | /echo b');
      expect(c.executorList.length, 2);
      expect(c.executorList[1].unnamedArgumentList.single.value, 'b');
    });

    test('块注释', () {
      final c = p('/echo a | /* 说明 *| /echo b');
      expect(c.executorList.length, 2);
    });

    test('命名参数值为闭包', () {
      final c = first('/if left=1 rule=eq {: /echo t :}');
      final named = c.namedArgumentList;
      expect(named[0].value, '1');
      expect(named[1].value, 'eq');
      expect(named[1].name, 'rule');
      expect(c.unnamedArgumentList.single.value, isA<SlashClosureNode>());
    });

    test('列表值取原文', () {
      final c = first('/setvar key=arr [1,2,3]');
      expect(c.namedArgumentList.first.value, 'arr');
      expect(c.unnamedArgumentList.single.value, '[1,2,3]');
    });

    test('宏括号内的竖线不切分', () {
      final c = first('/echo {{setvar::a::x|y}}');
      expect(c.unnamedArgumentList.single.value, '{{setvar::a::x|y}}');
    });
  });

  group('SlashRunner', () {
    test('管道传递(injectPipe)', () async {
      final r = await SlashRunner.execute('/pass 5 | /add1');
      expect(r.pipe, '6');
      expect(r.isError, false);
    });

    test('{{pipe}} 宏', () async {
      final r = await SlashRunner.execute('/pass 5 | /echo x{{pipe}}y');
      expect(r.pipe, 'x5y');
    });

    test('|| 抑制 pipe 注入', () async {
      final r = await SlashRunner.execute('/pass 5 || /add1');
      // 无参无注入 → add1 收空串 → 0+1
      expect(r.pipe, '1');
    });

    test('未知命令报错不抛异常', () async {
      final r = await SlashRunner.execute('/nope_xxx');
      expect(r.isError, true);
      expect(r.errorMessage, contains('nope_xxx'));
    });

    test('abort 中断后续命令', () async {
      final r = await SlashRunner.execute('/abort | /add1 9');
      expect(r.isAborted, true);
      expect(r.pipe, '');
    });

    test('多值连接(非split闭包混排)', () async {
      final r = await SlashRunner.execute('/join a {: /echo x :} b');
      // ST 语义:闭包周边的空格保留在字符串段里(首段 trimStart/尾段 trimEnd 不动中间)
      expect(r.pipe, 'a -<闭包>- b');
    });

    test('立即执行闭包 ()', () async {
      final r = await SlashRunner.execute('/pass {: /echo inner :}() | /add1');
      // 闭包立即执行 → 'inner' → add1 解析失败回 0+1
      expect(r.pipe, '1');
    });

    test('split命令的闭包数组传参', () async {
      SlashCommandRegistry.register(SlashCommand(name: 'closetest',
          splitUnnamedArgument: true,
          callback: (args) async {
            return args.unnamed
                .map((e) => e is SlashClosureNode ? 'C' : e.toString())
                .join(',');
          }));
      final r = await SlashRunner.execute('/closetest 5 {: /echo x :} end');
      expect(r.pipe, '5,C,end');
    });

    test('域内变量 {{var::}}', () async {
      SlashCommandRegistry.register(SlashCommand(name: 'setx',
          callback: (args) async {
        args.scope.letVariable('x', 42);
        return '';
      }));
      final r = await SlashRunner.execute('/setx | /echo {{var::x}}');
      expect(r.pipe, '42');
    });

    test('闭包沿父链读变量', () async {
      SlashCommandRegistry.register(SlashCommand(name: 'sety',
          callback: (args) async {
        args.scope.letVariable('y', 'outer');
        return '';
      }));
      SlashCommandRegistry.register(SlashCommand(name: 'runraw',
          callback: (args) async {
        final cl = args.unnamed.first as SlashClosureNode;
        final r = await SlashRunner.executeClosure(cl, parentScope: args.scope);
        return r.pipe;
      }));
      final r = await SlashRunner.execute(
          '/sety | /runraw {: /echo s{{var::y}}e :}');
      expect(r.pipe, 'soutere');
    });
  });

  group('P6-4 变量命令', () {
    setUp(() {
      // /setvar 落点直写 service 内存(测试无 SP)
      if (!SlashCommandRegistry.has('__vartest_env')) {
        SlashCommandRegistry.register(SlashCommand(name: '__vartest_env',
            callback: (args) async => ''));
      }
    });

    SlashEnv vartestEnv() => SlashEnv(chatId: 't', onSetVar:
        (type, name, value, {index, asType}) async {
      VariablesService.instance.setLocalVariable('t', name, value,
          index: index, asType: asType);
    }, onDeleteVar: (type, name) async {
      if (name.isEmpty) {
        VariablesService.instance.clearLocalVariables('t');
      } else {
        VariablesService.instance.deleteLocalVariable('t', name);
      }
    });

    test('setvar/getvar 读写往返', () async {
      await SlashRunner.execute('/setvar key=hp 100',
          env: vartestEnv());
      final r = await SlashRunner.execute('/getvar hp', env: vartestEnv());
      expect(r.pipe, '100');
    });

    test('getvar 缺失返回空串', () async {
      final r = await SlashRunner.execute('/getvar nope', env: vartestEnv());
      expect(r.pipe, '');
    });

    test('setvar 整句值(含空格)', () async {
      await SlashRunner.execute('/setvar key=msg hello world',
          env: vartestEnv());
      final r = await SlashRunner.execute('/getvar msg', env: vartestEnv());
      expect(r.pipe, 'hello world');
    });

    test('setvar index 列表写入', () async {
      await SlashRunner.execute('/setvar key=arr index=0 a',
          env: vartestEnv());
      final r = await SlashRunner.execute('/getvar key=arr index=0',
          env: vartestEnv());
      expect(r.pipe, 'a');
    });

    test('incvar/decvar', () async {
      await SlashRunner.execute('/setvar key=n 5', env: vartestEnv());
      final r = await SlashRunner.execute('/incvar n', env: vartestEnv());
      expect(r.pipe, '6');
      final r2 = await SlashRunner.execute('/decvar n', env: vartestEnv());
      expect(r2.pipe, '5');
    });

    test('flushvar 删除', () async {
      await SlashRunner.execute('/setvar key=gone 1', env: vartestEnv());
      await SlashRunner.execute('/flushvar gone', env: vartestEnv());
      final r = await SlashRunner.execute('/getvar gone', env: vartestEnv());
      expect(r.pipe, '');
    });
  });

  group('P6-4 控制流命令', () {
    test('if 数值比较 then 分支', () async {
      final r = await SlashRunner.execute(
          '/if left=5 rule=gt right=3 {: /echo big :} {: /echo small :}');
      expect(r.pipe, 'big');
    });

    test('if else 分支(双闭包写法)', () async {
      final r = await SlashRunner.execute(
          '/if left=1 rule=gt right=3 {: /echo big :} {: /echo small :}');
      expect(r.pipe, 'small');
    });

    test('if 字符串比较大小写不敏感', () async {
      final r = await SlashRunner.execute(
          '/if left=AbC rule=eq right=aBc {: /echo same :}');
      expect(r.pipe, 'same');
    });

    test('if in 规则', () async {
      final r = await SlashRunner.execute(
          '/if left="hello world" rule=in right=wor {: /echo hit :}');
      expect(r.pipe, 'hit');
    });

    test('while 循环+变量重读', () async {
      final r = await SlashRunner.execute(
          '/let i 3 | /while left=i rule=gt right=0 {: /var i 0 :}');
      // 第一轮 i=3>0 → 体把 i 置 0 → 第二轮条件假 → 出循环,返回体 pipe '0'
      expect(r.pipe, '0');
    });

    test('times 计次+timesIndex', () async {
      final r = await SlashRunner.execute('/times 3 {: /echo i{{timesIndex}} :}');
      expect(r.pipe, 'i2');
    });

    test('let 在闭包内是局部(不污染外层)', () async {
      final r = await SlashRunner.execute(
          '/let x 1 | /run {: /let x 2 :} | /echo {{var::x}}');
      expect(r.pipe, '1');
    });

    test('var 沿父链写(闭包内外层可见)', () async {
      final r = await SlashRunner.execute(
          '/let x 1 | /run {: /var x 2 :} | /echo {{var::x}}');
      expect(r.pipe, '2');
    });

    test('run 子脚本字符串', () async {
      final r = await SlashRunner.execute('/run "/echo inner |"');
      expect(r.pipe, 'inner');
    });
  });

  group('P6-4 数学命令', () {
    test('add 多值求和', () async {
      final r = await SlashRunner.execute('/add 1 2 3');
      expect(r.pipe, '6');
    });

    test('add 经 pipe 引用', () async {
      final r = await SlashRunner.execute('/pass 5 | /add {{pipe}} 3');
      expect(r.pipe, '8');
    });

    test('sub/mul/div/mod', () async {
      expect((await SlashRunner.execute('/sub 10 4')).pipe, '6');
      expect((await SlashRunner.execute('/mul 3 4')).pipe, '12');
      expect((await SlashRunner.execute('/div 10 4')).pipe, '2.5');
      expect((await SlashRunner.execute('/div 10 0')).pipe, '');
      expect((await SlashRunner.execute('/mod 10 3')).pipe, '1');
    });

    test('max/min/abs/round', () async {
      expect((await SlashRunner.execute('/max 2 9')).pipe, '9');
      expect((await SlashRunner.execute('/min 2 9')).pipe, '2');
      expect((await SlashRunner.execute('/abs -5')).pipe, '5');
      expect((await SlashRunner.execute('/round 3.6')).pipe, '4');
    });

    test('len 字符串/列表', () async {
      expect((await SlashRunner.execute('/len hello')).pipe, '5');
      expect((await SlashRunner.execute('/len [1,2,3]')).pipe, '3');
    });

    test('rand 范围内', () async {
      final r = await SlashRunner.execute('/rand from=1 to=5 round=floor');
      final v = int.tryParse(r.pipe) ?? -1;
      expect(v, inInclusiveRange(1, 4)); // floor 后上限内
    });

    test('数学命令用变量名取值', () async {
      final r = await SlashRunner.execute('/let a 7 | /add a 3');
      expect(r.pipe, '10');
    });
  });
}
