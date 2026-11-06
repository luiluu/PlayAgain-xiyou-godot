'use strict';
// 【cc·悟空·未经审查】179 流萤第二期（同一运行时）；第一期见 liuying_probe.cjs。下面第一段注释是第一期的，第二期例见文末
// 第一期原注释：179 流萤第一期（v0.62.12 js/codex/runtime/installLiuyingRuntime.js 的 W.CodexLiuying，运行时 1.2.0）：
// ① 学忘同步 L.sync（changeLevel／levelUp 触发；按等级 1／20／35、进阶 1／2／3 学忘 10622～10632＋梦应）、学 10628 连带学梦应；
// ② 能力值：param 生命／敏捷倍率与攻击 +5000、paramPlus 逐火生命与专武攻击／敏捷 30×等级、shieldEffectBonus、actionPlusSet；
// ③ 逐火 gainRewards：前 2000 场每场 +10，之后 10×2000/已胜场数；缺 wins 时按生命÷10 估一次；
// ④ 公式 CodexLiuying.damage（战斗外：护盾、_codexLbCastShield）与 AI 估值；⑤ 招募（专武 4004、法宝 4582）；
// ⑥ 战斗：必中、段数（天火 5／8、燃烧 9）、天火要剑；伤害钩子比值（每次新开一场，只取天火第一段：印记、付费、再释放是第二期）。
// 真实 BattleManager／Game_Action（Math.random 0.5：再释放 0.2 不触发）；只在内存，产物 .sandbox/liuying.json，拷成 tests/fixtures/liuying_oracle.json。
// 跑法：XIYOU_APP=…/冻结正式源/v0.62.12/app.nw node liuying_probe.cjs
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const L = w.CodexLiuying;
if (!L || typeof L.damage !== 'function') throw new Error('流萤模块未安装');
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
w.Math.random = () => 0.5;
w.eval('CodexZones.ENABLED=false;');  // 五乘区（CodexZones）重制不移植（O-044）：关掉让参照不含成长修正（专武品质 9 会改它）
const ACTOR = 179, WEAPON = 4004, ARMOR = 4582, BIG_HP = 1e12, TROOP = 3;
const P = L.passives, MENG = L.mengYingId();
const LIST = [10622, 10623, 10624, 10625, 10626, 10627, 10628, 10629, 10630, 10631, 10632, MENG];
const key = b => !b ? null : b.isActor() ? 'a' + b.actorId() : 'e' + b.index();
const skills = a => a._skills.filter(id => LIST.includes(id)).sort((x, y) => x - y);
const params = a => [0, 1, 2, 3, 4, 5, 6, 7].map(i => a.param(i));
const fresh = () => {
  newGame();
  w.eval('$gameParty._actors=[];$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.$gameSwitches.setValue(2494, true);  // 流萤是超强者（installBossDifficultyRuntime 包了 recruit／addActor），开挑战才能招募
  return w.$gameActors.actor(ACTOR);
};
const slotOf = (a, base) => a.equipSlots().indexOf(base.etypeId);
const worn = (a, base) => { const e = a.equips()[slotOf(a, base)]; return e ? Number(e.originalBaseItemId || e.baseItemId || e.id) : 0; };
const setPassives = (a, on) => { for (const id of [P.guoZai, P.ziXian, P.chiRan, P.zhuiLuo, P.xingHe, P.feiYing, P.changYe, P.mingTian]) {
  if (on.includes(id)) { if (!a.isLearnedSkill(id)) a._skills.push(id); } else a._skills = a._skills.filter(x => x !== id);
} a.refresh(); };
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
    log.push({user: key(this.subject()), skill: this.item().id, target: key(target), value, critical: !!target.result().critical});
    return old.apply(this, arguments);
  };
  try { fn(); } finally { w.Game_Action.prototype.executeHpDamage = old; }
  return log;
}

