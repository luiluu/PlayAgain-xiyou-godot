'use strict';
// 【cc·白龙_9·未经审查】174 云裳第一期（js/codex/runtime/installNativeYunshangRuntime.js 的 W.CodexYunshang）：
// ① 技能同步 Y.sync 与按等级／进阶学会的技能、八项能力值（最大生命／魔攻／敏捷倍率）、被动缓存的暴伤／终伤（云丝展幅、织神天梭）；
// ② 公式 CodexYunshang.formula（战斗外，防取目标魔防）；③ 招募（入队、本档第一次进背包一件织神天梭）；
// ④ 战斗：必中、戴织神天梭必暴击与结算 ×1.99、双针段数 ×2 与 ×0.555、云丝展幅打全体与 ×0.5／0.66／0.77、伤害行动定魔法；
//    能不能用：没解锁、敕衣点神要有人穿天衣、收针要有人觉醒。
// 觉醒、天衣各件、赠行／储行、拆段、符针是第二期，本探针不放。
// 真实 BattleManager／Game_Action（Math.random 0.5）；只在内存，产物 .sandbox/yunshang.json，拷成 tests/fixtures/yunshang_oracle.json（不接入全量同步）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const Y = w.CodexYunshang;
if (!Y || typeof Y.formula !== 'function') throw new Error('云裳模块未安装');
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
const ACTOR = 174, RELIC = 7935, BIG_HP = 1e12, TROOP = 3, DEF_PLUS = 5000;
const key = b => !b ? null : b.isActor() ? 'a' + b.actorId() : 'e' + b.index();
const skills = a => a._skills.filter(id => id >= 10270 && id <= 10287).sort((x, y) => x - y);
const params = a => [0, 1, 2, 3, 4, 5, 6, 7].map(i => a.param(i));
const cache = a => { a.initPassiveCache(); a.refreshPassiveCache(); const c = a._passiveCache; return {crit: c.critHarmRi || 0, final: c.globalHarmRi || 0}; };
const maxLevel = () => w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
// 新建角色（1 级 setup，进阶 0）→ 写进阶次数 → 升到 level（changeLevel 包装里同步）
function grow(level, stage) {
  const a = w.$gameActors.actor(ACTOR);
  a._AdvancedNum = stage;
  a.changeLevel(level, false);
  return a;
}
function wearRelic(a) {
  w.$gameParty.gainItem(w.$dataArmors[RELIC], 1, false);
  const gear = w.$gameParty.armors().filter(i => (i.baseItemId || i.id) === RELIC).slice(-1)[0];
  a.changeEquip(a.equipSlots().indexOf(w.$dataArmors[RELIC].etypeId), gear);
  return gear;
}

