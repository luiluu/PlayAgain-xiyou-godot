'use strict';
// YEP_X_ExtDoT（持续伤害／再生）参照：冻结正式源 Game_Battler.regenerateAll 前的 processDamageOverTimeStates。
// 量：①回合结束时机（onTurnEnd 内与 regenerateHp／Mp、再生脚本、状态回合递减的先后）②46 个真实状态（固定随机）的 HP 变化、弹字、动画、错误
// ③合成状态：波动／元素／自定义公式写法／标签顺序／负值／NaN④叠加与致死（顺序、死后再生复活）⑤结果槽恢复、存活／战斗外守卫
// ⑥施加者 origin：角色、敌人、无、缺失、导入角色、读档（JsonEx 往返）⑦护盾下的持续伤害。只在内存里跑；产物 .sandbox/dot.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');  // 五乘区（CodexZones）重制不移植（O-044），探针宿主默认开着；关掉让参照不含成长修正
const stub = new Proxy(function () {}, {get: (_, k) => k === '_waitCount' ? 0 : (() => false), set: () => true});
const sprites = new Map();
w.Game_Battler.prototype.battler = function () {
  if (!sprites.has(this)) sprites.set(this, new Proxy({x: 0, y: 0, _homeX: 0, _homeY: 0, width: 64, height: 64,
    scale: {x: 1, y: 1}, anchor: {x: 0.5, y: 1}, opacity: 255},
  {get: (t, k) => k in t ? t[k] : (() => false), set: (t, k, v) => {t[k] = v; return true;}}));
  return sprites.get(this);
};
w.BattleManager.actionBattleHud = () => true;
w.BattleManager.otbDisplayWindow = () => stub;
const key = b => !b ? null : (b.isActor && b.isActor()) ? 'a' + b.actorId() : (b.index ? 'e' + b.index() : '?');
let ENV = null;
function battle(troop) {
  if (ENV) {
    w.$gameParty._inBattle = true;
    for (const x of [ENV.a, ENV.b, ENV.e, ENV.e2]) { x.clearStates(); if (x.appear) x.appear(); delete x.damagedot; delete x.__dotStats; x._hp = Math.min(x.mhp, 100000); x._shield = 0; x._stateOrigin = {}; x.need_refresh = true; x.refresh(); x.clearResult(); }
    return ENV;
  }
  ENV = battle0(troop);
  return ENV;
}
function battle0(troop) {
  if (w.$gameParty) w.$gameParty._inBattle = false;
  newGame();
  w.eval('$gameParty._actors=[];');
  for (const id of [1, 8]) w.$gameParty.addActor(id);
  for (const id of [1, 8]) { const a = w.$gameActors.actor(id); a._paramPlus[0] = 1e9; a.need_refresh = true; a.refresh(); a.recoverAll(); }
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(troop, true, true);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.CodexYunshang._acted = [];
  w.$gameParty._inBattle = true;
  for (const e of w.$gameTroop.members()) { e._paramPlus[0] = 1e9; e.need_refresh = true; e.refresh(); e.recoverAll(); }
  return {bm, a: w.$gameActors.actor(1), b: w.$gameActors.actor(8), e: w.$gameTroop.members()[0], e2: w.$gameTroop.members()[1]};
}
// 合成状态：复制 4 的解析字段，清空特性与备注，再用原版 processEDoTNotetags1 解析我们给的备注
function synth(note, extra) {
  const st = w.JsonEx.makeDeepCopy(w.$dataStates[4]);
  const id = w.$dataStates.length;
  Object.assign(st, {id, name: '测试·DoT', traits: [], note, meta: {}, autoRemovalTiming: 0, minTurns: 1, maxTurns: 1, removeAtBattleEnd: false,
    restriction: 0, priority: 50, iconIndex: 0}, extra || {});
  for (const k of Object.keys(st.customEffectEval)) st.customEffectEval[k] = '';
  w.$dataStates.push(st);
  w.DataManager.processEDoTNotetags1([null, st]);
  return id;
}
const errors = [];
const oldError = w.Yanfly.Util.displayError;
w.Yanfly.Util.displayError = (error, code, message) => errors.push({text: String(error && error.message || error), message});
// 随机：Math.random 序列（回绕）；记抽取次数
let seq = [0.5], pos = 0, draws = 0;
const rnd = () => { draws++; const v = seq[pos % seq.length]; pos++; return v; };
// 战斗 setup 会换掉 Math.random（确定性随机），所以每次设序列都重新装
const setSeq = s => { seq = s; pos = 0; draws = 0; w.Math.random = rnd; };
// 记录器：包装 Game_Battler 上与持续伤害相关的方法（只记不改）
let LOG = null;
const mark = (...row) => { if (LOG) LOG.push([...row, 'd' + draws]); };
const snapResult = r => ({hpDamage: r.hpDamage, hpAffected: r.hpAffected, mpDamage: r.mpDamage, tpDamage: r.tpDamage,
  used: r.used, missed: r.missed, evaded: r.evaded, critical: r.critical, added: Array.from(r.addedStates), removed: Array.from(r.removedStates)});
