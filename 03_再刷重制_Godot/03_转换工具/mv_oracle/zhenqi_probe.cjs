'use strict';
// 真气第一批（installNativeZhenqiRuntime）的冻结 v0.28 参照：路线、境界与名称、加成、天道补偿、Boss 胜利真气、
// 溢出再动（OTB 首回合超额次数）、胜利结算（守层者首通／胜利、Boss、阵亡不得、溢出上限 10）与提示文字、
// 存读档、地图楼层解析、Boss 判定、状态页「修行」页行文。突破战、道法、神兵试炼留第二批，这里不测。
// 只在内存里跑：新局、战斗 setup 与 JsonEx 往返；不渲染、不写存档。
const fs = require('fs'), path = require('path');
const {APP, start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame, encode, restore} = host, Z = w.CodexZhenqi, G = w.CodexGuide;
const cases = [];
const toasts = [];
w.$ = Object.assign(w.$ || {}, {toaster: m => toasts.push(String(m && m.message))});
const ROUTE_SWITCHES = [2500, 2494, 2489, 2461, 2487, 2462, 2483, 2463];
const actor = id => w.$gameActors.actor(id);
const setData = (a, d) => { a._codexZhenqi = Object.assign({qi: 0, firsts: {}, realm: 0, pending: [], daofa: {}, spec: {}}, d); return a; };
const r6 = v => round(v);
const stateOf = a => { const s = Z.state(a); return {name: s.name, realm: s.realm, world: s.world, qi: s.qi, rate: r6(s.rate), capped: s.capped,
  next: s.next ? s.next.name : null, need: s.need, pending: s.pending, gate: s.gate, canBreak: s.canBreak, describe: Z.describe(a)}; };
const fresh = () => { newGame(); toasts.length = 0; for (const id of ROUTE_SWITCHES) w.$gameSwitches.setValue(id, false); };

// 路线
cases.push(makeCase('route.none', {}, () => { fresh(); return Z.route().key; }));
for (const sw of ROUTE_SWITCHES) cases.push(makeCase('route.' + sw, {switch: sw}, () => { fresh(); w.$gameSwitches.setValue(sw, true); return Z.route().key; }));

// 境界、名称、加成、门槛
const STATES = [[0, 0], [0, 46], [0, 47], [0, 92], [0, 100], [0, 553], [0, 599], [0, 600], [0, 5000], [1, 600], [1, 1232], [1, 1233], [1, 2499], [1, 2500],
  [2, 2500], [4, 18000], [4, 35999], [4, 36000], [5, 36000], [8, 111000], [8, 149999], [8, 150000], [9, 150000], [10, 300000], [12, 388000], [13, 500000], [13, 599999], [13, 600000], [13, 12345678]];
for (const pf of [0, 5, 10, 33]) for (const [realm, qi] of STATES) cases.push(makeCase(`state.r${realm}.q${qi}.f${pf}`, {realm, qi, progressFloor: pf}, () => {
  fresh(); w.$gameVariables.setValue(20, pf + 1); return stateOf(setData(actor(1), {realm, qi}));
}));
cases.push(makeCase('realm.allowed', {}, () => { fresh(); const out = [];
  for (let pf = 0; pf <= 34; pf++) { w.$gameVariables.setValue(20, pf + 1); out.push([pf, Z.progressFloor(), Z.allowedRealm()]); }
  return {allowed: out, required: Z.REALMS.map((_, i) => Z.requiredFloor(i)), majorByQi: [0, 599, 600, 2500, 499999, 500000, 9e6].map(q => [q, Z.majorByQi(q)])}; }));

// 天道补偿、Boss 奖励
cases.push(makeCase('comp.table', {}, () => Z.ROUTES.map(r => [r.key, Array.from({length: 35}, (_, f) => r6(Z.compFor(r.key, f)))])));
cases.push(makeCase('boss.reward', {}, () => Z.ROUTES.map(r => [r.coef, Array.from({length: 34}, (_, f) => Z.bossReward(f, r.coef))])));

