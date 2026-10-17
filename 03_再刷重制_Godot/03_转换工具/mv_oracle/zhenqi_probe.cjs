'use strict';
// 真气第一批（installNativeZhenqiRuntime）的冻结 v0.28 参照：路线、境界与名称、加成、天道补偿、Boss 胜利真气、
// 溢出再动（OTB 首回合超额次数）、胜利结算（守层者首通／胜利、Boss、阵亡不得、溢出上限 10）与提示文字、
// 存读档、地图楼层解析、Boss 判定、状态页「修行」页行文。第二批（文件后半）：闭关与角色页、瓶颈之战、突破、突破奖励与道法、奖励技能数值、主菜单「真气」；神兵试炼留第三批。
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


// ==== 第二批：闭关（retreat／actorPage）、瓶颈之战（startTrial、BattleManager.setup 的幻化敌人、onVictory、_trialEnd）、
// 突破（breakthrough、固定奖励技能）、突破奖励（pickFlow 属性／道法、rollDaofa、灵根／本命兵指定）、奖励技能数值（patchRewards、skillView）。
// 闭关流程原版靠 interp.setupChild 插入 101/401/102/301 指令列；这里用假解释器截下指令列，按选项号回调 Z._cb。
const fakeInterp = () => ({_eventId: 0, list: null, setupChild(list) { this.list = list; }});
const view = it => { const l = it.list || [], ch = l.find(c => c.code === 102), bt = l.find(c => c.code === 301);
  return {lines: l.filter(c => c.code === 401).map(c => c.parameters[0]), choices: ch ? ch.parameters[0] : null, cancel: ch ? ch.parameters[1] : null,
    battle: bt ? bt.parameters : null, then: l.some(c => c.code === 355)}; };
const pick = (it, k) => { Z._cb(k, it); return view(it); };
const zq = a => { const d = a._codexZhenqi; return {qi: d.qi, realm: d.realm, pending: d.pending.slice(), daofa: Object.keys(d.daofa).sort(), stages: d.daofaStages || {}}; };
const zqSkills = a => a._skills.filter(id => /<CodexZhenqi:/.test(w.$dataSkills[id].note || '')).sort((x, y) => x - y);
const spec = () => { const sp = w.$gameSystem._codexZhenqiSpec; return sp ? {w: Object.keys(sp.w).sort(), e: Object.keys(sp.e).sort()} : null; };
const withRand = (seq, fn) => { const old = w.Math.randomInt, q = seq.slice(); w.Math.randomInt = n => { const v = q.length ? q.shift() : 0; return v % n; }; try { return fn(); } finally { w.Math.randomInt = old; } };
function setupWorld(opts) {
  if (opts.route) w.$gameSwitches.setValue(opts.route, true);
  if (opts.progress !== undefined) w.$gameVariables.setValue(20, opts.progress + 1);
  if (opts.extra) for (const id of opts.extra) w.$gameParty.addActor(id);
  for (const [id, d] of Object.entries(opts.data || {})) setData(actor(+id), d);
}
const B = (id, opts, fn) => cases.push(makeCase('break.' + id, opts, () => { fresh(); setupWorld(opts); return fn(); }));

// 闭关首页：每页 4 人，标签含境界、加成与［待选奖励］／［可突破］／［通关N层后突破］
B('retreat.default', {}, () => view((it => (Z.retreat(it), it))(fakeInterp())));
B('retreat.tags', {progress: 6, data: {1: {qi: 700}, 8: {qi: 700}, 9: {qi: 3000, realm: 1, pending: [1]}, 10: {qi: 90000, realm: 4}}}, () => view((it => (Z.retreat(it), it))(fakeInterp())));
B('retreat.pages', {extra: [2, 3, 4, 5, 6]}, () => { const it = fakeInterp(); Z.retreat(it); const p0 = view(it); const p1 = pick(it, 4); const p2 = pick(it, 4); const back = pick(it, 4); return {p0, p1, p2, back}; });
B('retreat.page.clamp', {extra: [2]}, () => { const it = fakeInterp(); Z.retreat(it, 9); return view(it); });
// 角色页
for (const [id, opts] of [['default', {}], ['far', {data: {1: {qi: 1234, realm: 1}}}], ['capped', {progress: 3, data: {1: {qi: 700}}}], ['canBreak', {progress: 6, data: {1: {qi: 700}}}],
  ['pending', {progress: 6, data: {1: {qi: 3000, realm: 1, pending: [1]}}}], ['pendingBreak', {progress: 12, data: {1: {qi: 3000, realm: 1, pending: [1]}}}], ['top', {progress: 33, data: {1: {qi: 600000, realm: 13}}}]])
  B('actor.' + id, opts, () => { const it = fakeInterp(); Z.actorPage(it, actor(1)); return view(it); });
