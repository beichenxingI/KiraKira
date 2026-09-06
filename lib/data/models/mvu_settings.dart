import 'dart:convert';

/// MVU 额外模型解析的内置默认 task 提示词。
/// 用户可在设置里自定义;自定义内容风险由使用者自负。
const String kDefaultMvuTask = r'''你是变量更新引擎。请停止角色扮演，以客观的旁白视角工作。

根据 <past_observe> 中的最新剧情，以及下方"更新前变量状态"，
分析剧情发生后哪些变量变化了，输出更新命令。
注意：给出的是剧情【之前】的状态，你要算出【之后】的新值。

## 当前变量结构（重要，路径必须和这个一致）
络络.好感度       (数值)
络络.背包         (数组，可包含多个物品字符串)
更多角色变量同理，都在顶层，如 角色名.属性名

## 命令说明（按场景选对命令，用错会导致写入失败）
1. _.set('路径', 新值)           修改一个【已存在】的变量。路径必须在当前状态中存在，否则会被跳过。
2. _.add('路径', 增量)           在【已存在的数值】上做加减。如 _.add('络络.好感度', 5) 表示好感+5。
3. _.insert('路径', 元素)        往【数组】里新增一个元素。如 _.insert('络络.背包', '花')。
4. _.insert('父路径', '新键', 值) 给【对象】新增一个不存在的键。如新角色首次出现时用。

## 选择规则（关键）
- 改已有变量的值 → 用 _.set (前提：这个变量在"更新前状态"里已经存在)
- 数值增减 → 用 _.add (更贴合剧情，如好感、时间)
- 数组加元素 → 用 _.insert(数组路径, 元素)
- 状态里【没有】这个变量、要新建 → 用 _.insert(父路径, '新键', 值)，不能用 _.set

特别注意：如果"更新前状态"为空或某个变量不存在，只能用 _.insert 建立，不能用 _.set。

## 输出格式
只输出一个 <UpdateVariable> 块，每行一条命令：
_.命令('路径', 参数); // 变化原因
- 路径用点分隔，如 络络.好感度
- 数值不加引号，字符串用单引号
- 只输出确实变化的变量
- 无变化则输出空的 <UpdateVariable></UpdateVariable>
- 块外不要任何解释

## 示例
更新前状态：{ "络络": { "好感度": 40, "背包": ["旧钥匙"] } }
剧情：络络收到主角送的花很开心，把花放进背包，两人去了天台，还认识了新角色小satori。
输出：
<UpdateVariable>
_.add('络络.好感度', 5); // 收到礼物，好感提升
_.insert('络络.背包', '花'); // 花放进背包
_.insert('小satori', { "好感度": 30, "背包": [] }); // 认识新角色，建立变量
</UpdateVariable>''';

/// MVU 变量框架配置。
///
/// 对应注入 WebView 的 extensionSettings.mvu_settings.额外模型解析配置。
/// 字段与 mvu_bundle.js 的 zod schema 对齐,新增 maxChatHistory(原本走默认2)。
class MvuSettings {
  /// 更新方式:"额外模型解析" / "随AI输出"
  final String updateMode;

  /// 聊天历史条数(额外模型能看到的最近消息数)。范围 2-100,默认 10。
  final int maxChatHistory;

  /// 模型来源:"自定义" 等
  final String modelSource;

  /// 破限方案
  final String jailbreakScheme;

  /// 是否启用自动请求
  final bool autoRequest;

  /// 自定义 API 地址(非敏感)
  final String apiUrl;

  /// API 密钥(敏感,仅存本地 DB,不写入源码)
  final String apiKey;

  /// 模型名称
  final String modelName;

  /// 是否启用自定义 task 提示词(默认关,用内置安全版)
  final bool customPromptEnabled;

  /// 自定义 task 提示词内容(默认 = 内置安全版)
  final String customPrompt;

  // ── [P5-8/P1] 通知四键 ──────────────────────────────────────────
  // 对应 extensionSettings.mvu_settings.通知 的四个中文键,
  // 默认值与 mvu_bundle.js 出厂 zod schema 对齐(:2988-2993)。
  // 道渊报警1要求四键全真;出厂默认"变量更新出错"=false,用户可在道渊面板打开。

  /// MVU框架加载成功通知(出厂默认 true)
  final bool notifyFrameworkLoaded;

  /// 变量初始化成功通知(出厂默认 true)
  final bool notifyInitSuccess;

  /// 变量更新出错通知(出厂默认 false)
  final bool notifyVarError;

  /// 额外模型解析中通知(出厂默认 true)
  final bool notifyExtraParsing;

