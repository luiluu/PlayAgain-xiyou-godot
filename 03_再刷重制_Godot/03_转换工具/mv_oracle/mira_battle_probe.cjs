'use strict';
// 【Claude·白龙_6·未经审查】米拉 168 解放·黑龙与黑龙形态（js/codex/runtime/installNativeMiraRuntime.js 的战斗包装）：
// ① meetsSkillConditions：人形 10140～10143、解放 10146、劫焰 10147、黑龙 10148～10152 在各进阶／等级／形态下能不能用；battlerName。
// ② skillMpCost／skillTpCost：禁忌 10166（进阶 2）主动技 ×0.75 取整。
// ③ 真实行动（敌群 3 三只、敌人血量极大）：解放、黑龙四技、人形技；记每段 executeHpDamage、行动后状态与减益、生命与 TP、
//    劫火累计（_codexMiraTurnFlame），再跑 BattleManager.endTurn 记各人生命变化（劫火追加、不灭龙血回血、生命代价）。
// ④ 终焉 10167：黑龙形态下 isStateResist／addState／addDebuff。
// ⑤ 不灭龙血 10154：敌人普通攻击对米拉 makeDamageValue（人形／黑龙／黑龙＋10154）。
// ⑥ BattleManager.endBattle 删 2592／2597～2599。
// 真实 BattleManager／Game_Action，Math.random 0.5；只在内存，产物 .sandbox/mira_battle.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const M = w.CodexMira;
if (!M || typeof M.damage !== 'function') throw new Error('米拉模块未安装');
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
const key = b => !b ? null : b.isActor() ? 'a' + b.actorId() : 'e' + b.index();
const BIG_HP = 1e12, TROOP = 3, ACTOR = 168, DRAGON = 2592, SWITCH = 2494, FOE_ATK = 1e6;
const ACTIVE = [10140, 10141, 10142, 10143, 10146, 10147, 10148, 10149, 10150, 10151, 10152];

// 新局、开挑战开关 2494（168 是超强角色，BossDifficulty 只在挑战开关或混沌难度下让他出战、入队），队伍 [168, 1]，各 level 级；米拉进阶 rank、照 CodexSkillProgression.sync
// 同步专属技能（正式游戏里入队、升级、进阶都同步），再忘掉 drop 里的；敌群 3 每只生命加 1e12
function battle(rank, level, drop) {
  newGame();
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');  // 等级上限照 slice_probe 放开到 99
  w.$gameSwitches.setValue(SWITCH, true);
  w.eval('$gameParty._actors=[]; $gameParty._battleMembers=[0,0,0,0,0];');
  w.$gameParty.addActor(ACTOR); w.$gameParty.addActor(1);
  const a = w.$gameActors.actor(ACTOR);
  a._AdvancedNum = rank;
  for (const id of [ACTOR, 1]) {
    const b = w.$gameActors.actor(id); b.changeLevel(level, false); b._paramPlus[0] = BIG_HP; b.recoverAll();
  }
  w.CodexSkillProgression.sync(a);
  for (const id of drop) a.forgetSkill(id);
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub; bm._enteredEndPhase = false;
  w.$gameParty._inBattle = true;
  w.CodexYunshang._acted = [];
  for (const e of w.$gameTroop.members()) e._paramPlus[0] = BIG_HP;
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  a._tp = a.maxTp();
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
    if (this.subject().isActor() && this.subject().actorId() === ACTOR) log.push({target: key(target), value});
    return old.apply(this, arguments);
  };
  try { fn(); } finally { w.Game_Action.prototype.executeHpDamage = old; }
  return log;
}
const sorted = list => list.slice().sort((x, y) => x - y);
const debuffs = b => [0, 1, 2, 3, 4, 5, 6, 7].filter(i => b.isDebuffAffected(i));
const flame = a => (a._codexMiraTurnFlame || []).map(x => ({target: key(x.target), amount: x.amount}));
const cases = [];
cases.push(makeCase('module', {}, () => ({immune: M.endOfAllImmuneStates.slice(), dragon: M.dragon})));
// ① 技能条件与战斗图
for (const [rank, level, dragon] of [[3, 55, false], [3, 55, true], [2, 55, false], [3, 49, false], [3, 55, 'unlearned']]) {
  const drop = dragon === 'unlearned' ? [10146] : [];
  const id = `meets.r${rank}.lv${level}.${dragon === true ? 'dragon' : dragon === false ? 'human' : dragon}`;
  cases.push(makeCase(id, {rank, level, drop, dragon: dragon === true}, () => {
    const {a} = battle(rank, level, drop);
    if (dragon === true) a.addState(DRAGON);
    a._mp = a.mmp; a._tp = a.maxTp();
    const out = {members: w.$gameParty.battleMembers().map(b => b.actorId()), battlerName: a.battlerName(), skills: a._skills.filter(s => s >= 10140 && s <= 10167).sort((x, y) => x - y)};
    for (const s of ACTIVE) out['s' + s] = a.meetsSkillConditions(w.$dataSkills[s]);
    return out;
  }));
}
// ② 禁忌减耗
for (const rank of [1, 2]) {
  cases.push(makeCase(`cost.r${rank}`, {rank, level: 55, drop: []}, () => {
    const {a} = battle(rank, 55, []);
    const out = {};
    for (const s of ACTIVE) out['s' + s] = [a.skillMpCost(w.$dataSkills[s]), a.skillTpCost(w.$dataSkills[s])];
    return out;
  }));
}
// ③ 真实行动＋回合结束
function actCase(id, setup, prepare) {
  cases.push(makeCase(id, setup, () => {
    const {bm, a, foes} = battle(setup.rank, setup.level, setup.drop);
    if (setup.dragon) a.addState(DRAGON);
    for (const s of setup.preStates || []) a.addState(s);
    for (const p of setup.preDebuffs || []) a.addDebuff(p, 3);
    a._mp = a.mmp; a._tp = a.maxTp();
    if (setup.hp) a._hp = setup.hp;
    if (prepare) prepare(a);
    const hp0 = a.hp;
    let threw = null;
    const log = record(() => { try { act(bm, a, setup.skill, 0); } catch (e) { threw = String(e.message); } });
    if (threw) return {threw, log, states: sorted(a._states), debuffs: debuffs(a)};  // 原版在 endAction 里抛错（见 act.liberate.end.debuff）
    const out = {log, hpAfterAction: a.hp, hpBefore: hp0, mp: a.mp, tp: a.tp, states: sorted(a._states), debuffs: debuffs(a),
      flame: flame(a), foeStates: foes.map(e => sorted(e._states))};
    const before = [a, ...foes].map(b => b.hp);
    bm.endTurn();
    out.turnEndDelta = [a, ...foes].map((b, i) => b.hp - before[i]);
    out.flameAfterTurn = flame(a);
    return out;
  }));
}
const NO_END = [10167];
actCase('act.liberate', {rank: 3, level: 55, drop: NO_END, skill: 10146});
actCase('act.liberate.lv54', {rank: 3, level: 54, drop: NO_END, skill: 10146});
actCase('act.liberate.end', {rank: 3, level: 55, drop: [], skill: 10146, preStates: [4, 6, 5]});
// 原版缺陷：终焉清减益调了不存在的 removeDebuff，米拉身上有减益时解放在 endAction 抛 TypeError（正式游戏会报错停下）
actCase('act.liberate.end.debuff', {rank: 3, level: 55, drop: [], skill: 10146, preStates: [4], preDebuffs: [2, 3]});
actCase('act.liberate.keep', {rank: 3, level: 55, drop: NO_END, skill: 10146, preStates: [4, 6], preDebuffs: [2, 3]});
for (const s of [10148, 10149, 10150, 10151, 10152])
  actCase(`act.dragon.s${s}`, {rank: 3, level: 55, drop: [], skill: s, dragon: true, hp: 5e7});
