'use strict';
// 战力覆盖说明参照（CV 2026-11-06，换源重取 tests/fixtures/power_coverage_oracle.json）：无画面引擎（mv_oracle/hboot.cjs）新开局，
// 对每个有名字的角色取 CodexCombatPower.actor(a,true).evaluation.coverage 的 unknown（尚未完整评估的技能名）与 unmodeled（[名字, 原因]）。
// 在 v0.28 冻结副本上跑的结果与原浏览器读数（八戒_8，2026-10-16）逐角色相同。hboot 的文件守卫只许写 mv_oracle/.sandbox：
// 写到 mv_oracle/.sandbox/power_coverage_oracle.json，看过再复制到 01_Godot工程/tests/fixtures/。
// 用法：XIYOU_APP=<app.nw> node power_coverage_ref.cjs
const fs = require('fs'), path = require('path');
const {boot} = require('../mv_oracle/hboot.cjs');
const APP = process.env.XIYOU_APP || path.resolve(__dirname, '../../02_内容与素材/冻结正式源/app.nw');
const out = path.resolve(__dirname, '../mv_oracle/.sandbox/power_coverage_oracle.json');
fs.mkdirSync(path.dirname(out), {recursive: true});
const r = boot(APP, {tolerant: true, log: false}), w = r.window;
if (!w.DataManager.isDatabaseLoaded() || !w.CodexCombatPower) throw new Error('参照引擎启动失败');
w.eval('ConfigManager.applyData({}); DataManager.setupNewGame();');
let version = 'v0.28';  // v0.50 起才有 data/ContentVersion.json
try { version = JSON.parse(fs.readFileSync(path.join(APP, 'data/ContentVersion.json'), 'utf8')).releaseVersion || version; } catch (e) { /* 旧源 */ }
const ids = [], actors = {}, routes = [];
for (let id = 1; id < w.$dataActors.length; id++) {
  if (!w.$dataActors[id] || !String(w.$dataActors[id].name || '').trim()) continue;
  ids.push(id);
  const ev = w.CodexCombatPower.actor(w.$gameActors.actor(id), true).evaluation, c = ev.coverage || {};
  const unknown = (c.unknown || []).map(x => String(x.name || x)), unmodeled = (c.unmodeled || []).map(x => [String(x.name), String(x.reason)]);
  if (unknown.length || unmodeled.length) actors[id] = {unknown, unmodeled};
  if ((ev.routes || []).length !== 1) routes.push([id, (ev.routes || []).length]);
}
fs.writeFileSync(out, JSON.stringify({source: `正式 ${version} 冻结副本，ui_reference/power_coverage_ref.cjs 无画面读数（CV 2026-11-06 换源重取；v0.28 上与 2026-10-16 八戒_8 浏览器读数逐角色相同）：新开局（DataManager.setupNewGame）$gameActors.actor(id) 初始状态下 CodexCombatPower.actor(a,true).evaluation.coverage 的 unknown（尚未完整评估的技能名）与 unmodeled（战力未计入：[名字, 原因]）；routes 不是 1 条的角色记在 routes。ids 为参与比对的全部角色，未列在 actors 的两项皆空。`, ids, actors, routes}) + '\n');
console.log(JSON.stringify({ids: ids.length, actors: Object.keys(actors).length, routes}));
process.exit(0);
