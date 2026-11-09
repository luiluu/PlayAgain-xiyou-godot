'use strict';
// 【cc·GB·未经审查】v0.53.01 installCounterGuardRuntime（反击防护）参照：BattleManager.invokeCounterAttack 包装，
// 反击者是敌人、却已不在 $gameTroop.members() 里时跳过这次反击（skipped+1）；反击者是角色、或敌人还在敌群里照常反击。
// 量：同一次 invokeAction 里，目标（反击者）挨的那一下、行动者被反击扣的血、invokeCounterAttack 进没进原函数、守卫跳过次数。
// 反击者带状态 327（避苍：反击率 +100%、暴击闪避 +100%）；行动技能公式定值、无浮动不暴击；Math.random 固定 0.5（反射率 0 不反射、反击率 ≥1 必反击）。
// 「不在敌群」两种造法：另 new 一个同号 Game_Enemy（从没进过敌群）；把敌群里的那只从 _enemies 摘掉（开战后离开）。
// 全内存新局，只写 .sandbox/counter_guard.json，拷成 tests/fixtures/counter_guard_oracle.json（不接入全量同步）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');
const realmArray = values => { const out = w.eval('[]'); for (const v of values) out.push(v); return out; };
function bare(id) {
  const a = w.$gameActors.actor(id);
  a._skills = realmArray([]); a._states = realmArray([]); a._equips.forEach(x => x.setObject(null));
  a._paramPlus = realmArray([0, 0, 0, 0, 0, 0, 0, 0]);
  return a;
}
function settle(b) {
  b.need_refresh = true;
  b.need_refresh_param = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
  b.refresh(); if (b.initPassiveCache) b.initPassiveCache(); if (b.refreshPassiveCache) b.refreshPassiveCache();
}
const LOGWIN = {push() {}, displayActionResults() {}, displayCounter() {}, displayReflection() {}, displaySubstitute() {}, displayAffectedStatus() {}};
const SKILL = 1, COUNTER_STATE = 327;
// cfg：user 'actor'|'enemy'；where 'troop'（在敌群里）|'fresh'（另 new 的同号敌人）|'removed'（开战后从 _enemies 摘掉）
function run(cfg) {
  newGame(); w.$gameSystem.setDifficultyId(2);
  const a = bare(1); a._paramPlus[0] = 50000; settle(a); a.recoverAll();
  w.Math.random = () => 0.99; w.$gameTroop.setup(1); w.Math.random = () => 0.5;
  let foe = w.$gameTroop.members()[0];
  if (cfg.where === 'fresh') foe = new w.Game_Enemy(foe.enemyId(), 0, 0);
  else if (cfg.where === 'removed') w.$gameTroop._enemies.splice(w.$gameTroop._enemies.indexOf(foe), 1);
  foe.clearStates(); settle(foe); foe._paramPlus[0] = 50000; settle(foe); foe.recoverAll();
  const user = cfg.user === 'enemy' ? foe : a, target = cfg.user === 'enemy' ? a : foe;
  for (const b of [a, foe]) b.clearStates();
  target.addState(COUNTER_STATE);
  const s = w.$dataSkills[SKILL], save = [s.damage.formula, s.damage.variance, s.damage.critical, s.hitType];
  s.damage.formula = '100'; s.damage.variance = 0; s.damage.critical = false; s.hitType = 1;  // 技能 1 原是必中（hitType 0），改成物理才判反击
  const act = new w.Game_Action(user); act.setSkill(SKILL);
  w.$gameParty._inBattle = true;
  w.BattleManager._subject = user; w.BattleManager._action = act; w.BattleManager._logWindow = LOGWIN;
  if (w.CodexYunshang && !w.CodexYunshang._acted) w.CodexYunshang._acted = w.eval('[]');
  const G = w.__codexCounterGuardV05301, skipped0 = G ? G.skipped : null;
  // 原函数（守卫里面那一层）进了几次
  let inner = 0; const origCall = G && G.invokeCounterAttack;
  const yepProto = w.BattleManager.invokeCounterAttack;  // 守卫装在最外层时等于 G.invokeCounterAttack
  const before = {user: user.hp, target: target.hp};
  const dbg = {itemCnt: act.itemCnt(target), itemMrf: act.itemMrf(target), physical: act.isPhysical(), canMove: target.canMove()};
  const innerAtk = w.Game_Action.prototype.setAttack;
  w.Game_Action.prototype.setAttack = function () { inner++; return innerAtk.apply(this, arguments); };
  w.Math.random = () => 0.5;
  w.BattleManager.invokeAction(user, target);
  w.Game_Action.prototype.setAttack = innerAtk;
  s.damage.formula = save[0]; s.damage.variance = save[1]; s.damage.critical = save[2]; s.hitType = save[3];
  w.$gameParty._inBattle = false;
  return {dbg, guardInstalled: !!G && origCall === yepProto, cnt: target.cnt, mrf: target.mrf, inTroop: w.$gameTroop.members().indexOf(foe) >= 0,
    targetHpDelta: target.hp - before.target, userHpDelta: user.hp - before.user, counterEntered: inner, skipped: G ? G.skipped - skipped0 : null};
}
const CASES = [
  ['enemy.troop', {user: 'actor', where: 'troop'}],
  ['enemy.fresh', {user: 'actor', where: 'fresh'}],
  ['enemy.removed', {user: 'actor', where: 'removed'}],
  ['actor.counter', {user: 'enemy', where: 'troop'}],          // 反击者是角色：不看敌群，反击代替挨打
];
const cases = CASES.map(([id, cfg]) => makeCase(id, cfg, () => run(cfg)));
process.exitCode = finish(host, 'counter_guard.json', {scope: 'v0.53.01 installCounterGuardRuntime: skip counter when the countering enemy is no longer in $gameTroop', cases}) ? 0 : 1;
process.exit();
