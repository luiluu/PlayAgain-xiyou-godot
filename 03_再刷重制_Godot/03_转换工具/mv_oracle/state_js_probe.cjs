'use strict';
// 状态效果 js 再翻译（云端车道，2026-10-25）：先测原版整块，再加转换器形状。
// 只用 $dataStates 里的原文块（customEffectEval 照原插件解析），在真实 Game_Battler 上执行；
// 战斗者能力值用实例属性固定成给定档位，便于 Godot 用同样的输入逐项对照。弹字只记结果槽（不进精灵）。
// 只在内存里跑：新局与 BattleManager.setup；不渲染、不写存档。产物 .sandbox/state_js.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');  // 五乘区（CodexZones）重制不移植（O-044），探针宿主默认开着；关掉让参照不含成长修正（tools50 确认关与不关产物一致或已更新夹具）
const stub = new Proxy(function () {}, {get: (_, k) => k === '_waitCount' ? 0 : (() => false), set: () => true});
const key = b => !b ? null : (b.isActor && b.isActor()) ? 'a' + b.actorId() : (b.index ? 'e' + b.index() : '?');
let POPUPS = null, ANIMS = null, COLLAPSES = null;
// 弹字：记录调用时的结果槽（BEC startDamagePopup 推入结果副本）；不调原函数，表现层插件版本不同也不影响测量
w.Game_Battler.prototype.startDamagePopup = function () {
  if (POPUPS) { const r = this.result(); POPUPS.push([key(this), r.hpAffected, r.hpDamage, r.mpDamage, r.tpDamage]); }
};
w.Game_Battler.prototype.startAnimation = function (id) { if (ANIMS) ANIMS.push([key(this), id]); };
w.Game_Battler.prototype.performCollapse = function () { if (COLLAPSES) COLLAPSES.push(key(this)); };
// OTB／BEC 的画面对象（真实 startTurn／endTurn 要用）
const sprites = new Map();
w.Game_Battler.prototype.battler = function () {
  if (!sprites.has(this)) sprites.set(this, new Proxy({x: 0, y: 0, _homeX: 0, _homeY: 0, width: 64, height: 64,
    scale: {x: 1, y: 1}, anchor: {x: 0.5, y: 1}, opacity: 255},
  {get: (t, k) => k in t ? t[k] : (() => false), set: (t, k, v) => {t[k] = v; return true;}}));
  return sprites.get(this);
};
w.BattleManager.actionBattleHud = () => true;
w.BattleManager.otbDisplayWindow = () => stub;
const errors = [], oldError = w.Yanfly.Util.displayError;
// 原版报错记成 thrown，不用 error 键：同步的 has_error 把 error 键当探针失败（这里是测到的原版行为）
w.Yanfly.Util.displayError = (error, code, message) => errors.push({thrown: String(error), message});

function battle(troop) {
  if (w.$gameParty) w.$gameParty._inBattle = false;
  newGame();
  w.eval('$gameParty._actors=[];');
  for (const id of [1, 8]) w.$gameParty.addActor(id);
  for (const id of [1, 8]) { const a = w.$gameActors.actor(id); a._paramPlus[0] = 1e9; a.need_refresh = true; a.refresh(); a.recoverAll(); }
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(troop, true, true);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  if (w.CodexYunshang) w.CodexYunshang._acted = [];
  w.$gameParty._inBattle = true;
  for (const e of w.$gameTroop.members()) { e._paramPlus[0] = 1e9; e.need_refresh = true; e.refresh(); e.recoverAll(); }
  return {bm, a: w.$gameActors.actor(1), b: w.$gameActors.actor(8), e: w.$gameTroop.members()[0]};
}
const PARAMS = ['atk', 'mat', 'agi', 'luk', 'mhp', 'mmp', 'tp', 'level'];
// 来源能力值档位 [atk, mat, agi, luk, mhp, mmp, tp, level]；最后一档含小数与 0
const ORIGINS = [[120, 80, 50, 30, 5000, 300, 40, 25], [7, 3, 11, 13, 999, 17, 0, 1], [0.5, 1.25, 2.5, 0, 1, 0, 100, 99]];
function fix(b, values) {
  const saved = {_level: b._level};
  PARAMS.forEach((name, i) => {
    if (name === 'tp') { saved.tp = b._tp; b._tp = values[i]; return; }
    Object.defineProperty(b, name, {configurable: true, get: () => values[i]});
  });
  b._level = values[7];
  return () => { for (const name of PARAMS) if (name !== 'tp') delete b[name]; b._tp = saved.tp; b._level = saved._level; };
}
function capture(fn) {
  POPUPS = []; ANIMS = []; COLLAPSES = [];
  try { const out = fn(); return Object.assign(out || {}, {popups: POPUPS, anims: ANIMS, collapses: COLLAPSES}); }
  finally { POPUPS = ANIMS = COLLAPSES = null; }
}
function slots(sid) {
  const ev = w.$dataStates[sid].customEffectEval;
  return Object.keys(ev).filter(k => ev[k] !== '');
}

