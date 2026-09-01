const fs = require('fs');
const { makeEnvironment } = require('../env');
const { root } = require('../extract');

const DAOYUAN = `${root}/DiaoYan/scripts/daoyuan_helper.js`;

async function run() {
  const { browser, page } = await makeEnvironment();
  const timer = setTimeout(async () => {
    console.error('[场景1] 超时: 30000ms');
    await browser.close();
    process.exitCode = 1;
  }, 30000);
  try {
    // 原版是 ES module(顶层 await + 末尾 export{}),必须声明 type
    // Chromium 原生支持,不需要像 jsdom 那轮删 export{}
    await page.addScriptTag({ path: DAOYUAN, type: 'module' });

    // 球的检测由 setInterval(...,5e3) 驱动
    // 见 daoyuan_helper.js.pretty.js:1760,至少等一个周期
    await page.waitForTimeout(6000);

    const result = await page.evaluate(() => {
      const el = document.getElementById('bp-config-status');
      // 找不到目标元素时,把道渊自己插进 DOM 的节点全打出来,
      // 便于确认真实 id / 是否插到了别的 window
      const dump = el ? null : Array.from(
        document.querySelectorAll('[id^="bp-"]')
      ).map(n => n.id);
      return {
        found: !!el,
        text: el ? el.textContent : null,
        html: el ? el.innerHTML : null,
        bpNodes: dump,
        frames: document.querySelectorAll('iframe').length,
        calls: window.__harnessBridgeCalls || [],
      };
    });

    console.log(`[场景1] 找到状态节点=${result.found}`);
    console.log(`[场景1] 报警文案=${result.text}`);
    console.log(`[场景1] 报警HTML=${result.html}`);
    console.log(`[场景1] bp-节点列表=${JSON.stringify(result.bpNodes)}`);
    console.log(`[场景1] iframe数量=${result.frames}`);
    console.log(`[场景1] bridge调用=${JSON.stringify(result.calls)}`);

    clearTimeout(timer);
    await browser.close();
    return result;
  } catch (error) {
    clearTimeout(timer);
    console.error(`[场景1] 异常=${error.stack || error}`);
    await browser.close();
    throw error;
  }
}
module.exports = { run };