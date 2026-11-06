'use strict';
// recover_permanent 量具（tools CR，2026-11-06 补；原夹具是手搭量具测的，库里没有探针）：
// 内存新局 actor1／troop2 第 1 个敌人；挂 Permanent 686（5 回合）与普通状态 2（3 回合）、buff 参数 2 一层 4 回合、HP1 MP2 TP37，
// 分别 clearStates／recoverAll，记状态、回合、TP、buff 与 HP/MP 是否满。只写 .sandbox/recover_permanent_review.json，
// 拷成 tests/fixtures/recover_permanent_review.json（不接入全量同步）。设置与 tests/xiyou_recover_permanent.gd 一一对应。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const cases = [];
for (const kind of ['actor', 'enemy']) for (const operation of ['clearStates', 'recoverAll']) {
  cases.push(makeCase(kind + '.' + operation, {kind, operation, permanent: 686, ordinary: 2}, () => {
    newGame();
    const b = kind === 'actor' ? w.$gameActors.actor(1) : new w.Game_Enemy(w.$dataTroops[2].members[0].enemyId, 0, 0);
    b._states = w.Array.from([686, 2]);
    b._stateTurns = {686: 5, 2: 3};
    b._buffs = w.Array.from([0, 0, 1, 0, 0, 0, 0, 0]);
    b._buffTurns = w.Array.from([0, 0, 4, 0, 0, 0, 0, 0]);
    b.refresh();
    b._hp = 1; b._mp = 2; b._tp = 37;
    b[operation]();
    return {states: Array.from(b._states), turns: {...b._stateTurns}, tp: b._tp, buffs: Array.from(b._buffs), buffTurns: Array.from(b._buffTurns),
            hpIsMax: b.hp === b.mhp, mpIsMax: b.mp === b.mmp};
  }));
}
process.exit(finish(host, 'recover_permanent_review.json', {hostScope: '内存新局actor1/enemy troop2；clearStates/recoverAll保留Permanent686、清普通状态2', cases}) ? 0 : 1);