const wrap = (P, name, f) => { const old = P[name]; P[name] = function (...args) { f.call(this, args); return old.apply(this, args); }; };
const GB = w.Game_Battler.prototype;
for (const m of ['onTurnEnd', 'regenerateAll', 'processDamageOverTimeStates', 'regenerateHp', 'regenerateMp', 'regenerateTp', 'updateStateTurns',
  'updateBuffTurns', 'removeStatesAuto', 'clearResult', 'startDamagePopup', 'regenerateStateEffects'])
  wrap(GB, m, function () { mark(m, key(this)); });
wrap(GB, 'processDamageOverTimeStateEffect', function (a) { mark('dotState', key(this), a[0] && a[0].id); });
for (const P of [w.Game_Actor.prototype, w.Game_Enemy.prototype]) for (const m of ['gainHp', 'regenerateAll', 'onTurnEnd', 'performCollapse', 'startDamagePopup', 'regenerateHp'])
  if (Object.prototype.hasOwnProperty.call(P, m)) wrap(P, m, function (a) { mark(m + '*', key(this), a[0]); });
wrap(GB, 'gainHp', function (a) { mark('gainHp', key(this), a[0]); });
wrap(GB, 'startAnimation', function (a) { mark('anim', key(this), a[0]); });
wrap(GB, 'startDamagePopup', function () { mark('popup', key(this), snapResult(this._result)); });
wrap(GB, 'performCollapse', function () { mark('collapse', key(this)); });
wrap(GB, 'addState', function (a) { mark('addState', key(this), a[0]); });
wrap(GB, 'removeState', function (a) { mark('removeState', key(this), a[0]); });
function capture(fn) { const out = LOG = []; try { fn(); } finally { LOG = null; } return out; }
const snap = b => ({hp: b.hp, mp: b.mp, tp: b.tp, shield: b.shield === undefined ? null : b.shield, states: b._states.slice(), turns: Object.assign({}, b._stateTurns),
  dead: b.isDead(), result: snapResult(b._result)});
