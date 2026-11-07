'use strict';
// v0.62 installBabyAllActorsRuntime（宝宝路线号角商店全部角色免费）参照：真实 Scene_Shop.prepare 整条链改出的商品表、
// 免费期间号角的额外货币买入价、超强者开放。内存新局（队伍 1/8/9/10），不写存档。用法：XIYOU_APP=…/v0.62.12/app.nw node baby_all_actors_probe.cjs
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const B = () => w.CodexBabyAllActors;
function prepare(goods) {
  const sc = Object.create(w.Scene_Shop.prototype);
  sc.prepare(JSON.parse(JSON.stringify(goods)), false);
  const horn = w.$dataItems[10];
  const out = {goods: sc._goods, free: !!sc._codexBabyFree, hornItemBuyPrice: JSON.parse(JSON.stringify(horn.itemBuyPrice || {})),
    hornVariableBuyPrice: JSON.parse(JSON.stringify(horn.variableBuyPrice || {}))};
  B().makeFree(false);
  out.restoredItemBuyPrice = JSON.parse(JSON.stringify(horn.itemBuyPrice || {}));
  return out;
}
const GOODS = [[0, 10, 0, 0], [0, 1, 0, 0], [1, 1, 0, 0]];
const cases = [];
cases.push(makeCase('off', {baby: false, goods: GOODS}, () => { newGame(); return prepare(GOODS); }));
cases.push(makeCase('on', {baby: true, goods: GOODS}, () => { newGame(); w.$gameSwitches.setValue(2496, true); return prepare(GOODS); }));
cases.push(makeCase('on.no_horn', {baby: true, goods: [[0, 1, 0, 0]]}, () => { newGame(); w.$gameSwitches.setValue(2496, true); return prepare([[0, 1, 0, 0]]); }));
cases.push(makeCase('on.owned', {baby: true, goods: GOODS, saved: [12], taken: [16], recruitedVar: 62, bag: 33},
  () => { newGame(); w.$gameSwitches.setValue(2496, true); w.$gameParty._saveactors = [12]; B().taken().push(16);
    w.$gameVariables.setValue(62, 1); w.$gameParty.gainItem(w.$dataItems[33], 1); return prepare(GOODS); }));
cases.push(makeCase('super', {}, () => { newGame(); const D = w.CodexBossDifficulty; const off = !!D.superStrongEnabled();
  w.$gameSwitches.setValue(2496, true); return {off, on: !!D.superStrongEnabled()}; }));
cases.push(makeCase('horn_actor', {}, () => { newGame(); const m = {};
  w.$dataItems.forEach(it => { if (it && /^伙伴号角/.test(it.name)) m[it.id] = B().hornActor(it); }); return m; }));
process.exit(finish(host, 'baby_all_actors.json', {hostScope: '真实 Scene_Shop.prepare 链（installBabyAllActorsRuntime 最外层）＋CodexBossDifficulty.superStrongEnabled；新局队伍 1/8/9/10', cases}) ? 0 : 1);
