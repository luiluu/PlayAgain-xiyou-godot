'use strict';
// MOG_CollapseEffects 倒下粉碎参照（bailong-visual2）：用真实 Sprite_Enemy＋插件代码量碎片网格、时序。
// 默认死亡效果 0（粉碎，方向 Left）；全库没有 Collapse Effect／Collapse Animation 备注，所以所有敌人都走这一条。
// 随机量（sx、op）只量取值范围；网格（碎片大小、行列、取图矩形、起点）是确定的。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');
function battle() {
  if (w.$gameParty) w.$gameParty._inBattle = false;
  newGame(); w.eval('$gameParty._actors=[];'); w.$gameParty.addActor(1);
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  w.BattleManager.setup(2, true, true);
}
function spriteOf(id, bw, bh) {
  const en = new w.Game_Enemy(id, 300, 300);
  const a = new w.Sprite(), b = new w.Sprite(), sp = new w.Sprite_Enemy(en);
  a.addChild(b); b.addChild(sp);
  // 头less 环境图片不一定载入：直接给一张指定大小的位图，只量几何
  sp.bitmap = new w.Bitmap(bw, bh);
  // 参照引擎的 Sprite 是桩，没有真实宽高／取图框：给主精灵固定宽高，并让所有精灵记录 setFrame
  Object.defineProperty(sp, 'width', {get: () => bw, set: () => {}, configurable: true});
  Object.defineProperty(sp, 'height', {get: () => bh, set: () => {}, configurable: true});
  return {en, sp};
}
w.eval('Sprite.prototype.setFrame=function(x,y,ww,hh){this.__f=[x,y,ww,hh];this._frame={x:x,y:y,width:ww,height:hh};};');
const cases = [];
cases.push(makeCase('params', {}, () => {
  battle();
  return {def: w.Moghunter.collDefaultCollapse, dir: w.Moghunter.collShatterDirection,
    tagged: w.$dataEnemies.filter(e => e && /collapse (effect|animation)/i.test(e.note || '')).length,
    tagCount: w.$dataSkills.filter(s => s && /collapse (effect|animation)/i.test(s.note || '')).length};
}));
cases.push(makeCase('shatter', {}, () => {
  battle();
  let seed = 12345;  // 固定种子的随机数，量 sx、op 的取值范围
  w.Math.random = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; };
  const out = [];
  for (const [bw, bh] of [[100, 120], [64, 64], [200, 100], [333, 211], [48, 80]]) {
    const {en, sp} = spriteOf(1, bw, bh);
    for (let i = 0; i < 3; i++) sp.update();
    en.setHp(0); en.performCollapse();
    sp.update();
    const frags = sp._spriteCol || [];
    const rows = {}; for (const f of frags) rows[f.__f[1]] = (rows[f.__f[1]] || 0) + 1;
    const first = frags[0], last = frags[frags.length - 1];
    let sxMin = 9, sxMax = 0, opMin = 9, opMax = 0;
    for (const f of frags) { sxMin = Math.min(sxMin, f.sx); sxMax = Math.max(sxMax, f.sx); opMin = Math.min(opMin, f.op); opMax = Math.max(opMax, f.op); }
    const rec = {bw, bh, type: sp.collapseType(), count: frags.length, fragSize: Math.floor((bh + bw) / 40),
      first: first && {x: first.x + first.sx, y: first.y + first.sx, fx: first.__f[0], fy: first.__f[1], fw: first.__f[2], fh: first.__f[3]},
      last: last && {x: last.x + last.sx, y: last.y + last.sx, fx: last.__f[0], fy: last.__f[1], fw: last.__f[2], fh: last.__f[3]},
      sxMin, sxMax, opMin, opMax, mainFrame: sp.__f || null, hasDuration: sp._effectDuration, anchor: first && [first.anchor.x, first.anchor.y]};
    rec.rowCounts = Object.entries(rows).map(([y, c]) => [+y, c]);
    let n = 0;
    while (sp._effectType && n < 400) { sp.update(); n++; }
    rec.framesUntilDone = n; rec.opacityAfter = Math.round(sp.opacity);
    out.push(rec);
  }
  return out;
}));
process.exit(finish(host, 'collapse.json', {scope: 'MOG_CollapseEffects default shatter on frozen source', cases}) ? 0 : 1);