const globalValue = () => typeof w.value === 'undefined' ? null : w.value;
function holderOf(kind, env) { return kind === 'actor' ? env.b : env.e; }
function originOf(kind, env) { return kind === 'a1' ? env.a : kind === 'a8' ? env.b : kind === 'e0' ? env.e : kind === 'e1' ? env.e2 : null; }
// krz_state_re 把 dotstates() 缓存起来，只有 refresh() 时 need_refresh 为真才失效；addState 在内层 refresh 之后才置脏。
// 默认模拟「加状态之后战斗里总会有一次 refresh」（伤害结算、状态窗口刷新等）；staleCache 用例单独量不刷新时的缓存。
const STAT_KEYS = ['hp', 'mp', 'tp', 'mhp', 'mmp', 'atk', 'def', 'mat', 'mdf', 'agi', 'luk', 'level'];
const statsOf = x => x ? Object.fromEntries(STAT_KEYS.map(k => [k, x[k]])) : null;
function giveState(holder, sid, originKind, env, noRefresh) {
  holder.addState(sid);
  if (!noRefresh) { holder.need_refresh = true; holder.refresh(); }
  if (originKind === 'none') holder.clearStateOrigin(sid);
  else if (originKind === 'missing') holder._stateOrigin[sid] = [1, 999];
  else holder.setStateOrigin(sid, originOf(originKind, env));
  // 公式读到的能力值（供重制专项把同一组数代进公式程序）：a＝施加者（无记录＝持有者），b＝持有者
  holder.__dotStats = holder.__dotStats || {};
  const o = originKind === 'none' ? holder : originKind === 'missing' ? null : originOf(originKind, env);
  holder.__dotStats[sid] = {a: statsOf(o), b: statsOf(holder), originKind};
}
function prep(env, kind, hp) { const h = holderOf(kind, env); h.clearStates(); h.clearResult(); h._hp = hp === undefined ? Math.min(h.mhp, 100000) : hp; h._shield = 0; h.refresh(); return h; }
function runTurnEnd(h, env) {
  errors.length = 0;
  const before = snap(h);
  const log = capture(() => h.onTurnEnd());
  const rates = Array.from({length: 14}, (_, i) => h.elementRate(i));
  const stats = h.__dotStats ? JSON.parse(JSON.stringify(h.__dotStats)) : null;
  return {before, after: snap(h), log, sourceErrors: errors.splice(0), draws, globalValue: globalValue(), stats, rates};
}

const REAL = [33, 35, 43, 48, 54, 55, 57, 69, 70, 84, 89, 90, 91, 93, 95, 117, 132, 135, 160, 164, 168, 176, 177, 181, 185, 243, 261, 286, 347, 365, 473, 474, 487,
  619, 643, 644, 645, 828, 829, 834, 837, 902, 933, 1386, 2038];
const SYN = {
  fixed300: '<DoT Formula: 300>', variance0: '<DoT Formula: 300>\n<DoT Variance: 0%>', variance50: '<DoT Formula: 300>\n<DoT Variance: 50%>',
  varianceRegen: '<Regen Formula: 300>\n<Regen Variance: 50%>', varianceFw: '<DoT Formula: 300>\n<DoT Variance: 50％>',
  elem2: '<DoT Formula: 300>\n<DoT Variance: 0%>\n<DoT Element: 2>', elem2Regen: '<Regen Formula: 300>\n<Regen Variance: 0%>\n<Regen Element: 2>',
  annoAfter: '<DoT Formula: 300>\n<DoT Animation: 7>', annoBefore: '<DoT Animation: 7>\n<DoT Formula: 300>', regenDefaultAni: '<Regen Formula: 300>',
  dotLongTag: '<Damage Over Time Formula: 300>', regenLongTag: '<Regenerate Formula: 300>', lowerTag: '<dot formula: 300>',
  twoFormulas: '<DoT Formula: 300>\n<Regen Formula: 200>', twoFormulasRev: '<Regen Formula: 200>\n<DoT Formula: 300>',
  negative: '<DoT Formula: -300>', regenNeg: '<Regen Formula: -300>', zero: '<DoT Formula: 0>', fractional: '<DoT Formula: 2.5>', fractional2: '<DoT Formula: 3.5>',
  fractionalRegen: '<Regen Formula: 2.5>', nan: '<DoT Formula: a.nothing * 2>', undef: '<DoT Formula: nothing_here>',
  hpPct: '<DoT Formula: b.mhp * 0.03>', whole: '<DoT Formula: b.hp>', userAtk: '<DoT Formula: user.atk>', targetMat: '<DoT Formula: target.mat>',
  originSame: '<DoT Formula: origin.atk * 2>', vars: '<DoT Formula: v[1] + s[1]>', trailingGt: '<DoT Formula: 3 > 2 ? 100 : 50>',
  customDot: '<Custom DoT Formula>\nvalue = 300;\n</Custom DoT Formula>', customDotVar: '<Custom DoT Formula>\nvalue = 300;\nvariance = 0;\nelement = 2;\n</Custom DoT Formula>',
  customRegen: '<Custom Regen Formula>\nvalue = 300;\n</Custom Regen Formula>', customNoValue: '<Custom DoT Formula>\nvariance = 0;\n</Custom DoT Formula>',
  customHealOverride: '<Custom DoT Formula>\nvalue = 300;\nhealing = true;\n</Custom DoT Formula>', customAni: '<DoT Animation: 9>\n<Custom DoT Formula>\nvalue = 300;\n</Custom DoT Formula>',
  customThrow: '<Custom DoT Formula>\nthrow new Error("x");\n</Custom DoT Formula>', customCond: '<Custom DoT Formula>\nif (a.isActor()) { value = 100; } else { value = 200; }\n</Custom DoT Formula>',
  customAfterFormula: '<DoT Formula: 100>\n<Custom DoT Formula>\nvalue = 300;\n</Custom DoT Formula>', customBeforeFormula: '<Custom DoT Formula>\nvalue = 300;\n</Custom DoT Formula>\n<DoT Formula: 100>'
};
const cases = [];
const mk = (id, setup, fn) => makeCase(id, setup, () => { ENV = null; return fn(); });

