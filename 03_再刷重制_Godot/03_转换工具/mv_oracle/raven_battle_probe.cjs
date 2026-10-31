'use strict';
// 【cc·白龙_8·未经审查】167 渡鸦第三期：战斗内机制（js/codex/runtime/installNativeRavenRuntime.js 的 CodexRaven 战斗包装）：
// ① 神话形态（Game_Action.apply：<CodexRavenMyth> 技能 10127 命中、学了 10127、不在神话形态 → 3 回合）：endTurn 减一回合，
//    敌人倒下（gainSoulFrom）时不到 5 回合就加一；endBattle 清零；setupRaven（升级等）清零；神话之力＝神话形态且学了 10170，
//    让伤害钩子加普通／黑暗伤害 +1、最终伤害 +1.5，魔防穿透 +5%（到 95% 封顶）；
// ② 死亡残响 10132／三羽成环 10133：敌人倒下得魂后残响 +1（最多 3），本回合（startTurn 起）没有敌人倒下时 endTurn 再 +1；
//    学了 10133 且残响满 3 就进入狩猎；setupRaven 时没学 10132 清残响、没学 10133 清狩猎；
// ③ 追加伤害（BattleManager.endAction 之前，<CodexRavenDamage> 技能）：按目标累计本次行动的实际 HP 伤害；狩猎中消耗狩猎与残响，
//    对存活目标直接扣累计伤害 ×1（神话之力 ×1.5，冥界收割）；神话之力时对仍存活的目标再扣 ×0.85（回响）；
// ④ Game_Action.apply：渡魂鸦啄 10122 每次施放第一次命中回 2% 最大 MP；亡者盛宴 10124／万魂归鸦 10126 命中时，学了 10134
//    直接附加黑暗侵蚀 1663，否则二阶的亡者盛宴按普通附加状态（itemEffectAddNormalState）附加；
// ⑤ numRepeats：冥羽连葬 10123 加上额外攻击次数（特性 34，取整）。
// 真实 BattleManager／Game_Action（Math.random 0.5）；只在内存，产物 .sandbox/raven_battle.json，
// 拷成 tests/fixtures/raven_battle_oracle.json（不接入全量同步）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
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
  const log = [], oldExec = w.Game_Action.prototype.executeHpDamage, oldGain = w.Game_Battler.prototype.gainHp;
  let inExec = 0;
  w.Game_Action.prototype.executeHpDamage = function (target, value) {
    log.push({kind: 'hit', user: key(this.subject()), skill: this.item().id, target: key(target), value, critical: !!target.result().critical});
    inExec++;
    try { return oldExec.apply(this, arguments); } finally { inExec--; }
  };
  w.Game_Battler.prototype.gainHp = function (value) {
    if (!inExec && value < 0) log.push({kind: 'direct', target: key(this), value: -value});
    return oldGain.apply(this, arguments);
  };
  try { fn(); } finally { w.Game_Action.prototype.executeHpDamage = oldExec; w.Game_Battler.prototype.gainHp = oldGain; }
  return log;
}
const snap = (a, foes) => ({myth: a._codexRavenMythTurns || 0, residue: a._codexRavenResidue || 0, hunter: !!a._codexRavenHunter,
  soul: a._codexRavenSoul || 0, mp: a.mp, dead: foes.map(e => e.isDead()), erosion: foes.map(e => e.isStateAffected(1663))});
const kill = e => e.addState(1);
const cast = (bm, a, foes, id, target = 0) => { a.setMp(a.mmp); return {cast: id, log: record(() => act(bm, a, id, target)), ...snap(a, foes)}; };
const turn = (bm, a, foes) => { bm.endTurn(); const out = {turnEnd: true, ...snap(a, foes)}; bm.startTurn(); return out; };
const cases = [];
cases.push(makeCase('module', {}, () => ({require: R.REQUIRE.slice(), foes: (() => battle(5, 60).foes.length)()})));

