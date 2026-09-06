/* ============================================================
 * EJS 外部依赖桩 (Mimic) — dist 的 15 个 import 全指向这里
 * 接真: chat/chat_metadata/extension_settings/eventSource/
 *       event_types/getCurrentChatId/substituteParams
 * 空桩: 见 [STUB] 标记，一键捞坑 grep "[STUB"
 *   [STUB]        纯占位  [STUB→第X章] 归属未来BOSS  [STUB!] 有风险优先填
 * ============================================================ */

// ── 变量类（接 facade，Trinity 已同步）──
// Proxy 活引用：Trinity 整体替换 window.chat 后，dist 读到的仍是最新数组
if (!window.chat) window.chat = [];
if (!window.chat_metadata) window.chat_metadata = {};
export const chat = new Proxy([], {
  get(_, k) { var t = window.chat || []; if (k === 'length') return t.length; if (typeof k === 'string' && !isNaN(k)) return t[+k]; if (typeof t[k] === 'function') return t[k].bind(t); return t[k]; },
  set(_, k, v) { var t = window.chat || []; t[k] = v; return true; },
});
export const chat_metadata = new Proxy({}, {
  get(_, k) { return (window.chat_metadata || {})[k]; },
  set(_, k, v) { if (!window.chat_metadata) window.chat_metadata = {}; window.chat_metadata[k] = v; return true; },
});
export const extension_settings = window.extension_settings;
export const renderExtensionTemplateAsync = async () => '';  // [STUB] UI设置面板模板；引擎房无 #extensions_settings 节点，append 到空集合，聊天页不受影响

// ── 事件类（接 window._TH）──
export const eventSource = {
  on:(t,l)=>window._TH.eventOn(t,l),
  once:(t,l)=>window._TH.eventOnce(t,l),
  emit:(t,...a)=>window._TH.eventEmit(t,...a),
  makeLast:(t,l)=>window._TH.eventMakeLast(t,l),
  makeFirst:(t,l)=>window._TH.eventMakeFirst(t,l),
  emitAndWait:(t,...a)=>window._TH.eventEmitAndWait(t,...a),
  removeListener:(t,l)=>window._TH.eventRemoveListener&&window._TH.eventRemoveListener(t,l),
};
export const event_types = window.tavern_events;

// ── 宏 & 身份 ──
export function substituteParams(s){
  if(typeof s!=='string') return s;
  var m = window.__KIRA_MACRO_VALUES||{user:'User',char:'Assistant'};
  return s.replace(/\{\{user\}\}/gi,m.user).replace(/\{\{char\}\}/gi,m.char);
}
export const name1 = (window.__KIRA_MACRO_VALUES||{}).user || 'User';
export const name2 = (window.__KIRA_MACRO_VALUES||{}).char || 'Assistant';
export function getCurrentChatId(){ return window.__KIRA_CHAT_ID || ''; }

// ── script.js 其余 ──
export const this_chid = 0;                      // [STUB] 单角色恒0
export const characters = [];                    // [STUB]
export const user_avatar = '';                   // [STUB]
export const getThumbnailUrl = ()=>'';           // [STUB]
export const getUserAvatar = ()=>'';             // [STUB]
export const saveChatConditional = async()=>{};  // [STUB] 存盘走桥
export const saveSettingsDebounced = ()=>{};     // [STUB]
export const messageFormatting = (s)=>s;         // [STUB!] 渲染美化，高星卡可能要
export const updateMessageBlock = ()=>{};        // [STUB→第三章:楼层渲染]
export const appendMediaToMessage = ()=>{};      // [STUB]
export const addCopyToCodeBlocks = ()=>{};       // [STUB]
export const main_api = 'openai';                // [STUB
export const nai_settings = {};                  // [STUB] E1:NovelAI 设置占位,防 undefined 解引用
export const online_status = 'unknown';          // [STUB] E1:连接状态字符串,恒非空]
export const GenerateOptions = {};               // [STUB]

// ── openai.js（dist 确实 import，给空占位）──
export const oai_settings = {};                  // [STUB] openai 设置，EJS 极少读
export const chat_completion_sources = {};       // [STUB]
export function getChatCompletionModel() {       // [STUB→真] E1:求值路径必调,恒返非空字符串
  return ((typeof window !== 'undefined' && window.__KIRA_MODEL_NAME) || 'unknown');
}

// ── utils.js ──
export const copyText = ()=>{};                  // [STUB]
export const getCharaFilename = ()=>'';          // [STUB→第五章:WI]

// ── power-user.js ──
export const power_user = {};                    // [STUB]