// 0) 夹具：解析结果（原版 processEDoTNotetags1 的产物）
cases.push(mk('fixture', {states: REAL}, () => {
  newGame();
  return {defaults: {regenAni: w.Yanfly.Param.EDoTRegenAni, dotAni: w.Yanfly.Param.EDoTDamageAni, variance: w.Yanfly.Param.EDoTDefVariance, element: w.Yanfly.Param.EDoTDefElement},
    states: REAL.map(id => { const s = w.$dataStates[id]; return {id, name: s.name, formula: s.dotFormula, ani: s.dotAnimation, variance: s.dotVariance, element: s.dotElement,
      timing: s.autoRemovalTiming, minTurns: s.minTurns, maxTurns: s.maxTurns}; }),
    syn: SYN,
    withFormula: w.$dataStates.map((s, i) => s && s.dotFormula ? i : 0).filter(Boolean).length,
    globalValueBoot: globalValue()};
}));

// 1) 时机：onTurnEnd 内的次序（DoT 状态＋自带再生特性＋Custom Regenerate 状态＋一回合到期）
cases.push(mk('order', {}, () => {
  const out = {};
  for (const kind of ['enemy', 'actor']) {
    const env = battle(2); const h = prep(env, kind);
    const regenTrait = synth('', {traits: [{code: 22, dataId: 7, value: -0.000001}], autoRemovalTiming: 2});  // HP 再生率 -1%，到期时机 2
    const regenScript = synth('<Custom Regenerate Effect>\nuser.gainHp(-1);\n</Custom Regenerate Effect>');
    w.$dataStates[regenScript].customEffectEval.regenerateState = 'user.gainHp(-1);';
    const dotSid = synth('<DoT Formula: 300>\n<DoT Animation: 5>', {autoRemovalTiming: 2, minTurns: 1, maxTurns: 1});
    setSeq([0.5]);
    for (const sid of [regenTrait, regenScript, dotSid]) giveState(h, sid, 'e0', env);
    h._stateTurns[dotSid] = 1; h._stateTurns[regenTrait] = 1;
    out[kind] = {states: [regenTrait, regenScript, dotSid], ...runTurnEnd(h, env)};
  }
  return out;
}));

