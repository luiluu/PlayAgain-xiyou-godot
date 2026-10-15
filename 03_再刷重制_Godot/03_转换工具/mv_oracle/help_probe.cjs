'use strict';
// 说明卡探针：在正式版 MV 引擎里对每件物品/装备/技能调用 Sprite_ItemHelp.setItem（HelpExtend＋ItemQuality＋
// installDisplayPreferencesRuntime 的 characterHelpView＋战力/属性等 Codex 包装），记录实际画出的每一行
// [文字, 字号, 颜色, y, 对齐] 与卡片宽高，供 Godot XHelpCard 对照。仅写 .sandbox/help_cards.json。
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
w.eval('ConfigManager.applyData({}); DataManager.setupNewGame(); $gameSystem.setDifficultyId(3);');
// 记录画出的行：RJO.SW.drawContentText 前最后一次设置的字号/颜色
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
  const out = {width: h.width, height: h.visible ? h.height : 0, quality: Number((item.meta && item.meta.quality) || 0), rows};
  rows = null;
  return out;
}
const out = {sourceIdentity: identity, releaseVersion: identity.releaseVersion, skills: [], items: [], weapons: [], armors: [], gear: []};
const seenSkill = {};
for (const id of SLICE.actors) {
  const a = w.$gameActors.actor(id);
  a.changeLevel(SLICE.maxLevel || 30, false);
  for (const s of a.skills()) {
    if (seenSkill[s.id]) continue;
    seenSkill[s.id] = true;
    out.skills.push({id: s.id, name: s.name, ...card(s)});
  }
}
for (const sid of SLICE.extraSkills || []) if (!seenSkill[sid]) out.skills.push({id: sid, name: w.$dataSkills[sid].name, ...card(w.$dataSkills[sid])});
const pick = (table, n) => table.filter(o => o && o.id <= n && String(o.name || '').trim() !== '');
for (const it of pick(w.$dataItems, 200)) out.items.push({id: it.id, name: it.name, ...card(it)});
for (const it of pick(w.$dataWeapons, SLICE.weaponScan || 60)) out.weapons.push({id: it.id, name: it.name, ...card(it)});
for (const it of pick(w.$dataArmors, SLICE.weaponScan || 60)) out.armors.push({id: it.id, name: it.name, ...card(it)});
// 随机词缀的装备实例（与 equipment_probe 相同的生成方式；固定随机数）
function make(kind, id, roll) {
  w.Math.random = () => roll;
  w.$gameParty.RomDreamX = new w.Array(); w.$gameParty.RomDreamXNum = 0; w.$gameParty.RomDreamXs = new w.Array(); w.$gameParty.RomDreamXsNum = 0;
  const base = (kind === 'weapon' ? w.$dataWeapons : w.$dataArmors)[id];
  return w.DreamX.RandomPrefixSuffix.isConfiguredForPrefixSuffix(base) ? w.DreamX.RandomPrefixSuffix.makeItem(base) : w.DataManager.registerNewItem(base);
}
for (const [kind, id] of [['weapon', 2], ['weapon', 56], ['armor', 12], ['armor', 52], ['armor', 57]]) {
  for (const roll of [0, 0.5, 0.99]) {
    const e = make(kind, id, roll);
    out.gear.push({kind, id, roll, name: e.name, note: e.note, description: e.description, params: Array.from(e.params), price: e.price,
      traits: w.JSON.parse(w.JSON.stringify(e.traits || [])), quality: Number(e.meta.quality || 0),
      elementAmplify: w.JSON.parse(w.JSON.stringify(e.elementAmplify || {})), elementAmplifyN: w.JSON.parse(w.JSON.stringify(e.elementAmplifyN || {})), ...card(e)});
  }
}
if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
fs.mkdirSync(OUT, {recursive: true});
fs.writeFileSync(path.join(OUT, 'help_cards.json'), JSON.stringify(out));
console.log(JSON.stringify({skills: out.skills.length, items: out.items.length, weapons: out.weapons.length, armors: out.armors.length, gear: out.gear.length}));
process.exit(0);
