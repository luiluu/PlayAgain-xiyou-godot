'use strict';
// boss_rng 量具（tools CR，2026-11-06 补；原夹具是手搭量具测的，库里没有探针）：照 boss_lifecycle transform.0.2，敌群 1 第 1 个敌人在第 2 回合（偶数回合）变身 6 号，
// 原版加 Boss 状态 2651；变身与随后 recoverAll 各自调了几次 Math.random（计数器包一层，照常调原来的 0.5）。对应 tests/xiyou_random_streams.gd 的
// event.boss_transform_duration／event.boss_recover_duration。只写 .sandbox/boss_rng.json，拷成 tests/fixtures/boss_rng_oracle.json（不接入全量同步）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const sprites = new Map();  // 同 boss_lifecycle_probe：只补精灵占位
w.Game_Battler.prototype.battler = function () {
  if (!sprites.has(this)) sprites.set(this, new Proxy({}, {get: (t, k) => k in t ? t[k] : (() => false), set: (t, k, v) => { t[k] = v; return true; }}));
  return sprites.get(this);
};
const cases = [makeCase('boss_transform_recover_duration', {}, () => {
  newGame(); w.$gameSwitches.setValue(2494, true);
  w.$gameParty._actors = w.Array.from([1]); w.$gameParty._battleMembers = w.Array.from([1, 0, 0, 0, 0]);
  w.$gameSystem.setDifficultyId(3); w.$gameParty._inBattle = false; w.$gameTroop.clear();
  w.BattleManager._actionBattlers = []; w.BattleManager._nextTurnActionBattlers = [];
  w.$gameTroop.setup(1);
  const e = w.$gameTroop.members()[0];
  w.$gameParty._inBattle = true; e.onBattleStart(); e.refresh();
  w.$gameTroop.increaseTurn(); w.$gameTroop.increaseTurn();   // 第 2 回合（偶数），同 boss_lifecycle transform.0.2
  let draws = 0; const random = w.Math.random;
  w.Math.random = function () { draws++; return random.apply(this, arguments); };
  try {
    const rows = [];
    e.transform(6); rows.push({label: 'transform', draws, states: Array.from(e._states)});
    e.recoverAll(); rows.push({label: 'recover', draws, states: Array.from(e._states)});
    return {rows};
  } finally { w.Math.random = random; }
})];
process.exit(finish(host, 'boss_rng.json', {scope: 'native state-duration draws during even-turn Boss transform and recover, delegated Math.random counter only', cases}) ? 0 : 1);