const cases = [];
// ---- 叠毒 _stackingPoison：Apply 加层、Remove 清零、Regenerate 按来源能力与层数扣血 ----
const POISON = w.$dataStates.filter(s => s && /_stackingPoison/.test(s.note)).map(s => s.id);
cases.push(makeCase('poison.inventory', {}, () => ({states: POISON.map(id => ({id, slots: slots(id)}))})));
// Apply／再次附加（_Fix_StackOverflow 只续回合）／Remove；层数在持有者身上，所有叠毒状态共用
cases.push(makeCase('poison.lifecycle', {states: POISON}, () => {
  const rows = [];
  for (const sid of POISON) {
    const {bm, a, e} = battle(2);
    bm._subject = a;
    const seen = [];
    e.addState(sid); seen.push(e._stackingPoison === undefined ? null : e._stackingPoison);
    e.addState(sid); seen.push(e._stackingPoison === undefined ? null : e._stackingPoison);
    e.removeState(sid); seen.push(e._stackingPoison === undefined ? null : e._stackingPoison);
    // 同一结果槽里刚去掉的状态不能再加（isStateAddable），先清
    e.clearResult(); e._stackingPoison = 5; e.addState(sid); seen.push(e._stackingPoison);
    rows.push({state: sid, stacks: seen, affected: e.isStateAffected(sid)});
  }
  return {rows};
}));
// 两种叠毒共用层数：先 460（+1）再 504（+3），去掉其中一个全部清零
cases.push(makeCase('poison.shared_counter', {first: 460, second: 504}, () => {
  const {bm, a, e} = battle(2);
  bm._subject = a;
  e.addState(460); e.addState(504); const both = e._stackingPoison;
  e.removeState(460); return {both, afterRemove: e._stackingPoison, stillSecond: e.isStateAffected(504)};
}));
// Regenerate：持有者 [角色/敌人] × 来源 [另一方/无来源] × 能力档位 × 起始层数 [undefined, 0, 1, 3]，HP 足够与致死两种
cases.push(makeCase('poison.tick', {origins: ORIGINS, columns: ['state', 'holder', 'origin', 'profile', 'stacks', 'hpBefore', 'shield',
  'stacksAfter', 'hpAfter', 'dead', 'popups', 'anims', 'collapses', 'shieldAfter']}, () => {
  const rows = [];
  for (const sid of POISON) {
    if (w.$dataStates[sid].customEffectEval.regenerateState === '') continue;
    for (const holderKind of ['enemy', 'actor']) for (const originKind of ['other', 'self']) {
      let ctx = null;
      for (let p = 0; p < ORIGINS.length; p++) for (const stacks of [null, 0, 1, 3]) for (const [hpBefore, shield] of [[1e9, 0], [5, 0], [1e9, 7]]) {
        if (hpBefore === 5 && (p !== 0 || stacks !== null)) continue;  // 致死只测一档（倒下要另开一场，慢）
        // 同一场战斗里复用；持有者倒下后另开一场（倒下会清掉状态与来源）
        if (!ctx || ctx.holder.isDead()) {
          const {bm, a, e} = battle(2);
          const holder = holderKind === 'enemy' ? e : a, other = holderKind === 'enemy' ? a : e;
          bm._subject = originKind === 'other' ? other : null;
          holder.addState(sid);
          bm._subject = null;
          ctx = {holder};
        }
        const holder = ctx.holder;
        if (stacks === null) delete holder._stackingPoison; else holder._stackingPoison = stacks;
        holder._shield = 0; holder.setHp(hpBefore); holder._shield = shield; holder.clearResult();
        const origin = holder.stateOrigin(sid);
        const restore = fix(origin, ORIGINS[p]);
        let out;
        try {
          out = capture(() => { holder.regenerateStateEffects(sid); return {}; });
        } finally { restore(); }
        rows.push([sid, holderKind, originKind, p, stacks, hpBefore, shield,
          holder._stackingPoison === undefined ? null : holder._stackingPoison, holder.hp, holder.isDead(), out.popups, out.anims, out.collapses,
          holder._shield || 0]);
      }
    }
  }
  return {rows};
}));
// 接线：真实 endTurn 下 460 在敌人身上（角色施加）跑两回合；再生先于回合结束
cases.push(makeCase('poison.turn_end', {troop: 2, state: 460}, () => {
  const {bm, a, e} = battle(2);
  bm._subject = a; e.addState(460); bm._subject = null;
  const hp0 = e.hp;
  return capture(() => {
    bm.startTurn(); bm.endTurn(); const hp1 = e.hp, s1 = e._stackingPoison;
    bm.startTurn(); bm.endTurn();
    return {hp0, hp1, s1, hp2: e.hp, s2: e._stackingPoison, atk: a.atk, mat: a.mat, level: a._level};
  });
}));

