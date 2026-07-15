class ModelFamilyProfile {
  final String name;
  final Map<String, double> featureScores;
  final List<String> keyIndicators;

  const ModelFamilyProfile({required this.name, required this.featureScores, this.keyIndicators = const []});
}

class ModelFamilyProfiles {
  static const deepseek = ModelFamilyProfile(name: 'DeepSeek', featureScores: {
    'math': 0.90, 'logic': 0.85, 'code': 0.88, 'chinese': 0.95,
    'creative': 0.65, 'cross_cultural': 0.82, 'humanities': 0.78, 'roleplay': 0.70,
  }, keyIndicators: [
    '中文长推理高质量', 'CoT链完整', 'R1系列有<think>标签',
    '数学竞赛级表现', '代码生成质量高', '中英双语无明显落差',
    '回答风格偏工整', '创意写作相对较弱',
  ]);

  static const openai = ModelFamilyProfile(name: 'OpenAI', featureScores: {
    'math': 0.82, 'logic': 0.80, 'code': 0.85, 'chinese': 0.70,
    'creative': 0.88, 'cross_cultural': 0.85, 'humanities': 0.90, 'roleplay': 0.85,
  }, keyIndicators: [
    '指令遵循精确', '英文写作质量高', '商业文案和结构化输出强',
    '中文有翻译腔', '拒绝措辞固定(I cannot...)', '过度自信偏差',
    'o1/o1-mini输出前明显延迟且不输出中间推理',
  ]);

  static const claude = ModelFamilyProfile(name: 'Claude', featureScores: {
    'math': 0.80, 'logic': 0.85, 'code': 0.87, 'chinese': 0.65,
    'creative': 0.90, 'cross_cultural': 0.82, 'humanities': 0.92, 'roleplay': 0.88,
  }, keyIndicators: [
    '长文本处理能力强', '创意写作有文学感', '代码注释详细',
    '中文弱于原生中文模型', '几乎不用感叹号',
    '争议时给出多角度分析', '细致指令遵循',
  ]);

  static const qwen = ModelFamilyProfile(name: 'Qwen', featureScores: {
    'math': 0.85, 'logic': 0.82, 'code': 0.86, 'chinese': 0.93,
    'creative': 0.72, 'cross_cultural': 0.80, 'humanities': 0.76, 'roleplay': 0.75,
  }, keyIndicators: [
    '中文和DeepSeek一样强', '比DeepSeek更话多', '倾向给背景知识',
    '代码强', '中国本土知识细节丰富', 'Qwen2.5-72B与DeepSeek-V3最难区分',
  ]);

  static const gemini = ModelFamilyProfile(name: 'Gemini', featureScores: {
    'math': 0.75, 'logic': 0.78, 'code': 0.75, 'chinese': 0.55,
    'creative': 0.78, 'cross_cultural': 0.85, 'humanities': 0.82, 'roleplay': 0.75,
  }, keyIndicators: [
    '大量使用Markdown标题和列表', '实时知识更新及时(接入搜索)',
    '中文质量不稳定', '多模态强(当前检测无法触及)',
  ]);

  static const llama = ModelFamilyProfile(name: 'Llama', featureScores: {
    'math': 0.70, 'logic': 0.72, 'code': 0.68, 'chinese': 0.40,
    'creative': 0.72, 'cross_cultural': 0.55, 'humanities': 0.75, 'roleplay': 0.70,
  }, keyIndicators: [
    '中文夹杂英文比例高', '输出风格偏学院派',
    '教科书式答案', '安全过滤弱',
  ]);

  static const mistral = ModelFamilyProfile(name: 'Mistral', featureScores: {
    'math': 0.75, 'logic': 0.75, 'code': 0.78, 'chinese': 0.35,
    'creative': 0.75, 'cross_cultural': 0.60, 'humanities': 0.75, 'roleplay': 0.72,
  }, keyIndicators: [
    '法语等欧洲语言强', '中文弱', '回答风格简洁', '拒绝频率低',
  ]);

  static const all = [deepseek, openai, claude, qwen, gemini, llama, mistral];
}