// 2) 46 个真实状态：每个状态单独挂，holder 敌人／角色 × 施加者（角色1、敌人0、无、缺失），随机固定 0.5；再对波动取 0／0.999
for (const sid of REAL) {
  cases.push(mk('real.' + sid, {state: sid}, () => {
    const out = {};
    for (const hk of ['enemy', 'actor']) for (const ok of ['a1', 'e0', 'none', 'missing']) for (const r of [0.5, 0, 0.999]) {
      if (r !== 0.5 && ok !== 'a1') continue;
      const env = battle(2); const h = prep(env, hk);
      h.mhp; setSeq([r]);
      if (w.$dataStates[sid].customEffectEval.addState) { /* 先挂状态，Apply 效果在 addState 里跑 */ }
      giveState(h, sid, ok, env);
      const originBefore = h._stateOrigin ? h._stateOrigin[sid] : null;
      out[`${hk}.${ok}.${r}`] = {originBefore, dotFormula: w.$dataStates[sid].dotFormula, ...runTurnEnd(h, env)};
    }
    return out;
  }));
}

// 3) 合成状态：波动／元素／标签／写法
for (const [name, note] of Object.entries(SYN)) {
  cases.push(mk('syn.' + name, {note}, () => {
    const out = {};
    for (const r of [0.5, 0, 0.999]) for (const hk of ['enemy', 'actor']) {
      const env = battle(2); const h = prep(env, hk);
      const sid = synth(note);
      setSeq([r]); w.value = undefined; delete w.value;
      giveState(h, sid, 'a1', env);
      out[`${hk}.${r}`] = {formula: w.$dataStates[sid].dotFormula, ani: w.$dataStates[sid].dotAnimation, variance: w.$dataStates[sid].dotVariance, element: w.$dataStates[sid].dotElement,
        ...runTurnEnd(h, env)};
    }
    return out;
  }));
}

// 4) 元素倍率：持有者元素抗性（特性 11：元素有效度）影响 elementRate
cases.push(mk('element.rates', {}, () => {
  const out = {};
  for (const rate of [0.5, 1, 2, 0, -1]) for (const el of [2, 9]) {
    const env = battle(2); const h = prep(env, 'enemy');
    const res = synth('', {traits: [{code: 11, dataId: el, value: rate}]});
    h.addState(res); h.need_refresh = true; h.refresh();
    const sid = synth(`<DoT Formula: 300>\n<DoT Variance: 0%>\n<DoT Element: ${el}>`);
    setSeq([0.5]); giveState(h, sid, 'a1', env);
    out[`${rate}.${el}`] = {elementRate: h.elementRate(el), ...runTurnEnd(h, env)};
  }
  return out;
}));

// 5) 叠加与致死
function multi(name, sids, hp, kind, originKind) {
  cases.push(mk('multi.' + name, {sids, hp}, () => {
    const out = {};
    for (const r of [0.5]) {
      const env = battle(2); const h = prep(env, kind || 'enemy', hp);
      setSeq([r]); for (const s of sids) giveState(h, s, originKind || 'a1', env);
      out.run = {order: h.states().map(s => s.id), priorities: h.states().map(s => s.priority), ...runTurnEnd(h, env)};
      // 下一回合再跑一次，看倒下后的状态。真实回合开头必有 refresh（krz 的 dotstates 缓存靠它失效；不刷新时到期状态会多算一回合，见 cache.stale）
      h.need_refresh = true; h.refresh();
      out.next = runTurnEnd(h, env);
    }
    return out;
  }));
}
multi('three', [33, 43, 55], undefined);
multi('dot_dot', [33, 35], undefined);
multi('dot_heal_alive', [33, 55], undefined);
multi('lethal_first', [33], 100);
multi('lethal_then_heal', [33, 57], 100);
multi('lethal_then_heal_rev', [57, 33], 100);
multi('lethal_then_dot', [33, 35], 100);
multi('lethal_actor', [33], 100, 'actor');
multi('lethal_actor_heal', [33, 57], 100, 'actor');
multi('exact_zero', [33], 300);
multi('hp_one', [33], 1);
multi('dead_holder', [33], 0);

