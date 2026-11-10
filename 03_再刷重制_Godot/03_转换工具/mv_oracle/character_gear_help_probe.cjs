'use strict';
// 【cc·悟空·未经审查】专属装备说明卡探针（chars-gaps1）：
// ① installDisplayPreferencesRuntime 的 characterHelpTarget 除了专属技能还认专属装备（4001、4577～4581、7904～7911 破限之心、7920～7935 云裳天衣），
//    这些装备的说明卡也走 characterHelpView（作者行分组上色：专属 \c[2]、基本 \c[0]、成长 \c[3]、效果 \c[1]）；
// ② installNativeGarouRuntime 的 G.describeRelic（RJO.HE.getDescParams 包装，type 2）每次画破限之心说明卡前往备注末尾写 <CodexGarouHelp> 十行。
// 记这些装备的模板（4001 武器、防具都记）与一个破限之心独立实例（7906、5 级、经验 12）实际画出的行（同 help_probe）。
// 产物 .sandbox/character_gear_help.json，拷成 01_Godot工程/tests/fixtures/character_gear_help_oracle.json（不进同步），专项 xiyou_character_gear_help。
const fs = require('fs'), path = require('path');
const {boot} = require('./hboot.cjs');
const {sourceIdentity} = require('./source_identity.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const OUT = path.resolve(__dirname, '.sandbox');
const identity = sourceIdentity(APP);
const r = boot(APP, {tolerant: true, log: false});
const w = r.window;
if (r.errors.length || w.CodexRuntime.status().some(m => m.state !== 'installed') || !w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败');
w.eval('ConfigManager.applyData({}); DataManager.setupNewGame(); $gameSystem.setDifficultyId(3);');
const SW = w.RJO.SW;
let size = 0, color = '', rows = null;
const cs = SW.changeTextSize; SW.changeTextSize = function (s) { size = s; return cs.apply(this, arguments); };
const cc = SW.changeTextColor; SW.changeTextColor = function (c) { color = c; return cc.apply(this, arguments); };
const dc = SW.drawContentText;
SW.drawContentText = function (text, x, y, width, align) {
  if (rows) rows.push([String(text), Number(size), String(color), Number(y), align === undefined || align === null || align === '' ? null : Number(align)]);
  return dc.apply(this, arguments);
};
function card(item) {
  rows = [];
  const h = new w.Sprite_ItemHelp(w.RJO.HE.ItemDescWidth);
  h.setItem(item);
  const o = {width: h.width, height: h.visible ? h.height : 0, rows};
  rows = null;
  return o;
}
const relics = w.CodexGarou.config.relics;
const ids = [4001, 4577, 4578, 4579, 4580, 4581, ...relics];
for (let id = 7920; id <= 7935; id++) ids.push(id);
const templates = ids.filter(id => w.$dataArmors[id] && String(w.$dataArmors[id].name || '').trim()).map(id => ({kind: 'armor', id, ...card(w.$dataArmors[id])}));
templates.push({kind: 'weapon', id: 4001, ...card(w.$dataWeapons[4001])});
// 独立实例：DataManager.registerNewItem 新号、baseItemId 指回原型；level／exp 是独立装备字段，_garouStage 由同步写
const inst = w.DataManager.registerNewItem(w.$dataArmors[relics[2]]);
inst.level = 5; inst.exp = 12; inst._garouStage = 2;
const instance = {base: relics[2], level: 5, exp: 12, stage: 2, ...card(inst)};
// 画两次：describeRelic 先删旧 <CodexGarouHelp> 块再写，第二张卡不应多出一份
const again = card(inst);
fs.mkdirSync(OUT, {recursive: true});
fs.writeFileSync(path.join(OUT, 'character_gear_help.json'), JSON.stringify({schemaVersion: 1, sourceIdentity: identity, templates, instance, againRows: again.rows.length}));
console.log('character_gear_help: templates', templates.length, 'instance rows', instance.rows.length, 'again', again.rows.length);
process.exit(0);