// ---- 第二批：开战／回合开始加状态、暴击后加状态、开战与胜利回复、开战设变量、原版语法错误块 ----
const squash = code => code.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '').replace(/\s+/g, '');
const SLOT_PHASE = {battle: 'battle', turnStartState: 'turn_start', victory: 'victory', addState: 'apply', establishState: 'establish'};
function blocks(slots, test) {
  const out = [];
  for (const st of w.$dataStates) if (st) for (const slot of slots) {
    const code = st.customEffectEval[slot];
    if (code && test(squash(code))) out.push([st.id, slot]);
  }
  return out;
}
const ADD = blocks(['battle', 'turnStartState'], c => /^user\.addState\(\d+\);?$/.test(c));
const CRIT = blocks(['establishState'], c => /^if\(target\.result\(\)\.critical\)\{varparam=\d+;(varturns=\d+;)?(user|target)\.addState\(param(,turns)?\);\}$/.test(c));
const GAIN = blocks(['battle', 'victory', 'addState'], c => /^(?:varrate=[\d.]+;varvalue=Math\.ceil\(user\.m[hm]p\*rate\);user\.gain(?:Hp|Mp)\(value\);|user\.gain(?:Hp|Mp|Tp)\([^;]+\);)+$/.test(c));
const SETV = blocks(['battle'], c => /^\$gameVariables\.setValue\(\d+,\d+\);?$/.test(c));
const snapshot = b => ({states: b._states.slice(), turns: Object.assign({}, b._stateTurns), hp: b.hp, mp: b.mp, tp: b.tp,
  added: b.result().addedStates.slice(), dead: b.isDead()});
