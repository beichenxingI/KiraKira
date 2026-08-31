// 来源: data.extensions.tavern_helper.scripts
// === tavern_helper.scripts[1] ===
// name=ZOD type=script enabled=True id=fc83c3a3-0bc0-4170-a36a-f40f773204ab
// 字段路径: data.extensions.tavern_helper.scripts[1].content

import { registerMvuSchema } from 'https://testingcf.jsdelivr.net/gh/StageDog/tavern_resource/dist/util/mvu_zod.js';

export const Schema = z.object({
  世界: z.object({
    当前时间: z.string().prefault('未知'),
    当前地点: z.string().prefault('未知'),
    危机程度: z.string().prefault('无'),
    遭遇冷却: z.coerce.number().catch(0).transform(v => (isNaN(v) ? 0 : _.clamp(v, 0, 15))).prefault(0),
    动向: z.record(
      z.string().describe('事件标题'),
      z.preprocess((val) => {
        if (!val || typeof val !== 'object' || Array.isArray(val)) return val;
        // 英文→中文自动归一化
        const map = { type:'类型', description:'描述', desc:'描述', location:'地点', place:'地点', stage:'阶段', phase:'阶段' };
        const out = {};
        for (const [k, v] of Object.entries(val)) {
          out[map[k] || k] = v;
        }
        return out;
      }, z.object({
        阶段: z.enum(['起', '承', '转', '合']).catch('起').prefault('起'),
        类型: z.string().prefault('未知'),
        地点: z.string().prefault(''),
        描述: z.string().prefault(''),
      }))
    ).prefault({}),
  }).catch({}).prefault({}),

  主角: z.object({
    姓名: z.string().prefault('未知'),
    性别: z.string().prefault('未知'),
    容貌: z.string().prefault('未知'),
    身形: z.string().prefault('未知'),
    衣着: z.string().prefault('未知'),
    境界: z.string().prefault('凡人（DC:0）'),
    宗门: z.string().prefault('无'),
    宗门贡献: z.coerce.number().catch(0).prefault(0),
    所在界: z.enum(['玄天界', '仙界']).catch('玄天界').prefault('玄天界'),
    生命: z.coerce.number().catch(100).transform(v => (isNaN(v) ? 100 : _.clamp(v, 0, 100))).prefault(100),
    精血: z.coerce.number().catch(100).transform(v => (isNaN(v) ? 100 : _.clamp(v, 0, 100))).prefault(100),
    灵力: z.coerce.number().catch(100).transform(v => (isNaN(v) ? 100 : _.clamp(v, 0, 100))).prefault(100),
    修为: z.coerce.number().catch(0).transform(v => (isNaN(v) ? 0 : _.clamp(v, 0, 100))).prefault(0),
    神识: z.coerce.number().catch(100).transform(v => (isNaN(v) ? 100 : _.clamp(v, 0, 100))).prefault(100),
    道心: z.coerce.number().catch(50).transform(v => (isNaN(v) ? 50 : _.clamp(v, 0, 100))).prefault(50),
    神念: z.string().prefault('无'),
    气运: z.record(
      z.string().describe('气运名'),
      z.object({
        类型: z.coerce.string().prefault('被动'),
        效果: z.coerce.string().prefault(''),
        使用状态: z.coerce.string().prefault('常驻'),
        压制状态: z.coerce.string().prefault('正常'),
      })
    ).prefault({}),
    灵根: z.string().prefault('未知'),
    状态: z.string().prefault('无异常'),
    炼丹: z.object({
      阶级: z.string().catch('未入门').prefault('未入门'),
      熟练度: z.coerce.number().catch(0).transform(v => (isNaN(v) ? 0 : _.clamp(v, 0, 100))).prefault(0),
      成功率: z.coerce.number().catch(0).transform(v => (isNaN(v) ? 0 : _.clamp(v, 0, 100))).prefault(0),
      次数: z.coerce.number().catch(0).transform(v => (isNaN(v) ? 0 : v)).prefault(0),
    }).catch({}).prefault({}),
    炼器: z.object({
      阶级: z.string().catch('未入门').prefault('未入门'),
      熟练度: z.coerce.number().catch(0).transform(v => (isNaN(v) ? 0 : _.clamp(v, 0, 100))).prefault(0),
      成功率: z.coerce.number().catch(0).transform(v => (isNaN(v) ? 0 : _.clamp(v, 0, 100))).prefault(0),
      次数: z.coerce.number().catch(0).transform(v => (isNaN(v) ? 0 : v)).prefault(0),
    }).catch({}).prefault({}),
    储物袋: z.record(
      z.string().describe('物品名'),
      z.object({
        描述: z.string().prefault(''),
        数量: z.coerce.number().catch(1).prefault(1),
      })
    ).prefault({})
     .transform(data => _.pickBy(data, ({ 数量 }) => 数量 > 0)),
    功法: z.record(
      z.string().describe('功法名'),
      z.object({
        类型: z.string().prefault('未知'),
        境界: z.string().prefault('未入门'),
        熟练度: z.coerce.number().catch(0).transform(v => (isNaN(v) ? 0 : _.clamp(v, 0, 100))).prefault(0),
        描述: z.string().prefault(''),
      })
    ).prefault({}),
    器物: z.record(
      z.string().describe('器物名'),
      z.object({
        等级: z.string().prefault('未知'),
        类型: z.string().prefault('未知'),
        损耗度: z.coerce.number().catch(0).transform(v => (isNaN(v) ? 0 : _.clamp(v, 0, 100))).prefault(0),
        状态: z.string().prefault('正常'),
        描述: z.string().prefault(''),
      })
    ).prefault({}),
  }).catch({}).prefault({}),

  道侣: z.record(
    z.string().describe('道侣姓名'),
    z.object({
      性别: z.string().prefault('未知'),
      种族: z.string().prefault('人族'),
      状态: z.string().prefault('正常'),
      境界: z.string().prefault('未知'),
      亲密: z.coerce.number().catch(100).transform(v => (isNaN(v) ? 100 : _.clamp(v, 0, 100))).prefault(100),
      生命: z.coerce.number().catch(100).transform(v => (isNaN(v) ? 100 : _.clamp(v, 0, 100))).prefault(100),
      灵力: z.coerce.number().catch(100).transform(v => (isNaN(v) ? 100 : _.clamp(v, 0, 100))).prefault(100),
      修为: z.coerce.number().catch(0).transform(v => (isNaN(v) ? 0 : _.clamp(v, 0, 100))).prefault(0),
      道心: z.coerce.number().catch(50).transform(v => (isNaN(v) ? 50 : _.clamp(v, 0, 100))).prefault(50),
      性格: z.string().prefault('未知'),
      外观: z.string().prefault('未知'),
      身高: z.coerce.string().prefault('未知'),
      背景: z.string().prefault(''),
      神通: z.string().prefault('无'),
      心声: z.string().prefault('无'),
    })
  ).catch({}).prefault({}),

  灵宠: z.record(
    z.string().describe('灵宠姓名'),
    z.object({
      性别: z.string().prefault('未知'),
      种族: z.string().prefault('未知'),
      境界: z.string().prefault('未知'),
      生命: z.coerce.number().catch(100).transform(v => (isNaN(v) ? 100 : _.clamp(v, 0, 100))).prefault(100),
      灵力: z.coerce.number().catch(100).transform(v => (isNaN(v) ? 100 : _.clamp(v, 0, 100))).prefault(100),
      修为: z.coerce.number().catch(0).transform(v => (isNaN(v) ? 0 : _.clamp(v, 0, 100))).prefault(0),
      亲密度: z.coerce.number().catch(50).transform(v => (isNaN(v) ? 50 : _.clamp(v, 0, 100))).prefault(50),
      性格: z.string().prefault('未知'),
      容貌外观: z.string().prefault('未知'),
      神通: z.string().prefault('无'),
      状态: z.string().prefault('正常'),
      心声: z.string().prefault('无'),
    })
  ).catch({}).prefault({}),

  人物: z.record(
    z.string().describe('NPC姓名'),
    z.object({
      性别: z.string().prefault('未知'),
      头衔: z.string().prefault(''),
      境界: z.string().prefault('未知'),
      好感: z.coerce.number().catch(0).transform(v => (isNaN(v) ? 0 : _.clamp(v, 0, 100))).prefault(0),
      关系阶段: z.string().prefault('陌生'),
      生命: z.coerce.number().catch(100).transform(v => (isNaN(v) ? 100 : _.clamp(v, 0, 100))).prefault(100),
      灵力: z.coerce.number().catch(100).transform(v => (isNaN(v) ? 100 : _.clamp(v, 0, 100))).prefault(100),
      修为: z.coerce.number().catch(0).transform(v => (isNaN(v) ? 0 : _.clamp(v, 0, 100))).prefault(0),
      道心: z.coerce.number().catch(50).transform(v => (isNaN(v) ? 50 : _.clamp(v, 0, 100))).prefault(50),
      性格: z.string().prefault('未知'),
      描述: z.string().prefault(''),
    })
  ).catch({}).prefault({}),

  机遇: z.record(
    z.string().describe('任务名'),
    z.object({
      难度: z.string().prefault('未知'),
      目标: z.string().prefault(''),
      机缘: z.string().prefault(''),
      引言: z.string().prefault(''),
    })
  ).catch({}).prefault({})
   .transform(data => _(data).entries().takeRight(20).fromPairs().value()),

  绝色榜: z.record(
    z.string().describe('仙子姓名'),
    z.object({
      排名: z.coerce.string().prefault('未知'),
      头衔: z.string().prefault(''),
      仙姿: z.string().prefault(''),
      群芳谱: z.string().prefault(''),
    })
  ).catch({}).prefault({}),

  玉简: z.record(
    z.string().describe('好友姓名'),
    z.object({
      性别: z.string().prefault('未知'),
      境界: z.string().prefault('未知'),
      关系: z.string().prefault('陌生'),
      好感度: z.coerce.number().catch(0).transform(v => (isNaN(v) ? 0 : _.clamp(v, 0, 100))).prefault(0),
      历史记录: z.record(
        z.string().describe('消息标识'),
        z.object({
          发送者: z.string().prefault('未知'),
          时间: z.string().prefault(''),
          内容: z.string().prefault(''),
        })
      ).prefault({})
       .transform(data => _(data).entries().takeRight(100).fromPairs().value()),
    })
  ).catch({}).prefault({}),

  $器灵台词: z.array(z.string()).prefault([]),
});

$(() => {
  registerMvuSchema(Schema);
});