// ① 神话形态：施放、已在形态中再施放、回合结束、敌人倒下续期到 5、结束战斗
cases.push(makeCase('myth.r5', {rank: 5, level: 60}, () => {
  const {bm, a, foes} = battle(5, 60);
  const steps = [cast(bm, a, foes, 10127, a.index())];
  steps.push(turn(bm, a, foes));
  steps.push(cast(bm, a, foes, 10127, a.index()));
  for (const e of foes) { kill(e); steps.push({kill: key(e), ...snap(a, foes)}); }
  steps.push(turn(bm, a, foes));
  bm.endBattle(0);
  steps.push({endBattle: true, ...snap(a, foes)});
  return {skills: a._skills.filter(id => id >= 10122).sort((x, y) => x - y), steps};
}));
// 形态到期后可再开；升级（setupRaven）清形态
cases.push(makeCase('myth.expire', {rank: 5, level: 60}, () => {
  const {bm, a, foes} = battle(5, 60);
  const steps = [cast(bm, a, foes, 10127, a.index())];
  for (let i = 0; i < 3; i++) steps.push(turn(bm, a, foes));
  steps.push(cast(bm, a, foes, 10127, a.index()));
  a.levelUp();
  steps.push({levelUp: true, ...snap(a, foes)});
  return {steps};
}));
// 神话之力的伤害：开形态前、开形态后、忘掉神话余响 10170 后（形态仍在、没有神话之力），渡魂鸦啄与亡者盛宴
for (const id of [10122, 10124]) {
  cases.push(makeCase(`power.${id}`, {rank: 5, level: 60, skill: id}, () => {
    const {bm, a, foes} = battle(5, 60);
    const steps = [cast(bm, a, foes, id)];
    steps.push(cast(bm, a, foes, 10127, a.index()));
    steps.push(cast(bm, a, foes, id));
    a.forgetSkill(10170);
    steps.push(cast(bm, a, foes, id));
    return {steps};
  }));
}

// ② 残响与狩猎：没有敌人倒下的回合结束 +1，敌人倒下 +1，满 3 进狩猎；本回合有敌人倒下时回合结束不加
for (const [name, rank, level] of [['r3', 3, 60], ['r0', 0, 30], ['lv20', 0, 20]]) {
  cases.push(makeCase(`residue.${name}`, {rank, level}, () => {
    const {bm, a, foes} = battle(rank, level);
    const steps = [turn(bm, a, foes), turn(bm, a, foes)];
    kill(foes[0]); steps.push({kill: 'e0', ...snap(a, foes)});
    steps.push(turn(bm, a, foes));
    steps.push(turn(bm, a, foes));
    kill(foes[1]); steps.push({kill: 'e1', ...snap(a, foes)});
    return {steps};
  }));
}
cases.push(makeCase('residue.reserve', {rank: 3, level: 60, reserve: true}, () => {
  const {bm, a, foes} = battle(3, 60, {reserve: true});
  const steps = [turn(bm, a, foes)];
  kill(foes[0]); steps.push({kill: 'e0', ...snap(a, foes)});
  return {members: w.$gameParty.members().map(b => b.actorId()), steps};
}));
// 升级（setupRaven）：学会 10132 前清残响；学了 10132、10133 时保留
cases.push(makeCase('residue.sync', {rank: 3, level: 60}, () => {
  const {a, foes} = battle(3, 60);
  a._codexRavenResidue = 3; a._codexRavenHunter = true;
  a.levelUp();
  const kept = snap(a, foes);
  a.changeLevel(20, false);
  a._codexRavenResidue = 2; a._codexRavenHunter = true;
  a.levelUp();
  return {kept, lv21: snap(a, foes), skills: a._skills.filter(id => id >= 10122).sort((x, y) => x - y)};
}));

// ③ 追加伤害：狩猎（收割）、神话之力（收割 ×1.5、回响）、全体技能逐目标、非专属伤害技能不消耗狩猎
const HUNT = [['r3', 3, 60, false, 10122], ['r5', 5, 60, false, 10122], ['r5.myth', 5, 60, true, 10122], ['r5.myth.aoe', 5, 60, true, 10124],
  ['r5.myth.souls', 5, 60, true, 10126], ['r3.attack', 3, 60, false, 1]];