  /// [P6-BUG-1] web 侧写回的 mvu_settings 原始对象(中文键,MVU 自有 schema 形状)。
  ///
  /// MVU 的 Pinia store 把整份设置(含 internal 已提醒标志/自动清理变量/兼容性等)
  /// 写回 extensionSettings.mvu_settings;平台此前只提取已知三段落盘,
  /// internal 标志丢失 → 每次进聊天页 MVU 的"一次性升级提醒"全部重弹。
  /// 这里原样透传保存,烘焙时以 webRaw 为底、平台已知值覆盖,让 MVU 的
  /// 只提醒一次机制自然生效。为空(首次)时行为同旧版。
  final Map<String, dynamic> webRaw;

  const MvuSettings({
    this.updateMode = '随AI输出',
    this.maxChatHistory = 10,
    this.modelSource = '自定义',
    this.jailbreakScheme = '使用内置破限',
    this.autoRequest = false,
    this.apiUrl = 'https://api.deepseek.com',
    this.apiKey = '',
    this.modelName = 'deepseek-chat',
    this.customPromptEnabled = false,
    this.customPrompt = kDefaultMvuTask,
    this.notifyFrameworkLoaded = true,
    this.notifyInitSuccess = true,
    this.notifyVarError = false,
    this.notifyExtraParsing = true,
    this.webRaw = const {},
  });

  MvuSettings copyWith({
    String? updateMode,
    int? maxChatHistory,
    String? modelSource,
    String? jailbreakScheme,
    bool? autoRequest,
    String? apiUrl,
    String? apiKey,
    String? modelName,
    bool? customPromptEnabled,
    String? customPrompt,
    bool? notifyFrameworkLoaded,
    bool? notifyInitSuccess,
    bool? notifyVarError,
    bool? notifyExtraParsing,
    Map<String, dynamic>? webRaw,
  }) {
    return MvuSettings(
      updateMode: updateMode ?? this.updateMode,
      maxChatHistory: maxChatHistory ?? this.maxChatHistory,
      modelSource: modelSource ?? this.modelSource,
      jailbreakScheme: jailbreakScheme ?? this.jailbreakScheme,
      autoRequest: autoRequest ?? this.autoRequest,
      apiUrl: apiUrl ?? this.apiUrl,
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
      customPromptEnabled: customPromptEnabled ?? this.customPromptEnabled,
      customPrompt: customPrompt ?? this.customPrompt,
      notifyFrameworkLoaded: notifyFrameworkLoaded ?? this.notifyFrameworkLoaded,
      notifyInitSuccess: notifyInitSuccess ?? this.notifyInitSuccess,
      notifyVarError: notifyVarError ?? this.notifyVarError,
      notifyExtraParsing: notifyExtraParsing ?? this.notifyExtraParsing,
      webRaw: webRaw ?? this.webRaw,
    );
  }

  Map<String, dynamic> toJson() => {
        'updateMode': updateMode,
        'maxChatHistory': maxChatHistory,
        'modelSource': modelSource,
        'jailbreakScheme': jailbreakScheme,
        'autoRequest': autoRequest,
        'apiUrl': apiUrl,
        'apiKey': apiKey,
        'modelName': modelName,
        'customPromptEnabled': customPromptEnabled,
        'customPrompt': customPrompt,
        'notifyFrameworkLoaded': notifyFrameworkLoaded,
        'notifyInitSuccess': notifyInitSuccess,
        'notifyVarError': notifyVarError,
        'notifyExtraParsing': notifyExtraParsing,
        if (webRaw.isNotEmpty) 'webRaw': webRaw,
      };

  factory MvuSettings.fromJson(Map<String, dynamic> json) {
    // maxChatHistory 收敛到 mvu 的合法范围 2-100
    final rawHistory = (json['maxChatHistory'] as num?)?.toInt() ?? 10;
    final clampedHistory = rawHistory.clamp(2, 100);
    return MvuSettings(
      updateMode: json['updateMode'] as String? ?? '随AI输出',
      maxChatHistory: clampedHistory,
      modelSource: json['modelSource'] as String? ?? '自定义',
      jailbreakScheme: json['jailbreakScheme'] as String? ?? '使用内置破限',
      autoRequest: json['autoRequest'] as bool? ?? false,
      apiUrl: json['apiUrl'] as String? ?? 'https://api.deepseek.com',
      apiKey: json['apiKey'] as String? ?? '',
      modelName: json['modelName'] as String? ?? 'deepseek-chat',
      customPromptEnabled: json['customPromptEnabled'] as bool? ?? false,
      customPrompt: json['customPrompt'] as String? ?? kDefaultMvuTask,
      // [P5-8/P1] 通知四键,旧数据缺省时按 MVU 出厂默认回填(true,true,false,true)
      notifyFrameworkLoaded: json['notifyFrameworkLoaded'] as bool? ?? true,
      notifyInitSuccess: json['notifyInitSuccess'] as bool? ?? true,
      notifyVarError: json['notifyVarError'] as bool? ?? false,
      notifyExtraParsing: json['notifyExtraParsing'] as bool? ?? true,
      webRaw: (json['webRaw'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
 }