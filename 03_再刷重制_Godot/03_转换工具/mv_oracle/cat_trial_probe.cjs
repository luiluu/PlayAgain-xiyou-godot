'use strict';
// 【cc·白龙_13·未经审查】178 哈基米的守誓巨龙试炼与进阶小项（installImportedBalanceRuntime.js「小猫剑圣 v1.0」段）：
// ① 试炼 CodexCat.startTrial（公共事件 9018，第 248～249 行）：条件（178 在队、35 级、武器槽是剑、不在战斗中）不够时提示、返回 false；
//    够时记队伍（_actors／_battleMembers／_BattleMaxSize），只留 178、BattleMaxSize 1，BattleManager.setup(1999, 不能逃, 可以输)。
// ② startBattle 包装：试炼中 178 回满、TP 满。
// ③ 巨龙 1999 makeActions：OTB 下按 round()＝max(1, turnCount) 取 [爪, 蓄息, 喷焰, 空, 尾][(n−1)%5]，目标 0；空回合清掉行动。
//    startAction 包装：巨龙用蓄息时日志加一行。
// ④ Game_Enemy.param：巨龙用数据库原值；addState：试炼中挡 22 个难度状态。
// ⑤ restoreTrial：还原队伍；首胜给小猫进阶石 2900 并提示，之后不给；输了 178 倒下时留 1 血并提示。
// ⑥ 进阶小项：makeActionTimes（进阶且学了速剑 +1）、号角 2899 在 178 入队后 canUse 假、helpItem（进阶后终技 10440 品质 10）。
// 真实新游戏、Math.random 0.5，只在内存；产物 .sandbox/cat_trial.json，拷成 tests/fixtures/cat_trial_oracle.json（不进同步），专项 xiyou_cat_trial。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const C = w.CodexCat, I = C.ids;
const notes = [];
w.$ = w.$ || {};
w.$.toaster = m => notes.push(m.message);
let pushed = 0;
w.SceneManager.push = () => { pushed++; };
const logs = [];
function uncap() {
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
}
function putWeapon(a, id) {
  const before = w.$gameParty.weapons().slice();
  w.$gameParty.gainItem(w.$dataWeapons[id], 1);
  const it = w.$gameParty.weapons().find(x => before.indexOf(x) < 0) || w.$dataWeapons[id];
  a._equips[0].setObject(it);
  w.$gameParty.loseItem(it, 1, false);
}
// 新游戏＋招募 178（recruit 给练习剑 2）；level 设等级，sword=false 时卸下武器
function fresh({level = 35, sword = true, recruit = true} = {}) {
  newGame(); uncap();
  w.$gameActors._data[I.actor] = null;
  notes.length = 0; pushed = 0;
  if (recruit) C.recruit();
  const a = w.$gameActors.actor(I.actor);
  a.changeLevel(level, false);
  if (!sword) a._equips[0].setObject(null);
  else if (!a._equips[0].object()) putWeapon(a, 2);
  w.BattleManager._logWindow = {push: (...args) => logs.push(args), clear() {}, startAction() {}, endAction() {}, displayAction() {}};
  return a;
}
function party() {
  return {actors: w.$gameParty._actors.slice(), members: (w.$gameParty._battleMembers || []).slice(), max: w.$gameParty._BattleMaxSize === undefined ? null : w.$gameParty._BattleMaxSize};
}
function snap() {
  const d = w.$gameSystem._codexCatTrial;
  return d ? {actors: d.actors, members: d.members || null, max: d.max === undefined ? null : d.max, result: d.result === undefined ? null : d.result} : null;
}
const cases = [];
cases.push(makeCase('ids', {}, () => ({troop: I.troop, enemy: I.enemy, stone: I.stone, horn: I.horn, skills: [I.skill.claw, I.skill.charge, I.skill.breath, I.skill.tail],
  difficulty: C.trialDifficultyStates})));
