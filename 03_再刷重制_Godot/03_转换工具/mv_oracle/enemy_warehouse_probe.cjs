'use strict';
// Star_Warehouse 的敌人难度倍率：$gameParty.DCultyL1～5（公共事件 714 按难度开关置位）乘到 Game_Enemy 的 param／xparam／sparam 上。
// 冻结 v0.28 参照：逐个标志、逐个难度号、逐个敌人（含首领）读 8 项能力、10 项附加、10 项特殊能力值；内存新局，不写存档。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const cases = [];
function read(id) {
  const e = new w.Game_Enemy(id, 0, 0);
  return {mhp: e.mhp, param: Array.from({length: 8}, (_, i) => e.param(i)),
    xparam: Array.from({length: 10}, (_, i) => round(e.xparam(i))), sparam: Array.from({length: 10}, (_, i) => round(e.sparam(i)))};
}
for (const difficulty of [3, 4, 5, 6])
  for (const flags of [[], [1], [2], [3], [4], [5], [6], [7], [8], [4, 5], [2, 4], [1, 3, 5]])
    for (const enemy of [1, 6, 193, 214])
      cases.push(makeCase(`d${difficulty}.f${flags.join('')}.e${enemy}`, {difficulty, flags, enemy}, () => {
        newGame(); w.$gameSystem.setDifficultyId(difficulty);
        for (let i = 1; i <= 8; i++) w.$gameParty['DCultyL' + i] = flags.includes(i);
        return read(enemy);
      }));
process.exit(finish(host, 'enemy_warehouse.json', {hostScope: '真实 Game_Enemy.param／xparam／sparam 经 Star_Warehouse 与 installBossDifficultyRuntime 包装；DCultyL 标志直接写在 $gameParty 上', cases}) ? 0 : 1);
