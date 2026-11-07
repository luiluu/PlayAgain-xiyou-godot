'use strict';
// 【cc·白龙·未经审查】星爆气流斩三本被动书（新源 js/codex/runtime/installStarburstBooksRuntime.js，v0.62.10）。
// ① rate.*：六条路线（开关同真气 route）下 KyoStarburstBooks.immortalRate()。
// ② victory.*：真实 BattleManager.endBattle(0)，真气本场 _battle 设成守层者 8／13／18 层（含试炼、缩放、同层第二场），
//    看 1121／1141／1161 的数量、送过的层、提示文字；152 号地图不朽存在（云裳 isImmortalClear 换成恒真）在 Math.random 0.5 与 0.01 下各一次。
// ③ mapstart.*：变量 20（已通过层数＋1）为 1／9／19、旧存档已送过 8 层时，Scene_Map.start 包装补发。
// 只在内存，产物 .sandbox/starburst_books.json，拷成 tests/fixtures/starburst_books_oracle.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const B = w.KyoStarburstBooks, Z = w.CodexZhenqi, Y = w.CodexYunshang;
if (!B || !Z || !Y) throw new Error('星爆被动书／真气／云裳模块未安装');
const stub = new Proxy(function () {}, {get: (_, k) => k === '_waitCount' ? 0 : (() => false), set: () => true});
// Scene_Map.start 原链要的窗口、精灵都给一个点到底的空桩（属性、调用都还是它自己；转数值为 0、真假为假的字段用 FALSY 列出）
const FALSY = new Set(['_transfer', '_waitCount', 'isActive', 'isBusy']);
const deep = new Proxy(function () {}, {get: (_, k) => k === Symbol.toPrimitive ? (() => 0) : FALSY.has(k) ? false : deep,
  apply: () => deep, set: () => true});
const toasts = [];
w.$ = Object.assign(w.$ || {}, {toaster: o => toasts.push(String(o.message))});
const ROUTE_SWITCHES = {normal: [], hard: [2500], hell: [2494], calamity: [2489], doom: [2487], primordial: [2483]};
const BOOKS = [1121, 1141, 1161];
const counts = () => BOOKS.map(id => w.$gameParty.numItems(w.$dataItems[id]));
function fresh(route) {
  newGame();
  for (const id of ROUTE_SWITCHES[route]) w.$gameSwitches.setValue(id, true);
  toasts.length = 0;
}
const cases = [];
cases.push(makeCase('module', {}, () => ({gifts: B.GIFTS, immortalMap: B.IMMORTAL_MAP, immortalBook: B.IMMORTAL_BOOK})));
for (const route of Object.keys(ROUTE_SWITCHES)) {
  cases.push(makeCase(`rate.${route}`, {route, switches: ROUTE_SWITCHES[route]}, () => {
    fresh(route);
    return {coef: Z.route().coef, rate: B.immortalRate()};
  }));
}
function victory(battle, opts = {}) {
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(opts.troop || 3, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  Z._battle = battle;
  const imm = Y.isImmortalClear, rnd = w.Math.random;
  if (opts.immortal) Y.isImmortalClear = () => true;
  if (opts.random !== undefined) w.Math.random = () => opts.random;
  try { bm.endBattle(0); } finally { Y.isImmortalClear = imm; w.Math.random = rnd; }
}
const view = () => ({counts: counts(), given: Object.assign({}, w.$gameSystem._kyoStarburstBooks || {}), toasts: toasts.slice()});
const GUARDIAN = [
  ['g8', [{guardianFloor: 8}]], ['g18', [{guardianFloor: 18}]], ['g13', [{guardianFloor: 13}]],
  ['g8.trial', [{guardianFloor: 8, trial: {id: 1}}]], ['g8.scaled', [{guardianFloor: 8, scaled: true}]],
  ['g8.twice', [{guardianFloor: 8}, {guardianFloor: 8}]], ['nobattle', [null]]];
for (const [id, battles] of GUARDIAN) {
  cases.push(makeCase(`victory.${id}`, {battles}, () => {
    fresh('normal');
    for (const b of battles) victory(b);
    return view();
  }));
}
for (const [route, random] of [['normal', 0.5], ['normal', 0.01], ['primordial', 0.02], ['primordial', 0.04]]) {
  cases.push(makeCase(`victory.immortal.${route}.r${random}`, {route, switches: ROUTE_SWITCHES[route], map: B.IMMORTAL_MAP, random}, () => {
    fresh(route);
    w.$gameMap._mapId = B.IMMORTAL_MAP;
    victory(null, {immortal: true, random});
    return view();
  }));
}
for (const [v20, before] of [[1, {}], [9, {}], [19, {}], [19, {8: 1}]]) {
  cases.push(makeCase(`mapstart.v${v20}${Object.keys(before).length ? '.had8' : ''}`, {v20, given: before}, () => {
    fresh('normal');
    w.$gameVariables.setValue(20, v20);
    w.$gameSystem._kyoStarburstBooks = Object.assign({}, before);
    const passed = Z.progressFloor();
    w.Scene_Map.prototype.start.call(deep);
    return {passed, ...view()};
  }));
}
process.exit(finish(host, 'starburst_books.json', {hostScope: '真实 BattleManager.endBattle(0)；Scene_Map.start 包装（场景对象为空桩）', cases}) ? 0 : 1);
