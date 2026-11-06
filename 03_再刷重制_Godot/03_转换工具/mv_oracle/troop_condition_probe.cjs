'use strict';
// 【cc·rules-fix9·未经审查】条件分歧 111 类型 5（敌人）在地图上的取值：正式引擎 Game_Interpreter.command111 读 $gameTroop.members()[序号]，
// 战斗结束（Scene_Battle.terminate → $gameTroop.onBattleEnd）不清空敌群，所以地图上看到的是上一场战斗的敌人；新游戏／读档后 $gameTroop 为空。
// 在新游戏里依次量：没打过仗、打赢（敌人全死）、逃跑（敌人活着、0 号带中毒 4）、隐藏成员（战斗中 hide）结束后的取值。
// 冻结 v0.28 参照：结果写 .sandbox/troop_condition.json，人工复制成 01_Godot工程/tests/fixtures/troop_condition_oracle.json（xiyou_troop_condition 读）。
const fs = require('fs'), path = require('path');
const {boot} = require('./hboot.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const r = boot(APP, {tolerant: true, log: false}), w = r.window;
w.eval('Math.random = function() { return 0.5; }; ConfigManager.applyData({}); DataManager.setupNewGame();');
w.DataManager.loadMapData(4); w.$gameMap.setup(4); w.$gameSystem._difficultyId = 3; for (const id of [1, 8, 10, 9]) w.$gameParty.addActor(id);
function cond(params) {
  const it = new w.Game_Interpreter();
  it.setup([{code: 111, indent: 0, parameters: params}, {code: 0, indent: 1, parameters: []}, {code: 412, indent: 0, parameters: []}, {code: 0, indent: 0, parameters: []}], 0);
  it._params = params; it._indent = 0; it.command111();
  return !!it._branch[0];
}
const QUERIES = {appear0: [5, 0, 0], dead0: [5, 0, 1, 1], appear1: [5, 1, 0], state0_4: [5, 0, 1, 4], dead5: [5, 5, 1, 1]};
const ask = () => Object.fromEntries(Object.entries(QUERIES).map(([k, p]) => [k, cond(p)]));
const troop = w.$dataTroops.findIndex((t, i) => i > 0 && t && t.members && t.members.length >= 2);
function fight(during) {
  w.BattleManager.setup(troop, true, false); w.$gameParty.onBattleStart(); w.$gameTroop.onBattleStart();
  during(w.$gameTroop.members());
  w.$gameParty.onBattleEnd(); w.$gameTroop.onBattleEnd();   // Scene_Battle.terminate
}
const out = {troop, queries: QUERIES, fresh: ask()};
fight(ms => ms.forEach(e => e.addState(1)));
out.won = ask(); out.wonMembers = w.$gameTroop.members().length;
fight(ms => ms[0].addState(4));
out.escaped = ask(); out.state4RemoveAtBattleEnd = !!w.$dataStates[4].removeAtBattleEnd;
fight(ms => ms[1].hide());
out.hidden1 = ask();
const OUT = path.join(__dirname, '.sandbox/troop_condition.json');
fs.mkdirSync(path.dirname(OUT), {recursive: true});
fs.writeFileSync(OUT, JSON.stringify(out, null, 1) + '\n');
console.log(JSON.stringify(out));
process.exit(0);
