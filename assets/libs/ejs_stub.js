/* ============================================================
 * EJS external dependency stubs (Mimic) -- all 15 dist imports resolve here.
 * Wired to real implementations: chat/chat_metadata/extension_settings/eventSource/
 *       event_types/getCurrentChatId/substituteParams
 * Empty stubs: see the [STUB] markers; find them all with grep "[STUB"
 *   [STUB]        pure placeholder  [STUB->ch.X]  reserved for a future milestone  [STUB!]  risky, fill first
 * ============================================================ */

// Variables (wired to the facade, synced with Trinity).
// Live Proxy reference: after Trinity replaces window.chat wholesale, the dist still reads the latest array.
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
export const renderExtensionTemplateAsync = async () => '';  // [STUB] settings panel template; the engine room has no #extensions_settings node, so append targets an empty collection and the chat page is unaffected

// Events (wired to window._TH).
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

// Macros & identity.
export function substituteParams(s){
  if(typeof s!=='string') return s;
  var m = window.__KIRA_MACRO_VALUES||{user:'User',char:'Assistant'};
  return s.replace(/\{\{user\}\}/gi,m.user).replace(/\{\{char\}\}/gi,m.char);
}
export const name1 = (window.__KIRA_MACRO_VALUES||{}).user || 'User';
export const name2 = (window.__KIRA_MACRO_VALUES||{}).char || 'Assistant';
export function getCurrentChatId(){ return window.__KIRA_CHAT_ID || ''; }

// Remaining script.js exports.
export const this_chid = 0;                      // [STUB] single character, always 0
export const characters = [];                    // [STUB]
export const user_avatar = '';                   // [STUB]
export const getThumbnailUrl = ()=>'';           // [STUB]
export const getUserAvatar = ()=>'';             // [STUB]
export const saveChatConditional = async()=>{};  // [STUB] saving goes through the bridge
export const saveSettingsDebounced = ()=>{};     // [STUB]
export const messageFormatting = (s)=>s;         // [STUB!] message formatting; highly-rated cards may need it
export const updateMessageBlock = ()=>{};        // [STUB->ch.3: floor rendering]
export const appendMediaToMessage = ()=>{};      // [STUB]
export const addCopyToCodeBlocks = ()=>{};       // [STUB]
export const main_api = 'openai';                // [STUB
export const nai_settings = {};                  // [STUB] E1: NovelAI settings placeholder, guards against undefined dereference
export const online_status = 'unknown';          // [STUB] E1: connection status string, always non-empty]
export const GenerateOptions = {};               // [STUB]

// openai.js (the dist does import these; empty placeholders).
export const oai_settings = {};                  // [STUB] openai settings; EJS rarely reads them
export const chat_completion_sources = {};       // [STUB]
export function getChatCompletionModel() {       // [STUB->real] E1: always called on the evaluation path, always returns a non-empty string
  return ((typeof window !== 'undefined' && window.__KIRA_MODEL_NAME) || 'unknown');
}

// utils.js.
export const copyText = ()=>{};                  // [STUB]
export const getCharaFilename = ()=>'';          // [STUB->ch.5: WI]

// power-user.js.
export const power_user = {};                    // [STUB]

// group-chats.js (group chat is not implemented).
export const groups = [];                        // [STUB]
export const selected_group = null;              // [STUB]
export const getGroupMembers = ()=>[];           // [STUB]

// regex/engine.js.
// Wired to the real implementation: delegates to the facade's synchronous regex engine
// (platform regex asset snapshot __KIRA_REGEX_RULES).
export const getRegexedString = (s, placement, opts) => {
  try {
    if (typeof window.__kiraRunRegex === 'function') return window.__kiraRunRegex(s, placement, opts);
  } catch (e) { /* fallthrough */ }
  return s;
};
export const regex_placement = {MD_DISPLAY:0,USER_INPUT:1,AI_OUTPUT:2,SLASH_COMMAND:3,WORLD_INFO:5,REASONING:6};

// tokenizers.js.
export const getTokenCountAsync = async()=>0;    // [STUB]

// reasoning.js.
export const updateReasoningUI = ()=>{};         // [STUB]

// lib.js.
export const yaml = { load:()=>({}), dump:()=>'' }; // [STUB!] YAML for initial variables; used when a card ships initvar

// faker.mjs (E1).
// The dist's lazy loading assigns the whole stub namespace to the template scope's faker
// (Gm.faker=e); a namespace cannot take dynamic properties, so a same-named recursive proxy is
// exported as a fallback for the ns.faker access surface;
// callable at any depth and coerced to an empty string, with no real faker data provided
// (falls back to fail-open behavior).
function __fkNode() {
  const f = function(){ return ''; };
  return new Proxy(f, { get(t, k){
    if (typeof k === 'symbol') return () => '';
    if (k === 'then') return undefined;          // guard against the thenable trap
    if (!(k in t)) t[k] = __fkNode();
    return t[k];
  }});
}
export const faker = __fkNode();

// slash-commands family.
// execute() wired to the real implementation: goes over the bridge th_executeSlash -> Dart
// SlashRunner, with the pipe passed back.
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
export class SlashCommand { static fromProps(){return new SlashCommand();} } // [STUB->ch.5: Slash]
export class SlashCommandArgument {              // [STUB->ch.5: Slash] fromProps needed during init
  constructor(props){ Object.assign(this, props||{}); }
  static fromProps(props){ return new SlashCommandArgument(props); }
}
export class SlashCommandNamedArgument extends SlashCommandArgument { // [STUB->ch.5: Slash]
  static fromProps(props){ return new SlashCommandNamedArgument(props); }
}
export const ARGUMENT_TYPE = {STRING:'string',NUMBER:'number',BOOLEAN:'boolean',LIST:'list',DICTIONARY:'dictionary'}; // [STUB->ch.5: Slash]
export const SlashCommandParser = { addCommandObject(){}, addCommand(){} }; // [STUB->ch.5: Slash]

// world-info.js.
export const METADATA_KEY = 'world_info';                     // [STUB->ch.5: WI]
export const DEFAULT_WEIGHT = 100;                            // [STUB->ch.5: WI]
export const DEFAULT_DEPTH = 4;                               // [STUB->ch.5: WI]
export const world_info_max_recursion_steps = 0;             // [STUB->ch.5: WI]
export const world_info_position = {before:0,after:1,ANTop:2,ANBottom:3,atDepth:4}; // [STUB->ch.5: WI]
export const world_info_case_sensitive = false;              // [STUB->ch.5: WI]
export const world_info_match_whole_words = false;           // [STUB->ch.5: WI]
export const world_info_use_group_scoring = false;           // [STUB->ch.5: WI]
export const world_info_logic = {AND_ANY:0,NOT_ALL:1,NOT_ANY:2,AND_ALL:3}; // [STUB->ch.5: WI]
export const selected_world_info = [];                        // [STUB->ch.5: WI]
export const world_info = {};                                 // [STUB->ch.5: WI]
export const world_names = [];                                // [STUB->ch.5: WI]
export const loadWorldInfo = async()=>null;                   // [STUB!->ch.5: WI] heavily depended on by highly-rated cards
export const parseRegexFromString = ()=>null;                 // [STUB->ch.5: WI]