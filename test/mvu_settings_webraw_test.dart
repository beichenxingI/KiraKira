import 'package:flutter_test/flutter_test.dart';
import 'package:kirakira/data/models/mvu_settings.dart';

/// [P6-BUG-1] MvuSettings.webRaw 透传往返:internal 已提醒标志不丢。
void main() {
  test('webRaw 序列化往返保留 MVU 自有段', () {
    const webRaw = {
      '更新方式': '随AI输出',
      '通知': {
        'MVU框架加载成功': true,
        '变量初始化成功': true,
        '变量更新出错': false,
        '额外模型解析中': true,
      },
      '额外模型解析配置': {
        '破限方案': '使用内置破限',
        '启用自动请求': true,
        'max_chat_history': 10,
        '模型来源': '自定义',
        'api地址': 'https://x.example',
        '密钥': 'sk-test',
        '模型名称': 'm1',
        '温度': 0.7, // MVU 自有键,平台模型无此字段
      },
      'internal': {
        '已提醒更新了配置界面': true,
        '已提醒自动清理旧变量功能': true,
        '已默认开启自动清理旧变量功能': true,
      },
      '自动清理变量': {'启用': true, '快照保留间隔': 50},
    };

    final s = const MvuSettings().copyWith(webRaw: webRaw);
    final json = s.toJson();
    expect(json['webRaw'], isNotNull);

    final restored = MvuSettings.fromJson(json);
    expect(restored.webRaw, isNotNull);
    expect(restored.webRaw!.length, webRaw.length);
    final internal = restored.webRaw!['internal'] as Map;
    expect(internal['已提醒自动清理旧变量功能'], true);
    expect(
        (restored.webRaw!['自动清理变量'] as Map)['启用'], true);
    // 已知字段不受影响
    expect(restored.updateMode, '随AI输出');
  });

  test('webRaw 为空时不写入 json(兼容旧存档)', () {
    final json = const MvuSettings().toJson();
    expect(json.containsKey('webRaw'), false);
    final restored = MvuSettings.fromJson(json);
    expect(restored.webRaw, isEmpty);
  });
}
