'use strict';
// 【cc·白龙_12·未经审查】168 米拉的深渊掉落（js/codex/runtime/installNativeMiraRuntime.js 第 392～401 行，BattleManager.makeRewards 包装）：
// MapInfos 名字以「深渊」开头的地图上，makeRewards 时 Math.randomInt(30)===0 就在奖励物品里多加黑龙进阶石 2903。
// 真实 BattleManager.makeRewards（敌群 3），Math.random 取 0（必中）、0.0333（=1/30 边上，不中）、0.5；地图 37（深渊:无垠虚空）、58（深渊:众神黄昏）、4（非深渊）。
// 只在内存，产物 .sandbox/mira_abyss.json，拷成 tests/fixtures/mira_abyss_oracle.json（不接入全量同步），专项 xiyou_mira_abyss。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const cases = [];
for (const map of [37, 58, 4]) for (const roll of [0, 0.0333, 0.034, 0.5]) cases.push(makeCase(`abyss.m${map}.r${roll}`, {map, roll}, () => {
  newGame();
  w.DataManager.loadMapData(map); w.$gameMap.setup(map);
  w.BattleManager.setup(3, false, false);
  w.eval('Math.random=function(){return ' + roll + ';};');
  // 敌人原生掉落另走 Math.random：先把敌群的掉落表清空，只看包装加的那一件
  for (const e of w.$gameTroop.members()) { e.makeDropItems = () => []; e.die && e.die(); }
  w.BattleManager.makeRewards();
  w.eval('Math.random=function(){return 0.5;};');
  const items = w.BattleManager._rewards.items.map(i => i.id);
  return {name: w.$dataMapInfos[map].name, stone: items.filter(id => id === 2903).length, items};
}));
process.exit(finish(host, 'mira_abyss.json', {hostScope: '真实 BattleManager.makeRewards；Math.random 固定', cases}) ? 0 : 1);