// 新局、云裳 level 级 stage 进阶入队并排到第一位（_actors 与出战表 _battleMembers 都挪；addActor 会把 1、8、9、10 补回来，清队无效；出战 174、1、8、9）、
// 可选戴织神天梭；全队与敌群 3 生命加 1e12、敌人物防 +5000；开第一回合
function battle(level, stage, relic) {
  newGame(); maxLevel();
  w.$gameSwitches.setValue(2494, true);  // 挑战开关：超强者才能出战（同 garou_battle_probe）
  const a = grow(level, stage);
  w.$gameParty.addActor(ACTOR);
  for (const list of [w.$gameParty._actors, w.$gameParty._battleMembers]) { list.splice(list.indexOf(ACTOR), 1); list.unshift(ACTOR); }
  if (relic) wearRelic(a);
  for (const b of w.$gameParty.allMembers()) b._paramPlus[0] = BIG_HP;
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  w.CodexYunshang._acted = [];
  for (const e of w.$gameTroop.members()) { e._paramPlus[0] = BIG_HP; e._paramPlus[3] = DEF_PLUS; }
  for (const b of [...w.$gameParty.allMembers(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  bm.startTurn();
  return {bm, a, party: w.$gameParty.battleMembers().map(b => b.actorId())};
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
const MEETS = [10270, 10271, 10272, 10273, 10274, 10277];
const snap = a => { a.setMp(a.mmp); a.setTp(a.maxTp()); return {meets: MEETS.map(id => a.meetsSkillConditions(w.$dataSkills[id]))}; };
const cast = (bm, a, id, target = 0) => { a.setMp(a.mmp); a.setTp(a.maxTp()); a.clearCooldowns && a.clearCooldowns(); return {cast: id, log: record(() => act(bm, a, id, target)), ...snap(a)}; };
const cases = [];

// ① 技能、能力值、被动缓存：各级 × 进阶
for (const [level, stage] of [[1, 0], [10, 0], [20, 0], [25, 0], [30, 0], [35, 0], [35, 1], [40, 1], [45, 1], [50, 1], [50, 2], [55, 2], [60, 2]]) {
  cases.push(makeCase(`skills.lv${level}.s${stage}`, {level, stage}, () => {
    newGame(); maxLevel();
    const a = grow(level, stage);
    return {skills: skills(a), params: params(a), cache: cache(a)};
  }));
}
// 戴织神天梭：终伤 +3（不看云丝展幅）；能力值不变
for (const level of [10, 30]) {
  cases.push(makeCase(`relic.lv${level}`, {level, stage: 0}, () => {
    newGame(); maxLevel();
    const a = grow(level, 0);
    wearRelic(a);
    return {skills: skills(a), params: params(a), cache: cache(a)};
  }));
}
// 降级：changeLevel 往下也同步（35 级进阶 1 → 20 级）
cases.push(makeCase('skills.down', {level: 20, stage: 1, from: 35}, () => {
  newGame(); maxLevel();
  const a = grow(35, 1);
  a.changeLevel(20, false);
  return {skills: skills(a), params: params(a), cache: cache(a)};
}));
// ② 公式（战斗外：防＝目标魔防）
cases.push(makeCase('formula', {level: 45, stage: 1}, () => {
  newGame(); maxLevel();
  const a = grow(45, 1);
  const e = new w.Game_Enemy(2, 0, 0);
  const rows = [];
  for (const mdfPlus of [0, 30000]) {
    e._paramPlus[5] = mdfPlus;
    for (const id of [10270, 10271, 10274, 10282, 10286, 10272]) {
      const action = new w.Game_Action(a); action.setSkill(id);
      rows.push({id, mdf: e.mdf, value: Y.formula(action, a, e)});
    }
  }
  return {mat: a.mat, def: a.def, mdf: a.mdf, rows};
}));
// ③ 招募：新局（队里 1、8、9、10）招两次
cases.push(makeCase('recruit', {level: 1}, () => {
  newGame();
  Y.recruit();
  const count = () => w.$gameParty.armors().filter(i => (i.baseItemId || i.id) === RELIC).length;
  const first = {party: w.$gameParty.members().map(b => b.actorId()), relics: count(), worn: w.$gameActors.actor(ACTOR).equips().filter(Boolean).map(i => i.baseItemId || i.id)};
  Y.recruit();
  return {first, again: {party: w.$gameParty.members().map(b => b.actorId()), relics: count()}, skills: skills(w.$gameActors.actor(ACTOR))};
}));
// ④ 战斗：钉影 10270、拆神 10271、普通攻击 1 各打一次（主目标 0）；比值看本例第一段
for (const [level, stage, relic] of [[20, 0, false], [25, 0, false], [30, 0, false], [30, 0, true], [35, 1, false], [35, 1, true]]) {
  const id = `battle.lv${level}.s${stage}${relic ? '.relic' : ''}`;
  cases.push(makeCase(id, {level, stage, relic}, () => {
    const {bm, a, party} = battle(level, stage, relic);
    const steps = [{start: true, ...snap(a)}];
    steps.push(cast(bm, a, 10270, 1));
    if (level >= 10) steps.push(cast(bm, a, 10271, 0));
    steps.push(cast(bm, a, 1, 2));
    bm.endBattle(0);
    return {party, skills: skills(a), cri: a.cri, steps};
  }));
}
process.exit(finish(host, 'yunshang.json', {hostScope: '真实 BattleManager／Game_Action（Math.random 0.5）；云裳第一期', cases}) ? 0 : 1);
