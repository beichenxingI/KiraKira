// lib/presentation/screens/main_page/daily_oracle_data.dart
/// Daily wish: purely local copy pool. All const, zero network.
/// Tone: comforting companionship, no fortune-telling scare tactics; "leaves you in a better mood" is the only rule.
library;

import 'package:flutter/material.dart';

/// Today's keywords (gentle and positive)
const kOracleKeywords = <String>[
  '闪耀', '松弛', '好奇', '温柔', '勇敢', '清澈', '明亮', '轻盈',
  '柔软', '热烈', '安静', '自由', '甜', '新鲜', '舒展', '笃定',
  '浪漫', '灵巧', '暖', '开阔', '细腻', '鲜活', '坦荡', '俏皮',
];

/// Fortune levels (all positive/neutral; even the "lowest" is a comfort)
const kOracleLevels = <String>['大吉', '上上签', '小确幸', '平和日', '慢慢来'];

/// Today's message pool (50+, gentle encouragement with a playful edge)
const kOracleMessages = <String>[
  '今天的你自带主角光环,主动迈出一步,好消息会跑得更快。',
  '把烦恼写在纸上,再画个笑脸盖住它,今天就归你管。',
  '适合喝一杯温热的东西,然后原谅昨天的自己。',
  '有人正在悄悄欣赏你的认真,只是你没发现。',
  '今天的风很配合,吹走的都是不值得带走的事。',
  '允许自己慢一点,蜗牛也有自己的风景。',
  '你纠结的那件事,答案比你想象的简单。',
  '今天适合穿得好看一点,好运喜欢先看脸。',
  '把"算了"换成"试试看",剧情会不一样。',
  '你的直觉今天在线,第一感觉大概率是对的。',
  '久违的人可能会带来久违的惊喜,别急着挂断。',
  '今天的小确幸藏在第二口奶茶里,记得慢慢喝。',
  '不用事事完美,完成就已经很了不起了。',
  '傍晚的天空会给你免费放映一部大片,抬头看。',
  '今天适合把收藏夹里的东西真正打开一次。',
  '别人眼里的难题,恰好是你顺手的事,露一手吧。',
  '心里那件小事,今天说出来会意外地顺利。',
  '今天的你比昨天更接近想成为的人,虽然你自己没察觉。',
  '给自己一个小奖励,你最近辛苦了。',
  '适合整理桌面/房间,清空角落也清空心情。',
  '今天说"不"的底气格外足,该拒绝就拒绝。',
  '有顿好吃的在等你,别辜负它。',
  '你随口的善意,可能正照亮别人的整天。',
  '今天适合发呆五分钟,大脑需要个喘气窗口。',
  '那个一直想学的技能,今天就点开第一课吧。',
  '天气好的话出去走走,天气不好就窝着,横竖都是好日子。',
  '你的努力正在路上堵车,但方向没错,会到的。',
  '今天适合听一首老歌,回忆会给你充电。',
  '别怕选错,今天的选项都通往不错的结局。',
  '有人记得你说过的小事,你比自己以为的更重要。',
  '今天的效率小高峰在上午,重要的事趁早。',
  '把手机放下十分钟,世界不会塌,眼睛会谢谢你。',
  '今天笑三次以上,运气值自动充值。',
  '适合主动夸一个人,包括镜子里的那位。',
  '悬着的事会有温和的进展,不用再反复刷新了。',
  '今天的水分要喝够,皮肤和心情都靠它。',
  '你以为的普通日常,是别人羡慕的安稳。',
  '灵感今天路过你家门口,记得开门。',
  '适合提前睡半小时,明天会感谢今晚的你。',
  '你担心的最坏结果,发生概率约等于中彩票的反面。',
  '今天适合宽恕自己一次,人无完人,你有魅力就够了。',
  '路过的猫都愿意停下来看你,你很有亲和力。',
  '把目标拆成三小块,今天的你能轻松通关。',
  '适合给未来写一句话,未来的你会回来点赞。',
  '今天的你反应特别快,接梗都接得漂亮。',
  '旧物翻出来会有新用处,包括某段回忆。',
  '适合列个小清单,划掉那一瞬最解压。',
  '今天的世界对你开了美颜滤镜,放心出门。',
  '有人会需要你的建议,大胆说,你懂的比别人多。',
  '偶尔躺平不是罪,是充电,充完继续闪。',
  '今天遇到的挫折都是缩小版,顺手就能拍掉。',
  '你的存在本身就是某些人今天的好消息。',
  '适合换一条新路线回家,生活需要一点新意。',
  '今天适合把"改天再说"变成"现在就做"。',
  '深呼吸三次,你要的平静一直都在。',
  '今晚的梦可能特别好,早点休息去领奖。',
];

