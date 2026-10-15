// 地图探针：当前正式版的 Game_Map.isPassable，逐格逐方向输出，供 Godot 通行判定对照。
// 用法：node map_probe.cjs → 仅写 .sandbox/maps.json；核验后由资料库侧复制到 generated/oracle。
'use strict';
const fs = require('fs'), path = require('path');
const {boot} = require('./hboot.cjs');
const {sourceIdentity} = require('./source_identity.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const OUT = path.resolve(__dirname, '.sandbox');
const SLICE = JSON.parse(fs.readFileSync(path.join(__dirname, '../xiyou_slice.json'), 'utf8'));
const identity = sourceIdentity(APP);
const r = boot(APP, {tolerant: true, log: false});
const w = r.window;
if (r.errors.length || w.CodexRuntime.status().some(m => m.state !== 'installed') || !w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败');
w.eval('ConfigManager.applyData({}); DataManager.setupNewGame();');
const out = {};
for (const id of SLICE.maps) {
  w.eval('DataManager.loadMapData(' + id + ');');
  w.eval('$gameMap.setup(' + id + ');');
  const m = w.$gameMap, rows = [];
  for (let y = 0; y < m.height(); y++) {
    let row = '';
    for (let x = 0; x < m.width(); x++) {
      // 每格一个十六进制位：bit0=下 bit1=左 bit2=右 bit3=上 可通行
      const v = [2, 4, 6, 8].reduce((acc, d, i) => acc | (m.isPassable(x, y, d) ? 1 << i : 0), 0);
      row += v.toString(16);
    }
    rows.push(row);
  }
  out[id] = {width: m.width(), height: m.height(), passable: rows};
  // 循环地图（scrollType）：越过边缘的那一步，每行／列一位，1＝能从边缘格走到另一侧（Game_Map.roundXWithDirection 后双向 isPassable）
  if (m.isLoopHorizontal() || m.isLoopVertical()) {
    out[id].loop = [m.isLoopHorizontal(), m.isLoopVertical()];
    const W = m.width(), H = m.height(), cross = (x, y, d) => m.isPassable(x, y, d) && m.isPassable(m.roundXWithDirection(x, d), m.roundYWithDirection(y, d), 10 - d);
    if (m.isLoopHorizontal()) out[id].wrapLeft = Array.from({length: H}, (_, y) => cross(0, y, 4) ? 1 : 0).join('');
    if (m.isLoopVertical()) out[id].wrapUp = Array.from({length: W}, (_, x) => cross(x, 0, 8) ? 1 : 0).join('');
  }
}
fs.mkdirSync(OUT, {recursive: true});
if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
fs.writeFileSync(path.join(OUT, 'maps.json'), JSON.stringify(out));
fs.writeFileSync(path.join(OUT, 'maps_source.json'), JSON.stringify(identity));
console.log('maps', Object.keys(out).join(','));
process.exit(0);