// ── group-chats.js（不做群聊）──
export const groups = [];                        // [STUB]
export const selected_group = null;              // [STUB]
export const getGroupMembers = ()=>[];           // [STUB]

// ── regex/engine.js ──
export const getRegexedString = (s)=>s;          // [STUB!→第五章:正则] 原样返回
export const regex_placement = {MD_DISPLAY:0,USER_INPUT:1,AI_OUTPUT:2,SLASH_COMMAND:3,WORLD_INFO:5}; // [STUB→第五章:正则]

// ── tokenizers.js ──
export const getTokenCountAsync = async()=>0;    // [STUB]

// ── reasoning.js ──
export const updateReasoningUI = ()=>{};         // [STUB]

// ── lib.js ──
export const yaml = { load:()=>({}), dump:()=>'' }; // [STUB!] 初始变量YAML，卡带initvar时用

// ── faker.mjs(E1)──
// dist 惰性加载把【整个 stub 命名空间】赋给模板作用域的 faker(Gm.faker=e),
// 命名空间无法动态加属性,这里导出同名递归代理兜底 ns.faker 访问面;
// 任意深度可调用、字符串强转返回空串,真实 faker 数据不提供(走 fail-open 兜底)。
function __fkNode() {
  const f = function(){ return ''; };
  return new Proxy(f, { get(t, k){
    if (typeof k === 'symbol') return () => '';
    if (k === 'then') return undefined;          // 防 thenable 陷阱
    if (!(k in t)) t[k] = __fkNode();
    return t[k];
  }});
}
export const faker = __fkNode();

// ── slash-commands 全家桶 ──
// [P6-3] execute() 接真:走桥 th_executeSlash → Dart SlashRunner,pipe 回传
export const executeSlashCommandsWithOptions = async (text) => {
  try {
    if (typeof __thCall !== 'function') return { pipe: String(text ?? ''), isAborted: false, isBreak: false, isError: true, errorMessage: 'bridge missing' };
    var r = await __thCall('th_executeSlash', [String(text ?? '')]);
    return {
      pipe: (r && typeof r.pipe === 'string') ? r.pipe : '',
      isAborted: !!(r && r.isAborted),
      isBreak: !!(r && r.isBreak),
      isError: !!(r && r.isError),
      errorMessage: (r && r.errorMessage) || undefined,
    };
  } catch (e) {
    return { pipe: '', isAborted: false, isBreak: false, isError: true, errorMessage: String(e) };
  }
};
export class SlashCommand { static fromProps(){return new SlashCommand();} } // [STUB→第五章:Slash]
export class SlashCommandArgument {              // [STUB→第五章:Slash] init期需 fromProps
  constructor(props){ Object.assign(this, props||{}); }
  static fromProps(props){ return new SlashCommandArgument(props); }
}
export class SlashCommandNamedArgument extends SlashCommandArgument { // [STUB→第五章:Slash]
  static fromProps(props){ return new SlashCommandNamedArgument(props); }
}
export const ARGUMENT_TYPE = {STRING:'string',NUMBER:'number',BOOLEAN:'boolean',LIST:'list',DICTIONARY:'dictionary'}; // [STUB→第五章:Slash]
export const SlashCommandParser = { addCommandObject(){}, addCommand(){} }; // [STUB→第五章:Slash]

// ── world-info.js ──
export const METADATA_KEY = 'world_info';                     // [STUB→第五章:WI]
export const DEFAULT_WEIGHT = 100;                            // [STUB→第五章:WI]
export const DEFAULT_DEPTH = 4;                               // [STUB→第五章:WI]
export const world_info_max_recursion_steps = 0;             // [STUB→第五章:WI]
export const world_info_position = {before:0,after:1,ANTop:2,ANBottom:3,atDepth:4}; // [STUB→第五章:WI]
export const world_info_case_sensitive = false;              // [STUB→第五章:WI]
export const world_info_match_whole_words = false;           // [STUB→第五章:WI]
export const world_info_use_group_scoring = false;           // [STUB→第五章:WI]
export const world_info_logic = {AND_ANY:0,NOT_ALL:1,NOT_ANY:2,AND_ALL:3}; // [STUB→第五章:WI]
export const selected_world_info = [];                        // [STUB→第五章:WI]
export const world_info = {};                                 // [STUB→第五章:WI]
export const world_names = [];                                // [STUB→第五章:WI]
export const loadWorldInfo = async()=>null;                   // [STUB!→第五章:WI] 高星卡重度依赖
export const parseRegexFromString = ()=>null;                 // [STUB→第五章:WI]