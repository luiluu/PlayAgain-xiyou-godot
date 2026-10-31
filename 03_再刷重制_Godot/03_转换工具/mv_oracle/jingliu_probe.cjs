'use strict';
// 【cc·白龙_8·未经审查】170 镜流第一期（js/codex/runtime/installNativeYomiJingliuRuntime.js 的 W.CodexJingliu）：
// ① 技能整理（setup 的 normalizeJingliuSkills）与按等级学会的技能；② 星魂 paramBase（20／40 级最大生命、35 级攻击各再加一份）；
// ③ 公式 CodexJingliu.damage（战斗外：月魄取角色身上的值，霜痕 2628／裂隙 2629 各 +10%）；④ 招募（月魄剑匣 4579 装进槽）；
// ⑤ 战斗：开回合月魄满 3、剑技必中与固定段数、强化剑技扣月魄与月魄 0 时不能用、命中回月魄（25 级学了朔望盈满 +2）、
//    10187 给霜痕、10189 给裂隙；伤害钩子：戴剑匣、星魂（忘掉 10194 前后）的伤害比值。
// 放血、绽放、追加段、裂隙演化、追加行动是第二期，本探针的战斗例不放强化剑技伤害（只看月魄与能不能用）。
// 真实 BattleManager／Game_Action（Math.random 0.5）；只在内存，产物 .sandbox/jingliu.json，拷成 tests/fixtures/jingliu_oracle.json（不接入全量同步）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const J = w.CodexJingliu;
if (!J || typeof J.damage !== 'function') throw new Error('镜流模块未安装');
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
const ACTOR = 170, ARMOR = 4579, BIG_HP = 1e12, TROOP = 3, FROST = 2628, GAP = 2629;
const key = b => !b ? null : b.isActor() ? 'a' + b.actorId() : 'e' + b.index();
const skills = a => a._skills.filter(id => id >= 10187 && id <= 10202).sort((x, y) => x - y);
const params = a => [0, 1, 2, 3, 4, 5, 6, 7].map(i => a.param(i));

