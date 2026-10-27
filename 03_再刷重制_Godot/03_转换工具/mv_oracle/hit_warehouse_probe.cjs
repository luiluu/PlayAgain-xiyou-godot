'use strict';
// Star_Warehouse 难度倍率下的命中／闪避／暴击判定：DCultyL 标志把 Game_Enemy 的 xparam 乘到 1.4～2.85 后，
// 冻结 v0.28 的 Game_Action.itemHit／itemEva／itemCri 与 apply 的 missed／evaded／critical 是否钳到 1、超 1 时是否必然。
// 内存新局，不写存档；Math.random 固定取 0.01／0.5／0.99。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const cases = [];
const stub = new Proxy(function(){}, {get: (_t, k) => k === '_waitCount' ? 0 : (() => false), set: () => true});
// 挑一个物理、一个魔法、一个必中技能（会暴击），并记下编号
const pick = (ht) => w.$dataSkills.find(s => s && s.name && s.id < 400 && s.hitType === ht && s.damage.type === 1 && s.damage.critical && s.successRate === 100);
const SKILLS = {attack: 1, physical: pick(1) && pick(1).id, magical: pick(2) && pick(2).id, certain: pick(0) && pick(0).id};
function fixture(setup) {
  newGame();
  w.$gameParty._inBattle = true;
  for (let i = 1; i <= 8; i++) w.$gameParty['DCultyL' + i] = setup.flags.includes(i);
  w.BattleManager.setup(157, true, false);
  w.BattleManager._logWindow = stub; w.BattleManager._spriteset = stub; w.BattleManager._statusWindow = stub;
  w.BattleManager.startBattle();
  const enemy = w.$gameTroop.members()[0], actor = w.$gameActors.actor(1);
  // 在内存里给敌人数据追加 xparam 特征（22：命中 0、闪避 1、暴击 2、暴击闪避 3、魔法闪避 4），把基础值放到会在倍率后越过 1 的位置
  const data = w.$dataEnemies[enemy.enemyId()];
  enemy.enemy = () => ({...data, traits: Array.from(data.traits).concat(setup.extra.map(([id, v]) => ({code: 22, dataId: id, value: v})))});
  const a = setup.pair === 'enemy_actor' ? enemy : actor, b = setup.pair === 'enemy_actor' ? actor : enemy;
  const act = new w.Game_Action(a);
  if (setup.skill === 'attack') act.setAttack(); else act.setSkill(SKILLS[setup.skill]);
  w.BattleManager._subject = a; w.BattleManager._targets = w.Array.of(b); w.BattleManager._allTargets = w.Array.of(b);
  const rates = {hit: round(act.itemHit(b)), eva: round(act.itemEva(b)), cri: round(act.itemCri(b)),
    aHit: round(a.hit), aCri: round(a.cri), bEva: round(b.eva), bMev: round(b.mev), bCev: round(b.cev)};
  const results = [];
  for (const r of [0.01, 0.2, 0.4, 0.6, 0.8, 0.99]) {
    w.Math.random = () => r;
    b.clearResult(); b._hp = b.mhp; b._states = new w.Array(); b._stateTurns = {};
    const act2 = new w.Game_Action(a);
    if (setup.skill === 'attack') act2.setAttack(); else act2.setSkill(SKILLS[setup.skill]);
    act2.apply(b);
    results.push({random: r, missed: b.result().missed, evaded: b.result().evaded, critical: b.result().critical});
  }
  return {enemyId: enemy.enemyId(), difficulty: w.$gameSystem.difficultyId ? w.$gameSystem.difficultyId() : null, actorLevel: actor.level, rates, results};
}
const EXTRAS = {base: [], eva: [[1, 0.3]], evaHigh: [[1, 0.6], [4, 0.6]], hitLow: [[0, -0.5]], cri: [[2, 0.3], [3, 0.2]], criHigh: [[2, 0.5]]};
for (const pair of ['enemy_actor', 'actor_enemy'])
  for (const skill of ['attack', 'physical', 'magical', 'certain'])
    for (const [ek, extra] of Object.entries(EXTRAS))
      for (const flags of [[], [2], [4], [5]])
        cases.push(makeCase(`${pair}.${skill}.${ek}.f${flags.join('')}`, {pair, skill, flags, extra}, () => fixture({pair, skill, flags, extra})));
process.exit(finish(host, 'hit_warehouse.json', {skills: SKILLS, hostScope: '真实 Game_Action.itemHit／itemEva／itemCri／apply，DCultyL 标志写在 $gameParty 上', cases}) ? 0 : 1);