B('actor.nav', {progress: 6, data: {1: {qi: 700}}}, () => { const it = fakeInterp(); Z.retreat(it); const page = pick(it, 0); const back = pick(it, 1); pick(it, 0); const leave = Z._cbs && Z._cbs[2]; return {page, back, leaveIsNull: leave === null}; });

// 挑战瓶颈之战：条件不足的说明、不在出战队伍、心魔（狗逍遥 1 号用 770）、天劫
const TRIAL = (id, aid, opts) => B('trial.' + id, opts, () => { const it = fakeInterp(); Z.startTrial(it, actor(aid)); const t = Z._pendingTrial;
  return {view: view(it), pending: t && {actorId: t.actorId, target: t.target, kind: t.kind, troopId: t.troopId, ref: t.ref}}; });
TRIAL('notReady', 1, {progress: 6});
TRIAL('locked', 1, {progress: 3, data: {1: {qi: 700}}});
TRIAL('heart1', 1, {progress: 6, data: {1: {qi: 700}}});
TRIAL('heart8', 8, {progress: 7, data: {8: {qi: 700}}});
TRIAL('heart.f0', 8, {progress: 0, data: {8: {qi: 700, realm: 0}}});
TRIAL('heart.f21', 9, {progress: 21, data: {9: {qi: 40000, realm: 4}}});
TRIAL('tianjie', 9, {progress: 33, data: {9: {qi: 120000, realm: 7}}});
TRIAL('xian', 10, {progress: 33, data: {10: {qi: 400000, realm: 11}}});
TRIAL('reserve', 6, {progress: 6, extra: [2, 3, 4, 5, 6], data: {6: {qi: 700}}});
cases.push(makeCase('trial.ref.table', {}, () => { fresh(); const out = []; for (let f = 0; f <= 34; f++) { w.$gameVariables.setValue(20, f + 1); out.push(Z.trialRef(1)); } return out; }));

// 瓶颈之战本场：BattleManager.setup 吃掉 _pendingTrial；敌人能力值＝参照守层者 paramBase，生命／攻击／魔攻 ×倍数；不掉落；胜负与结果
function trialBattle(aid, opts) {
  const it = fakeInterp(); Z.startTrial(it, actor(aid)); const troop = Z._pendingTrial.troopId;
  w.BattleManager.setup(troop, false, true);
  const b = Z._battle, en = w.$gameTroop.members().map(e => ({enemyId: e.enemyId(), base: [0, 1, 2, 3, 4, 5, 6, 7].map(i => e.paramBase(i)), param: [0, 1, 2, 3, 4, 5, 6, 7].map(i => e.param(i)), hp: e.hp, mp: e.mp, drops: e.makeDropItems().length}));
  w.BattleManager.makeRewards(); const rw = w.BattleManager._rewards;
  for (const id of opts.dead || []) actor(id).addState(1);
  toasts.length = 0; const before = zq(actor(aid)); Z.onVictory(); const done = Z._trialDone && {won: Z._trialDone.won, actorId: Z._trialDone.actorId, target: Z._trialDone.target};
  for (const id of opts.dead || []) actor(id).removeState(1);
  const qiAfter = zq(actor(aid)).qi, end = fakeInterp(); Z._trialEnd(end);
  const r = {troop, battle: {trial: !!b.trial, guardianFloor: b.guardianFloor, floor: b.floor, comp: r6(b.comp), route: b.route.key}, enemies: en,
    rewards: {exp: rw.exp, gold: rw.gold, items: rw.items.length}, done, qiGain: qiAfter - before.qi, after: zq(actor(aid)), skills: zqSkills(actor(aid)), toasts: toasts.slice(), end: view(end), cleared: Z._pendingTrial === null && Z._trialDone === null};
  r.next = view((Z._cb(0, end), end));
  return r;
}
for (const [id, aid, opts] of [['heart1', 1, {progress: 6, data: {1: {qi: 700}}}], ['heart8', 8, {progress: 11, data: {8: {qi: 3000, realm: 1}}}], ['jindan', 9, {progress: 15, data: {9: {qi: 7000, realm: 2}}}],
  ['dead', 8, {progress: 6, data: {8: {qi: 700}}, dead: [8]}], ['otherDead', 8, {progress: 6, data: {8: {qi: 700}}, dead: [9]}], ['tianjie', 9, {progress: 33, data: {9: {qi: 120000, realm: 7}}}],
  ['hard', 10, {progress: 25, route: 2500, data: {10: {qi: 40000, realm: 4}}}], ['xian', 10, {progress: 33, data: {10: {qi: 400000, realm: 11}}}]])
  B('fight.' + id, opts, () => trialBattle(aid, opts));
