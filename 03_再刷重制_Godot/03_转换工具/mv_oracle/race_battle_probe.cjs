'use strict';
// 种族祝福战斗与能力值效果（installNativeRaceRuntime：Game_Actor.param／paramPlus／skillMpCost／skillTpCost 包装、
// race-blessings 伤害钩子、startAction／executeHpDamage／endAction 的行动根、setHp 的蛮骨上限、回合末毒鸡汤与残响交接、反攻）。
// ① params：角色 1（练习剑）30 级，七族 × 1／4／7 阶与无祝福，八项 param／paramPlus 与几个技能的 MP／TP 消耗。
// ② battle.*：真实 BattleManager 跑行动（同 cat_probe 的 act），敌群 2／6，敌人生命加 1e12；每步记各敌人与角色的生命、法力、
//    毒鸡汤状态（角色用本来的生命）、角色的 _codexRaceBattle（战斗者换成标签），回合直接写 $gameTroop._turnCount，回合末直接调 CodexRaces.roundEnd。
// 新游戏（Math.random 0.5），只在内存；产物 .sandbox/race_battle.json。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const R = w.CodexRaces, C = w.$dataCodexRaces;
if (!R || !C) throw new Error('种族祝福模块未安装');
const P = [0, 1, 2, 3, 4, 5, 6, 7];
const r = v => round(v);
const toasts = [];
w.$.toaster = o => toasts.push(String(o && o.message));
function uncap() { w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });'); }
// 直接设种族与阶位（learnSkill 包装：已有数据且同族时阶位取较大，再 sync 换种族技能、刷新）
function setRace(a, race, rank, blood) {
  if (race < 0) { a._codexRace = {race: -1, rank: 1, free: true, blood: false, legacy: []}; a.learnSkill(C.skills[0][0]); a._codexRace.race = -1; a._skills = a._skills.filter(id => !R.skillInfo(id)); a.refresh(); return; }
  a._codexRace = {race, rank: 1, free: false, blood: !!blood, legacy: []};
  a.learnSkill(C.skills[race][rank - 1]);
}
const SKILLS = [8, 9, 10, 72, 101];
const cases = [];
for (const race of [-1, 0, 1, 2, 3, 4, 5, 6]) {
  for (const rank of race < 0 ? [1] : [1, 4, 7]) {
    cases.push(makeCase('params.' + race + '.' + rank, {actor: 1, level: 30, race, rank, skills: SKILLS}, () => {
      newGame(); uncap();
      const a = w.$gameActors.actor(1);
      a.changeLevel(30, false);
      setRace(a, race, rank);
      a.refresh(); if (a.initPassiveCache) { a.initPassiveCache(); a.refreshPassiveCache(); }
      return {race: JSON.parse(JSON.stringify(a._codexRace)), raceSkills: a._skills.filter(id => R.skillInfo(id)), rate: R.rate(a),
        param: P.map(i => a.param(i)), paramPlus: P.map(i => r(a.paramPlus(i))),
        mpCost: SKILLS.map(id => a.skillMpCost(w.$dataSkills[id])), tpCost: SKILLS.map(id => a.skillTpCost(w.$dataSkills[id])),
        weaponBody: P.map(i => r(R.weaponBody(a.weapons()[0], i)))};
    }));
  }
}

