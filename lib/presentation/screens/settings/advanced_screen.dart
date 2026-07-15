import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';

class AdvancedScreen extends StatelessWidget {
  const AdvancedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('高级模式')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _section(context, Icons.tune, 'API 高级配置', '温度、Top P、Logit偏置、Logprobs', '/advanced-settings'),
        _section(context, Icons.auto_awesome, '预设与模板', 'AI预设、提示词管理', '/ai-presets', extra: _extraTile(context, '提示词管理', '/prompt-manager')),
        _section(context, Icons.code, '正则系统', '全局正则、角色正则', '/regex-settings'),
        _section(context, Icons.storage, '向量存储（RAG）', '向量存储、自动总结', '/vector-storage-settings'),
        _section(context, Icons.multitrack_audio, '多媒体', 'TTS语音、STT识别、图像生成', '/tts-settings'),
        _section(context, Icons.emoji_emotions, '精灵图', '表情精灵图设置', '/sprite-settings'),
        _section(context, Icons.data_object, '变量与分词器', '变量管理、分词器', '/variables-settings'),
        _section(context, Icons.analytics, '日志与统计', '日志查看、性能统计', '/statistics'),
      ]),
    );
  }

  Widget _section(BuildContext context, IconData icon, String title, String desc, String route, {Widget? extra}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        ListTile(
          leading: Icon(icon, color: AppTheme.primaryColor),
          title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
          subtitle: Text(desc, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          onTap: () => context.push(route),
        ),
        if (extra != null) extra,
      ]),
    );
  }

  Widget _extraTile(BuildContext context, String label, String route) {
    return ListTile(
      leading: const Icon(Icons.notes, color: AppTheme.primaryColor, size: 20),
      title: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
      onTap: () => context.push(route),
      dense: true,
    );
  }
}
