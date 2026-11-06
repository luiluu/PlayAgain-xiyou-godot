'use strict';
// 【cc·界面·未经审查】流萤技能卡探针（总装追加，流萤运行时清单 13、15）：installLiuyingRuntime 的
// ① 15 L.refreshText：10622 天火轰击、10623 完全燃烧的说明按流萤（179）当前进阶 0～3 阶重写（Sprite_ItemHelp.setItem 包装里触发），
//    记每阶两张卡实际画出的行（同 help_probe）、备注与 customCostText；
// ② 13 Window_Base.drawItemName 包装：10622～10632 与带 <CodexLiuyingPassive: 的技能名用 RJO.IQ.QualitiesColor[品质]，记每个的品质与颜色。
// 产物 .sandbox/liuying_help.json，拷成 01_Godot工程/tests/fixtures/liuying_help_oracle.json（不进同步），专项 xiyou_liuying_help。
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
  const out = {width: h.width, height: h.visible ? h.height : 0, rows};
  rows = null;
  return out;
}
const a = w.$gameActors.actor(179);
const ranks = [];
for (const rank of [0, 1, 2, 3, 0]) {
  a._AdvancedNum = rank;
  const one = {rank, cards: []};
  for (const id of [10622, 10623]) {
    const c = card(w.$dataSkills[id]);
    one.cards.push({id, note: w.$dataSkills[id].note, customCostText: w.$dataSkills[id].customCostText || '', ...c});
  }
  ranks.push(one);
}
// 13：drawItemName 实际用的颜色（包住 changeTextColor 看画名字前最后一次设的颜色）
const win = new w.Window_Base(new w.Rectangle(0, 0, 400, 100));
const bwin = new w.Window_BattleSkill(0, 0, 400, 100);
function drawn(win, sk) {
  let last = null;
  const bm = win.contents, dt = bm.drawText;
  bm.drawText = function (text) { if (String(text) === String(sk.name)) last = this.textColor; return dt.apply(this, arguments); };
  win.drawItemName(sk, 0, 0, 300);
  bm.drawText = dt;
  return String(last);
}
const names = [];
for (const sk of w.$dataSkills) {
  if (!sk) continue;
  const tagged = sk.id >= 10622 && sk.id <= 10632 || /<CodexLiuyingPassive:/.test(sk.note || '');
  if (!tagged && sk.id !== 10171 && sk.id !== 10001) continue;
  let last = null;
  const bm = win.contents, dt = bm.drawText;
  bm.drawText = function (text) { if (String(text) === String(sk.name)) last = this.textColor; return dt.apply(this, arguments); };
  win.drawItemName(sk, 0, 0, 300);
  bm.drawText = dt;
  const m = /<quality:\s*(\d+)>/i.exec(sk.note || '');
  names.push({id: sk.id, name: sk.name, battle: drawn(bwin, sk), table: String(w.RJO.IQ.QualitiesColor[Number(sk.meta && sk.meta.quality) || (m ? Number(m[1]) : 0)]), metaQuality: Number(sk.meta && sk.meta.quality) || 0, noteQuality: m ? Number(m[1]) : 0, color: String(last)});
}
if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
fs.mkdirSync(OUT, {recursive: true});
fs.writeFileSync(path.join(OUT, 'liuying_help.json'), JSON.stringify({schemaVersion: 1, sourceIdentity: identity, ranks, names}));
console.log(JSON.stringify({ranks: ranks.map(x => x.cards.map(c => c.rows.length)), names: names.length}));
process.exit(0);