// ② 战斗
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
// 五乘区修正按数值平衡不移植（O-044），同 cat／settlement 探针关掉
w.eval('CodexZones.ENABLED=false;');
const BIG_HP = 1e12;
function battle(spec) {
  newGame(); uncap();
  const a = w.$gameActors.actor(1), b = w.$gameActors.actor(8);
  a.changeLevel(spec.level || 30, false); b.changeLevel(30, false);
  setRace(a, spec.race, spec.rank, spec.blood);
  w.eval('$gameParty._actors=[];');
  w.$gameParty.addActor(1); w.$gameParty.addActor(8);
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(spec.troop || 2, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  w.CodexYunshang._acted = [];
  const enemies = w.$gameTroop.members();
  enemies.forEach((e, i) => { e._paramPlus[0] = BIG_HP; if (spec.enemyAtkPlus) e._paramPlus[2] = spec.enemyAtkPlus; });
  for (const x of [...w.$gameParty.members(), ...enemies]) { x.need_refresh = true; x.refresh(); x.recoverAll(); }
  // startBattle 包装的最后一步：出战成员建本场种族数据（记下当时的最大生命）；不走 startBattle 画面
  w.$gameParty.battleMembers().forEach(x => R.battleState(x));
  return {bm, a, b, enemies};
}
function act(bm, user, skillId, targetIndex) {
  const action = new w.Game_Action(user);
  if (skillId === 2) action.setGuard(); else action.setSkill(skillId);
  action.setTarget(targetIndex);
  user._actions = [action]; bm._subject = user; bm._action = null;
  bm.startAction();
  for (let i = 0; i < 20000; i++) {
    const ph = bm._phase;
    if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
    else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
  }
  return action;
}
function label(x, ctx) {
  if (!x) return null;
  const i = ctx.enemies.indexOf(x); if (i >= 0) return 'e' + i;
  if (x === ctx.a) return 'a'; if (x === ctx.b) return 'b';
  return '?';
}
function raceState(a, ctx) {
  const s = a._codexRaceBattle; if (!s) return null;
  const out = {};
  for (const k of ['godTurn', 'bloodTurn', 'capTurn', 'gainTurn', 'spendTurn', 'echoTurn', 'humanExtra']) out[k] = s[k];
  out.ghostPrevious = s.ghostPrevious ? {group: s.ghostPrevious.group, turn: s.ghostPrevious.turn} : null;
  out.ghostCurrent = s.ghostCurrent ? {group: s.ghostCurrent.group, turn: s.ghostCurrent.turn} : null;
  out.counter = s.counter ? {target: label(s.counter.target, ctx), until: s.counter.until} : null;
  out.cap = s.cap ? {spent: r(s.cap.spent)} : null;
  out.poison = (s.poison || []).map(p => ({target: label(p.target, ctx), id: p.id, amount: r(p.amount), turn: p.turn}));
  out.lastPrey = s.lastPrey ? label(s.lastPrey, ctx) : null;
  return out;
}
const reading = ctx => ({enemies: ctx.enemies.map(e => ({hp: r(e.hp), poisons: C.poisons.filter(id => e.isStateAffected(id))})),
  a: {hp: r(ctx.a.hp), mp: r(ctx.a.mp), tp: r(ctx.a.tp), mhp: ctx.a.mhp}, b: {hp: r(ctx.b.hp)}, race: raceState(ctx.a, ctx), aRace: ctx.b._codexRaceBattle ? raceState(ctx.b, ctx) : null});
// steps：{round, user: 'a'|'b'|'e0'…, skill, target}；{roundEnd: N}；{set: …} 调整（blood、敌人生命比例、角色生命）
function battleCase(name, spec, steps) {
  cases.push(makeCase('battle.' + name, Object.assign({actor: 1, ally: 8}, spec, {steps}), () => {
    const ctx = battle(spec), rows = [];
    for (const st of steps) {
      toasts.length = 0;
      if (st.roundEnd) { w.$gameTroop._turnCount = st.roundEnd; R.roundEnd(); rows.push(Object.assign({roundEnd: st.roundEnd}, reading(ctx), {toasts: toasts.slice()})); continue; }
      if (st.set) {
        if (st.set.blood != null) ctx.a._codexRace.blood = st.set.blood;
        if (st.set.enemyHpRate != null) { const e = ctx.enemies[st.set.enemy || 0]; e._hp = Math.floor(e.mhp * st.set.enemyHpRate); }
        if (st.set.allyHpRate != null) ctx.b._hp = Math.floor(ctx.b.mhp * st.set.allyHpRate);
        rows.push(Object.assign({set: st.set}, reading(ctx)));
        continue;
      }
      w.$gameTroop._turnCount = st.round;
      const user = st.user === 'b' ? ctx.b : st.user && st.user[0] === 'e' ? ctx.enemies[Number(st.user.slice(1))] : ctx.a;
      user.setTp(100); user._mp = user.mmp;
      const before = reading(ctx);
      const action = act(ctx.bm, user, st.skill, st.target || 0);
      rows.push(Object.assign({step: st, before}, reading(ctx), {toasts: toasts.slice(), preyIndex: action._codexRacePreyIndex == null ? null : action._codexRacePreyIndex}));
    }
    return {skills: ctx.a._skills.filter(id => R.skillInfo(id)), rate: R.rate(ctx.a), atk: ctx.a.atk, mat: ctx.a.mat, mhp: ctx.a.mhp, enemies: ctx.enemies.map(e => ({id: e.enemyId(), params: P.map(i => e.param(i))})), rows};
  }));
}
// 无祝福基线
battleCase('none', {race: -1, rank: 1, troop: 2}, [{round: 1, skill: 3}, {round: 1, skill: 9}, {round: 1, skill: 1}]);
// 神：本回合首次魔法伤害无视 q/2 魔防，魔法伤害与治疗 ×(1+q)
battleCase('god', {race: 0, rank: 7, troop: 2}, [{round: 1, skill: 9}, {round: 1, skill: 9}, {round: 1, skill: 3},
  {set: {allyHpRate: 0.5}}, {round: 1, skill: 8, target: 1}, {round: 2, skill: 9}, {round: 2, skill: 10}]);
// 妖：群攻选猎物（预演伤害最高），单体沿用目标；猎物生命 ≤30% 时收割
battleCase('demon', {race: 1, rank: 7, troop: 6}, [{round: 1, skill: 10}, {round: 1, skill: 3, target: 1}, {set: {enemy: 2, enemyHpRate: 0.2}},
  {round: 1, skill: 3, target: 2}, {round: 2, skill: 10}]);
// 人：八项 ×1.03，伤害后挂毒鸡汤，回合末按有效伤害 ×q/2 结算
battleCase('human', {race: 2, rank: 7, troop: 2}, [{round: 1, skill: 3}, {round: 1, skill: 3}, {round: 1, skill: 9, target: 1}, {roundEnd: 1}, {round: 2, skill: 3}]);
// 魔：物理 ×(1+q)、暴击倍率 +q/2；血契开时每回合首次物理技能付 3% 最大生命再 ×(1+q/2)
battleCase('fiend', {race: 3, rank: 7, troop: 2}, [{round: 1, skill: 3}, {round: 1, skill: 9}, {set: {blood: true}}, {round: 2, skill: 3}, {round: 2, skill: 3},
  {round: 3, skill: 9}, {round: 3, skill: 1}]);
// 鬼：最大法力 ×(1+q)、消耗打折；连续两回合同组技能，第二次额外 q 结算
battleCase('ghost', {race: 4, rank: 7, troop: 2}, [{round: 1, skill: 9}, {roundEnd: 1}, {round: 2, skill: 9}, {round: 2, skill: 9}, {roundEnd: 2},
  {round: 3, skill: 10}, {roundEnd: 3}, {round: 4, skill: 9}, {round: 4, skill: 1}]);
// 灵：武器本体值 ×q/2 加进 paramPlus；匹配兵器的技能（普通攻击总匹配）终伤 ×(1+q)
battleCase('spirit', {race: 5, rank: 7, troop: 2}, [{round: 1, skill: 1}, {round: 1, skill: 3}, {round: 1, skill: 9}]);
// 蛮：最大生命 ×(1+q)；敌人的一次行动最多扣最大生命 (0.75−2q)；受伤 ≥10% 后下回合内对来源 ×(1+1.5q)
// 第二个敌人的行动不受上限（上限只认本回合第一个敌人行动），所以只让一个敌人打
battleCase('brute', {race: 6, rank: 7, troop: 2, enemyAtkPlus: 4000}, [{round: 1, user: 'e0', skill: 1, target: 0},
  {round: 1, skill: 3, target: 1}, {round: 1, skill: 3, target: 0}, {round: 2, skill: 3, target: 0},
  {roundEnd: 2}, {round: 3, user: 'e1', skill: 1, target: 0}, {round: 4, skill: 3, target: 1}, {round: 4, skill: 3, target: 0}]);
battleCase('brute4', {race: 6, rank: 4, troop: 2, enemyAtkPlus: 4000}, [{round: 1, user: 'e0', skill: 1, target: 0}, {round: 1, skill: 3, target: 0}]);
process.exit(finish(host, 'race_battle.json', {hostScope: '新游戏（Math.random 0.5）；种族祝福能力值与战斗效果', cases}) ? 0 : 1);
