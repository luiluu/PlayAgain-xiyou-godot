'use strict';
// 【cc·rules-fix9·未经审查】条件分歧 111 类型 5（敌人）在地图上的取值：正式引擎 Game_Interpreter.command111 读 $gameTroop.members()[序号]，
// 战斗结束（Scene_Battle.terminate → $gameTroop.onBattleEnd）不清空敌群，所以地图上看到的是上一场战斗的敌人；新游戏／读档后 $gameTroop 为空。
// 本探针在新游戏里依次量：没打过仗、打赢（敌人全死）、逃跑（敌人活着、带状态）后的取值，只打印，不写文件。
const {boot} = require('./hboot.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const r = boot(APP, {tolerant: true, log: false}), w = r.window;
w.eval('Math.random = function() { return 0.5; }; ConfigManager.applyData({}); DataManager.setupNewGame();');
w.DataManager.loadMapData(4); w.$gameMap.setup(4); w.$gameSystem._difficultyId = 3; for (const id of [1, 8, 10, 9]) w.$gameParty.addActor(id);
function cond(params) {
  const it = new w.Game_Interpreter(); it.setup([{code: 111, indent: 0, parameters: params}, {code: 0, indent: 1, parameters: []}, {code: 412, indent: 0, parameters: []}, {code: 0, indent: 0, parameters: []}], 0);
  it._params = params; it._indent = 0; it.command111();
  return !!it._branch[0];
}
const ask = tag => {
  const out = {tag, members: w.$gameTroop.members().length};
  for (const [k, p] of Object.entries({appear0: [5, 0, 0], dead0: [5, 0, 1, 1], appear1: [5, 1, 0], state0_s: [5, 0, 1, 4], dead5: [5, 5, 1, 1]})) out[k] = cond(p);
  out.states0 = w.$gameTroop.members()[0] ? w.$gameTroop.members()[0]._states.slice() : null;
  console.log(JSON.stringify(out));
};
ask('fresh');
const troop = w.$dataTroops.findIndex((t, i) => t && t.members && t.members.length >= 2 && i > 0);
// 打赢：开战、全部敌人死亡、走 Scene_Battle.terminate 里的两步
w.BattleManager.setup(troop, true, false); w.$gameParty.onBattleStart(); w.$gameTroop.onBattleStart();
w.$gameTroop.members().forEach(e => e.die());   // Game_BattlerBase.die：清状态后附加死亡（state 1）由 refresh 完成
w.$gameTroop.members().forEach(e => { e.addState(1); });
w.$gameParty.onBattleEnd(); w.$gameTroop.onBattleEnd();
ask('won troop ' + troop);
// 逃跑：敌人活着，0 号带状态 4
w.BattleManager.setup(troop, true, false); w.$gameParty.onBattleStart(); w.$gameTroop.onBattleStart();
w.$gameTroop.members()[0].addState(4);
const during = {}; for (const [k, p] of Object.entries({appear0: [5, 0, 0], state0_s: [5, 0, 1, 4]})) during[k] = cond(p);
console.log(JSON.stringify({tag: 'in battle', ...during, s4: w.$dataStates[4] && {removeAtBattleEnd: w.$dataStates[4].removeAtBattleEnd, name: w.$dataStates[4].name}, s1: w.$dataStates[1] && {removeAtBattleEnd: w.$dataStates[1].removeAtBattleEnd}}));
w.$gameParty.onBattleEnd(); w.$gameTroop.onBattleEnd();
ask('escaped');
// 隐藏敌人（中途出现的）：战斗结束后仍隐藏吗
w.BattleManager.setup(troop, true, false); w.$gameParty.onBattleStart(); w.$gameTroop.onBattleStart();
w.$gameTroop.members()[1].hide();
w.$gameParty.onBattleEnd(); w.$gameTroop.onBattleEnd();
console.log(JSON.stringify({tag: 'hidden1 after end', hidden1: w.$gameTroop.members()[1].isHidden(), appear1: cond([5, 1, 0]), src: String(w.Game_Enemy.prototype.onBattleEnd || w.Game_Battler.prototype.onBattleEnd).slice(0, 400)}));
process.exit(0);