// 不是本场的敌群：_pendingTrial 作废，按普通战斗；输了／逃了：未能突破
B('fight.otherTroop', {progress: 6, data: {1: {qi: 700}}}, () => { const it = fakeInterp(); Z.startTrial(it, actor(1)); w.BattleManager.setup(1, true, false);
  const b = Z._battle; return {trial: !!b.trial, pendingCleared: Z._pendingTrial === null, params: w.$gameTroop.members().map(e => e.paramBase(0))}; });
B('fight.lost', {progress: 6, data: {8: {qi: 700}}}, () => { const it = fakeInterp(); Z.startTrial(it, actor(8)); w.BattleManager.setup(Z._pendingTrial.troopId, false, true);
  const t = Z._battle.trial; t.won = false; Z._trialDone = t; Z._battle = null; const end = fakeInterp(); Z._trialEnd(end); const v = view(end); return {end: v, after: zq(actor(8)), next: view((Z._cb(0, end), end))}; });
// breakthrough 直接调用：门槛、真气、最高境界
for (const [id, opts] of [['ok', {progress: 5, data: {1: {qi: 600}}}], ['noQi', {progress: 5, data: {1: {qi: 599}}}], ['noGate', {progress: 4, data: {1: {qi: 600}}}],
  ['skip', {progress: 33, data: {1: {qi: 500000, realm: 2}}}], ['top', {progress: 33, data: {1: {qi: 900000, realm: 13}}}], ['r8', {progress: 33, data: {1: {qi: 150000, realm: 8}}}], ['r12', {progress: 33, data: {1: {qi: 500000, realm: 12}}}]])
  B('direct.' + id, opts, () => { toasts.length = 0; const ok = Z.breakthrough(actor(1)); return {ok, after: zq(actor(1)), skills: zqSkills(actor(1)), toasts: toasts.slice(), mhp: actor(1).mhp, cri: r6(actor(1).cri)}; });
// 突破奖励：属性三选一（筑基～化神）或全属性（炼虚起）＋道法；选完下一个待选，直到空，回角色页
for (const [id, realm, pending] of [['r1', 1, [1]], ['r4', 4, [4]], ['r5', 5, [5]], ['r13', 13, [13]], ['multi', 3, [1, 2, 3]]])
  B('pick.' + id, {progress: 33, data: {1: {qi: 600000, realm, pending}}}, () => { const it = fakeInterp(); Z.pickFlow(it, actor(1)); const first = view(it); const steps = [];
    for (let n = 0; n < pending.length; n++) { const v = pick(it, n % 2 === 0 ? 0 : (realm >= 5 ? 0 : 2)); steps.push({view: v, after: zq(actor(1)), skills: zqSkills(actor(1))}); }
    return {first, steps}; });
B('pick.later', {progress: 33, data: {1: {qi: 3000, realm: 1, pending: [1]}}}, () => { const it = fakeInterp(); Z.pickFlow(it, actor(1)); return {view: view(it), laterIsNull: Z._cbs[Z._cbs.length - 1] === null}; });
B('pick.none', {progress: 33, data: {1: {qi: 3000, realm: 1}}}, () => { const it = fakeInterp(); Z.pickFlow(it, actor(1)); return view(it); });
B('pick.allDaofa', {progress: 33, data: {1: {qi: 3000, realm: 1, pending: [1], daofa: {lianji: 1, fenshen: 1, lingtai: 1, benming: 1, linggen: 1, huichun: 1, jinshen: 1, pojia: 1, hufa: 1}}}}, () => { const it = fakeInterp(); Z.pickFlow(it, actor(1)); return view(it); });
// 道法随机：Math.randomInt 固定序列；本命兵／灵根没有可指定时直接随机，有降服过的就列出可指定项与「随机（X）」
for (let k = 0; k < 9; k++) B('daofa.k' + k, {progress: 33, data: {1: {qi: 3000, realm: 1, pending: [1, 2]}}}, () => withRand([k, 4], () => { const it = fakeInterp(); Z.pickFlow(it, actor(1));
  const opt = Z._cbs.length - 2; const got = pick(it, opt); const r = {got, after: zq(actor(1)), skills: zqSkills(actor(1))}; if (got.then) r.next = pick(it, 0); r.afterNext = zq(actor(1)); return r; }));
