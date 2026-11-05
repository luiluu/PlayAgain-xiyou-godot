'use strict';
// 说明卡探针（小猫一族）：在正式版 MV 引擎里对每件物品/装备/技能调用 Sprite_ItemHelp.setItem（HelpExtend＋ItemQuality＋
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
// 小猫剑圣一族（note 含 <CodexCat:）的说明卡：characterHelpView 走 CodexCat.helpItem，分「没有 178」（预览）和「178 已建、10 级」两种。
// 仅写 .sandbox/cat_help_cards.json。
const out = {sourceIdentity: identity, releaseVersion: identity.releaseVersion, states: {}};
const targets = [];
for (let id = 10437; id <= 10450; id++) targets.push(['skills', w.$dataSkills, id]);
for (const id of [2899, 2900]) targets.push(['items', w.$dataItems, id]);
targets.push(['armors', w.$dataArmors, 7999]);
function measure() {
  const res = [];
  for (const [cat, table, id] of targets) {
    const it = table[id];
    if (!it || !/<CodexCat:/.test(it.note || '')) continue;
    res.push({cat, id, name: it.name, ...card(it)});
  }
  return res;
}
w.$gameActors._data[178] = undefined;   // 预览态：没有 178（CodexCat 取不到就用初始状态的替身）
out.states.preview = measure();
w.$gameActors.actor(178).changeLevel(10, false);
out.states.level10 = measure();
if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
fs.mkdirSync(OUT, {recursive: true});
fs.writeFileSync(path.join(OUT, 'cat_help_cards.json'), JSON.stringify(out));
console.log(JSON.stringify({preview: out.states.preview.length, level10: out.states.level10.length}));
process.exit(0);
