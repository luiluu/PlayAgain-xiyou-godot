'use strict';
// 怪物图鉴击败数（AB_EnemyBook：Game_Enemy.die 包装里即时 $gameSystem.incrementDefeatNumber(enemyId)，与 ResisterTiming=2 的登记分开）。
// 沙僧50 系统批 P2-1 的四例：死亡→复活→再死亡、死亡→复活→逃跑（战斗结束）、死亡后变身、死亡后立刻读数（战斗中打开图鉴）。
// 新游戏（Math.random 0.5），敌群 2 首个敌人；变身目标取敌群 3 首个敌人的编号。只在内存；产物 .sandbox/enemy_book_defeat.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const TROOP = 2, OTHER_TROOP = 3;
// 变身会碰精灵（YEP_X_AnimatedSVEnemies setTransform），没有画面时给一个什么都接受的替身（同 cat_probe）
const sprites = new Map();
w.Game_Battler.prototype.battler = function () {
  if (!sprites.has(this)) sprites.set(this, new Proxy({}, {get: (t, k) => k in t ? t[k] : (() => false), set: (t, k, v) => {t[k] = v; return true;}}));
  return sprites.get(this);
};
function battle() {
  newGame();
  w.$gameSystem.clearDefeatNumber();
  w.$gameTroop.setup(TROOP);
  w.$gameParty._inBattle = true;
  return w.$gameTroop.members()[0];
}
const count = id => w.$gameSystem.defeatNumber(id);
const cases = [];
cases.push(makeCase('dieReviveDie', {troop: TROOP}, () => {
  const e = battle(), id = e.enemyId();
  e.die(); const first = count(id);
  e.revive(); e.setHp(1); const revived = count(id);
  e.die(); const second = count(id);
  w.$gameTroop.onBattleEnd(); w.$gameParty._inBattle = false;
  return {enemyId: id, afterFirstDeath: first, afterRevive: revived, afterSecondDeath: second, afterBattleEnd: count(id)};
}));
cases.push(makeCase('dieReviveEscape', {troop: TROOP}, () => {
  const e = battle(), id = e.enemyId();
  e.die(); e.revive(); e.setHp(1);
  const before = count(id);
  w.$gameTroop.onBattleEnd(); w.$gameParty._inBattle = false;   // 逃跑：本场结束时敌人活着
  return {enemyId: id, beforeEnd: before, afterBattleEnd: count(id), aliveAtEnd: e.isAlive()};
}));
cases.push(makeCase('dieThenTransform', {troop: TROOP, otherTroop: OTHER_TROOP}, () => {
  const e = battle(), id = e.enemyId();
  w.$gameTroop.setup(OTHER_TROOP); const other = w.$gameTroop.members()[0].enemyId();
  w.$gameTroop.setup(TROOP); const t = w.$gameTroop.members()[0];
  t.die(); t.transform(other);
  w.$gameTroop.onBattleEnd(); w.$gameParty._inBattle = false;
  return {enemyId: id, otherId: other, original: count(id), transformed: count(other), deadAfterTransform: t.isDead()};
}));
cases.push(makeCase('dieThenRead', {troop: TROOP}, () => {
  const e = battle(), id = e.enemyId();
  const before = count(id);
  e.die();
  return {enemyId: id, before, inBattleAfterDeath: count(id)};
}));
process.exit(finish(host, 'enemy_book_defeat.json', {hostScope: '新游戏（Math.random 0.5）；怪物图鉴击败数在死亡时即时计（沙僧50 系统批 P2-1）', cases}) ? 0 : 1);
