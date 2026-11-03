'use strict';
// 【cc·悟空·未经审查】璇战斗效果第一期（installNativeXuanRuntime）：不靠绑定就成立的部分。
// ① 全部状态的 isCleanseState（软／硬）；② MP 费用（按璇 MP 上限百分比，1／30／60 级）；③ 回光：治疗、净化第一个硬控、溢出转护盾（余辉 0～3 级，等级不足不生效）；
// ④ 定星：净化后 1 级不给、2 级给（列星期间 1 级也给），下一个硬控被挡一次，到期不挡，普通状态不挡；⑤ 璃壁：护盾量、回合、等级曲线；
// ⑥ 棱光：伤害、双防减益、蚀辉（1～3 级冷却、驱散顺序）；⑦ 技能条件（未绑定）；⑧ 战斗结束清标记状态。
// 真实 Game_Action.apply（BattleManager._action 设好），随机固定 0.5，五乘区关掉。产物 .sandbox/xuan_battle.json，手工复制为 tests/fixtures/xuan_battle_oracle.json（tests/xiyou_xuan_battle 对照，不进同步）。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const X = w.CodexXuan, B = w.CodexBinding, L = w.CodexShieldLedger;
if (!X || !B || !L) throw new Error('璇模块未安装');
// 用户 10-12 定不移植五乘区与超强者路线压制（O-050），参照里关掉（同 tusu_battle_probe）
w.eval('CodexZones.ENABLED=false;');
w.CodexRouteSuppress.otherScale = () => 1;
w.CodexRouteSuppress.isSuper = () => false;
const stub = new Proxy({}, {get: () => () => {}});
const XUAN = 177, ALLY = 1;
const KEY = k => X.ids().skill[k], ST = k => X.ids().state[k];
function setup(o = {}) {
  newGame();
  w.Math.random = () => 0.5;
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.eval(`$gameParty._actors=[${XUAN},${ALLY}]; $gameParty._battleMembers=[${XUAN},${ALLY},0,0,0];`);
  w.$gameSwitches.setValue(2494, true);  // 超强者挑战路线：否则开战时璇被移出出战（同 yunshang_probe）
  const a = w.$gameActors.actor(XUAN), t = w.$gameActors.actor(ALLY);
  a.changeLevel(o.level || 60, false);
  const c = X.chart(a);
  for (const [m, lv] of Object.entries(o.marks || {})) { c.level[m] = lv; c.slots[X.MARKS.indexOf(m) < 3 ? 0 : X.MARKS.indexOf(m) < 6 ? 1 : 2] = m; }
  X.syncMarkSkills(a);
  a.refresh(); a.recoverAll();
  const bm = w.BattleManager;
  bm.setup(3, true, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.SceneManager._scene = {_otbDisplayWindow: stub};
  bm.startBattle();
  bm.startTurn();  // 本场数据 _codexXuan 在第一回合 onRoundStart 才建好（绑定框架 startBattle 会 onClear 掉）
  a.refresh(); t.refresh(); t.recoverAll();
  a._states.filter(i => i !== 1).forEach(i => { if (o.clean) a.eraseState(i); });
  const enemies = w.$gameTroop.members();
  return {a, t, e: enemies[0], enemies, bm};
}
function use(ctx, key, target) {
  const act = new w.Game_Action(ctx.a); act.setSkill(KEY(key));
  ctx.bm._action = act; target.clearResult(); act.apply(target);
  const r = target.result(); ctx.bm._action = null;
  return {hit: r.isHit(), hp: round(r.hpDamage)};
}
const rows = b => L.rows(b).map(r => ({...r, value: round(r.value)}));
const has = (b, ids) => ids.filter(i => b.isStateAffected(i));
const HARD = 10, HARD2 = 8;  // 睡眠（限制 4）、混乱（限制 2）
const cases = [];

// ① 净化口径
cases.push(makeCase('cleanse.table', {}, () => {
  const hard = [], soft = [];
  w.$dataStates.forEach(s => { if (!s) return; if (X.isCleanseState(s, true)) hard.push(s.id); if (X.isCleanseState(s, false)) soft.push(s.id); });
  return {hard, soft};
}));
// ② MP
for (const level of [1, 30, 60]) cases.push(makeCase(`mp.${level}`, {level}, () => {
  const {a} = setup({level});
  const out = {mmp: round(a.mmp)};
  for (const k of ['huiguang', 'libi', 'lengguang', 'liexing', 'jixing']) out[k] = round(a.skillMpCost(w.$dataSkills[KEY(k)]));
  out.attack = round(a.skillMpCost(w.$dataSkills[1]));
  return out;
}));
// ③ 回光与余辉
for (const [tag, level, marks, hurt] of [['plain', 60, {yuhui: 1}, 0.2], ['over1', 60, {yuhui: 1}, 1], ['over2', 60, {yuhui: 2}, 0.99], ['over3', 60, {yuhui: 3}, 0.99], ['nomark', 60, {xianzhao: 1}, 1], ['lowlevel', 9, {yuhui: 3}, 1], ['level10', 10, {yuhui: 1}, 1]]) cases.push(makeCase(`huiguang.${tag}`, {level, marks, hurt}, () => {
  const c = setup({level, marks});
  c.t.setHp(Math.max(1, Math.floor(c.t.mhp * hurt)));
  const before = c.t.hp, r = use(c, 'huiguang', c.t);
  return {...r, level: c.a.level, mat: round(c.a.mat), mhp: round(c.t.mhp), before: round(before), after: round(c.t.hp), heal: round(X.healAmount(c.a, c.t)), shields: rows(c.t), markLevel: X.markLevel(c.a, Object.keys(marks)[0])};
}));
// 回光给璇自己
cases.push(makeCase('huiguang.self', {}, () => {
  const c = setup({marks: {yuhui: 3}});
  const r = use(c, 'huiguang', c.a);
  return {...r, after: round(c.a.hp), mhp: round(c.a.mhp), shields: rows(c.a)};
}));
// ④ 净化、定星
for (const [tag, marks, liexing] of [['lv1', {dingxing: 1}, false], ['lv2', {dingxing: 2}, false], ['lv3', {dingxing: 3}, false], ['lv1_liexing', {dingxing: 1}, true], ['none', {yuhui: 1}, false]]) cases.push(makeCase(`dingxing.${tag}`, {marks, liexing}, () => {
  const c = setup({marks});
  if (liexing) X.chart(c.a), c.a._codexXuan.liexingUntil = B.round() + 1;
  const stun = HARD, other = 5;  // 黑暗不算硬控
  c.t.addState(stun); c.t.addState(other); c.t.refresh();
  const beforeStates = c.t.states().map(s => s.id);
  const r = use(c, 'huiguang', c.t);
  c.t.refresh();
  const after = c.t.states().map(s => s.id), mark = c.t.isStateAffected(ST('dingxing')), guard = c.a._codexXuan.dingxing[ALLY] || null;
  const soft = 6;
  c.t.clearResult();  // isStateAddable：本次结果里刚移除的状态加不上
  c.t.addState(soft); c.t.refresh();
  const softOn = c.t.isStateAffected(soft);
  c.t.addState(stun); c.t.refresh();
  const blocked = !c.t.isStateAffected(stun), markAfter = c.t.isStateAffected(ST('dingxing'));
  return {...r, beforeStates, after, mark, guard, softOn, blocked, markAfter, cleanse: [stun, other, soft].map(i => X.isCleanseState(w.$dataStates[i], true))};
}));
cases.push(makeCase('dingxing.expired', {}, () => {
  const c = setup({marks: {dingxing: 2}});
  c.t.addState(HARD); c.t.refresh();
  use(c, 'huiguang', c.t);
  c.a._codexXuan.dingxing[ALLY].until = B.round() - 1;
  c.t.clearResult();
  c.t.addState(HARD); c.t.refresh();
  return {stun: c.t.isStateAffected(HARD), mark: c.t.isStateAffected(ST('dingxing')), guard: !!c.a._codexXuan.dingxing[ALLY]};
}));
cases.push(makeCase('dingxing.enemy_user', {}, () => {   // 净化只在回光：普通技能打不触发
  const c = setup({marks: {dingxing: 2}});
  c.t.addState(HARD); c.t.refresh();
  const act = new w.Game_Action(c.t); act.setSkill(1); c.bm._action = act; act.apply(c.e); c.bm._action = null;
  return {guard: !!c.a._codexXuan.dingxing[ALLY], stun: c.t.isStateAffected(HARD)};
}));
cases.push(makeCase('dingxing.two_hard', {}, () => {
  const c = setup({marks: {dingxing: 2}});
  c.t.addState(HARD2); c.t.addState(HARD); c.t.refresh();
  const order = c.t.states().map(s => s.id);
  use(c, 'huiguang', c.t); c.t.refresh();
  return {order, after: c.t.states().map(s => s.id), guard: c.a._codexXuan.dingxing[ALLY]};
}));
cases.push(makeCase('dingxing.self', {}, () => {   // 给璇自己净化
  const c = setup({marks: {dingxing: 2}});
  c.a.addState(HARD); c.a.refresh();
  use(c, 'huiguang', c.a); c.a.refresh();
  const guard = c.a._codexXuan.dingxing[XUAN] || null, mark = c.a.isStateAffected(ST('dingxing'));
  c.a.clearResult();
  c.a.addState(HARD); c.a.refresh();
  return {guard, mark, blocked: !c.a.isStateAffected(HARD)};
}));
// ⑤ 璃壁
for (const level of [1, 10, 30, 60]) cases.push(makeCase(`libi.${level}`, {level}, () => {
  const c = setup({level});
  const r = use(c, 'libi', c.t);
  return {...r, mat: round(c.a.mat), mhp: round(c.a.mhp), tmhp: round(c.t.mhp), amount: round(X.shieldAmount(c.a, c.t)), weight: round(X.weight(c.a)), shields: rows(c.t), total: round(L.amount(c.t))};
}));
// ⑥ 棱光
const tough = e => { e.addParam(0, 1e12); e.need_refresh = true; e.refresh(); e.setHp(e.mhp); };
const bufs = e => [0, 1, 2, 3, 4, 5, 6, 7].map(i => e._buffs[i]);
cases.push(makeCase('lengguang.plain', {}, () => {
  const c = setup({});
  tough(c.e);
  const r = use(c, 'lengguang', c.e);
  return {...r, coef: X.coefficient('lengguang', c.a), mat: round(c.a.mat), buffs: bufs(c.e), turns: [c.e._buffTurns[3], c.e._buffTurns[5]], record: c.a._codexXuan.record};
}));
cases.push(makeCase('lengguang.dead', {}, () => {
  const c = setup({});
  c.e.setHp(1);
  const r = use(c, 'lengguang', c.e);
  c.e.refresh();
  return {...r, alive: c.e.isAlive(), buffs: bufs(c.e)};
}));
for (const lv of [0, 1, 2, 3]) cases.push(makeCase(`shihui.${lv}`, {lv}, () => {
  const c = setup({marks: lv ? {shihui: lv} : {tongdiao: 1}});
  const seq = [];
  tough(c.e);
  [2, 4, 6, 7].forEach(i => c.e.addBuff(i, 5));
  for (let turn = 0; turn < 4; turn++) {
    use(c, 'lengguang', c.e); c.e.setHp(c.e.mhp);
    seq.push({round: B.round(), buffs: bufs(c.e), last: c.a._codexXuan.shihuiRound});
    use(c, 'lengguang', c.e); c.e.setHp(c.e.mhp);
    seq.push({round: B.round(), buffs: bufs(c.e), last: c.a._codexXuan.shihuiRound});
    c.a._codexXuan.shihuiRound -= 1;  // 当作过了一回合（B.round 由自然回合推进）
  }
  return {seq};
}));
// ⑦ 技能条件
cases.push(makeCase('meets.unbound', {}, () => {
  const c = setup({});
  const out = {auto: X.autoEnabled(c.a), qualified: X.autoQualified(c.a)};
  for (const k of ['jixing', 'jixing.possess', 'huiguang', 'libi', 'lengguang', 'liexing', 'return', 'menu.starchart']) out[k] = c.a.meetsSkillConditions(w.$dataSkills[KEY(k)]);
  return out;
}));
// ⑧ 战斗结束清标记
cases.push(makeCase('endbattle.clear', {}, () => {
  const c = setup({marks: {dingxing: 2}});
  c.t.addState(HARD); c.t.refresh();
  use(c, 'huiguang', c.t);
  const before = has(c.t, [ST('dingxing')]);
  c.bm.endBattle(0);
  return {before, after: c.t._states.filter(i => [ST('hostmark'), ST('shadow'), ST('dingxing')].includes(i))};
}));
process.exit(finish(host, 'xuan_battle.json', {hostScope: '真实 Game_Action.apply，不跑回合；BattleManager._action 手工设；随机固定 0.5；五乘区关', cases}) ? 0 : 1);