// ① 条件
for (const [id, opt] of [['level34', {level: 34}], ['nosword', {sword: false}], ['absent', {recruit: false}]]) cases.push(makeCase(`start.fail.${id}`, opt, () => {
  fresh(opt);
  const before = party();
  const ok = C.startTrial(null);
  return {ok, notes: notes.slice(), pushed, party: party(), same: JSON.stringify(before) === JSON.stringify(party()), trial: snap()};
}));
cases.push(makeCase('start.ok', {}, () => {
  fresh();
  w.$gameParty.addActor(5); w.$gameParty.addActor(9);
  const before = party();
  const ok = C.startTrial(null);
  return {ok, notes: notes.slice(), pushed, before, party: party(), trial: snap(), troop: w.$gameTroop._troopId,
    canEscape: w.BattleManager._canEscape, canLose: w.BattleManager._canLose, enemies: w.$gameTroop.members().map(e => e.enemyId())};
}));
// ② 开战回满
cases.push(makeCase('start.recover', {}, () => {
  const a = fresh();
  C.startTrial(null);
  a.setHp(1); a.setTp(0);
  let err = null;
  try { w.BattleManager.startBattle(); } catch (e) { err = String(e && e.message || e); }
  return {err, hp: a.hp, mhp: a.mhp, tp: a.tp, maxTp: a.maxTp()};
}));
// ③ 出招
cases.push(makeCase('actions', {}, () => {
  fresh();
  C.startTrial(null);
  const e = w.$gameTroop.members()[0];
  const out = [];
  for (let t = 0; t <= 11; t++) {
    w.$gameTroop._turnCount = t;
    e.makeActions();
    const act = e._actions[0];
    out.push({turn: t, n: e._actions.length, skill: act && act.item() ? act.item().id : 0, target: act ? act._targetIndex : null});
  }
  return {otb: w.BattleManager.isOTB(), out};
}));
cases.push(makeCase('charge.text', {}, () => {
  fresh();
  C.startTrial(null);
  const e = w.$gameTroop.members()[0];
  const out = {};
  for (const [k, id] of [['charge', I.skill.charge], ['claw', I.skill.claw]]) {
    logs.length = 0;
    e.makeActions(); e._actions[0].setSkill(id);
    w.BattleManager._subject = e;
    w.BattleManager._logWindow = {push: (...args) => logs.push(args), clear() {}, startAction() {}, endAction() {}, displayAction() {}};
    let err = null;
    try { w.BattleManager.startAction(); } catch (x) { err = String(x && x.message || x); }
    err = err ? 'err' : null;  // 拦下的画面对象不全，原 startAction 后面会报错；只看包装先加的那一行
    out[k] = {texts: logs.filter(l => l[0] === 'addText').map(l => l[1]), err};
  }
  return out;
}));
// ④ 参数与状态
cases.push(makeCase('dragon.param', {}, () => {
  fresh();
  C.startTrial(null);
  const e = w.$gameTroop.members()[0];
  return {param: [0, 1, 2, 3, 4, 5, 6, 7].map(i => e.param(i)), raw: w.$dataEnemies[I.enemy].params};
}));
cases.push(makeCase('dragon.states', {}, () => {
  fresh();
  C.startTrial(null);
  const e = w.$gameTroop.members()[0];
  const ids = C.trialDifficultyStates.concat([I.state.read, I.state.scar]);
  const inTrial = ids.map(id => { e.addState(id); return e.isStateAffected(id) ? 1 : 0; });
  ids.forEach(id => e.removeState(id));
  C.restoreTrial(-1);
  const after = ids.map(id => { e.addState(id); return e.isStateAffected(id) ? 1 : 0; });
  return {ids, inTrial, after};
}));
// ⑤ 还原
cases.push(makeCase('restore', {}, () => {
  const a = fresh();
  w.$gameParty.addActor(5);
  const before = party();
  const count = () => w.$gameParty.numItems(w.$dataItems[I.stone]);
  const out = [];
  for (const [result, dead] of [[0, false], [0, false], [2, true], [2, false], [-1, false]]) {
    notes.length = 0;
    C.startTrial(null);
    if (dead) a.setHp(0); else a.setHp(a.mhp);
    w.$gameSystem._codexCatTrial.result = result;
    C.restoreTrial(result);
    out.push({result, dead, stone: count(), won: !!w.$gameSystem._codexCatTrialWon, notes: notes.slice(), hp: a.hp, restored: JSON.stringify(before) === JSON.stringify(party()), trial: snap()});
  }
  return out;
}));
// ⑥ 进阶小项
cases.push(makeCase('extras', {}, () => {
  const a = fresh();
  const horn = w.$dataItems[I.horn];
  w.$gameParty.gainItem(horn, 1);
  const hornIn = w.$gameParty.members()[0].canUse(horn);
  const times = [];
  for (const [adv, speed] of [[0, 0], [1, 0], [0, 1], [1, 1]]) {
    a._AdvancedNum = adv;
    if (adv) a.learnSkill(I.skill.advanced); else a.forgetSkill(I.skill.advanced);
    if (speed) a.learnSkill(I.skill.speed); else a.forgetSkill(I.skill.speed);
    times.push({adv, speed, n: a.makeActionTimes()});
  }
  const holy = w.$dataSkills[I.skill.holy];
  const view = C.helpItem(holy, a);
  a._AdvancedNum = 0;
  const plain = C.helpItem(holy, a);
  w.$gameParty.removeActor(I.actor);
  const hornOut = w.$gameParty.members()[0].canUse(horn);
  return {hornIn, hornOut, times, advanced: {quality: view.meta.quality, ici: view.meta.ici, same: view === holy,
    note: /<quality:10>/.test(view.note) && /<ici:10>/.test(view.note), desc: (view.descParams || []).filter(r => /品质/.test(r[0])).map(r => [r[0], r[2]])},
    plain: {same: plain === holy}};
}));
process.exit(finish(host, 'cat_trial.json', {hostScope: '真实 CodexCat.startTrial／restoreTrial、Game_Enemy.makeActions、BattleManager.startBattle／startAction；SceneManager.push 与 toaster 拦下', cases}) ? 0 : 1);
