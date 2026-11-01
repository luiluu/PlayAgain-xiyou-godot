'use strict';
// 【cc·八戒·未经审查】三法宝成长（js/codex/runtime/installThreeGrowthRelicRuntime.js 的 R.syncItem：60 级进化，
// paramPlusPerLevel 由每级 18（定位四项 36）改为 36（72）、改名、改说明；changeLevel／levelUp／changeEquip／magicWeaponCustomParam
// 包装触发同步，进化一次后不退）。切片里只有谷雨 175 的百谷生 7912（屠苏 176 止戈环、璇 177 璇玑星盘不在切片）。
// 新局、难度 2、开 2494、G.recruit() 装上百谷生；谷雨改到各等级、法宝实例改到各等级，记八项能力、法宝名、说明、每级成长、进化标记。
// 只在内存，产物 .sandbox/three_growth.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const R = w.CodexThreeGrowth, G = w.Guyu;
if (!R || !G) throw new Error('三法宝成长／谷雨模块未安装');
if (!w.$) w.$ = {};
w.$.toaster = () => {};
const ID = 175, RELIC = 7912;

function setup() {
  newGame();
  w.eval('$gameSystem.setDifficultyId(2); $gameSwitches.setValue(2494, true); $gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  G._notifiedRelic = false; G.recruit();
  const a = w.$gameActors.actor(ID);
  const slot = a.equips().findIndex(x => x && (x.baseItemId || x.id) === RELIC);
  return {a, slot};
}
function snap(a, slot) {
  a.need_refresh = true; a.refresh();
  const x = a.equips()[slot];
  return {level: a.level, params: [0, 1, 2, 3, 4, 5, 6, 7].map(i => a.param(i)), name: x.name, description: x.description,
    perLevel: Array.from(x.paramPlusPerLevel || []), evolved: !!x._codex60Evolved, relicLevel: x.level,
    rates: (x.traits || []).filter(t => t.code === 21).map(t => [t.dataId, t.value])};
}
const cases = [];
for (const lv of [1, 59, 60, 70]) {
  for (const rl of [1, 10]) {
    cases.push(makeCase(`relic.lv${lv}.r${rl}`, {level: lv, relicLevel: rl}, () => {
      const {a, slot} = setup();
      a.changeLevel(lv, false);
      a.equips()[slot].level = rl;
      return snap(a, slot);
    }));
  }
}
// 原版缺陷（relic.lv1.r1 量得到）：招募生成的实例第一次同步按旧版倍率去重（备注认不出「额外四项」），生命 ×1.3、物防 ×1.2 各重复一条，
// 改过人物等级或法宝等级后 CP_MagicWeapon 重算才恢复；这期间生命按 ×1.6、物防按 ×1.4 算（rates 字段可见）
// 进化一次后不退：60 级进化，再降回 50 级
cases.push(makeCase('relic.down', {from: 60, to: 50, relicLevel: 5}, () => {
  const {a, slot} = setup();
  a.changeLevel(60, false); a.equips()[slot].level = 5; const at60 = snap(a, slot);
  a.changeLevel(50, false);
  return {at60, at50: snap(a, slot)};
}));
process.exit(finish(host, 'three_growth.json', {cases}) ? 0 : 1);
