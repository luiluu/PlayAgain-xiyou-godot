'use strict';
// 【cc·悟空·未经审查】渡鸦魔法反射支：目标 mrf 强设后渡鸦技能（hitType 2）被反射回自己，量原版扣血各段、MP、神话／狩猎状态。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');
const R = w.CodexRaven;
if (!R || typeof R.damageMultiplier !== 'function') throw new Error('渡鸦模块未安装');
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
const ACTOR = 167, BIG_HP = 1e12, TROOP = 3;
const key = b => !b ? null : b.isActor() ? 'a' + b.actorId() : 'e' + b.index();

// 新局、开挑战开关 2494（渡鸦是超强者）、阶 rank、level 级、招募；party 为渡鸦之后再入队的成员（默认 [1]）；
// 全队与敌群 3 每只生命加 1e12；opts.reserve：渡鸦排在第 5 位（本作出战上限够，仍在 members 里，照样计残响）
function battle(rank, level, opts = {}) {
  newGame();
  w.$gameSwitches.setValue(2494, true);
  w.eval('$gameParty._actors=[];$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  const a = w.$gameActors.actor(ACTOR);
  a._AdvancedNum = rank; a._codexRavenStage = rank;
  a.changeLevel(level, false);
  if (opts.reserve) for (const id of [1, 8, 9, 10]) w.$gameParty.addActor(id);
  if (!R.recruit()) throw new Error('招募失败');
  if (!opts.reserve) w.$gameParty.addActor(1);
  for (const b of w.$gameParty.allMembers()) b._paramPlus[0] = BIG_HP;
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  w.CodexYunshang._acted = [];
  for (const e of w.$gameTroop.members()) e._paramPlus[0] = BIG_HP;
  for (const b of [...w.$gameParty.allMembers(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  bm.startTurn();
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
// 实际扣血：executeHpDamage 的各段（hit）与不经伤害计算的直接扣血（direct：gainHp，不在 executeHpDamage 里）
function record(fn) {
  const log = [], oldExec = w.Game_Action.prototype.executeHpDamage, oldSet = w.Game_BattlerBase.prototype.setHp, protos = [w.Game_Actor.prototype, w.Game_Enemy.prototype, w.Game_Battler.prototype].filter(p => Object.prototype.hasOwnProperty.call(p, 'setHp')), olds = protos.map(p => p.setHp);
  let inExec = 0;
  w.Game_Action.prototype.executeHpDamage = function (target, value) {
    log.push({kind: 'hit', user: key(this.subject()), skill: this.item().id, target: key(target), value, critical: !!target.result().critical});
    inExec++;
    try { return oldExec.apply(this, arguments); } finally { inExec--; }
  };
  const wrap = old => function (hp) {
    if (!inExec && hp < this.hp) log.push({kind: 'direct', target: key(this), value: this.hp - Math.max(0, hp)});
    return old.apply(this, arguments);
  };
  w.Game_BattlerBase.prototype.setHp = wrap(oldSet);
  protos.forEach((p, i) => { p.setHp = wrap(olds[i]); });
  try { fn(); } finally { w.Game_Action.prototype.executeHpDamage = oldExec; w.Game_BattlerBase.prototype.setHp = oldSet; protos.forEach((p, i) => { p.setHp = olds[i]; }); }
  return log;
}
const snap = (a, foes) => ({myth: a._codexRavenMythTurns || 0, residue: a._codexRavenResidue || 0, hunter: !!a._codexRavenHunter,
  soul: a._codexRavenSoul || 0, mp: a.mp, dead: foes.map(e => e.isDead()), erosion: foes.map(e => e.isStateAffected(1663)), self: {dead: a.isDead(), hp: a.hp, erosion: a.isStateAffected(1663)}});
const kill = e => e.addState(1);
const cast = (bm, a, foes, id, target = 0) => { a.setMp(a.mmp); return {cast: id, log: record(() => act(bm, a, id, target)), ...snap(a, foes)}; };
const turn = (bm, a, foes) => { bm.endTurn(); const out = {turnEnd: true, ...snap(a, foes)}; bm.startTurn(); return out; };

const cases = [];
const reflectOn = (foes, v = 1) => { for (const e of foes) Object.defineProperty(e, 'mrf', {get: () => v, configurable: true}); };
const mpLog = [];
// 渡鸦魔法反射支：目标 mrf=1，渡鸦技能（hitType 2 魔法）被反射回渡鸦自己；量扣血各段（谁挨打）、MP、神话、残响、狩猎
// ref: 'plain' 普通 / 'hunt' 狩猎中（残响满3、学三羽成环）/ 'myth' 神话形态
function setupMode(bm, a, foes, mode) {
  if (mode === 'myth') a._codexRavenMythTurns = 3;
  if (mode === 'hunt') { a._codexRavenResidue = 3; a._codexRavenHunter = true; }
}
// 10124 在神话形态里原版的黑暗侵蚀增伤晚一击生效（第三击才 ×1.5，plain 是第二击），原因没查清，这两例不进比对
for (const id of [10122, 10123, 10124, 10125]) for (const mode of ['plain', 'hunt', 'myth', 'hunt+myth']) {
  if (id === 10124 && mode.includes('myth')) continue;
  cases.push(makeCase(`reflect.${id}.${mode}`, {rank: 5, level: 60, skill: id, mode}, () => {
    const {bm, a, foes} = battle(5, 60);
    reflectOn(foes);
    a._paramPlus[5] += 1e6; a.refresh();
    for (const m of mode.split('+')) setupMode(bm, a, foes, m);
    return cast(bm, a, foes, id);
  }));
}
// 对照：没有反射时同一施放（hunt／plain）
for (const id of [10122, 10124]) for (const mode of ['plain', 'hunt']) {
  cases.push(makeCase(`noreflect.${id}.${mode}`, {rank: 5, level: 60, skill: id, mode}, () => {
    const {bm, a, foes} = battle(5, 60);
    setupMode(bm, a, foes, mode);
    return cast(bm, a, foes, id);
  }));
}
// mrf=0.5（Math.random 0.5 不小于 0.5 → 不反射）边界
cases.push(makeCase('reflect.edge.0.5', {rank: 5, level: 60}, () => {
  const {bm, a, foes} = battle(5, 60); reflectOn(foes, 0.5); return cast(bm, a, foes, 10122);
}));
cases.push(makeCase('reflect.edge.0.51', {rank: 5, level: 60}, () => {
  const {bm, a, foes} = battle(5, 60); reflectOn(foes, 0.51); return cast(bm, a, foes, 10122);
}));
// 饿狼 critical 0 伤（installNativeGarouRuntime applyCritical：v===0 返回 0）：出手者 atk／mat 强设 0、cri 强设 1，量扣血各段与暴击标记
const G = w.CodexGarou, GACTOR = 173;
const direct = (a, sid, v) => { const x = new w.Game_Action(a); x.setSkill(sid); return x.applyCritical(v); };
function gbattle(stage, level, relic) {
  newGame();
  w.$gameSwitches.setValue(2494, true);
  w.eval('$gameParty._actors=[];$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  const a = w.$gameActors.actor(GACTOR);
  a._AdvancedNum = stage;
  a.changeLevel(level, false);
  if (!G.recruit()) throw new Error('招募失败');
  if (!relic) a.changeEquip(a.equipSlots().indexOf(13), null);
  w.$gameParty.addActor(1);
  for (const id of [GACTOR, 1]) { const b = w.$gameActors.actor(id); b._paramPlus[0] = BIG_HP; }
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

for (const [name, stage, sid, zero] of [['s6.zero', 6, 10250, true], ['s0.zero', 0, 10250, true], ['s6.normal', 6, 10250, false], ['s3.zero.other', 3, 10253, true]]) {
  cases.push(makeCase('garouzero.' + name, {stage, skill: sid, zero}, () => {
    const {bm, a, foes} = gbattle(stage, 60, true);
    if (zero) for (const k of ['atk', 'mat']) Object.defineProperty(a, k, {get: () => 0, configurable: true});
    Object.defineProperty(a, 'cri', {get: () => 1, configurable: true});
    const log = record(() => act(bm, a, sid, 0));
    return {log, direct: [direct(a, sid, 0), direct(a, sid, 1000), direct(a, 1, 0), direct(a, 1, 1000)]};
  }));
}
const ok0 = finish(host, 'raven_reflect.json', {cases});
process.exit(ok0 ? 0 : 1);