actCase('act.dragon.s10148.no10162', {rank: 3, level: 55, drop: [10162], skill: 10148, dragon: true});
actCase('act.dragon.s10148.no10154', {rank: 3, level: 55, drop: [10154], skill: 10148, dragon: true, hp: 5e7});
actCase('act.human.s10140', {rank: 3, level: 55, drop: NO_END, skill: 10140});
actCase('act.human.s10142.r2', {rank: 2, level: 55, drop: [], skill: 10142});
actCase('act.human.s10140.hp1', {rank: 2, level: 55, drop: [], skill: 10140, hp: 1});
actCase('act.human.s10140.r1', {rank: 1, level: 55, drop: [], skill: 10140});
// ④ 终焉免疫
for (const end of [false, true]) {
  cases.push(makeCase(`immune.${end ? 'end' : 'plain'}`, {rank: 3, level: 55, drop: end ? [] : NO_END, dragon: true}, () => {
    const {a} = battle(3, 55, end ? [] : NO_END);
    a.addState(DRAGON);
    const resist = {s4: a.isStateResist(4), s6: a.isStateResist(6), s5: a.isStateResist(5)};
    a.addState(4); a.addState(5); a.addDebuff(2, 3);
    return {resist, states: sorted(a._states), debuffs: debuffs(a)};
  }));
}
// ⑤ 不灭龙血受伤
for (const [dragon, blood] of [[false, true], [true, false], [true, true]]) {
  const drop = blood ? [] : [10154];
  cases.push(makeCase(`incoming.${dragon ? 'dragon' : 'human'}.${blood ? 'b' : 'nob'}`, {rank: 3, level: 55, drop, dragon, foeAtkPlus: FOE_ATK}, () => {
    const {a, foes} = battle(3, 55, drop);
    if (dragon) a.addState(DRAGON);
    foes[0]._paramPlus[2] += FOE_ATK; foes[0].refresh();
    a.refresh();
    const action = new w.Game_Action(foes[0]); action.setAttack();
    return {value: action.makeDamageValue(a, false), def: a.def, mdf: a.mdf};
  }));
}
// ⑥ 战斗结束
cases.push(makeCase('end', {rank: 3, level: 55, drop: []}, () => {
  const {bm, a} = battle(3, 55, []);
  for (const s of [DRAGON, 2597, 2598, 2599]) a.addState(s);
  const before = sorted(a._states);
  bm.endBattle(0);
  return {before, after: sorted(a._states), flame: flame(a)};
}));
process.exit(finish(host, 'mira_battle.json', {hostScope: '真实 BattleManager／Game_Action（Math.random 0.5）；米拉解放·黑龙与黑龙形态', cases}) ? 0 : 1);