// 持有者（角色）自己的开战／回合开始脚本；第二例持有者已倒下（isStateAddable 要求活着）
cases.push(makeCase('add_state.self', {blocks: ADD}, () => {
  const rows = [];
  for (const [sid, slot] of ADD) for (const dead of [false, true]) {
    const {a} = battle(2);
    a.addState(sid); a.clearResult();
    if (dead) { a.setHp(0); a.refresh(); a.clearResult(); }
    a.customEffectEval(sid, slot);
    rows.push({state: sid, phase: SLOT_PHASE[slot], dead, after: snapshot(a)});
  }
  return {rows};
}));
// 暴击后：行动者 a 的 Establish，目标 e 的结果槽 critical 真／假；addState 第二个参数（回合）原版不认
cases.push(makeCase('add_state.critical', {blocks: CRIT}, () => {
  const rows = [];
  for (const [sid] of CRIT) for (const critical of [false, true]) {
    const {a, e} = battle(2);
    const action = new w.Game_Action(a); action.setSkill(1);
    a.clearResult(); e.clearResult(); e.result().critical = critical;
    const value = action.customEffectEval(e, sid, 'establishState', a, 7);
    rows.push({state: sid, critical, value, user: snapshot(a), target: snapshot(e)});
  }
  return {rows};
}));
// 回复：固定 HP/MP 上限，起点 [hp, mp, tp]
cases.push(makeCase('gain.self', {blocks: GAIN, mhp: 1000, mmp: 300, start: [[500, 100, 10], [1, 0, 95], [1000, 300, 0]]}, () => {
  const rows = [];
  for (const [sid, slot] of GAIN) for (let k = 0; k < 3; k++) {
    const {a} = battle(2);
    Object.defineProperty(a, 'mhp', {configurable: true, get: () => 1000});
    Object.defineProperty(a, 'mmp', {configurable: true, get: () => 300});
    const start = [[500, 100, 10], [1, 0, 95], [1000, 300, 0]][k];
    a._hp = start[0]; a._mp = start[1]; a._tp = start[2]; a.clearResult();
    try { a.customEffectEval(sid, slot); } finally { delete a.mhp; delete a.mmp; }
    const r = a.result();
    rows.push({state: sid, phase: SLOT_PHASE[slot], start: k, hp: a._hp, mp: a._mp, tp: a._tp,
      slot: [r.hpDamage, r.mpDamage, r.tpDamage, r.hpAffected]});
  }
  return {rows};
}));
cases.push(makeCase('set_variable.battle', {blocks: SETV}, () => {
  const rows = [];
  for (const [sid, slot] of SETV) {
    const {a} = battle(2);
    const m = squash(w.$dataStates[sid].customEffectEval[slot]).match(/setValue\((\d+),/);
    w.$gameVariables.setValue(+m[1], 7);
    a.customEffectEval(sid, slot);
    rows.push({state: sid, variable: +m[1], value: w.$gameVariables.value(+m[1])});
  }
  return {rows};
}));
// 接线：真实开战（BattleManager.startBattle），a1 带 607（开战 TP+200）；原版 onBattleStart 先随机初始 TP 再跑 Battle 脚本
cases.push(makeCase('battle.start_order', {troop: 2, state: 607}, () => {
  const {bm, a} = battle(2);
  a.addState(607);
  w.$gameParty._inBattle = false;
  bm.startBattle();
  return {tp: a.tp, maxTp: a.maxTp()};
}));
// 原版解析不了的块（SyntaxError）：customEffectEval 只报错，什么都不改
const vm = require('vm');
const SYNTAX = [];
for (const st of w.$dataStates) if (st) for (const slot of Object.keys(st.customEffectEval)) {
  const code = st.customEffectEval[slot];
  if (!code) continue;
  try { new vm.Script(code); } catch (e) { if (e instanceof SyntaxError || e.name === 'SyntaxError') SYNTAX.push([st.id, slot]); }
}
cases.push(makeCase('syntax_error.blocks', {blocks: SYNTAX}, () => {
  const rows = [];
  for (const [sid, slot] of SYNTAX) {
    const {a, e} = battle(2);
    const before = [snapshot(a), snapshot(e), w.JsonEx.stringify(w.$gameVariables._data)];
    const n = errors.length;
    let value = 7;
    if (['confirmState', 'reactState', 'establishState', 'respondState', 'initiateState', 'selectState', 'deselectState', 'concludeState'].includes(slot)) {
      const action = new w.Game_Action(a); action.setSkill(1);
      value = action.customEffectEval(e, sid, slot, a, 7);
    } else a.customEffectEval(sid, slot);
    const reported = errors.slice(n).map(x => x.thrown);
    errors.length = n;  // 预期的报错不进 nativeErrors
    rows.push({state: sid, slot, value, reported, unchanged: w.JsonEx.stringify([snapshot(a), snapshot(e), w.JsonEx.stringify(w.$gameVariables._data)]) === w.JsonEx.stringify(before)});
  }
  return {rows};
}));

// ---- 第三批：YEP 状态计数 _stateCounter（G_StateParam paramState 按计数乘 <G_ShuXing>） ----
// paramState 的层数变量 ceng 在循环外：某状态计数为真后，排在它后面的状态都沿用这个层数（原版写法，照测）
const COUNTER = blocks(['addState'], c => /^user\._stateCounter\[(\d+)\]=user\._stateCounter\[\1\]\|\|\$gameVariables\.value\(\d+\);?$/.test(c)).map(([sid]) => sid);
const gOf = st => st.G_ShuXing || [0, 0, 0, 0, 0, 0, 0, 0];
const params = b => [0, 1, 2, 3, 4, 5, 6, 7].map(i => b.param(i));
function fresh() {
  const {a, b} = battle(2);
  b._paramPlus[0] = 0; b.need_refresh = true; b.refresh(); b.clearResult();
  return b;
}
cases.push(makeCase('counter.init', {states: COUNTER, values: [37, 0]}, () => {
  const rows = [];
  for (const sid of COUNTER) for (const value of [37, 0]) {
    const b = fresh();
    const v = +squash(w.$dataStates[sid].customEffectEval.addState).match(/value\((\d+)\)/)[1];
    const p0 = params(b);
    w.$gameVariables.setValue(v, value);
    b.addState(sid);
    const immediate = params(b), counter = b._stateCounter[sid];
    b.refresh();
    const refreshed = params(b);
    b.removeState(sid); b.clearResult();
    const afterRemove = b._stateCounter[sid];
    w.$gameVariables.setValue(v, 99);
    b.addState(sid);
    rows.push({state: sid, variable: v, value, p0, immediate, refreshed, counter, afterRemove, readd: b._stateCounter[sid], readdParams: params(b)});
  }
  return {rows};
}));
// 层数沿用：计数状态 A（变量 12）＋普通 <G_ShuXing> 状态 B；B 排在 A 前或后
const PLAIN = w.$dataStates.filter(st => st && gOf(st).some(x => x) && !Object.keys(st.customEffectEval || {}).some(k => st.customEffectEval[k])
  && !st.traits.length && !COUNTER.includes(st.id));
const order = (x, y) => (y.priority - x.priority) || (x.id - y.id);
cases.push(makeCase('counter.carry', {}, () => {
  const rows = [];
  for (const sid of [COUNTER[0], COUNTER[COUNTER.length - 1]]) {
    const A = w.$dataStates[sid];
    const after = PLAIN.filter(st => order(A, st) < 0).slice(0, 3), before = PLAIN.filter(st => order(A, st) > 0).slice(0, 2);
    for (const B of after.concat(before)) {
      const b = fresh();
      const v = +squash(A.customEffectEval.addState).match(/value\((\d+)\)/)[1];
      w.$gameVariables.setValue(v, 12);
      const p0 = params(b);
      b.addState(B.id); b.refresh();
      const pB = params(b);
      b.addState(sid); b.refresh();
      rows.push({counterState: sid, plain: B.id, plainAfter: order(A, B) < 0, states: b._states.slice(), p0, pB, pAB: params(b)});
    }
  }
  return {rows};
}));
cases.push(makeCase('counter.battle', {state: 1763, mp: [0, 7, 150]}, () => {
  const rows = [];
  for (const mp of [0, 7, 150]) {
    const b = fresh();
    b.addState(1763); b.refresh();
    const p0 = params(b);
    b._mp = mp;
    b.customEffectEval(1763, 'battle');
    b.refresh();
    rows.push({mp, counter: b._stateCounter[1763], p0, p1: params(b)});
  }
  return {rows};
}));

const ok = finish(host, 'state_js.json', {cases, nativeErrors: errors});
w.Yanfly.Util.displayError = oldError;
process.exit(ok ? 0 : 1);