/// Five-dimension names
const kOracleDims = <String>['综合', '灵感', '人缘', '活力', '财运'];

/// Lucky time slots
const kLuckyHours = <String>[
  '07:00 - 09:00', '09:00 - 11:00', '11:00 - 13:00', '13:00 - 15:00',
  '15:00 - 17:00', '17:00 - 19:00', '19:00 - 21:00', '21:00 - 23:00',
];

/// Lucky directions (down-to-earth edition)
const kLuckyDirections = <String>[
  '有绿植的地方', '窗边', '楼下便利店', '书桌朝南的一侧', '阳台',
  '常去的那家店', '有阳光的座位', '图书馆靠窗位', '厨房附近',
  '今天少走回头路', '电梯靠里的位置', '有音乐飘出的街角',
];

/// Lucky items (emoji + name)
const kLuckyItems = <Map<String, String>>[
  {'emoji': '🔑', 'name': '你的旧钥匙扣'},
  {'emoji': '🎧', 'name': '单曲循环的歌'},
  {'emoji': '🧦', 'name': '那双舒服的袜子'},
  {'emoji': '☕', 'name': '第二杯半价'},
  {'emoji': '📖', 'name': '翻开任何一页的书'},
  {'emoji': '🌙', 'name': '睡前的小夜灯'},
  {'emoji': '🍬', 'name': '口袋里的糖'},
  {'emoji': '🧸', 'name': '床上的玩偶'},
  {'emoji': '💧', 'name': '随手的水杯'},
  {'emoji': '🎫', 'name': '一张没拆的优惠券'},
  {'emoji': '🌱', 'name': '刚发芽的小盆栽'},
  {'emoji': '✏️', 'name': '顺手的笔'},
  {'emoji': '🛼', 'name': '说走就走的鞋'},
  {'emoji': '📷', 'name': '随手一拍的镜头'},
  {'emoji': '🧣', 'name': '软软的围巾'},
  {'emoji': '🍪', 'name': '下午三点的饼干'},
];

/// Lucky colors (name + color value)
const kLuckyColors = <Map<String, dynamic>>[
  {'name': '星云紫', 'color': Color(0xFFB39DDB)},
  {'name': '樱粉', 'color': Color(0xFFF8BBD0)},
  {'name': '海盐蓝', 'color': Color(0xFF90CAF9)},
  {'name': '薄荷绿', 'color': Color(0xFFA5D6A7)},
  {'name': '奶油黄', 'color': Color(0xFFFFF59D)},
  {'name': '珊瑚橙', 'color': Color(0xFFFFAB91)},
  {'name': '月光白', 'color': Color(0xFFFAFAFA)},
  {'name': '雾灰', 'color': Color(0xFFB0BEC5)},
  {'name': '蜜桃粉', 'color': Color(0xFFFFCCBC)},
  {'name': '青柠', 'color': Color(0xFFDCE775)},
];

/// Do's (warm little things)
const kDos = <String>[
  '夸奖自己', '尝试新歌单', '完成一件小事', '早点睡', '多喝水',
  '给旧友发句话', '晒晒太阳', '整理桌面', '吃点好的', '散步十分钟',
  '看一集想看的剧', '拍张天空照', '学一个小知识', '对镜子笑笑',
  '把烦恼写下来撕掉', '抱抱枕头', '换套干净的床单', '认真吃早餐',
  '回复那条拖了很久的消息', '给自己买束花',
];