const cases = [];
const ST = L.states, FIRE = L.fireflyStateId();
const NEG = 32;  // 破胆（<BuffType:损伤>，负面）
// 战斗：level／rank、招募（专武＋法宝）、被动 on（null＝按学忘）；再入队 1。敌群 3 每只生命加 1e12；角色 1 生命加 1e12；流萤生命不加（伤害别把敌人打死）
function battle(level, rank, on, opts = {}) {
  const a = fresh(); a._AdvancedNum = rank; a.changeLevel(level, false);
  if (!L.recruit()) throw new Error('招募失败');
  if (opts.noArmor) a.changeEquip(slotOf(a, w.$dataArmors[ARMOR]), null);
  if (on) setPassives(a, on);
  w.$gameParty.addActor(1);
  w.$gameActors.actor(1)._paramPlus[0] = BIG_HP;
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(opts.troop || TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  if (w.CodexYunshang) w.CodexYunshang._acted = [];
  for (const e of w.$gameTroop.members()) e._paramPlus[0] = BIG_HP;
  for (const b of [...w.$gameParty.allMembers(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  bm.startBattle && 0;
  for (const m of w.$gameParty.battleMembers()) m.onBattleStart();
  bm.startTurn();
  return {bm, a, foes: w.$gameTroop.members()};
}
const st = b => b._states.slice().sort((x, y) => x - y);
function snap(a, foes) {
  return {hp: a.hp, mhp: a.mhp, shield: a._shield || 0, states: st(a), rsReady: a._codexLbRsReady || 0, turn: w.$gameTroop.turnCount(),
    firefly: w.$gameTroop._codexLbFirefly || 0, meets: [10622, 10623].map(id => a.meetsSkillConditions(w.$dataSkills[id])),
    battler: a.battlerName(), a1: {hp: w.$gameActors.actor(1).hp, states: st(w.$gameActors.actor(1))},
    foes: foes.map(e => ({hp: e.hp, alive: e.isAlive(), marks: L.markCount(e), states: st(e), lock: e._codexLbStunLock == null ? null : e._codexLbStunLock}))};
}
const cast = (bm, a, foes, id, t = 0) => ({cast: id, log: record(() => act(bm, a, id, t)), ...snap(a, foes)});
const step = (name, a, foes, fn) => { const out = fn ? fn() : undefined; return {step: name, out: out === undefined ? null : out, ...snap(a, foes)}; };

// ① 开战：形态、负面免疫、免死（二阶学了飞萤）；负面状态加不上、正面照常；SV 图
cases.push(makeCase('form.start', {level: 60, rank: 2}, () => {
  const {bm, a, foes} = battle(60, 2);
  const steps = [step('start', a, foes)];
  steps.push(step('addNeg', a, foes, () => { a.addState(NEG); return a.isStateAffected(NEG); }));
  steps.push(step('addable', a, foes, () => [a.isStateAddable(NEG), a.isStateAddable(29)]));
  bm.endBattle(0);
  steps.push(step('end', a, foes));
  return {steps};
}));
// 不戴法宝不变身；没学飞萤（一阶）不免疫
cases.push(makeCase('form.noArmor', {level: 60, rank: 1}, () => {
  const {bm, a, foes} = battle(60, 1, null, {noArmor: true});
  const s = [step('start', a, foes), step('addNeg', a, foes, () => { a.addState(NEG); return a.isStateAffected(NEG); })];
  bm.endBattle(0);
  return {steps: s};
}));
// ② 天火：付 5% 当前生命转护盾、主目标 +1 印记、扩散；再放天火 → 2 层；萤火（二阶学了梦应）
cases.push(makeCase('cast.tianhuo', {level: 60, rank: 2}, () => {
  const {bm, a, foes} = battle(60, 2);
  const steps = [step('start', a, foes), cast(bm, a, foes, 10622, 0), cast(bm, a, foes, 10622, 1)];
  bm.endBattle(0);
  steps.push(step('end', a, foes));
  return {steps};
}));
// ③ 完全燃烧（二阶）：消耗自身护盾、回满生命、冷却 4 自然回合；+5 印记只给第一个打中的
cases.push(makeCase('cast.ranshao', {level: 60, rank: 2}, () => {
  const {bm, a, foes} = battle(60, 2);
  const steps = [cast(bm, a, foes, 10622, 0)];
  a._shield = (a._shield || 0) + 5000; a._hp = Math.floor(a.mhp / 2);
  steps.push(step('prep', a, foes));
  steps.push(cast(bm, a, foes, 10623, 0));
  for (let i = 0; i < 4; i++) { bm.endTurn && 0; w.$gameTroop.increaseTurn(); steps.push(step('turn', a, foes)); }
  return {steps};
}));
// ④ 三阶燃烧：护盾不消耗、加等量（上限 50% 最大生命）；冷却 3（Math.random 0.5 不免冷却）
cases.push(makeCase('cast.ranshao.r3', {level: 60, rank: 3}, () => {
  const {bm, a, foes} = battle(60, 3);
  a._shield = 8000;
  const steps = [step('prep', a, foes), cast(bm, a, foes, 10623, 0)];
  a._shield = 9e9;
  steps.push(step('big', a, foes));
  a._codexLbRsReady = 0;
  steps.push(cast(bm, a, foes, 10623, 0));
  return {steps};
}));
// ⑤ 引爆：设 11 层后天火 → 12 层引爆（最大生命×6 真伤、强制眩晕、2 回合锁）；锁内再引爆不眩晕；驱散、清状态挡不掉印记；减疗
cases.push(makeCase('mark.explode', {level: 60, rank: 2}, () => {
  const {bm, a, foes} = battle(60, 2);
  const e = foes[0], steps = [cast(bm, a, foes, 10622, 0)];
  e._codexLbMark = 11;
  steps.push(cast(bm, a, foes, 10622, 0));
  steps.push(step('removeStun', a, foes, () => { e.removeState(29); return e.isStateAffected(29); }));
  e.addState(ST.mark); e._codexLbMark = 11;
  steps.push(cast(bm, a, foes, 10622, 0));
  const f = foes[1]; f.addState(ST.mark); f._codexLbMark = 3;
  steps.push(step('dispel', a, foes, () => { f.removeState(ST.mark); f.eraseState(ST.mark); return [f.isStateAffected(ST.mark), L.markCount(f)]; }));
  steps.push(step('clear', a, foes, () => { f.clearStates(); return [f.isStateAffected(ST.mark), L.markCount(f)]; }));
  steps.push(step('heal', a, foes, () => { f._hp = f.mhp - 1e6; f.gainHp(100000); return f.mhp - f.hp; }));
  steps.push(step('healPlain', a, foes, () => { const g = foes[2]; g._hp = g.mhp - 1e6; g.gainHp(100000); return g.mhp - g.hp; }));
  bm.endBattle(0);
  steps.push(step('end', a, foes));
  return {steps};
}));
// ⑥ 印记易伤：角色 1 普攻打 0 层与 6 层的敌人（第一段伤害的比值）
cases.push(makeCase('mark.vuln', {level: 60, rank: 2}, () => {
  const {bm, a, foes} = battle(60, 2);
  const u = w.$gameActors.actor(1), r1 = record(() => act(bm, u, 1, 0));
  foes[0].addState(ST.mark); foes[0]._codexLbMark = 6;
  const r2 = record(() => act(bm, u, 1, 0));
  return {plain: r1[0] || null, marked: r2[0] || null};
}));
// ⑦ 单目标：其余两只先倒下；天火 ×1.2、燃烧 ×1.5 且额外 4 段
cases.push(makeCase('cast.single', {level: 60, rank: 2}, () => {
  const {bm, a, foes} = battle(60, 2);
  foes[1].addState(1); foes[2].addState(1);
  const steps = [cast(bm, a, foes, 10622, 0), cast(bm, a, foes, 10623, 0)];
  return {steps};
}));
// ⑧ 萤火：敌人打流萤（每次行动 1 层）、角色 1 的终伤（比值）；超过 30 层夹住
cases.push(makeCase('firefly', {level: 60, rank: 2}, () => {
  const {bm, a, foes} = battle(60, 1);
  const u = w.$gameActors.actor(1), r0 = record(() => act(bm, u, 1, 0));
  const steps = [];
  for (let i = 0; i < 2; i++) { const lg = record(() => act(bm, foes[0], 1, a.index())); steps.push(step('hit', a, foes, () => lg)); }
  const r1 = record(() => act(bm, u, 1, 0));
  w.$gameTroop._codexLbFirefly = 30; L.addFirefly();
  steps.push(step('cap', a, foes));
  return {plain: r0[0] || null, boosted: r1[0] || null, steps};
}));
// ⑨ 再释放：Math.random 0.1（< 0.2）：整次重放，不重复叠印记、不重复收费
cases.push(makeCase('cast.rerelease', {level: 60, rank: 2, random: 0.1}, () => {
  const {bm, a, foes} = battle(60, 2);
  w.Math.random = () => 0.1;
  try { return {steps: [cast(bm, a, foes, 10622, 0)]}; } finally { w.Math.random = () => 0.5; }
}));
process.exit(finish(host, 'liuying2.json', {hostScope: '真实 BattleManager／Game_Action（Math.random 0.5，再释放例 0.1）；流萤第二期（v0.62.12）', cases}) ? 0 : 1);
