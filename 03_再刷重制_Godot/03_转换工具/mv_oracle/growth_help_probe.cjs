'use strict';
// 【cc·八戒·未经审查】成长装备说明卡探针（growth3）：心之钢／杰作利维坦／狂妄／杰作无我的实例在不同层数、旧版生命、
// 本场待结算、扬名增益下，正式版 Sprite_ItemHelp.setItem（H/U.helpView → describe → groupHelpRows）实际画出的行。
// 每例记下实例刚建好时（层数 0 时 describe 过）的备注与说明 note0／description0，再改层数、调 describe（同胜利结算），
// 重制拿 note0 加层数字段走 XHelpCard.content 比。画行记录同 help_probe。另记装备评分 CodexCombatPower.equipment（power，成长装备按阶加成）。
// 产物 .sandbox/growth_help.json，拷成 01_Godot工程/tests/fixtures/growth_help_oracle.json（不进同步），专项 xiyou_growth_help。
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
const H = w.CodexHeartsteel, U = w.CodexHubris;
if (!H || !U || !H.helpView || !U.helpView) throw new Error('心钢／狂妄说明模块未安装');
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
function gear(base) {
  w.Math.random = () => 0.5;
  w.$gameParty.gainItem(w.$dataArmors[base], 1, false);
  const list = w.$gameParty.armors().filter(x => x.baseItemId === base);
  return list[list.length - 1];
}
const actor = w.$gameActors.actor(1);
w.$gameParty._actors = [1];
const cases = [];
// fields：实例字段；pending：本场待结算；buff：扬名增益 {rate, remaining, sameRound}
function add(id, base, fields, opt) {
  opt = opt || {};
  const it = gear(base);
  const rec = {id, base, name: it.name, note0: it.note, description0: it.description, params: Array.from(it.params), price: it.price,
    traits: w.JSON.parse(w.JSON.stringify(it.traits || [])), quality: Number(it.meta.quality || 0), fields};
  Object.assign(it, fields);
  (H.isGear(it) ? H : U).describe(it);
  if (opt.pending) (H.isGear(it) ? H : U)._ledger.push({item: it, gain: opt.pending});
  let restore = null;
  if (opt.buff) {
    const slot = actor.equipSlots().indexOf(it.etypeId);
    actor.changeEquip(slot, it);
    const inBattle = w.$gameParty.inBattle, turn = w.$gameTroop.turnCount;
    w.$gameParty.inBattle = () => true;
    w.$gameTroop.turnCount = () => 2;
    actor._codexHubrisBuff = {itemId: it.id, rate: opt.buff.rate, remaining: opt.buff.remaining, round: opt.buff.sameRound ? 2 : 1};
    restore = () => { w.$gameParty.inBattle = inBattle; w.$gameTroop.turnCount = turn; delete actor._codexHubrisBuff; actor.changeEquip(slot, null); };
  }
  const pw = w.CodexCombatPower.equipment(it);
  rec.power = {total: pw.total, parts: Array.from(pw.parts), rows: pw.rows.map(x => ({label: x.label, parts: Array.from(x.parts)}))};
  rec.note = it.note;
  rec.description = it.description;
  Object.assign(rec, card(it));
  if (opt.pending) { H._ledger = []; U._ledger = []; }
  if (restore) restore();
  rec.pending = opt.pending || 0;
  rec.buff = opt.buff || null;
  cases.push(rec);
}
add('heart.0', 7900, {_codexHeartsteelStacks: 0});
add('heart.100', 7900, {_codexHeartsteelStacks: 100});
add('heart.350.legacy', 7900, {_codexHeartsteelStacks: 350, _codexHeartsteelHp: 1234});
add('heart.99.pending', 7900, {_codexHeartsteelStacks: 99}, {pending: 7});
add('lev.0', 7901, {_codexHeartsteelStacks: 0});
add('lev.5049.pending', 7901, {_codexHeartsteelStacks: 5049}, {pending: 3});
add('hubris.0', 7902, {_codexHubrisFame: 0});
add('hubris.300', 7902, {_codexHubrisFame: 300});
add('hubris.42.pending', 7902, {_codexHubrisFame: 42}, {pending: 4});
add('hubris.600.buff', 7902, {_codexHubrisFame: 600}, {buff: {rate: 1.4, remaining: 2, sameRound: false}});
add('hubris.600.buff.same', 7902, {_codexHubrisFame: 600}, {pending: 1, buff: {rate: 1.4, remaining: 3, sameRound: true}});
add('ataraxia.1000', 7903, {_codexHubrisFame: 1000});
if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
fs.mkdirSync(OUT, {recursive: true});
fs.writeFileSync(path.join(OUT, 'growth_help.json'), JSON.stringify({schemaVersion: 1, sourceIdentity: identity, cases}));
console.log(JSON.stringify({cases: cases.length, rows: cases.map(c => c.rows.length)}));
process.exit(0);