/// Don'ts (light reminders, nothing scary)
const kDonts = <String>[
  '忽略消息', '熬夜', '冲动消费', '跟自己较劲', '反复刷新等待',
  '空腹喝咖啡', '想起尴尬往事', '和机器人吵赢', '深夜做决定',
  '忘了喝水', '久坐不动', '刷短视频到天亮', '把话憋回去',
  '对镜子太苛刻',
];

/// Star sign pool (one of three drawn per day)
const kStarSigns = <String>[
  '这张签说:你想要的,正在来的路上,记得留门。',
  '签文:近期的努力会先开一朵小花,别急着摘。',
  '签曰:今天适合把心事说给信任的人听。',
  '此签大妙:转机藏在你差点放弃的那一步之后。',
  '签文:有人默默站在你这边,你不是一个人。',
  '签曰:放下比较,你的时区没有迟到这回事。',
  '这张签带着糖:今天会有一句让你开心的话出现。',
  '签文:旧的问题会有新的解法,换个角度看看。',
  '签曰:你的温柔会被这个世界温柔记账。',
  '此签提示:身体是最重要的朋友,听听它的。',
  '签文:小概率好事即将发生,比如刚好赶上绿灯一路。',
  '签曰:允许一切如其所是,也允许自己慢慢来。',
  '这张签画了一只猫:慵懒一点,效率反而高。',
  '签文:你散发的光,已经照亮过某个人的下午。',
  '签曰:接下来的一周,适合种下一个小小心愿。',
  '此签盖章:你比上周的你更厉害了一点点。',
  '签文:把期待降低,把行动抬高,惊喜自然来。',
  '签曰:今天适合原谅,包括原谅自己。',
];

/// Holiday easter egg table (fixed solar dates: month*100+day; lunar festivals use the per-year override table)
class OracleHoliday {
  final String name;
  final String emoji;
  final Color accent;
  final String? title;
  final List<String> messages;
  const OracleHoliday({
    required this.name,
    required this.emoji,
    required this.accent,
    this.title,
    this.messages = const [],
  });
}

/// Fixed solar-date holiday easter eggs
const kSolarHolidays = <int, OracleHoliday>{
  101: OracleHoliday(
    name: '元旦', emoji: '🎊', accent: Color(0xFFEF9A9A),
    title: '新的一年,从一句好话开始',
    messages: [
      '新年第一页,写下你想成为的样子吧。',
      '元旦快乐!今年的好运已装订成册,今天发货。',
    ],
  ),
  214: OracleHoliday(
    name: '情人节', emoji: '💝', accent: Color(0xFFF48FB1),
    title: '爱要大声,也要爱自己',
    messages: [
      '不管有没有人陪,今天都要好好爱自己,你是限量款。',
      '情人节快乐!被爱的前提,是你一直在认真地可爱着。',
    ],
  ),
  401: OracleHoliday(
    name: '愚人节', emoji: '🃏', accent: Color(0xFF90CAF9),
    title: '唯一的真话:你很棒',
    messages: [
      '愚人节只骗你一件事:其实你没有那么好——骗你的,你超好。',
      '今天所有玩笑都当真也无妨,反正好运是真的。',
    ],
  ),
  405: OracleHoliday(
    name: '清明', emoji: '🌿', accent: Color(0xFFA5D6A7),
    title: '春天很适合想念与出发',
    messages: [
      '清明时节,万物清洁明净,适合想念,也适合重新出发。',
      '踏青去吧,把冬天最后一点闷气留在草地上。',
    ],
  ),
  501: OracleHoliday(
    name: '劳动节', emoji: '🛠️', accent: Color(0xFFFFCC80),
    title: '劳有所得,也要躺有所值',
    messages: [
      '劳动节快乐!认真工作的人最帅,认真休息的人最聪明。',
      '今天合法偷懒,罪恶感为零,系统已认证。',
    ],
  ),
  601: OracleHoliday(
    name: '儿童节', emoji: '🎈', accent: Color(0xFF80DEEA),
    title: '谁还不是个宝宝',
    messages: [
      '六一快乐!今天允许你理直气壮地幼稚一天。',
      '长大是工作,童心是天赋。儿童节快乐,大朋友。',
    ],
  ),
  1001: OracleHoliday(
    name: '国庆', emoji: '🇨🇳', accent: Color(0xFFEF9A9A),
    title: '假期余额已到账',
    messages: [
      '国庆快乐!七天的小日子,记得分一点给快乐。',
      '山河远阔,人间烟火,假期愉快呀。',
    ],
  ),
  1024: OracleHoliday(
    name: '程序员节', emoji: '💻', accent: Color(0xFFCE93D8),
    title: '今天你的代码零 bug ✨',
    messages: [
      '1024,程序员节快乐!愿你代码零 bug,需求不改稿。',
      '今天编译一次通过,测试一次全绿,许愿灵验率 +1024%。',
    ],
  ),
  1031: OracleHoliday(
    name: '万圣节', emoji: '🎃', accent: Color(0xFFFFB74D),
    title: '不给糖就捣蛋',
    messages: [
      '万圣节快乐!今晚出没的都是可爱鬼,比如你。',
      '装扮成谁都行,别装扮成大人,太累了。',
    ],
  ),
  1111: OracleHoliday(
    name: '双十一', emoji: '🛒', accent: Color(0xFFB39DDB),
    title: '购物车与钱包的和解日',
    messages: [
      '双十一快乐!买需要的,省下的都是给自己的礼物。',
      '今天最大的优惠,是记得对自己好一点,还不花钱。',
    ],
  ),
  1225: OracleHoliday(
    name: '圣诞', emoji: '🎄', accent: Color(0xFFEF9A9A),
    title: '平安喜乐,得偿所愿',
    messages: [
      '圣诞快乐!袜子挂好,愿望写好,剩下的交给奇迹。',
      '今夜有人翻越整个冬天来看你,晚安,好梦。',
    ],
  ),
};

