'use strict';
// 【cc·白龙_7·未经审查】173 饿狼第三期：战斗内被动（js/codex/runtime/installNativeGarouRuntime.js 的 CodexGarou 战斗包装）：
// ① 饿狼拳法（HP 伤害）：进化层（命中后 +1，最多 3；伤害 ×(1＋层×(形态每层＋法宝每层)/100)）、解析层（每个命中目标 +1，最多 3；
//    无视物防／魔防 层×形态每层%）、神杀追击（解析满 3 的目标追加 10258，沿用施放开始时的进化层）、流水岩碎拳命中回 20 TP；
// ② 敌人 HP 伤害行动命中饿狼：受伤时进化 +1（每回合一次）、给出手的敌人加一层解析；33% 用流水岩碎拳反击，反击命中再加一层解析；
//    onTurnEnd 清「本回合受过伤」与琦玉模式；
// ③ itemCnt：饿狼不被原生反击；④ meetsSkillConditions：未到形态的拳法、追击 10258 不能用，认真一拳 10263 要琦玉模式（模式：琦玉 10262 命中自己）；
// ⑤ 结束战斗清进化、解析、琦玉。
// 真实 BattleManager／Game_Action（Math.random 0.5，反击例 0.1）；只在内存，产物 .sandbox/garou_battle.json，
// 拷成 tests/fixtures/garou_battle_oracle.json（不接入全量同步）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const G = w.CodexGarou;
if (!G || typeof G.finishAction !== 'function') throw new Error('饿狼模块未安装');
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
const ACTOR = 173, BIG_HP = 1e12, TROOP = 3;
const key = b => !b ? null : b.isActor() ? 'a' + b.actorId() : 'e' + b.index();

// 新局、开挑战开关 2494（饿狼是超强者）、形态 stage、level 级、招募（装上当前形态的破限之心）、队伍 [173, 1]；敌群 3 每只生命加 1e12
function battle(stage, level, relic) {
  newGame();
  w.$gameSwitches.setValue(2494, true);
  w.eval('$gameParty._actors=[];$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  const a = w.$gameActors.actor(ACTOR);
  a._AdvancedNum = stage;
  a.changeLevel(level, false);
  if (!G.recruit()) throw new Error('招募失败');
  if (!relic) a.changeEquip(a.equipSlots().indexOf(13), null);
  w.$gameParty.addActor(1);
  for (const id of [ACTOR, 1]) { const b = w.$gameActors.actor(id); b._paramPlus[0] = BIG_HP; }
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  w.CodexYunshang._acted = [];
  for (const e of w.$gameTroop.members()) e._paramPlus[0] = BIG_HP;
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  G.sync(a); G.clearBattle(a);
  return {bm, a, foes: w.$gameTroop.members()};
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
    log.push({user: key(this.subject()), skill: this.item().id, kind: this._garouTriggered || '', target: key(target), value, critical: !!target.result().critical});
    return old.apply(this, arguments);
  };
  try { fn(); } finally { w.Game_Action.prototype.executeHpDamage = old; }
  return log;
}
const snap = (a, foes) => ({evolution: a._garouEvolution || 0, analysis: foes.map(e => G.analysis(a, e)), tp: a.tp, received: !!a._garouReceivedThisRound, saitama: !!a._garouSaitama});
const cases = [];
cases.push(makeCase('module', {}, () => ({main: [0, 1, 2, 3, 4, 5, 6].map(st => [10250, 10251, 10252, 10253, 10255, 10255, 10259][st]),
  passives: G.config.stages.map(s => s.passives), relicEvolution: G.config.stages.map(s => s.relic.evolution_bonus_per_stack_percent)})));

