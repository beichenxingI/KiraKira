// P5-4 验证:生成门面 JS 并落盘,交给 node --check 做语法验证。
import 'dart:io';
import 'package:kirakira/data/models/mvu_settings.dart';
import 'package:kirakira/presentation/screens/chat/tavern_helper_facade.dart';

void main() {
  final js = buildTavernHelperFacadeJs(frameId: 'engine-room', mvu: const MvuSettings());
  final out = File(r'C:\Users\wangyi\AppData\Local\Temp\opencode\facade_out.js');
  out.writeAsStringSync(js, flush: true);
  stdout.writeln('OK len=${js.length} path=${out.path}');
}
