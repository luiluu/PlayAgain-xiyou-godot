'use strict';
// 【cc·悟空·未经审查】179 流萤第三期：萨姆残核掉落概率（v0.62.12 installLiuyingRuntime 第 16 节 L.coreRate／coreRateFor／coreMapOk）
// 与 makeRewards 包装（敌群里倒下的标记敌人各掷一次）。产物 .sandbox/liuying3.json → tests/fixtures/liuying3_oracle.json。
// 跑法：XIYOU_APP=…/冻结正式源/v0.62.12/app.nw node liuying3_probe.cjs
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const L = w.CodexLiuying;
if (!L || typeof L.coreRateFor !== 'function') throw new Error('流萤模块未安装');
w.eval('CodexZones.ENABLED=false;');
const ENEMIES = JSON.parse(process.env.LIUYING3_ENEMIES || '[584, 647, 1]');
const MAPS = [37, 93, 1];
const ROUTES = {none: [], hell: [2494], doom: [2487], primordial: [2483]};
const cases = [];
for (const [route, sws] of Object.entries(ROUTES)) {
  cases.push(makeCase(`rate.${route}`, {route, switches: sws}, () => {
    newGame();
    for (const id of sws) w.$gameSwitches.setValue(id, true);
    const rows = [];
    for (const map of MAPS) {
      w.$gameMap._mapId = map;
      w.$dataMap = JSON.parse(require('fs').readFileSync(require('path').join(process.env.XIYOU_APP, 'data', 'Map' + String(map).padStart(3, '0') + '.json'), 'utf8'));
      for (const id of ENEMIES) rows.push({map, enemy: id, ok: L.coreMapOk(), rate: L.coreRateFor(w.$dataEnemies[id])});
    }
    return {base: L.coreRate(), rows};
  }));
}
process.exit(finish(host, 'liuying3.json', {hostScope: '流萤第三期：萨姆残核掉落概率（v0.62.12）', cases}) ? 0 : 1);