// 溢出再动：OTB 首回合排序（_actionBattlers）时，追加次数超过 4 的部分每次记 1 点；下个回合的排序不记
for (const n of [1, 4, 5, 6, 7, 9, 12, 20]) for (const which of ['current', 'next']) cases.push(makeCase(`overflow.${which}.t${n}`, {makeActionTimes: n, array: which}, () => {
  fresh(); w.$gameTroop.setup(1); const a = actor(1); a.makeActionTimes = () => n; Z._ovf = {};
  const arr = new w.Array(); arr.push(a); if (which === 'current') w.BattleManager._actionBattlers = arr; else { w.BattleManager._actionBattlers = []; w.BattleManager._nextTurnActionBattlers = arr; }
  w.BattleManager.otbActionTimesModification(arr); delete a.makeActionTimes;
  return {ovf: Z._ovf[1] || 0, entries: arr.length, actionDMG: Number(a._actionDMG) || 0};
}));

// 胜利结算
function battle(troop, opts = {}) {
  if (opts.route) w.$gameSwitches.setValue(opts.route, true);
  if (opts.progress !== undefined) w.$gameVariables.setValue(20, opts.progress + 1);
  if (opts.map) { w.DataManager.loadMapData(opts.map); w.$gameMap.setup(opts.map); }
  for (const [id, d] of Object.entries(opts.data || {})) setData(actor(+id), d);
  const before = {}; w.$gameParty.members().forEach(a => { Z.data(a); before[a.actorId()] = a._codexZhenqi.qi; });
  w.BattleManager.setup(troop, true, false);
  const b = Z._battle, info = b && {troopId: b.troopId, route: b.route.key, guardianFloor: b.guardianFloor, floor: b.floor, comp: r6(b.comp)};
  for (const id of opts.dead || []) actor(id).addState(1);
  if (opts.ovf) Object.assign(Z._ovf, opts.ovf);
  toasts.length = 0; Z.onVictory();
  const gains = {}, firsts = {};
  w.$gameParty.members().forEach(a => { gains[a.actorId()] = a._codexZhenqi.qi - before[a.actorId()]; firsts[a.actorId()] = Object.keys(a._codexZhenqi.firsts).sort(); });
  for (const id of opts.dead || []) actor(id).removeState(1);
  return {battle: info, gains, firsts, toasts: toasts.slice(), cleared: Z._battle === null};
}
const V = (id, troop, opts) => cases.push(makeCase('victory.' + id, Object.assign({troop}, opts), () => { fresh(); return battle(troop, opts); }));
V('guardian20', 456, {});
V('guardian20.hard', 456, {route: 2500});
V('guardian1.calamity', 4, {route: 2461});
V('guardian5.alt245', 245, {});
V('guardian20.dead8', 456, {dead: [8]});
V('guardian20.overflow', 456, {ovf: {1: 15, 9: 3}});
V('guardian20.toCapped', 456, {data: {1: {qi: 590}}, progress: 3});
V('guardian20.toCappedGate', 456, {data: {1: {qi: 590}}, progress: 20});
V('guardian20.subLevel', 456, {data: {1: {qi: 40}}});
cases.push(makeCase('victory.guardian20.twice', {troop: 456}, () => { fresh(); const first = battle(456, {}); toasts.length = 0; return {first, second: battle(456, {})}; }));
V('plain1', 1, {});
V('plain1.overflow', 1, {ovf: {1: 4}});
V('plain1.overflowOnlyDead', 1, {ovf: {8: 4}, dead: [8]});
// 非守层者的 Boss 敌群：在楼层地图、在大厅（按进度层）
function bossTroop() {
  const guardians = new Set(Object.keys(Z.GUARDIANS).map(Number));
  for (const t of w.$dataTroops) if (t && t.members.length && !guardians.has(t.id)) {
    w.$gameTroop.setup(t.id); if (w.$gameTroop.members().some(Z.isBossEnemy)) return t.id; }
  return 0;
}
cases.push(makeCase('victory.boss.lobby', {map: 4, progress: 12}, () => { fresh(); const t = bossTroop(); return {troop: t, ...battle(t, {progress: 12})}; }));
cases.push(makeCase('victory.boss.lobby.f26', {map: 4, progress: 26}, () => { fresh(); const t = bossTroop(); return {troop: t, ...battle(t, {progress: 26, route: 2483})}; }));
cases.push(makeCase('victory.boss.lobby.f0', {map: 4, progress: 0}, () => { fresh(); const t = bossTroop(); return {troop: t, ...battle(t, {progress: 0})}; }));

