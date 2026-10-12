// 地图探针：正式 v0.04 的 Game_Map.isPassable，逐格逐方向输出，供 Godot 通行判定对照。
// 用法：node map_probe.cjs → 01_Godot工程/modes/xiyou/generated/oracle/maps.json
'use strict';
const fs = require('fs'), path = require('path');
const {boot} = require('./hboot.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Applications/再刷一把：西游（mod_KYO）.app/Contents/Resources/app.nw';
const OUT = path.resolve(__dirname, '../../01_Godot工程/modes/xiyou/generated/oracle');
const SLICE = JSON.parse(fs.readFileSync(path.join(__dirname, '../xiyou_slice.json'), 'utf8'));
const w = boot(APP, {tolerant: true, log: false, allowWrite: [OUT]}).window;
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
}
fs.mkdirSync(OUT, {recursive: true});
fs.writeFileSync(path.join(OUT, 'maps.json'), JSON.stringify(out));
console.log('maps', Object.keys(out).join(','));
process.exit(0);
