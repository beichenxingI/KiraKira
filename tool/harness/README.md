# 无头脚本房验证台

## 运行

```powershell
node tool/harness/run.js daoyuan_alerts
```

引擎使用固定版本 Playwright 的 headless Chromium。`env.js` 启动真实 Chromium 页面，注入从真实源提取的 facade，并由场景加载真实的 `DiaoYan/scripts/daoyuan_helper.js`；不保存业务 JS 副本。

桥 mock 默认对未配置请求抛错，不返回空数组。

## 当前状态

Chromium 浏览器尚未下载成功时，场景无法验收。下载命令：

```powershell
npx playwright install chromium
```

## 能测与不能测

能测：脚本侧判断逻辑、facade 行为、真实 Chromium 的 iframe/module/blob/fetch/timer 基础行为、影子 DOM 交互、脚本间数据流和事件时序。

不能测：真实 Flutter 数据正确性、Android WebView 与桌面 Chromium 的全部差异、renderer 崩溃、真实网络/LLM 调用。最终仍需真机确认。