// 存读档
cases.push(makeCase('save.roundtrip', {}, () => { fresh(); battle(456, {ovf: {1: 3}}); const before = JSON.stringify(actor(1)._codexZhenqi);
  restore(encode()); return {before: JSON.parse(before), after: actor(1)._codexZhenqi, retro: w.$gameSystem._codexZhenqiRetro && {route: w.$gameSystem._codexZhenqiRetro.route, floors: w.$gameSystem._codexZhenqiRetro.floors}}; }));
cases.push(makeCase('newgame.default', {}, () => { fresh(); const a = actor(9); delete a._codexZhenqi; return {data: Z.data(a), retro: {route: w.$gameSystem._codexZhenqiRetro.route, floors: w.$gameSystem._codexZhenqiRetro.floors}}; }));

// 楼层解析（MapInfos 名称，其次地图显示名）与 Boss 判定
cases.push(makeCase('map.floor', {}, () => { const infos = JSON.parse(fs.readFileSync(path.join(APP, 'data', 'MapInfos.json'), 'utf8')), out = [];
  for (const info of infos) if (info) { let disp = ''; try { disp = JSON.parse(fs.readFileSync(path.join(APP, 'data', 'Map' + String(info.id).padStart(3, '0') + '.json'), 'utf8')).displayName || ''; } catch (e) {}
    fresh(); w.DataManager.loadMapData(info.id); w.$gameMap.setup(info.id); out.push([info.id, Z.mapFloor()]); }
  return out; }));
cases.push(makeCase('boss.enemies', {}, () => { fresh(); const out = []; for (const e of w.$dataEnemies) if (e) { const g = new w.Game_Enemy(e.id, 0, 0); if (Z.isBossEnemy(g)) out.push(e.id); } return out; }));

// 状态页「修行」页（JAH_Window_Status_Zhenqi.buildRows）与战力条旁的真气文字
function pageRows(a) { const W = w.JAH_Window_Status_Zhenqi; return W.prototype.buildRows.call({_actor: a, _rows: []}); }
for (const [id, opts] of [['default', {}], ['qi2000', {data: {1: {qi: 2000}}}], ['capped', {data: {1: {qi: 700}}, progress: 3}], ['canBreak', {data: {1: {qi: 700}}, progress: 6}],
  ['hard.f20', {data: {1: {qi: 26000, realm: 4}}, progress: 20, route: 2500}], ['daozu', {data: {1: {qi: 777777, realm: 13, daofa: {lianji: 1, hufa: 1}, pending: [13]}}, progress: 33}]])
  cases.push(makeCase('page.' + id, opts, () => { fresh(); if (opts.route) w.$gameSwitches.setValue(opts.route, true); if (opts.progress !== undefined) w.$gameVariables.setValue(20, opts.progress + 1);
    for (const [aid, d] of Object.entries(opts.data || {})) setData(actor(+aid), d);
    const a = actor(1), s = Z.state(a);
    return {rows: pageRows(a).map(r => r.type === 'cols' ? {type: 'cols', cells: r.cells, system: !!r.system, warn: !!r.warn} : r),
      strip: '真气·' + s.name + ' ' + G.format.mult(s.rate) + (s.pending ? '（待选）' : s.capped ? '（瓶颈）' : ''), stripWarn: !!(s.capped || s.pending), context: (c => ({route: c.route.key, floor: c.floor, comp: r6(c.comp)}))(G.context())}; }));
cases.push(makeCase('format.mult', {}, () => [0, 0.00004, 0.0003, 0.05, 0.123, 0.99, 1, 1.04, 1.05, 9.96, 123.4, 999.9, 1000, 12345.6].map(v => [v, G.format.mult(v)])));

process.exit(finish(host, 'zhenqi.json', {hostScope: '真实 CodexZhenqi／CodexGuide 与 BattleManager.setup、otbActionTimesModification、JsonEx；无渲染，提示文字由 $.toaster 截获', cases}) ? 0 : 1);
