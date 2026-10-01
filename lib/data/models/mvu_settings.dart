
/// Built-in default task prompt for MVU extra-model parsing.
/// Users can customize it in settings; customization risks are borne by the user.
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

/// MVU variable framework settings.
///
/// Corresponds to the extensionSettings.mvu_settings extra-model parsing
/// config injected into the WebView.
/// Fields align with the mvu_bundle.js zod schema; adds maxChatHistory
/// (previously fell back to the default of 2).
class MvuSettings {
  /// Update mode: extra-model parsing or follow AI output
  final String updateMode;

  /// Number of recent messages visible to the extra model. Range 2-100, default 10.
  final int maxChatHistory;

  /// Model source, e.g. custom
  final String modelSource;

  /// Jailbreak scheme
  final String jailbreakScheme;

  /// Whether auto request is enabled
  final bool autoRequest;

  /// Custom API URL (non-sensitive)
  final String apiUrl;

  /// API key (sensitive, stored only in the local database, never written into source)
  final String apiKey;

  /// Model name
  final String modelName;

  /// Whether the custom task prompt is enabled (off by default, uses the built-in safe version)
  final bool customPromptEnabled;

  /// Custom task prompt content (defaults to the built-in safe version)
  final String customPrompt;

  // Notification flags
  // Four Chinese keys under extensionSettings.mvu_settings notifications;
  // defaults align with the factory zod schema in mvu_bundle.js (:2988-2993).
  // Factory default for the variable-update-error flag is false; users can
  // enable it in the panel.

  /// Framework loaded notification (factory default true)
  final bool notifyFrameworkLoaded;

  /// Variable initialization success notification (factory default true)
  final bool notifyInitSuccess;

  /// Variable update error notification (factory default false)
  final bool notifyVarError;

  /// Extra-model parsing notification (factory default true)
  final bool notifyExtraParsing;

  /// Raw mvu_settings object written back from the web side
  /// (Chinese keys, MVU's own schema shape).
  ///
  /// MVU's Pinia store writes the full settings (including internal one-time
  /// reminder flags, auto-cleanup variables, compatibility flags, etc.) back
  /// to extensionSettings.mvu_settings. The platform previously only extracted
  /// three known sections, so internal flags were lost and MVU's one-time
  /// upgrade reminders re-appeared on every chat page visit. This field is
  /// persisted as-is; when baking, webRaw is the base overridden by known
  /// platform values, letting MVU's remind-once mechanism work naturally.
  /// Empty (first run) behaves like the legacy version.
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
    // Clamp maxChatHistory to the MVU-valid range 2-100
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
      // Notification flags; backfill with MVU factory defaults for legacy
      // data (true, true, false, true)
      notifyFrameworkLoaded: json['notifyFrameworkLoaded'] as bool? ?? true,
      notifyInitSuccess: json['notifyInitSuccess'] as bool? ?? true,
      notifyVarError: json['notifyVarError'] as bool? ?? false,
      notifyExtraParsing: json['notifyExtraParsing'] as bool? ?? true,
      webRaw: (json['webRaw'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
 }