B('daofa.skipTaken', {progress: 33, data: {1: {qi: 3000, realm: 1, pending: [1], daofa: {lianji: 1, fenshen: 1, lingtai: 1}}}}, () => withRand([0], () => { const it = fakeInterp(); Z.pickFlow(it, actor(1)); const got = pick(it, 3); return {got, after: zq(actor(1)), skills: zqSkills(actor(1))}; }));
for (const [id, kind, known] of [['linggen', 4, {e: {2: 1, 5: 1, 11: 1}}], ['benming', 3, {w: {2: 1, 7: 1}}]])
  for (const choice of [0, 1, 2]) B('spec.' + id + '.c' + choice, {progress: 33, known, data: {1: {qi: 3000, realm: 1, pending: [1]}}}, () => withRand([kind, 6], () => {
    w.$gameSystem._codexZhenqiSpec = {w: known.w || {}, e: known.e || {}};
    const it = fakeInterp(); Z.pickFlow(it, actor(1)); const ask = pick(it, 3); const got = pick(it, choice); return {ask, got, after: zq(actor(1)), skills: zqSkills(actor(1))}; }));
// 降服 Boss（敌人备注 Element Absorb 的 1～9 元素）解锁灵根可指定元素：只记第一次，提示
B('unlock.element', {}, () => { const out = []; const ids = [];
  for (const t of w.$dataTroops) if (t && t.members.length && ids.length < 3) { w.$gameTroop.setup(t.id); if (w.$gameTroop.members().some(e => Z.isBossEnemy(e) && /<Element Absorb:/i.test(e.enemy().note || ''))) ids.push(t.id); }
  for (const t of ids.concat([ids[0]])) { w.BattleManager.setup(t, true, false); toasts.length = 0; Z.onVictory(); out.push({troop: t, spec: spec(), toasts: toasts.slice()}); }
  return out; });
B('unlock.trialNoSpec', {progress: 33, data: {9: {qi: 120000, realm: 7}}}, () => { const it = fakeInterp(); Z.startTrial(it, actor(9)); w.BattleManager.setup(Z._pendingTrial.troopId, false, true); Z.onVictory(); return spec(); });
// 奖励技能数值：patchRewards（筑基～化神 30/50/70/99、金丹 20、元婴 50）与 skillView（道法按境界缩放 daofaScale）
cases.push(makeCase('reward.skills', {}, () => { fresh(); const out = [];
  for (const s of w.$dataSkills) if (s && /<CodexZhenqi:/.test(s.note || '')) {
    const row = {id: s.id, tag: /<CodexZhenqi:\s*([^>]+)>/.exec(s.note)[1].trim(), name: s.name, views: []};
    for (const realm of [0, 1, 2, 3, 4, 5, 9]) { setData(actor(1), {realm}); const v = Z.skillView(s, actor(1)); const meta = {};
      for (const k of Object.keys(v.meta)) if (/^passive/.test(k)) meta[k] = v.meta[k];
      row.views.push({realm, scale: r6(Z.daofaScale(actor(1))), note: v.note, meta}); }
    out.push(row); }
  return out; }));
cases.push(makeCase('reward.keys', {}, () => { fresh(); const out = {}; for (const k of ['fixed:jindan', 'fixed:yuanying', 'fixed:xianyuan:9', 'fixed:xianyuan:13', 'attr:atk:1', 'attr:all:13', 'daofa:lianji', 'daofa:benming:12', 'daofa:linggen:9', 'nope']) out[k] = Z.skillKey(k) || null; return out; }));
// 突破后的能力值（奖励被动：属性 +%、金丹暴击率、元婴爆伤）
for (const [id, keys] of [['atk1', ['attr:atk:1']], ['def2', ['attr:def:2']], ['sup3', ['attr:sup:3']], ['all5', ['attr:all:5']], ['jindan', ['fixed:jindan']], ['dujie', ['fixed:dujie']]])
  B('stats.' + id, {}, () => { const a = actor(1), base = [0, 1, 2, 3, 4, 5, 6, 7].map(i => a.param(i)), cri0 = r6(a.cri);
    for (const k of keys) a.learnSkill(Z.skillKey(k)); Z.refreshRewards(a); return {base, after: [0, 1, 2, 3, 4, 5, 6, 7].map(i => a.param(i)), cri0, cri: r6(a.cri)}; });
// 主菜单「真气」：有队员就可用
cases.push(makeCase('menu.command', {}, () => { fresh(); const win = Object.create(w.Window_MenuCommand.prototype); win._list = []; win.addCommand = function (n, s, e) { this._list.push({name: n, symbol: s, enabled: e}); };
  win.addOriginalCommands(); return win._list.filter(c => c.symbol === 'codexZhenqi'); }));

process.exit(finish(host, 'zhenqi.json', {hostScope: '真实 CodexZhenqi／CodexGuide 与 BattleManager.setup、otbActionTimesModification、JsonEx；无渲染，提示文字由 $.toaster 截获', cases}) ? 0 : 1);
