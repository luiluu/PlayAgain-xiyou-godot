// 【Claude·未经Codex检验】参照引擎启动检查：加载全部插件与 Codex 模块，确认数据库与模块状态。
'use strict';
const {boot} = require('./hboot.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const t = Date.now();
const r = boot(APP, {tolerant: true, log: false});
const w = r.window;
const failed = w.CodexRuntime ? w.CodexRuntime.status().filter(m => m.state !== 'installed') : null;
console.log(JSON.stringify({ms: Date.now() - t, scripts: r.loaded.length, db: w.DataManager.isDatabaseLoaded(),
  plugins: w.$plugins.filter(p => p.status).length, modulesFailed: failed, errors: r.errors.slice(0, 10),
  version: w.nw.App.manifest.releaseVersion}));
process.exit(0);
