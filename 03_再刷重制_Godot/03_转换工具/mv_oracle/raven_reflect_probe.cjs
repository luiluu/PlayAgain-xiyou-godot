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
  runPhases(bm);
}
function runPhases(bm) {
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
// raven4（审查 43 P3-1）：跨行动。敌人 e0 在行动 N 打 8 号（必中、黑暗 1e6、加黑暗侵蚀 1663），tcr 0.01／2 决定受伤充 TP 是否在加状态前 refresh；
// 行动 N+1 由别人打 8 号（同槽、两段、不加状态），看第一击读到的是旧缓存（×1）还是新状态（×1.5）。between：direct＝直接下一次 startAction，
// turn＝中间 endTurn／startTurn，process＝e1 走真实 processTurn，self＝8 号自己先普攻一次，ally＝1 号队友打 8 号（单体友方），
// reflect＝行动 N 改成 8 号自己放魔法单体被反射回自己（reflect.turn／self／ally 同上面的 between）。
// rate＝各步之后 8 号对黑暗（9）的有效度（读缓存）。
function stateSkill(sk, o) {
  sk.damage.formula = o.formula || (o.small ? '100' : '1000000'); sk.damage.elementId = 9; sk.damage.critical = false; sk.damage.variance = 0; sk.damage.type = o.dmg === false ? 0 : 1;
  sk.effects = o.state ? [{code: 21, dataId: 1663, value1: 1, value2: 0}] : [];
  sk.scope = o.scope || 1; sk.repeats = o.repeats || 1; sk.hitType = 0; sk.successRate = 100; sk.mpCost = 0; sk.tpCost = 0; sk.tpGain = 0; sk.meta = {}; sk.note = '';
}
function seqBattle(tcr) {
  const {bm, a, foes} = xbattle(8, 60);
  a._paramPlus[0] = 2e6 - a.paramBase(0); a.need_refresh = true; a.refresh(); a.recoverAll(); a.setTp(0);  // 生命上限 2e6：受伤充 TP＝floor(50×伤害/2e6×tcr)，tcr 2 时 ≥1
  Object.defineProperty(a, 'tcr', {get: () => tcr, configurable: true});
  w.SceneManager._scene = {_otbDisplayWindow: stub};
  return {bm, a, foes, rate: () => a.elementRate(9)};
}
for (const [tcr, between] of [[0.01, 'direct'], [2, 'direct'], [2, 'turn'], [2, 'process'], [2, 'self'], [2, 'ally'], [2, 'reflect'], [2, 'reflect.turn'], [2, 'reflect.self'], [2, 'reflect.ally']]) {
  cases.push(makeCase(`refseq.tcr${tcr}.${between}`, {tcr, between}, () => {
    const {bm, a, foes, rate} = seqBattle(tcr);
    const sk = w.$dataSkills[10124], rates = {before: rate(), states0: a._states.slice()};
    stateSkill(sk, {state: true});
    let first;
    if (between.startsWith('reflect')) {  // 行动 N 是 8 号自己放魔法单体被反射回自己：自己是出手者，不在收尾 immortal: targets 的 refresh 里
      sk.hitType = 2; reflectOn(foes);
      first = record(() => act(bm, a, 10124, 0));
      reflectOn(foes, 0);
    } else first = record(() => act(bm, foes[0], 10124, 0));
    rates.afterN = rate(); const tp = a.tp;
    if (between.endsWith('turn')) { bm.endTurn(); bm.startTurn(); }
    if (between.endsWith('self')) act(bm, a, 1, 0);
    rates.between = rate();
    stateSkill(sk, between.endsWith('ally') ? {repeats: 2, scope: 7, formula: '100000'} : {repeats: 2});  // 队友出手不乘敌人的输出倍率，基伤小一档免得打倒 8 号
    let second;
    if (between === 'process') {
      const e = foes[1], x = new w.Game_Action(e); x.setSkill(10124); x.setTarget(0);
      second = record(() => { e._actions = [x]; bm._subject = e; bm._action = null; bm._phase = 'turn'; bm.processTurn(); runPhases(bm); });
    } else if (between.endsWith('ally')) second = record(() => act(bm, w.$gameActors.actor(1), 10124, 0));
    else second = record(() => act(bm, foes[1], 10124, 0));
    rates.after = rate();
    return {first, second, rates, tp, tpEnd: a.tp, states: a._states.slice()};
  }));
}
// raven4（审查 43 P3-2）：嵌套 apply 同一目标。e0 对 8 号的两段行动（加侵蚀），第一段的 applyItemUserEffect 里（同璇回光内置棱光的位置）
// 对 8 号再 apply 一次内层行动：hit＝内层黑暗伤害（不加状态），small＝内层伤害很小（TP 加 0），none＝内层不伤害也不加状态（不 refresh）。
// 看外层第二段读到的侵蚀（×1 晚一击还是 ×1.5）。
for (const [tcr, inner] of [[2, 'hit'], [2, 'small'], [2, 'none'], [0.01, 'hit']]) {
  cases.push(makeCase(`refnest.tcr${tcr}.${inner}`, {tcr, inner}, () => {
    const {bm, a, foes, rate} = seqBattle(tcr);
    const sk = w.$dataSkills[10124], sk2 = w.$dataSkills[10125];
    stateSkill(sk, {state: true, repeats: 2});
    stateSkill(sk2, {dmg: inner !== 'none', small: inner === 'small'});
    const old = w.Game_Action.prototype.applyItemUserEffect, rates = [];
    let nested = 0;
    w.Game_Action.prototype.applyItemUserEffect = function (target) {
      old.apply(this, arguments);
      if (nested || this.item().id !== 10124 || target !== a) return;
      nested++;
      rates.push(rate());
      try { const x = new w.Game_Action(foes[1]); x.setSkill(10125); x.apply(a); } finally { rates.push(rate()); }
    };
    let log;
    try { log = record(() => act(bm, foes[0], 10124, 0)); } finally { w.Game_Action.prototype.applyItemUserEffect = old; }
    return {log, rates, nested, after: rate(), tp: a.tp, states: a._states.slice()};
  }));
}
// raven5（审查 45 P3-1、P3-2）：
// mid.*：行动 N（同 refseq.reflect：8 号自己放魔法单体被反射回自己、加侵蚀，TP 先 refresh → 侵蚀陈旧，出手者不在收尾的 removeImmortal 里）之后，1 号队友对 8 号用一次不伤害的技能（10125 槽）：
//   buff＝加攻击 buff（效果 31）、heal＝回 HP 1000（效果 11）、healmp＝回 MP 100（效果 12）、state＝加一个没有特性的状态（效果 21）、none＝什么效果都没有；
//   再由 e1 打 8 号两段，看第一击读到旧缓存还是新状态（原版 addBuff／addState 自带 refresh、gainHp 走 setHp 的 refresh）。
// zero：8 号 TP 先设 99（第一击充满后 TP 不再变，不触发 setTp 的 refresh），e0 三段、每段致死（immortal 夹 0 血）并加侵蚀：
//   第二段请求的 hp 是负数、与 0 不同，原版 setHp 照样 refresh，第三段读新状态；只看扣完后的值变没变就不会清（审查 45 P3-1）。
function neutralState() {
  for (let i = 30; i < w.$dataStates.length; i++) {
    const st = w.$dataStates[i];
    if (st && st.name && !st.traits.length && !st.note && st.restriction === 0 && st.autoRemovalTiming === 0 && !st.removeAtBattleEnd) return i;
  }
  throw new Error('找不到没有特性的状态');
}
const NEUTRAL = neutralState();
for (const mid of ['none', 'buff', 'heal', 'healmp', 'state']) {
  cases.push(makeCase(`refmid.tcr2.${mid}`, {tcr: 2, mid, neutral: NEUTRAL}, () => {
    const {bm, a, foes, rate} = seqBattle(2);
    const sk = w.$dataSkills[10124], sk2 = w.$dataSkills[10125], rates = {before: rate()};
    stateSkill(sk, {state: true});
    sk.hitType = 2; reflectOn(foes);
    const first = record(() => act(bm, a, 10124, 0));
    reflectOn(foes, 0);
    rates.afterN = rate(); const tp = a.tp;
    stateSkill(sk2, {dmg: false, scope: 7});
    sk2.effects = {none: [], buff: [{code: 31, dataId: 2, value1: 5, value2: 0}], heal: [{code: 11, dataId: 0, value1: 0, value2: 1000}],
      healmp: [{code: 12, dataId: 0, value1: 0, value2: 100}], state: [{code: 21, dataId: NEUTRAL, value1: 1, value2: 0}]}[mid];
    act(bm, w.$gameActors.actor(1), 10125, 0);
    rates.between = rate();
    stateSkill(sk, {repeats: 2});
    const second = record(() => act(bm, foes[1], 10124, 0));
    rates.after = rate();
    return {first, second, rates, tp, tpEnd: a.tp, hp: a.hp, buffs: a._buffs.slice(), states: a._states.slice()};
  }));
}
// ev.*：同上，中间不经行动、直接调（战斗事件 313 改状态／311 改 HP／插件脚本的 addBuff 走的路径）：
//   evstate＝addState(没特性的状态)、evbuff＝addBuff(2,5)、evheal＝gainHp(1000)、evmp＝gainMp(100)、evtp＝gainTp(5)、evnone＝什么都不做
for (const mid of ['evnone', 'evstate', 'evbuff', 'evheal', 'evmp', 'evtp', 'evremove']) {
  cases.push(makeCase(`refmid.tcr2.${mid}`, {tcr: 2, mid, neutral: NEUTRAL}, () => {
    const {bm, a, foes, rate} = seqBattle(2);
    const sk = w.$dataSkills[10124], rates = {before: rate()};
    if (mid === 'evremove') a.addState(NEUTRAL);
    stateSkill(sk, {state: true});
    sk.hitType = 2; reflectOn(foes);
    const first = record(() => act(bm, a, 10124, 0));
    reflectOn(foes, 0);
    rates.afterN = rate(); const tp = a.tp;
    ({evnone: () => {}, evstate: () => a.addState(NEUTRAL), evbuff: () => a.addBuff(2, 5), evheal: () => a.gainHp(1000), evmp: () => a.gainMp(100),
      evtp: () => a.gainTp(5), evremove: () => a.removeState(NEUTRAL)})[mid]();
    rates.between = rate();
    stateSkill(sk, {repeats: 2});
    const second = record(() => act(bm, foes[1], 10124, 0));
    rates.after = rate();
    return {first, second, rates, tp, tpEnd: a.tp, hp: a.hp, buffs: a._buffs.slice(), states: a._states.slice()};
  }));
}
cases.push(makeCase('refzero.tcr2', {tcr: 2}, () => {
  const {bm, a, foes, rate} = seqBattle(2);
  a.setTp(99);
  const sk = w.$dataSkills[10124];
  stateSkill(sk, {state: true, repeats: 3, formula: '10000000'});
  const rates = [];
  const old = w.Game_Action.prototype.executeHpDamage;
  w.Game_Action.prototype.executeHpDamage = function (target, value) { rates.push(rate()); return old.apply(this, arguments); };
  let log;
  try { log = record(() => act(bm, foes[0], 10124, 0)); } finally { w.Game_Action.prototype.executeHpDamage = old; }
  return {log, rates, tp: a.tp, hp: a.hp, dead: a.isDead(), states: a._states.slice()};
}));
const ok0 = finish(host, 'raven_reflect.json', {cases});
process.exit(ok0 ? 0 : 1);
