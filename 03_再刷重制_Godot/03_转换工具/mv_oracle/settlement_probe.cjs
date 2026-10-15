'use strict';
// 复核 dev.050：真实 makeDamageValue → onPreDamageStateEffects → onReactStateEffects。
// 正式数据库状态与敌人；只在内存把普攻公式固定为 1000000，去掉浮动和五乘区成长。
const fs = require('fs'), path = require('path');
const {boot} = require('./hboot.cjs'), {sourceIdentity} = require('./source_identity.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Applications/再刷一把：西游（mod_KYO）.app/Contents/Resources/app.nw';
const identity = sourceIdentity(APP), r = boot(APP, {tolerant: true, log: false}), w = r.window;
if (r.errors.length || !w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败');
w.eval('ConfigManager.applyData({});DataManager.setupNewGame();CodexZones.ENABLED=false;Math.random=function(){return 0.5;};');
w.$gameSystem.setDifficultyId(3);
const cases = [];
for (const actorStates of [[], [995,1631]]) for (const enemyStates of [[], [1103], [1460], [1103,1460]]) {
  const a = new w.Game_Actor(1); w.$gameActors._data[1] = a; // Game_Action.subject() 按角色 ID 从这里取人
  a._equips.forEach(e => e.setObject(null)); a._skills = []; a.clearStates();
  actorStates.forEach(id => a.addState(id)); a.initPassiveCache(); a.refreshPassiveCache(); a.refresh();
  w.Math.random = () => 0.99; w.$gameTroop.setup(173); w.Math.random = () => 0.5;
  const b = w.$gameTroop.members()[0]; b.clearStates();
  enemyStates.forEach(id => b.addState(id)); b.refresh(); b.refreshPassiveCache();
  const item = w.$dataSkills[1]; item.damage.formula = '1000000'; item.damage.variance = 0; item.damage.elementId = 1;
  const act = new w.Game_Action(a); act.setSkill(1);
  const gross = act.makeDamageValue(b, false);
  const confirmed = act.onPreDamageStateEffects(b, gross);
  const final = act.onReactStateEffects(b, confirmed);
  cases.push({actorStates, enemyStates, enemy: b.enemyId(), gross, flat: b._passiveCache.harmRe[1], confirmed, final});
}
if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
fs.writeFileSync(path.join(__dirname, '.sandbox/settlement.json'), JSON.stringify({sourceIdentity: identity, cases}, null, 1));
console.log(JSON.stringify(cases));
process.exit(0);