// 新局、level 级（新建角色在 1 级 setup 后逐级升）、招募（装剑匣）、再入队 1；全队与敌群 3 每只生命加 1e12；开第一回合
function battle(level) {
  newGame();
  w.eval('$gameParty._actors=[];$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  const a = w.$gameActors.actor(ACTOR);
  a.changeLevel(level, false);
  if (!J.recruit()) throw new Error('招募失败');
  // 剑技要求武器类型（requiredWtypeId1）：给一把能装的、编号最小的该类武器（技能能不能用才看得到月魄那一条）
  const wt = w.$dataSkills[10187].requiredWtypeId1;
  const weapon = w.$dataWeapons.find(x => x && x.wtypeId === wt && a.canEquip(x));
  if (weapon) a.forceChangeEquip(0, weapon);
  w.$gameParty.addActor(1);
  for (const b of w.$gameParty.allMembers()) b._paramPlus[0] = BIG_HP;
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  w.CodexYunshang._acted = [];
  for (const e of w.$gameTroop.members()) e._paramPlus[0] = BIG_HP;
  for (const b of [...w.$gameParty.allMembers(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  bm.startTurn();
  return {bm, a, foes: w.$gameTroop.members(), weapon: weapon ? weapon.id : 0};
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
    log.push({user: key(this.subject()), skill: this.item().id, target: key(target), value, critical: !!target.result().critical});
    return old.apply(this, arguments);
  };
  try { fn(); } finally { w.Game_Action.prototype.executeHpDamage = old; }
  return log;
}
const ENHANCED = [10188, 10190, 10192];
// meets：先补满 MP／TP（只看月魄这一条，不让费用挡住）
const snap = (a, foes) => { a.setMp(a.mmp); a.setTp(a.maxTp()); return {moon: J.moon(a), frost: foes.map(e => e.isStateAffected(FROST)), gap: foes.map(e => e.isStateAffected(GAP)),
  meets: ENHANCED.map(id => a.meetsSkillConditions(w.$dataSkills[id]))}; };
const cast = (bm, a, foes, id, target = 0) => { a.setMp(a.mmp); a.setTp(a.maxTp()); return {cast: id, log: record(() => act(bm, a, id, target)), ...snap(a, foes)}; };
const cases = [];

// ① 技能：新建角色（1 级 setup）后升到各级
for (const level of [1, 10, 15, 20, 25, 30, 40, 45, 60]) {
  cases.push(makeCase(`skills.lv${level}`, {level}, () => {
    newGame();
    w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
    const a = w.$gameActors.actor(ACTOR);
    a.changeLevel(level, false);
    return {skills: skills(a), params: params(a), mhpBase: a.paramBase(0), atkBase: a.paramBase(2)};
  }));
}
// 忘掉命途：毁灭 10194 时星魂不生效
cases.push(makeCase('params.no10194', {level: 45}, () => {
  newGame();
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  const a = w.$gameActors.actor(ACTOR);
  a.changeLevel(45, false);
  a.forgetSkill(10194);
  a.need_refresh = true; a.refresh();
  return {skills: skills(a), params: params(a)};
}));
// ③ 公式（战斗外）：各剑技 × 月魄 0～3 × 目标印记
cases.push(makeCase('formula', {level: 45}, () => {
  newGame();
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  const a = w.$gameActors.actor(ACTOR);
  a.changeLevel(45, false);
  const e = new w.Game_Enemy(3, 0, 0);
  const out = [];
  for (const marks of [[], [FROST], [GAP], [FROST, GAP]]) {
    e._states = w.JSON.parse(JSON.stringify(marks));  // 战斗外 addState 附加不上（与本期无关），直接写状态表（用引擎那边的 Array）
    for (let moon = 0; moon <= 3; moon++) {
      a._codexJingliuMoon = moon;
      for (let id = 10187; id <= 10193; id++) out.push({id, moon, marks, affected: [FROST, GAP].map(x => e.isStateAffected(x)), value: J.damage(a, e, id)});
    }
  }
  a._codexJingliuMoon = 0;
  return {atk: a.atk, mhp: a.mhp, rows: out, other: J.damage(w.$gameActors.actor(1), e, 10187)};
}));
// ④ 招募
cases.push(makeCase('recruit', {level: 1}, () => {
  newGame();
  w.eval('$gameParty._actors=[];');
  const first = J.recruit(), a = w.$gameActors.actor(ACTOR);
  const slot = a.equipSlots().indexOf(w.$dataArmors[ARMOR].etypeId);
  return {first, again: J.recruit(), party: w.$gameParty._actors.slice(), slot, worn: (a.equips()[slot] || {}).baseItemId || (a.equips()[slot] || {}).id || 0};
}));
// ⑤ 战斗：月魄、必中段数、霜痕／裂隙；45 级（学了 10195，命中 +2）与 20 级（+1）
for (const level of [45, 20]) {
  cases.push(makeCase(`battle.lv${level}`, {level}, () => {
    const {bm, a, foes, weapon} = battle(level);
    const steps = [{start: true, ...snap(a, foes)}];
    if (level >= 20) steps.push({cast: 10190, ...(() => { a.setMp(a.mmp); a.setTp(a.maxTp()); act(bm, a, 10190, 0); return snap(a, foes); })()});
    a._codexJingliuMoon = 0;  // 从 0 起看每次命中回几层
    steps.push(cast(bm, a, foes, 10187, 1));
    steps.push(cast(bm, a, foes, 10189, 2));
    if (level >= 30) steps.push(cast(bm, a, foes, 10191, 0));
    if (level >= 45) steps.push(cast(bm, a, foes, 10193, 0));
    // 月魄耗到 0：强化剑技不能用
    a._codexJingliuMoon = 0;
    steps.push({drained: true, ...snap(a, foes)});
    bm.endBattle(0);
    steps.push({endBattle: true, ...snap(a, foes)});
    return {weapon, skills: skills(a), steps};
  }));
}
// 伤害钩子：戴剑匣与卸下、忘掉 10194（星魂 25／30 级寒冰加成）；比值看第一段
cases.push(makeCase('hook.lv45', {level: 45}, () => {
  const {bm, a, foes, weapon} = battle(45);
  const steps = [cast(bm, a, foes, 10187, 0), cast(bm, a, foes, 10191, 0)];
  const slot = a.equipSlots().indexOf(w.$dataArmors[ARMOR].etypeId);
  a.changeEquip(slot, null);
  steps.push(cast(bm, a, foes, 10187, 0));
  a.forgetSkill(10194);
  a.need_refresh = true; a.refresh();
  steps.push(cast(bm, a, foes, 10187, 0));
  return {weapon, steps};
}));
process.exit(finish(host, 'jingliu.json', {hostScope: '真实 BattleManager／Game_Action（Math.random 0.5）；镜流第一期', cases}) ? 0 : 1);