for (const [name, rank, level, myth, id] of HUNT) {
  cases.push(makeCase(`hunt.${name}`, {rank, level, myth, skill: id}, () => {
    const {bm, a, foes} = battle(rank, level);
    const steps = [];
    if (myth) steps.push(cast(bm, a, foes, 10127, a.index()));
    a._codexRavenResidue = 3; a._codexRavenHunter = true;
    steps.push(cast(bm, a, foes, id));
    steps.push(cast(bm, a, foes, id));
    return {steps};
  }));
}
// 没有狩猎、只有神话之力：回响
cases.push(makeCase('echo.r5', {rank: 5, level: 60}, () => {
  const {bm, a, foes} = battle(5, 60);
  return {steps: [cast(bm, a, foes, 10127, a.index()), cast(bm, a, foes, 10122)]};
}));
// 收割打倒目标：目标先剩「本次伤害＋1」的生命，命中后收割致死——得魂、残响从 0 加回 1、神话续期，回响不再打
cases.push(makeCase('hunt.kill', {rank: 5, level: 60, myth: true}, () => {
  const {bm, a, foes} = battle(5, 60);
  const steps = [cast(bm, a, foes, 10127, a.index())];
  const probe = cast(bm, a, foes, 10122, 1);
  steps.push(probe);
  const first = probe.log.find(l => l.kind === 'hit').value;
  foes[0].setHp(first + 1);
  a._codexRavenResidue = 3; a._codexRavenHunter = true;
  steps.push(cast(bm, a, foes, 10122, 0));
  return {first, steps};
}));

// ④ 鸦啄回 MP（每次施放一次）；黑暗侵蚀：二阶亡者盛宴按普通附加，学了 10134（45 级）直接附加
cases.push(makeCase('peck.r0', {rank: 0, level: 10}, () => {
  const {bm, a, foes} = battle(0, 10);
  a.setMp(a.mmp);
  const before = a.mp;
  const log = record(() => act(bm, a, 10122, 0));
  return {mmp: a.mmp, before, after: a.mp, log};
}));
for (const [name, rank, level, id] of [['r2.feast', 2, 30, 10124], ['r2.lv45.feast', 2, 45, 10124], ['r1.peck', 1, 45, 10122], ['r4.souls', 4, 50, 10126], ['r4.lv44.souls', 4, 44, 10126], ['r3.feast', 3, 40, 10124]]) {
  cases.push(makeCase(`erosion.${name}`, {rank, level, skill: id}, () => {
    const {bm, a, foes} = battle(rank, level);
    return {learned: a._skills.indexOf(id) >= 0, has10134: a._skills.indexOf(10134) >= 0, step: cast(bm, a, foes, id)};
  }));
}

// ⑤ 冥羽连葬吃额外攻击次数：加状态 41（+1）、267（+2）
for (const [name, states] of [['plain', []], ['s41', [41]], ['s267', [267]], ['s41.s267', [41, 267]]]) {
  cases.push(makeCase(`repeats.${name}`, {rank: 1, level: 20, states}, () => {
    const {bm, a, foes} = battle(1, 20);
    for (const s of states) a.addState(s);
    a.need_refresh = true; a.refresh();  // 特性缓存：加状态后不刷新时 attackTimesAdd 仍是旧值（与本期无关），先刷新
    const atk = a.attackTimesAdd(), runtimeRepeats = w.$dataSkills[10123].repeats;
    return {attackTimesAdd: atk, runtimeRepeats, step: cast(bm, a, foes, 10123)};
  }));
}
process.exit(finish(host, 'raven_battle.json', {hostScope: '真实 BattleManager／Game_Action（Math.random 0.5）；渡鸦战斗内机制', cases}) ? 0 : 1);
