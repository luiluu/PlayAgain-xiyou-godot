'use strict';
// 【cc·悟空·未经审查】1 号孙悟空普攻（技能 1）打敌群 3（萌萌怪×3）第 1 只的伤害，拆开云裳专项里的几个条件逐项比（白龙 yunshang4 记的
// 「1 号基础伤害比原版高约 0.9%」）：云裳 174 在不在队（在就排第一）、全员生命 +1e12（_paramPlus[0]）、敌人物防 +5000（_paramPlus[3]）、1 号等级。
// 每例记 1 号与敌人 0 的 param(0..7)、xparam(0..9)、sparam(0..9)，再走真实 BattleManager.startAction 到行动结束，记 executeHpDamage 的值与暴击。
// 真实新局（Math.random 0.5），只在内存；产物 .sandbox/actor1_damage.json（generated/oracle/actor1_damage.json，tests/xiyou_actor1_damage.gd 读）。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
// 五乘区（installNativePowerZonesRuntime 的成长修正）不移植（数值平衡），伤害对照照 race_battle／attack_element 探针关掉
w.eval('CodexZones.ENABLED=false;');
const stub = new Proxy(function () {}, {get: (_, k) => k === '_waitCount' ? 0 : (() => false), set: () => true});
const sprites = new Map();
w.Game_Battler.prototype.battler = function () {
  if (!sprites.has(this)) sprites.set(this, new Proxy({x: 0, y: 0, _homeX: 0, _homeY: 0, width: 64, height: 64,
    scale: {x: 1, y: 1}, anchor: {x: 0.5, y: 1}, opacity: 255},
  {get: (t, k) => k in t ? t[k] : (() => false), set: (t, k, v) => {t[k] = v; return true;}}));
  return sprites.get(this);
};
w.BattleManager.actionBattleHud = () => true;
w.BattleManager.otbDisplayWindow = () => stub;
const TROOP = 3, BIG_HP = 1e12, DEF_PLUS = 5000;
const params = b => [0, 1, 2, 3, 4, 5, 6, 7].map(i => round(b.param(i)));
const xparams = b => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map(i => round(b.xparam(i)));
const sparams = b => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map(i => round(b.sparam(i)));
function battle(yun, bigHp, defPlus, level) {
  newGame();
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.$gameSwitches.setValue(2494, true);
  if (level > 1) w.$gameActors.actor(1).changeLevel(level, false);
  if (yun) {
    w.$gameParty.addActor(174);
    for (const list of [w.$gameParty._actors, w.$gameParty._battleMembers]) { list.splice(list.indexOf(174), 1); list.unshift(174); }
  }
  if (bigHp) for (const b of w.$gameParty.allMembers()) b._paramPlus[0] = BIG_HP;
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  for (const e of w.$gameTroop.members()) { e._paramPlus[0] = BIG_HP; if (defPlus) e._paramPlus[3] = DEF_PLUS; }
  for (const b of [...w.$gameParty.allMembers(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  bm.startTurn();
  return bm;
}
function act(bm, user, skillId, targetIndex) {
  const action = new w.Game_Action(user); action.setSkill(skillId); action.setTarget(targetIndex);
  user._actions = [action]; bm._subject = user; bm._action = null;
  bm.startAction();
  for (let i = 0; i < 20000; i++) {
    const ph = bm._phase;
    if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
    else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
  }
}
function record(fn) {
  const log = [], old = w.Game_Action.prototype.executeHpDamage;
  w.Game_Action.prototype.executeHpDamage = function (target, value) {
    log.push({skill: this.item().id, target: target.isActor() ? 'a' + target.actorId() : 'e' + target.index(), value: round(value), critical: !!target.result().critical});
    return old.apply(this, arguments);
  };
  try { fn(); } finally { w.Game_Action.prototype.executeHpDamage = old; }
  return log;
}
const cases = [];
for (const yun of [false, true]) for (const bigHp of [false, true]) for (const defPlus of [false, true]) for (const level of [1, 30]) {
  if (level === 30 && !(yun && bigHp && defPlus) && !(!yun && !bigHp && !defPlus)) continue;
  cases.push(makeCase(`atk.${yun ? 'yun' : 'solo'}.${bigHp ? 'hp' : 'base'}.${defPlus ? 'def' : 'nodef'}.l${level}`, {yun, bigHp, defPlus, level, troop: TROOP}, () => {
    const bm = battle(yun, bigHp, defPlus, level);
    const a = w.$gameActors.actor(1), e = w.$gameTroop.members()[0];
    const before = {members: w.$gameParty.battleMembers().map(b => b.actorId()), a: {param: params(a), xparam: xparams(a), sparam: sparams(a)},
      e: {param: params(e), xparam: xparams(e), sparam: sparams(e)}};
    a.setTp(a.maxTp()); a.setMp(a.mmp);
    const log = record(() => act(bm, a, 1, 0));
    return {...before, log};
  }));
}
process.exit(finish(host, 'actor1_damage.json', {hostScope: '正式 BattleManager.startAction／Game_Action（1 号普攻）', cases}) ? 0 : 1);