// 6) 结果槽恢复／守卫：直接调 processDamageOverTimeStates
cases.push(mk('guards', {}, () => {
  const out = {};
  const env = battle(2); const h = prep(env, 'enemy');
  const sid = synth('<DoT Formula: 300>\n<DoT Variance: 0%>'); giveState(h, sid, 'a1', env);
  setSeq([0.5]);
  // 结果槽恢复
  h._result.hpDamage = 77; h._result.hpAffected = true; h._result.used = true; h._result.critical = true;
  const before = snapResult(h._result);
  const log = capture(() => h.processDamageOverTimeStates());
  out.restore = {before, after: snapResult(h._result), hp: h.hp, log};
  // 倒下的持有者：regenerateAll 不跑 DoT
  h._hp = 0; h.refresh(); out.deadSkips = {dead: h.isDead(), log: capture(() => h.regenerateAll())};
  // 战斗外：不跑
  const env2 = battle(2); const h2 = prep(env2, 'enemy'); const sid2 = synth('<DoT Formula: 300>\n<DoT Variance: 0%>'); giveState(h2, sid2, 'a1', env2);
  w.$gameParty._inBattle = false; const hp2 = h2.hp; h2.regenerateAll(); out.outsideBattle = {hpBefore: hp2, hpAfter: h2.hp};
  w.$gameParty._inBattle = true;
  // 直接调 processDamageOverTimeStates，不经 regenerateAll
  const env3 = battle(2); const h3 = prep(env3, 'enemy'); const sid3 = synth('<DoT Formula: 300>\n<DoT Variance: 0%>'); giveState(h3, sid3, 'a1', env3);
  h3.processDamageOverTimeStates(); out.direct = {hp: h3.hp};
  return out;
}));

// 7) 施加者：不同来源的 a／origin；读档往返；来源敌人倒下后
cases.push(mk('origin', {}, () => {
  const out = {};
  const sid = synth('<DoT Formula: a.atk * 10>\n<DoT Variance: 0%>');
  const sidO = synth('<DoT Formula: origin.atk * 10>\n<DoT Variance: 0%>');
  const sidB = synth('<DoT Formula: b.atk * 10>\n<DoT Variance: 0%>');
  const sidU = synth('<DoT Formula: user.atk * 10>\n<DoT Variance: 0%>');
  for (const [nm, s] of [['a', sid], ['origin', sidO], ['b', sidB], ['user', sidU]]) for (const ok of ['a1', 'a8', 'e0', 'e1', 'none', 'missing']) {
    const env = battle(2); const h = prep(env, 'enemy'); setSeq([0.5]);
    giveState(h, s, ok, env);
    const o = originOf(ok, env);
    out[`${nm}.${ok}`] = {originAtk: o ? o.atk : null, holderAtk: h.atk, stored: h._stateOrigin ? h._stateOrigin[s] : null, ...runTurnEnd(h, env)};
  }
  // 来源敌人已倒下（死亡不移除 troop 成员）
  { const env = battle(2); const h = prep(env, 'enemy'); setSeq([0.5]); giveState(h, sid, 'e1', env); env.e2._hp = 0; env.e2.refresh();
    out['a.e1_dead'] = {originDead: env.e2.isDead(), ...runTurnEnd(h, env)}; }
  // 来源敌人被移出（hidden／成员数变化）
  { const env = battle(2); const h = prep(env, 'enemy'); setSeq([0.5]); giveState(h, sid, 'e1', env); env.e2.hide && env.e2.hide();
    out['a.e1_hidden'] = {hidden: !!env.e2.isHidden(), members: w.$gameTroop.members().length, ...runTurnEnd(h, env)}; }
  // 读档往返：JsonEx 序列化持有者
  { const env = battle(2); const h = prep(env, 'actor'); setSeq([0.5]); giveState(h, sid, 'e0', env);
    const json = w.JsonEx.stringify(h); const copy = w.JsonEx.parse(json);
    out.roundTrip = {stored: copy._stateOrigin ? copy._stateOrigin[sid] : null, hasOrigin: !!(copy._stateOrigin && copy._stateOrigin[sid]), originResolved: key(copy.stateOrigin(sid))}; }
  // 导入角色（141～166）作为施加者：持续伤害是否被 ×0.01
  for (const aid of [141, 163]) {
    const env = battle(2); const h = prep(env, 'enemy'); setSeq([0.5]);
    const imp = w.$gameActors.actor(aid); imp.refresh();
    h.addState(sid); h.setStateOrigin(sid, imp); h.need_refresh = true; h.refresh();
    out['imported.' + aid] = {impAtk: imp.atk, ...runTurnEnd(h, env)};
  }
  return out;
}));

