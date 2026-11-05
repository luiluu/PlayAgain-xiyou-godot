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
// raven2：10124 神话形态两例恢复（原版黑暗侵蚀增伤晚一击，查因见交付单）
for (const id of [10122, 10123, 10124, 10125]) for (const mode of ['plain', 'hunt', 'myth', 'hunt+myth']) {
  cases.push(makeCase(`reflect.${id}.${mode}`, {rank: 5, level: 60, skill: id, mode}, () => {
    const {bm, a, foes} = battle(5, 60);
    reflectOn(foes);
    a._paramPlus[5] += 1e6; a.refresh();
    for (const m of mode.split('+')) setupMode(bm, a, foes, m);
    return cast(bm, a, foes, id);
  }));
}
// raven2：黑暗侵蚀晚一击的原因＝krz 状态缓存时序。伤害充 TP（floor(50×伤害/mhp×tcr)≥1）会在同一击加侵蚀前消耗待刷新标记，
// 侵蚀的 ×1.5 晚一击；与神话形态无关（神话只是伤害更大）。用 tcr 强设扫过 TP 加 0／1 的边界（普通形态、神话形态各几例）
for (const [mode, tcr] of [['plain', 0.01], ['plain', 1.1], ['plain', 1.5], ['plain', 2], ['myth', 0.01], ['myth', 1], ['hunt+myth', 0.01]]) {
  cases.push(makeCase(`reflect.tcr.${tcr}.${mode}`, {rank: 5, level: 60, skill: 10124, mode, tcr}, () => {
    const {bm, a, foes} = battle(5, 60);
    reflectOn(foes);
    a._paramPlus[5] += 1e6; a.refresh();
    for (const m of mode.split('+')) setupMode(bm, a, foes, m);
    Object.defineProperty(a, 'tcr', {get: () => tcr, configurable: true});
    const out = cast(bm, a, foes, 10124);
    out.tp = a.tp; out.mhp = a.mhp;
    return out;
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
// raven2（审查 42 P3②）：别的有 Game_Action.apply／makeDamageValue 包装的角色被魔法反射时有没有同类差异：
// 云裳 174（穿针 10270、断锦 10271）、饿狼 173（核分裂 10259、伽马射线暴 10261）；甚尔 171 的魔法技能 10224／10232／10233 伤害为 0（反弹／神灶），
// 饿狼其余拳法与镜流 170 全是物理或必中（hitType 0／1），不会被魔法反射。量扣血各段（谁挨打、绝对值）、出手者生命／MP、身上状态。
function xbattle(id, level) {
  newGame();
  w.$gameSwitches.setValue(2494, true);
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.eval('$gameParty._actors=[' + id + ',1]; $gameParty._battleMembers=[' + id + ',1,0,0,0];');
  for (const b of [id, 1]) { const x = w.$gameActors.actor(b); x.changeLevel(level, false); x.recoverAll(); }
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) b._paramPlus[0] = BIG_HP;
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  w.$gameParty._inBattle = true;
  w.CodexYunshang._acted = [];
  bm.startTurn();
  return {bm, a: w.$gameActors.actor(id), foes: w.$gameTroop.members()};
}
for (const [nm, id, sk] of [['yunshang', 174, 10270], ['yunshang', 174, 10271], ['garou', 173, 10259], ['garou', 173, 10261]]) for (const refl of [false, true]) {
  cases.push(makeCase(`refx.${nm}.${sk}.${refl ? 'reflect' : 'plain'}`, {actor: id, level: 55, skill: sk, reflect: refl}, () => {
    const {bm, a, foes} = xbattle(id, 55);
    a.learnSkill(sk); a.setMp(a.mmp); a.setTp(0);
    if (refl) reflectOn(foes);
    const log = record(() => act(bm, a, sk, 0));
    return {log, hp: a.hp, mp: a.mp, states: a._states.slice(), foeStates: foes.map(e => e._states.slice()), foeHp: foes.map(e => e.hp)};
  }));
}
// raven2→3：多段／反射加状态的通用情形（不限渡鸦）。借 10124 的数据槽临时改成「全体、魔法、黑暗、固定伤害 1e7、效果加黑暗侵蚀 1663」，
// 普通角色 1 号出手，反射回自己；tcr 强设 0.01（受伤充 TP 加 0）与 2（加 ≥1）。量出：加状态前若同一次 apply 里 TP 已 refresh，
// 状态特性晚一击（krz 状态缓存时序，与渡鸦无关，见交付单）。
for (const [tcr, refl] of [[0.01, false], [0.01, true], [2, false], [2, true]]) {
  cases.push(makeCase(`refstate.tcr${tcr}.${refl ? 'reflect' : 'plain'}`, {tcr, reflect: refl}, () => {
    const {bm, a, foes} = xbattle(8, 60);
    const sk = w.$dataSkills[10124];
    sk.damage.formula = '10000000'; sk.damage.elementId = 9; sk.effects = [{code: 21, dataId: 1663, value1: 1, value2: 0}];
    sk.scope = 2; sk.repeats = 1; sk.hitType = 2; sk.mpCost = 0; sk.tpCost = 0; sk.meta = {}; sk.note = '';
    a.learnSkill(10124); a.setMp(a.mmp); a.setTp(0);
    Object.defineProperty(a, 'tcr', {get: () => tcr, configurable: true});
    if (refl) reflectOn(foes);
    const log = record(() => act(bm, a, 10124, 0));
    return {log, hp: a.hp, mp: a.mp, states: a._states.slice(), foeStates: foes.map(e => e._states.slice()), foeHp: foes.map(e => e.hp)};
  }));
}
const ok0 = finish(host, 'raven_reflect.json', {cases});
process.exit(ok0 ? 0 : 1);