// ① 主拳连打 5 次（每次前 TP 回满 100、MP 回满）
const CHAINS = [['s1', 1, 60, true], ['s2', 2, 60, true], ['s4', 4, 60, true], ['s4.norelic', 4, 60, false], ['s6', 6, 60, true]];
for (const [name, stage, level, relic] of CHAINS) {
  cases.push(makeCase(`chain.${name}`, {stage, level, relic, troop: TROOP, casts: 5}, () => {
    const {bm, a, foes} = battle(stage, level, relic);
    const skill = G.main(a), steps = [];
    for (let i = 0; i < 5; i++) {
      a.setTp(100); a.setMp(a.mmp);
      const log = record(() => act(bm, a, skill, 0));
      steps.push({log, ...snap(a, foes)});
    }
    return {skill, skills: a._skills.filter(id => id >= 10250 && id <= 10269).sort((x, y) => x - y), steps};
  }));
}
// 流水岩碎拳：命中回 20 TP（TP 从 0 起）
cases.push(makeCase('water.s0', {stage: 0, level: 20, relic: true, casts: 2}, () => {
  const {bm, a, foes} = battle(0, 20, true);
  a.setTp(0);
  const steps = [];
  for (let i = 0; i < 2; i++) steps.push({log: record(() => act(bm, a, 10250, 0)), ...snap(a, foes)});
  return {steps};
}));
// 全体拳：每个命中目标各加一层解析，进化只 +1
cases.push(makeCase('aoe.s3', {stage: 3, level: 60, relic: true, casts: 2}, () => {
  const {bm, a, foes} = battle(3, 60, true);
  const steps = [];
  for (let i = 0; i < 2; i++) { a.setTp(100); steps.push({log: record(() => act(bm, a, 10254, 0)), ...snap(a, foes)}); }
  return {steps};
}));
// ② 敌人打饿狼：两次同回合、回合结束、再一次；random 0.5 不反击，0.1 反击
for (const [name, rnd] of [['plain', 0.5], ['counter', 0.1]]) {
  cases.push(makeCase(`enemy.${name}`, {stage: 2, level: 60, relic: true, random: rnd}, () => {
    const {bm, a, foes} = battle(2, 60, true);
    w.Math.random = () => rnd;
    const steps = [];
    const hit = () => steps.push({log: record(() => act(bm, foes[0], 1, a.index())), ...snap(a, foes)});
    hit(); hit();
    a.onTurnEnd(); steps.push({turnEnd: true, ...snap(a, foes)});
    hit();
    w.Math.random = () => 0.5;
    return {steps};
  }));
}
// ③ itemCnt
cases.push(makeCase('cnt', {stage: 2, level: 60}, () => {
  const {a, foes} = battle(2, 60, true);
  const one = w.$gameActors.actor(1);
  const action = new w.Game_Action(foes[0]); action.setAttack();
  return {garou: action.itemCnt(a), other: action.itemCnt(one), garouCnt: a.cnt};
}));
// ④ 技能使用条件（TP、MP 满）
for (const stage of [0, 4, 6]) {
  cases.push(makeCase(`meets.s${stage}`, {stage, level: 60}, () => {
    const {bm, a, foes} = battle(stage, 60, true);
    const ids = []; for (let id = 10250; id <= 10263; id++) ids.push(id);
    const meets = () => { a.setTp(100); a.setMp(a.mmp); return ids.filter(id => a.meetsSkillConditions(w.$dataSkills[id])); };
    const out = {plain: meets()};
    if (stage === 6) {
      a.setTp(100);
      act(bm, a, 10262, a.index());
      out.afterMode = {saitama: !!a._garouSaitama, meets: meets()};
      a.setTp(100);
      const log = record(() => act(bm, a, 10263, 0));
      out.afterSerious = {saitama: !!a._garouSaitama, hits: log.length, meets: meets()};
      act(bm, a, 10262, a.index());
      a.onTurnEnd();
      out.afterTurn = {saitama: !!a._garouSaitama};
    }
    return out;
  }));
}
// ⑤ 结束战斗清数据
cases.push(makeCase('end', {stage: 2, level: 60}, () => {
  const {bm, a, foes} = battle(2, 60, true);
  a.setTp(100);
  act(bm, a, G.main(a), 0);
  const before = snap(a, foes);
  bm.endBattle(0);
  return {before, after: {evolution: a._garouEvolution || 0, analysis: (a._garouAnalysis || []).length, saitama: !!a._garouSaitama}};
}));
process.exit(finish(host, 'garou_battle.json', {hostScope: '真实 BattleManager／Game_Action（Math.random 0.5）；饿狼战斗内被动', cases}) ? 0 : 1);
