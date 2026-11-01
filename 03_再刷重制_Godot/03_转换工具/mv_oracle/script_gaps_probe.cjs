'use strict';
// 事件脚本普查第一批（悟空 events1）：重制认不出的两种写法在正式引擎里的结果。
// - 大厅小盖盖调速（Map004 EV044）：脚本 $gamePlayer._moveSpeed = 3／4／5，读 _moveSpeed、realMoveSpeed（走／冲刺），存读档往返后再读；
//   另：下载具 getOffVehicle 里 setMoveSpeed(4)（rpg_objects），这里直接调原函数的那一句等价路径不好搭，只量调速与存档。
// - 牛头人认证（Map017 EV004）：条件分支脚本 $gameSystem.defeatNumber(66) >= 999／9999，击败数 0／998／999／9998／9999 各一例，
//   在 Game_Interpreter 里真跑条件分支（真支设变量 1＝1、否则支设 2），读变量 1。
// 新游戏（Math.random 0.5），只在内存；产物 .sandbox/script_gaps.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame, restore, encode} = host;
const cmd = (code, parameters, indent) => ({code, indent: indent || 0, parameters});
const runList = list => { const it = new w.Game_Interpreter(); it.setup(list, 0); let n = 0; while (it.isRunning() && n++ < 100) it.update(); return n; };
const cases = [];
for (const speed of [3, 4, 5]) {
  cases.push(makeCase('moveSpeed.' + speed, {map: 4, event: 44, script: '$gamePlayer._moveSpeed = ' + speed}, () => {
    newGame();
    runList([cmd(355, ['$gamePlayer._moveSpeed = ' + speed]), cmd(0, [])]);
    const p = w.$gamePlayer, walk = p.realMoveSpeed();
    p._dashing = true; const dash = p.realMoveSpeed(); p._dashing = false;
    const saved = encode(); restore(saved);
    return {moveSpeed: p._moveSpeed, walk, dash, afterLoad: w.$gamePlayer._moveSpeed};
  }));
}
for (const need of [999, 9999]) {
  for (const kills of [0, 998, 999, 9998, 9999]) {
    if (need === 999 && kills > 999) continue;
    if (need === 9999 && kills < 998) continue;
    const expr = '$gameSystem.defeatNumber(66) >= ' + need;
    cases.push(makeCase('defeat.' + need + '.' + kills, {map: 17, event: 4, enemy: 66, kills, condition: expr}, () => {
      newGame();
      w.$gameSystem.clearDefeatNumber();
      for (let i = 0; i < kills; i++) w.$gameSystem.incrementDefeatNumber(66);
      runList([cmd(111, [12, expr]), cmd(122, [1, 1, 0, 0, 1], 1), cmd(0, [], 1), cmd(411, []), cmd(122, [1, 1, 0, 0, 2], 1), cmd(0, [], 1), cmd(412, []), cmd(0, [])]);
      return {defeatNumber: w.$gameSystem.defeatNumber(66), branch: w.$gameVariables.value(1)};
    }));
  }
}
process.exit(finish(host, 'script_gaps.json', {hostScope: '新游戏（Math.random 0.5）；事件脚本普查第一批：调速脚本、击败数条件（悟空 events1）', cases}) ? 0 : 1);