// 8) 护盾／绑定下的持续伤害
cases.push(mk('shield', {}, () => {
  const out = {};
  const sid = synth('<DoT Formula: 300>\n<DoT Variance: 0%>');
  for (const hk of ['enemy', 'actor']) for (const shield of [0, 100, 300, 1000]) {
    const env = battle(2); const h = prep(env, hk); setSeq([0.5]); giveState(h, sid, 'a1', env); h._shield = shield;
    out[`${hk}.${shield}`] = runTurnEnd(h, env);
  }
  return out;
}));

// 8b) dotstates() 缓存：加状态后不刷新、刷新后、去状态后
cases.push(mk('cache.stale', {}, () => {
  const out = {};
  const env = battle(2); const h = prep(env, 'enemy'); setSeq([0.5]);
  const sid = synth('<DoT Formula: 300>\n<DoT Variance: 0%>');
  giveState(h, sid, 'a1', env, true);
  out.noRefresh = {dirty: !!h.need_refresh, cached: h._dotstates ? h._dotstates.map(s => s.id) : null, ...runTurnEnd(h, env)};
  const env2 = battle(2); const h2 = prep(env2, 'enemy'); setSeq([0.5]); giveState(h2, sid, 'a1', env2, true); h2.refresh();
  out.afterRefresh = {cached: h2._dotstates ? h2._dotstates.map(s => s.id) : null, ...runTurnEnd(h2, env2)};
  const env3 = battle(2); const h3 = prep(env3, 'enemy'); setSeq([0.5]); giveState(h3, sid, 'a1', env3); h3.removeState(sid);
  out.removedNoRefresh = {dirty: !!h3.need_refresh, cached: h3._dotstates ? h3._dotstates.map(s => s.id) : null, ...runTurnEnd(h3, env3)};
  return out;
}));

// 9) 2038 全局 value 泄漏：先有别的持续伤害留下全局 value，再看 2038 角色来源分支
cases.push(mk('leak2038', {}, () => {
  const out = {};
  for (const prior of ['none', 'dot300', 'heal500']) for (const ok of ['a1', 'e0', 'none']) {
    const env = battle(2); const h = prep(env, 'enemy'); setSeq([0.5]); delete w.value; w.eval('var __x=0');
    if (prior !== 'none') {
      const p = synth(prior === 'dot300' ? '<DoT Formula: 300>\n<DoT Variance: 0%>' : '<Regen Formula: 500>\n<Regen Variance: 0%>');
      giveState(h, p, 'a1', env); h.processDamageOverTimeStates(); h.removeState(p); h._hp = Math.min(h.mhp, 100000); errors.length = 0;
    }
    const gv = globalValue();
    giveState(h, 2038, ok, env);
    out[`${prior}.${ok}`] = {damagedot: h.damagedot === undefined ? null : h.damagedot, leakedBefore: gv, ...runTurnEnd(h, env)};
  }
  return out;
}));

process.exit(finish(host, 'dot.json', {scope: 'YEP_X_ExtDoT processDamageOverTimeStates on frozen source; synthetic states only parsed by native processEDoTNotetags1', cases}) ? 0 : 1);
