'use strict';
// 【Claude·白龙_6·未经审查】渡鸦 167 灵魂积累与铸印（js/codex/runtime/installNativeRavenRuntime.js）：
// ① Game_Enemy.die 包装 gainSoulFrom：各敌人（经验 0～25000、神话、首领备注 <Boss>）倒下时渡鸦得魂
//    clamp(10..50, floor(12＋5×log2(1＋经验/100)))，神话 ×3、首领 ×10，再夹到 50；同一敌人只算一次；渡鸦不在出战队伍不得。
// ② awardRavenAdvanceSeal：本阶灵魂达 REQUIRE[阶＋1] 且本阶没铸过印 → 得冥羽进阶印 2901（已有就不再给）；五阶不再给。
// ③ Scene_ActorAdvanced.onConfirmOk 包装：渡鸦进阶成功后灵魂清零、重排技能、再判一次铸印。
// ④ restoreRavenState（新局／读档）：已在队时判一次铸印。
// 只在内存，产物 .sandbox/raven_soul.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const R = w.CodexRaven;
if (!R || !R.REQUIRE) throw new Error('渡鸦模块未安装');
const stub = new Proxy({}, {get: (_, k) => k === 'index' ? (() => 0) : (() => undefined), set: () => true});  // 进阶界面各窗口：index() 取 0，其余调用不做事
const ACTOR = 167, SEAL = 2901, SWITCH = 2494;
const ENEMIES = [29, 3, 37, 180, 815, 814, 1999];

// 新局、开挑战开关 2494（167 是超强角色，BossDifficulty 只在挑战开关或混沌难度下让他入队出战）；party 为入队名单
function setup(level, rank, party) {
  newGame();
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.$gameSwitches.setValue(SWITCH, true);
  w.eval('$gameParty._actors=[]; $gameParty._battleMembers=[0,0,0,0,0];');
  for (const id of party) w.$gameParty.addActor(id);
  const a = w.$gameActors.actor(ACTOR);
  a._AdvancedNum = rank; a._codexRavenStage = rank;
  a.changeLevel(level, false);
  return a;
}
const seals = () => w.$gameParty.numItems(w.$dataItems[SEAL]);
const die = (id, elite) => {
  const e = new w.Game_Enemy(id, 0, 0);
  e._elite = !!elite;
  const exp = e.exp();
  e.addState(1);
  return {e, exp};
};
const cases = [];
cases.push(makeCase('module', {}, () => ({require: R.REQUIRE.slice(), seal: SEAL})));
// ① 得魂
for (const id of ENEMIES) for (const elite of [false, true]) {
  cases.push(makeCase(`gain.e${id}.${elite ? 'elite' : 'plain'}`, {enemy: id, elite, level: 30, rank: 0, party: [ACTOR, 1]}, () => {
    const a = setup(30, 0, [ACTOR, 1]);
    const before = a._codexRavenSoul;
    const {e, exp} = die(id, elite);
    const once = a._codexRavenSoul - before;
    e.removeState(1); e.setHp(1); e.addState(1);  // 复活再倒下：同一敌人不再计
    return {exp, isElite: e.isElite(), gain: once, again: a._codexRavenSoul - before - once};
  }));
}
for (const [id, party] of [['reserve', [1, 8, 9, 10, ACTOR]], ['absent', [1]]]) {
  cases.push(makeCase(`gain.${id}`, {enemy: 180, party, level: 30, rank: 0}, () => {
    const a = setup(30, 0, party);
    const before = a._codexRavenSoul;
    die(180, false);
    return {members: w.$gameParty.members().map(b => b.actorId()), gain: a._codexRavenSoul - before};
  }));
}
// ② 铸印
for (const rank of [0, 1, 2, 3, 4, 5]) for (const pre of [0, 1]) {
  if (pre && rank !== 2) continue;
  cases.push(makeCase(`seal.r${rank}${pre ? '.have' : ''}`, {rank, level: 60, preSeals: pre, party: [ACTOR, 1]}, () => {
    const a = setup(60, rank, [ACTOR, 1]);
    if (pre) w.$gameParty.gainItem(w.$dataItems[SEAL], pre);
    const need = R.REQUIRE[Math.min(5, rank + 1)];
    a._codexRavenSoul = need - 10;
    const s0 = seals();
    die(180, false);  // 妖精仙子：30 魂
    const first = {soul: a._codexRavenSoul, seals: seals() - s0, forged: a._codexRavenForgedStage};
    die(180, false);
    return {need, first, second: {soul: a._codexRavenSoul, seals: seals() - s0, forged: a._codexRavenForgedStage}};
  }));
}
// 铸过本阶的印、印被卖掉或丢掉后再得魂：本阶不再给
cases.push(makeCase('spent.r2', {rank: 2, level: 60, party: [ACTOR, 1]}, () => {
  const a = setup(60, 2, [ACTOR, 1]);
  a._codexRavenSoul = R.REQUIRE[3] - 10;
  die(180, false);
  const first = seals();
  w.$gameParty.loseItem(w.$dataItems[SEAL], first);
  die(180, false);
  return {first, after: seals(), forged: a._codexRavenForgedStage, soul: a._codexRavenSoul};
}));
// ③ 进阶确认
for (const [rank, soul] of [[0, 5000], [1, 40000], [4, 200000]]) {
  cases.push(makeCase(`advance.r${rank}`, {rank, soul, level: 60, party: [ACTOR, 1]}, () => {
    const a = setup(60, rank, [ACTOR, 1]);
    a._codexRavenSoul = soul;
    a._codexRavenForgedStage = rank;  // 本阶已铸过
    const row = w.$dataStarAdvancedOpt.filter(o => o && o.AdvancedActId === ACTOR && o.AdvancedActNum === rank)[0];
    for (const [item, n] of row.AdvancedItem) w.$gameParty.gainItem(w.$dataItems[item], n);
    w.$gameParty.gainGold(Number(row.AdvancedGold) || 0);
    const s0 = seals();
    const scene = Object.create(w.Scene_ActorAdvanced.prototype);
    Object.assign(scene, {_windowIdx: 0, _goldWindow: stub, _confirmWindow: stub, _indexWindow: stub, _statusWindow: stub});
    const oldScene = w.SceneManager._scene; w.SceneManager._scene = scene;
    try { scene.onConfirmOk(); } finally { w.SceneManager._scene = oldScene; }
    return {rank: a._AdvancedNum, stage: a._codexRavenStage, soul: a._codexRavenSoul, forged: a._codexRavenForgedStage,
      seals: seals() - s0, skills: a._skills.filter(id => (id >= 10122 && id <= 10139) || id === 10170).sort((x, y) => x - y)};
  }));
}
process.exit(finish(host, 'raven_soul.json', {hostScope: '正式 Game_Enemy.die／Scene_ActorAdvanced.onConfirmOk；渡鸦灵魂积累与铸印', cases}) ? 0 : 1);
