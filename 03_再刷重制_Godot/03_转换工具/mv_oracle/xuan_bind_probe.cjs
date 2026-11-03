'use strict';
// 【cc·悟空·未经审查】璇第二期（installNativeXuanRuntime）：绑定种类登记与手动附身。手动模式（没开星契自律）。
// 寄星、转移（寄星·附身）、回身的真实 Game_Action.apply；星纹标记；默契结算（寄住、护主、协同、名册、转移保留）；同轨；每回合用过转移；宿主、本体倒下解除；附身期间不掉血；战斗结束清理。
// 回合用真实 BattleManager.startTurn／endTurn。随机固定 0.5，五乘区、路线压制关（O-050）。产物 .sandbox/xuan_bind.json，手工复制为 tests/fixtures/xuan_bind_oracle.json（tests/xiyou_xuan_bind 对照，不进同步）。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const X = w.CodexXuan, B = w.CodexBinding, L = w.CodexShieldLedger;
if (!X || !B || !L) throw new Error('璇模块未安装');
w.eval('CodexZones.ENABLED=false;');
w.CodexRouteSuppress.otherScale = () => 1;
w.CodexRouteSuppress.isSuper = () => false;
w.CodexRouteSuppress.support = () => 1;  // 共宿伤害率 ×路线支援（O-050 不移植）
if (!w.$) w.$ = {};
w.$.toaster = () => {};
const XUAN = 177, A1 = 1, A8 = 8;
const KEY = k => X.ids().skill[k], ST = k => X.ids().state[k];
let lines = [];
const stub = new Proxy(function () {}, {get: (_, k) => k === 'push' ? ((c, t) => { if (c === 'addText') lines.push(t); }) : k === '_waitCount' ? 0 : (() => false), set: () => true});
w.BattleManager.actionBattleHud = () => true;
w.BattleManager.otbDisplayWindow = () => stub;
function setup(o = {}) {
  newGame(); lines = [];
  w.Math.random = () => 0.5;
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  const P = o.party || [XUAN, A1, A8];
  w.eval(`$gameParty._actors=[${P}]; $gameParty._battleMembers=[${P.concat([0, 0, 0, 0, 0]).slice(0, 5)}];`);
  w.$gameSwitches.setValue(2494, true);
  const a = w.$gameActors.actor(XUAN), t = w.$gameActors.actor(A1), t2 = w.$gameActors.actor(A8);
  a.changeLevel(o.level || 60, false);
  const c = X.chart(a);
  for (const [m, lv] of Object.entries(o.marks || {})) { c.level[m] = lv; c.slots[X.MARKS.indexOf(m) < 3 ? 0 : X.MARKS.indexOf(m) < 6 ? 1 : 2] = m; }
  if (o.stage != null) a._AdvancedNum = o.stage;
  if (o.roster) c.roster = o.roster.slice();
  X.syncMarkSkills(a);
  a.refresh(); a.recoverAll();
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager;
  bm.setup(3, true, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.SceneManager._scene = {_otbDisplayWindow: stub};
  for (const e of w.$gameTroop.members()) e._paramPlus[0] = 1e12;
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  bm.startBattle();
  bm.startTurn();
  return {a, t, t2, e: w.$gameTroop.members()[0], bm};
}
function use(ctx, key, target) {
  const act = new w.Game_Action(ctx.a); act.setSkill(KEY(key));
  ctx.bm._action = act; target.clearResult(); act.apply(target);
  ctx.bm._action = null;
}
const nextRound = c => { c.bm.endTurn(); c.bm.startTurn(); };
const KEYS = ['jixing', 'jixing.possess', 'huiguang', 'libi', 'lengguang', 'liexing', 'return'];
const snap = c => {
  const d = c.a._codexXuan, h = B.host(c.a);
  return {round: B.round(), host: h ? h.actorId() : 0, charges: B.charges(c.a), tacit: d ? d.tacit : null, tonggui: d ? d.tonggui : null, counter: c.a._codexXuanTacit, jixingUsed: !!(d && d.used.jixing),
    form: c.a.isStateAffected(ST('possess')), empty: c.a.isStateAffected(ST('empty')), tongguiState: c.a.isStateAffected(ST('tonggui')),
    marks: [A1, A8, XUAN].filter(id => w.$gameActors.actor(id).isStateAffected(ST('hostmark'))), meets: KEYS.filter(k => c.a.meetsSkillConditions(w.$dataSkills[KEY(k)])), lines: lines.slice()};
};
const cases = [];
const C = (id, setupArgs, fn) => cases.push(makeCase(id, setupArgs, () => fn(setup(setupArgs))));
C('jixing.ally', {}, c => { const s0 = snap(c); use(c, 'jixing', c.t); return {s0, s1: snap(c)}; });
C('jixing.roster', {stage: 1, roster: [A1]}, c => { use(c, 'jixing', c.t); return snap(c); });
C('jixing.roster_stage0', {stage: 0, roster: [A1]}, c => { use(c, 'jixing', c.t); return snap(c); });
C('jixing.self', {}, c => { use(c, 'jixing', c.a); return snap(c); });
C('jixing.dead', {}, c => { c.t.setHp(0); c.t.refresh(); use(c, 'jixing', c.t); return snap(c); });
for (const [tag, o] of [['plain', {}], ['roster_old', {stage: 2, roster: [A1]}], ['roster_new', {stage: 2, roster: [A8]}], ['roster_json', {stage: 2, roster: [A8], json: true}]]) C(`possess.${tag}`, o, c => {
  use(c, 'jixing', c.t);
  c.a._codexXuan.tacit = 31;
  const s0 = snap(c);
  use(c, 'jixing.possess', c.t2);
  const s1 = snap(c);
  use(c, 'jixing.possess', c.t);      // 同回合再转：技能条件挡的是选择，apply 本身不挡
  const s2 = snap(c);
  nextRound(c);
  return {s0, s1, s2, s3: snap(c)};
});
C('possess.same_target', {}, c => { use(c, 'jixing', c.t); c.a._codexXuan.tacit = 31; use(c, 'jixing.possess', c.t); return snap(c); });
C('return.plain', {}, c => {
  use(c, 'jixing', c.t); c.a._codexXuan.tacit = 100; c.a._codexXuan.tonggui = true;
  const s0 = snap(c);
  use(c, 'return', c.a);
  const s1 = snap(c);
  nextRound(c);
  return {s0, s1, s2: snap(c)};
});
C('mark.remove', {}, c => {
  use(c, 'jixing', c.t);
  c.t.removeState(ST('hostmark'));
  const s = snap(c);
  c.t.clearStates && 0;
  return s;
});
C('host.dies', {}, c => { use(c, 'jixing', c.t); c.t.setHp(0); c.t.refresh(); B.validate(); return snap(c); });
C('owner.dies', {}, c => { use(c, 'jixing', c.t); c.a._hp = 0; c.a.addState(1); B.validate(); return snap(c); });
C('owner.hp_loss', {}, c => {
  use(c, 'jixing', c.t);
  const before = c.a.hp;
  c.a.gainHp(-100); c.a.setHp(before - 50);
  const held = c.a.hp;
  c.a.gainHp(0);
  use(c, 'return', c.a);
  c.a.gainHp(-100);
  return {before: round(before), held: round(held), after: round(c.a.hp)};
});
// 审查第 34 期 P2-1：附身期间回合末的持续伤害（中毒 hrg −0.1）不扣；同场没绑定的 8 号照扣；回身后再扣
C('owner.poison', {}, c => {
  c.a.addState(4); c.t2.addState(4);
  use(c, 'jixing', c.t);
  const a0 = c.a.hp, o0 = c.t2.hp;
  nextRound(c);
  const a1 = c.a.hp, o1 = c.t2.hp, poisoned = c.a.isStateAffected(4);
  use(c, 'return', c.a);
  nextRound(c);
  return {poisoned, poisonedAfter: c.a.isStateAffected(4), a: [a0, a1, c.a.hp].map(round), o: [o0, o1, c.t2.hp].map(round)};
});
for (const [tag, level, act] of [['stay10', 10, 0], ['stay60', 60, 0], ['protect20', 20, 'huiguang'], ['protect60', 60, 'huiguang'], ['assist60', 60, 'lengguang'], ['libi60', 60, 'libi']]) C(`tacit.${tag}`, {level}, c => {
  use(c, 'jixing', c.t);
  const seq = [];
  for (let i = 0; i < 7; i++) {
    if (act) use(c, act, act === 'lengguang' ? c.e : c.t);
    nextRound(c);
    seq.push({round: B.round(), tacit: c.a._codexXuan.tacit, tonggui: c.a._codexXuan.tonggui, state: c.a.isStateAffected(ST('tonggui'))});
  }
  return {seq};
});
C('tacit.transfer_round', {}, c => {
  use(c, 'jixing', c.t);
  nextRound(c);
  const t1 = c.a._codexXuan.tacit;
  use(c, 'jixing.possess', c.t2);
  const t2 = c.a._codexXuan.tacit;
  nextRound(c);
  const t3 = c.a._codexXuan.tacit;
  nextRound(c);
  return {t1, t2, t3, t4: c.a._codexXuan.tacit};
});
C('tacit.unbound_round', {}, c => { nextRound(c); const t1 = c.a._codexXuan.tacit; use(c, 'lengguang', c.e); nextRound(c); return {t1, t2: c.a._codexXuan.tacit, s: snap(c)}; });
C('end.clear', {}, c => {
  use(c, 'jixing', c.t);
  c.bm.endBattle(0);
  return {data: !!c.a._codexXuan, form: c.a._states.includes(ST('possess')), mark: c.t._states.includes(ST('hostmark')), bound: B.isBound(c.a), counter: c.a._codexXuanTacit === undefined ? null : c.a._codexXuanTacit};
});
// ---- 第二期续：移光、接力、留辉、共宿、并轨 3 级、列星 ----
const A2 = 2;
const sh = b => L.rows(b).filter(r => /^xuan\./.test(r.source)).map(r => ({source: r.source, amount: round(r.amount), until: r.until})).sort((x, y) => x.source < y.source ? -1 : 1);
const dm = b => ({def: round(b.def), mdf: round(b.mdf)});
for (const [tag, o] of [['lv1', {marks: {yiguang: 1}}], ['lv3', {marks: {yiguang: 3}}], ['none', {}]]) C(`yiguang.${tag}`, o, c => {
  use(c, 'jixing', c.t); use(c, 'libi', c.t);
  const s0 = sh(c.t);
  use(c, 'jixing.possess', c.t2);
  return {s0, prev: sh(c.t), next: sh(c.t2)};
});
for (const [tag, level, mk] of [['lv20', 20, {}], ['lv60', 60, {}], ['lv60_yiguang2', 60, {yiguang: 2}], ['lv10', 10, {}]]) C(`relay.${tag}`, {level, marks: mk, party: [XUAN, A1, A8, A2]}, c => {
  const t3 = w.$gameActors.actor(A2);
  t3.setHp(Math.floor(t3.mhp / 2));
  use(c, 'jixing', c.t); use(c, 'libi', c.t);
  const s0 = sh(c.t);
  use(c, 'jixing.possess', c.t2);
  return {s0, prev: sh(c.t), next: sh(c.t2), third: sh(t3)};
});
for (const level of [10, 20, 40, 60]) C(`gongsu.lv${level}`, {level}, c => {
  const base = {t: dm(c.t), t2: dm(c.t2)};
  use(c, 'jixing', c.t);
  return {base, bound: {t: dm(c.t), t2: dm(c.t2)}, xuan: dm(c.a), rate: X.hostDamageRate(c.t), rate2: X.hostDamageRate(c.t2), dmgRate: X.gongsuDamageRate(c.a), defRate: X.gongsuDefenseRate(c.a)};
});
C('binggui.partner', {marks: {binggui: 3}}, c => {
  X.chart(c.a).partner = A8;
  const base = dm(c.t2);
  use(c, 'jixing', c.t);
  return {base, partner: dm(c.t2), host: dm(c.t)};
});
for (const [tag, mk] of [['lv2', {liuhui: 2}], ['none', {}]]) C(`liuhui.${tag}`, {marks: mk}, c => {
  use(c, 'jixing', c.t);
  const seq = [dm(c.t)];
  use(c, 'jixing.possess', c.t2);
  seq.push(dm(c.t));
  for (let i = 0; i < 3; i++) { nextRound(c); seq.push({round: B.round(), ...dm(c.t)}); }
  return {seq};
});
const ids2 = list => list.map(b => b.isActor() ? b.actorId() : -b.index() - 1);
const tg = (c, key, target) => { const act = new w.Game_Action(c.a); act.setSkill(KEY(key)); act.setTarget(target.index()); return ids2(act.makeTargets()); };
for (const [tag, level] of [['lv30', 30], ['lv40', 40], ['lv60', 60]]) C(`liexing.${tag}`, {level, party: [XUAN, A1, A8, A2]}, c => {
  const t3 = w.$gameActors.actor(A2);
  t3.setHp(Math.floor(t3.mhp / 2));
  use(c, 'jixing', c.t);
  use(c, 'liexing', c.a);
  const d = c.a._codexXuan;
  const s0 = {until: d.liexingUntil, shadows: d.shadows.slice(), shadowState: [A1, A8, A2].filter(id => w.$gameActors.actor(id).isStateAffected(ST('shadow'))), self: c.a.isStateAffected(ST('liexing')),
    cover: X.beneficiaries(c.a).list.map(b => b.actorId()), heal: tg(c, 'huiguang', c.t), wall: tg(c, 'libi', c.t), prism: tg(c, 'lengguang', c.e), rate3: X.hostDamageRate(t3), def3: dm(t3)};
  const seq = [];
  for (let i = 0; i < 3; i++) { nextRound(c); seq.push({round: B.round(), until: d.liexingUntil, shadows: d.shadows.slice(), self: c.a.isStateAffected(ST('liexing')), shadowState: [A1, A8, A2].filter(id => w.$gameActors.actor(id).isStateAffected(ST('shadow')))}); }
  return {s0, seq};
});
process.exit(finish(host, 'xuan_bind.json', {hostScope: '真实 Game_Action.apply、BattleManager.startTurn／endTurn；手动模式；随机 0.5；五乘区、路线压制关', cases}) ? 0 : 1);
