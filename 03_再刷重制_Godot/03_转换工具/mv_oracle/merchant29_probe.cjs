'use strict';
// 【cc·八戒·未经审查】深渊／不朽商人（v0.30 起 installAbyssMerchantRuntime，CodexAbyssMerchant）「修复后原版」参照（DG，Kyo 11-06 定修）。
// 新源 v0.62.12 的 33 条 355 把 parameters 存成字符串，YEP command355 只 eval 第一个字符，complete／openCurrent 从不生效（v0.62.13 正式 MOD 已修）。
// 这里把 CE1439 与各商人地图 NPC 第 2 页那几条的 parameters 改回 [整段]（同 v0.62.13），再量：
// ① complete（CE1439 末条，真跑解释器）：Game_Map.setup 开新一轮、真实 BattleManager.setup／startBattle／endBattle 记本场；胜负、敌群、换图、领两次、
//    出现率 0.5 与保底 3（同一身份连续没出现两次，第三次必出）、未知存在（不朽／深渊身份键、来源地图）；toast、点数账、商人页、openCurrent 推场景。
// ② draw（M.draw）：各档、各分组的生成结果（基础装备、特效、名字、八项属性、孔数）、点数扣除、次数上限、点数不足、没有商人。
// ③ preview：装备池列表（名字＋分组）。
// Math.random 按用例序列（序列外 0.5）；地图 setup 时的种子同样取 Math.random。
// 产物 .sandbox/merchant29.json，手工复制为 tests/fixtures/merchant29_oracle.json（tests/xiyou_merchant29 对照，不进同步）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const M = w.CodexAbyssMerchant;
if (!M || !M.complete) throw new Error('商人模块未安装');
const toasts = [], pushed = [];
if (!w.$) w.$ = {};
w.$.toaster = o => toasts.push(String(o && o.message || ''));
const stub = new Proxy({}, {get: () => () => {}});
w.SceneManager.push = function (cls) { pushed.push(cls === w.Scene_Merchant29 ? 'Scene_Merchant29' : String(cls && cls.name)); };
w.eval('ImageManager.isReady=function(){return true;};');
const fixParams = list => (list || []).forEach(c => { if (c && typeof c.parameters === 'string') c.parameters = [c.parameters]; });
w.$dataCommonEvents.forEach(ce => ce && fixParams(ce.list));
const C = w.$dataCodexMerchants;
let seq = [];
const setRand = list => { seq = list.slice(); };
w.Math.random = () => (seq.length ? seq.shift() : 0.5);
const PARTY = [1, 8, 9, 10];
function fresh() {
  newGame(); toasts.length = 0; pushed.length = 0; seq = [];
  w.Math.random = () => (seq.length ? seq.shift() : 0.5);
  w.eval('$gameParty._actors=[' + PARTY + ']; $gameParty._battleMembers=[' + PARTY + ',0];');
  M.active = false; M.interpreter = null;
}
function goto(map, origin) {
  w.DataManager.loadMapData(map);
  w.$dataMap.events.forEach(e => e && e.pages.forEach(p => fixParams(p.list)));
  if (origin !== undefined) w.$gameMap._mapId = origin;
  w.$gameMap.setup(map);
  if (origin !== undefined && w.$gameMap._yunUnknownOrigin == null && origin !== null) w.$gameMap._yunUnknownOrigin = origin;
}
function battle(troop, result) {
  const bm = w.BattleManager; bm.setup(troop, true, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.SceneManager._scene = {_otbDisplayWindow: stub};
  bm.startBattle();
  if (result !== undefined) bm.endBattle(result);
}
function runCE1439Tail() {
  const list = w.$dataCommonEvents[1439].list, last = list.filter(c => c.code === 355).pop();
  const it = new w.Game_Interpreter(); it.setup([w.JsonEx.makeDeepCopy(last), {code: 0, indent: 0, parameters: []}], 0);
  it.update();
  return {wait: it._waitMode, text: last.parameters[0]};
}
const merchantEvent = () => (C.merchantEvents.find(e => e.map === w.$gameMap.mapId()) || {}).event;
function pageOf() {
  const id = merchantEvent(); if (!id) return null;
  const ev = w.$gameMap.event(id); if (!ev) return null;
  return ev.findProperPageIndex();
}
const snap = () => {
  const run = w.$gameMap._merchantRun29, l = w.$gameSystem._codexMerchants29 || null;
  return {run: run && {sequence: run.sequence, claimed: run.claimed, appeared: run.appeared, used: run.used, seed: run.seed, identity: run.identity || null, pool: run.pool ? run.pool.length : null},
    ledger: l && JSON.parse(JSON.stringify(l)), has: M.hasMerchant(), page: pageOf(), toasts: toasts.slice(), pushed: pushed.slice(), active: !!M.active};
};
const cases = [];
const ROUTE = 37, TROOP = C.routes[ROUTE].troops[0];
// ① complete
const COMPLETE = [
  // tag, 地图, 敌群, 胜负, Math.random 序列（setup 种子、complete 出现）
  ['win.appear', ROUTE, TROOP, 0, [0.5, 0.1]],
  ['win.miss', ROUTE, TROOP, 0, [0.5, 0.9]],
  ['win.edge', ROUTE, TROOP, 0, [0.5, 0.5]],      // random<0.5 才出现：0.5 不出
  ['lost', ROUTE, TROOP, 1, [0.5, 0.1]],
  ['escape', ROUTE, TROOP, 2, [0.5, 0.1]],
  ['other_troop', ROUTE, 3, 0, [0.5, 0.1]],
  ['not_route', 4, TROOP, 0, [0.5, 0.1]],
  ['route38', 38, C.routes[38].troops[1], 0, [0.25, 0.1]]
];
for (const [tag, map, troop, result, rolls] of COMPLETE) cases.push(makeCase(`complete.${tag}`, {map, troop, result, rolls}, () => {
  fresh(); setRand(rolls.slice(0, 1)); goto(map); const before = snap();
  battle(troop, result);
  setRand(rolls.slice(1)); const r = runCE1439Tail();
  return {before: {page: before.page, run: before.run}, ...r, after: snap()};
}));
cases.push(makeCase('complete.no_battle', {map: ROUTE}, () => { fresh(); goto(ROUTE); w.BattleManager.setup(TROOP, true, false); return {ok: M.complete(null), after: snap()}; }));
cases.push(makeCase('complete.twice', {map: ROUTE}, () => {
  fresh(); goto(ROUTE); battle(TROOP, 0); setRand([0.9]); runCE1439Tail();
  setRand([0.1]); const second = M.complete(null); return {second, after: snap()};
}));
cases.push(makeCase('complete.left_map', {map: ROUTE}, () => {
  fresh(); goto(ROUTE); battle(TROOP, 0); goto(38); return {ok: M.complete(null), after: snap()};
}));
cases.push(makeCase('complete.reenter', {map: ROUTE}, () => {
  // 打完离开再回来：新一轮（sequence+1），上一场的战斗记录不算本轮
  fresh(); goto(ROUTE); battle(TROOP, 0); goto(4); goto(ROUTE); return {ok: M.complete(null), after: snap()};
}));
cases.push(makeCase('complete.pity', {map: ROUTE}, () => {
  fresh(); const rounds = [];
  for (const r of [0.9, 0.9, 0.9, 0.9]) { goto(4); goto(ROUTE); battle(TROOP, 0); setRand([r]); runCE1439Tail(); rounds.push(snap()); }
  return {rounds: rounds.map(s => ({appeared: s.run.appeared, misses: s.ledger.misses, balances: s.ledger.balances, toasts: s.toasts}))};
}));
// 未知存在：不朽／深渊身份（来源地图）、没有来源时按变量 107
const UNKNOWN = [['abyss', 152, 57], ['immortal', 152, 38], ['legacy', 152, null]];
for (const [tag, map, origin] of UNKNOWN) if (C.routes[map]) cases.push(makeCase(`unknown.${tag}`, {map, origin}, () => {
  fresh(); if (origin === null) w.$gameVariables.setValue(107, 2);
  goto(map, origin === null ? 4 : origin);
  const troop = (w.CodexYunshang.config.unknownBattles[map] || {troops: C.routes[map].troops}).troops[0];
  battle(troop, 0); setRand([0.1]); runCE1439Tail();
  return {troop, routeTroops: C.routes[map].troops, origin: w.$gameMap._yunUnknownOrigin == null ? null : w.$gameMap._yunUnknownOrigin, immortal: w.CodexYunshang.isImmortalClear(), after: snap()};
}));
// ② draw
function present(map, balance) {
  fresh(); goto(map); battle(C.routes[map].troops[0], 0); setRand([0.1]); runCE1439Tail(); toasts.length = 0; pushed.length = 0; M.active = false;
  const key = w.$gameMap._merchantRun29.identity.key; w.$gameSystem._codexMerchants29.balances[key] = balance;
  return key;
}
const view = i => i && {id: i.id, base: Number(i.originalBaseItemId || i.baseItemId), name: i.name, params: i.params.slice(), affix: i._codexExtraAffix29 || null,
  slots: i.upgradeSlots === undefined ? null : i.upgradeSlots, price: i.price, atypeId: i.atypeId, wtypeId: i.wtypeId, etypeId: i.etypeId, merchant: !!i._codexMerchant29};
const tryDraw = (tier, g) => { try { const i = M.draw(tier, g); return {ok: true, item: view(i)}; } catch (e) { return {ok: false, error: e.message}; } };
for (const [tag, map, tier, g] of [['t0.weapon', ROUTE, 0, '武器'], ['t1.armor', ROUTE, 1, '防具'], ['t2.acc', ROUTE, 2, '饰品'], ['t0.any', 38, 0, null]]) cases.push(makeCase(`draw.${tag}`, {map, tier, group: g}, () => {
  const key = present(map, 500); const pool = M.pool(g).length;
  const r = tryDraw(tier, g);
  return {key, pool, ...r, balance: M.balance(key), used: w.$gameMap._merchantRun29.used, weapons: w.$gameParty.weapons().length, armors: w.$gameParty.armors().length};
}));
cases.push(makeCase('draw.sequence', {map: ROUTE}, () => {
  const key = present(ROUTE, 500); const out = [];
  for (let n = 0; n < 4; n++) out.push(tryDraw(0, '武器'));
  return {key, out, balance: M.balance(key), used: w.$gameMap._merchantRun29.used};
}));
cases.push(makeCase('draw.poor', {map: ROUTE}, () => { const key = present(ROUTE, 29); return {key, r: tryDraw(0, '武器'), balance: M.balance(key)}; }));
cases.push(makeCase('draw.no_merchant', {map: ROUTE}, () => { fresh(); goto(ROUTE); return {r: tryDraw(0, '武器')}; }));
cases.push(makeCase('draw.bad_tier', {map: ROUTE}, () => { present(ROUTE, 500); return {r: tryDraw(3, '武器')}; }));
// ③ 池子预览
for (const map of [ROUTE, 152]) if (C.routes[map]) cases.push(makeCase(`pool.${map}`, {map}, () => {
  fresh(); goto(map);
  const r = C.routes[map];
  return {name: r.name, pool: r.pool.map(d => { const i = w['$data' + d.db][d.id]; return [d.db, d.id, i.name, d.db === 'Weapons' ? '武器' : [9, 10, 11, 12].indexOf(i.etypeId) >= 0 ? '饰品' : '防具']; })};
}));
process.exit(finish(host, 'merchant29.json', {scope: 'Native installAbyssMerchantRuntime with v0.62.13 parameter fix (string 355 parameters → [string]) on CE1439 and merchant map events; real Game_Map.setup, BattleManager.setup/startBattle/endBattle; Math.random scripted per case (else 0.5); SceneManager.push recorded.',
  config: {costs: C.costs, reward: C.reward, encounterRate: C.encounterRate, pity: C.pity, visitLimit: C.visitLimit}, cases}) ? 0 : 1);