/// Lunar festivals, overridden per year (extend the table yearly; key = year*10000 + month*100 + day)
const kLunarHolidayOverrides = <int, OracleHoliday>{
  // 2026: Spring Festival 2/17, Lantern Festival 3/3, Dragon Boat Festival 6/19, Mid-Autumn Festival 9/25
  20260217: OracleHoliday(
    name: '春节', emoji: '🧧', accent: Color(0xFFE57373),
    title: '新年第一签,好运连连鸭',
    messages: [
      '新春快乐!红红火火,万事都顺,压岁钱请多来点。',
      '新年第一天,祝你被爱包围,被钱砸中(温柔的砸)。',
    ],
  ),
  20260303: OracleHoliday(
    name: '元宵', emoji: '汤圆', accent: Color(0xFFFFCC80),
    title: '一碗汤圆,团团圆圆',
    messages: [
      '元宵快乐!日子像汤圆一样,甜甜糯糯,圆圆满满。',
      '灯月交辉的晚上,愿望会说给月亮听。',
    ],
  ),
  20260619: OracleHoliday(
    name: '端午', emoji: '🎋', accent: Color(0xFFA5D6A7),
    title: '粽有好事发生',
    messages: [
      '端午安康!"粽"有好事会发生,"粽"有人惦记着你。',
      '艾草香里,夏天正式开场,苦尽甘来。',
    ],
  ),
  20260925: OracleHoliday(
    name: '中秋', emoji: '🥮', accent: Color(0xFFFFD54F),
    title: '月亮很圆,你也很好',
    messages: [
      '中秋快乐!千里共婵娟,思念的人都会平安。',
      '月饼甜,月亮圆,你和家人的距离,今晚只有一片天。',
    ],
  ),
  // 2027: Spring Festival 2/6
  20270206: OracleHoliday(
    name: '春节', emoji: '🧧', accent: Color(0xFFE57373),
    title: '新年第一签,好运连连鸭',
    messages: [
      '新春快乐!新的一年,慢慢来,都会有的。',
      '爆竹声中一岁除,烦恼也一起除掉了。',
    ],
  ),
};
