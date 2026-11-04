'use strict';
// 状态效果阶段钩子第一期：冻结版「最后生效」的调用链参照（沙僧核查报告 2026-10-21 状态效果提案，必改一与第一期）。
// 往 $dataStates 追加测试状态 T（复制中毒 4 的已解析字段），它的每个 customEffectEval 槽都只调用记录函数，不改 value；
// 在真实 BattleManager／Game_Action 流程里记：phase、状态、持有者、两类上下文（Battler 版 a＝持有者；Action 版 a＝行动者、b＝目标），
// 以及 startAction／endAction／refresh／addState／removeState 等边界标记，按发生先后排成一条序列。
// 用例：开战（battle 与 dsPassiveSkill 开战标签的先后）、普通行动全链、未命中、魔法反射、反击、防御、强制行动、
// OTB 行动结束、回合开始／再生／回合结束、KRZ 热缓存（先暖 typestates 再加／去状态）、自然到期与驱散、胜／逃／败。
// 只在内存里跑：新局与 BattleManager.setup；不渲染、不写存档。产物 .sandbox/state_effects.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
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
let LOG = null;
const mark = (...row) => { if (LOG) LOG.push(row); };
w.__seLog = (type, sid, a, b) => mark('fx', type, sid, key(a), b === undefined ? null : key(b));
const TYPES = ['addState', 'removeState', 'leaveState', 'turnStartState', 'turnEndState', 'regenerateState', 'selectState', 'deselectState',
  'reactState', 'respondState', 'initiateState', 'concludeState', 'confirmState', 'establishState', 'actionStartState', 'actionEndState',
  'battle', 'victory', 'defeat', 'escape'];
// 测试状态：复制 4 的解析字段，特性清空；每个槽：Battler 版没有 b（typeof 判断），Action 版传 b
function testState(name, extra) {
  const st = w.JsonEx.makeDeepCopy(w.$dataStates[4]);
  const id = w.$dataStates.length;
  Object.assign(st, {id, name, traits: [], note: '', meta: {}, autoRemovalTiming: 0, minTurns: 1, maxTurns: 1, removeAtBattleEnd: false,
    restriction: 0, priority: 50, iconIndex: 0}, extra || {});
  for (const k of TYPES) st.customEffectEval[k] = `__seLog('${k}', ${id}, a, typeof b === 'undefined' ? undefined : b);`;
  w.$dataStates.push(st);
  return id;
}
const T = testState('测试·阶段记录');
const T2 = testState('测试·阶段记录二');
const EXPIRE = testState('测试·一回合到期', {autoRemovalTiming: 2, minTurns: 1, maxTurns: 1});
const fakeTrait = (code, dataId, value, name) => { const id = testState(name); w.$dataStates[id].traits = [{code, dataId, value}];
  for (const k of TYPES) w.$dataStates[id].customEffectEval[k] = ''; return id; };
const MRF = fakeTrait(22, 5, 1, '测试·魔法反射'), CNT = fakeTrait(22, 6, 1, '测试·反击'), EVA = fakeTrait(22, 4, 1, '测试·魔法回避');
// 边界标记（最外层包装）
const wrap = (obj, name, tag) => { const old = obj[name]; obj[name] = function (...args) {
  mark('>' + tag, key(this && this._subject !== undefined ? this._subject : this), ...args.filter(x => typeof x === 'number'));
  try { return old.apply(this, args); } finally { mark('<' + tag, key(this && this._subject !== undefined ? this._subject : this)); } }; };
wrap(w.BattleManager, 'startAction', 'startAction');
wrap(w.BattleManager, 'endAction', 'endAction');
wrap(w.BattleManager, 'startTurn', 'startTurn');
wrap(w.BattleManager, 'endTurn', 'endTurn');
wrap(w.BattleManager, 'endBattle', 'endBattle');
for (const m of ['refresh', 'addState', 'removeState', 'onTurnStart', 'onTurnEnd', 'regenerateAll', 'onBattleStart', 'onAllActionsEnd']) {
  wrap(w.Game_Battler.prototype, m, m);
  // 角色／敌人原型上有自己的同名方法时（盖过 Game_Battler 的），也包一层
  for (const P of [w.Game_Actor.prototype, w.Game_Enemy.prototype]) if (Object.prototype.hasOwnProperty.call(P, m)) wrap(P, m, m);
}
const oldApply = w.Game_Action.prototype.apply;
w.Game_Action.prototype.apply = function (t) { mark('>apply', key(this.subject()), key(t)); try { return oldApply.apply(this, arguments); } finally { mark('<apply', key(this.subject()), key(t)); } };
// 只记录测试状态的 addState／removeState，其余（死亡 1 等）也记，便于看嵌套
function battle(troop) {
  if (w.$gameParty) w.$gameParty._inBattle = false;  // 上一例留下的战斗中标记会让新局建对象时走战斗分支
  newGame();
  w.eval('$gameParty._actors=[];');
  for (const id of [1, 8]) w.$gameParty.addActor(id);
  for (const id of [1, 8]) { const a = w.$gameActors.actor(id); a._paramPlus[0] = 1e9; a.need_refresh = true; a.refresh(); a.recoverAll(); }
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(troop, true, true);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.CodexYunshang._acted = [];
  w.$gameParty._inBattle = true;  // 回合结束、再生等条件要求在战斗中（开战用例另由 startBattle 设）
  for (const e of w.$gameTroop.members()) { e._paramPlus[0] = 1e9; e.need_refresh = true; e.refresh(); e.recoverAll(); }
  return {bm, a: w.$gameActors.actor(1), b: w.$gameActors.actor(8), e: w.$gameTroop.members()[0]};
}
function runAction(bm, user, skillId, targetIndex, extra) {
  const action = new w.Game_Action(user); action.setSkill(skillId); action.setTarget(targetIndex);
  if (extra) extra(action);
  user._actions = [action]; bm._subject = user; bm._action = null;
  bm.startAction();
  for (let i = 0; i < 20000; i++) {
    const ph = bm._phase;
    if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
    else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
  }
  return bm._phase;
}
// 只保留 fx 与和测试相关的边界，去掉大量无关 refresh（只留紧邻 fx 的）
function trim(log) { return log; }
function capture(fn) { const out = LOG = []; try { fn(); } finally { LOG = null; } return out; }
const cases = [];
cases.push(makeCase('fixture', {T, T2, EXPIRE, MRF, CNT, EVA}, () => ({types: TYPES, states: [T, T2, EXPIRE, MRF, CNT, EVA].map(id => ({id, name: w.$dataStates[id].name,
  traits: w.$dataStates[id].traits, autoRemovalTiming: w.$dataStates[id].autoRemovalTiming, slots: Object.keys(w.$dataStates[id].customEffectEval).filter(k => w.$dataStates[id].customEffectEval[k] !== '')}))})));
// 开战：真实 Scene_Battle.start（dsPassiveSkill 包装在外）＝BattleManager.startBattle → 原 onBattleStart → 逐成员 refresh＋Custom Battle，之后 DS 开战标签加状态
cases.push(makeCase('battle.start', {troop: 2, holders: ['a1', 'a8', 'e0'], dsPassive: 6168}, () => {
  const {bm, a, b, e} = battle(2);
  a.learnSkill(6168); a.addState(T); b.addState(T); e.addState(T);
  const scene = Object.create(w.Scene_Battle.prototype);
  scene.startFadeIn = () => {}; scene.fadeSpeed = () => 24; scene._active = false;
  const base = w.Scene_Base.prototype.start; w.Scene_Base.prototype.start = function () {};
  let log;
  try { log = capture(() => scene.start()); } finally { w.Scene_Base.prototype.start = base; }
  return {log, states: [a, b, e].map(x => [key(x), x._states.slice()])};
}));
// 普通行动全链：行动者与目标都带 T，真实 startAction 流程
for (const [id, skill, setup] of [['attack', 1, null], ['miss', 1, 'eva'], ['reflect', 1, 'mrf'], ['guard', 2, null]]) {
  cases.push(makeCase('action.' + id, {troop: 2, user: 'a1', skill, target: 'e0', setup}, () => {
    const {bm, a, e} = battle(2);
    a.addState(T); e.addState(T);
    if (setup === 'eva') e.addState(EVA);
    if (setup === 'mrf') e.addState(MRF);
    for (const x of [a, e]) { x.need_refresh = true; x.refresh(); }
    const log = capture(() => runAction(bm, a, skill, 0));
    return {log};
  }));
}
cases.push(makeCase('action.forced', {troop: 2, user: 'a1', skill: 1, target: 'e0', forced: true}, () => {
  const {bm, a, e} = battle(2);
  a.addState(T); e.addState(T);
  for (const x of [a, e]) { x.need_refresh = true; x.refresh(); }
  const log = capture(() => { a.forceAction(1, 0); bm.forceAction(a); bm._subject = null;
    for (let i = 0; i < 20000 && (bm._actionForcedBattler || bm._subject || bm._phase === 'action' || bm._phase === 'actionList' || bm._phase === 'actionTargetList' || bm._phase === 'phaseChange'); i++) {
      if (bm._actionForcedBattler && !bm._subject) { bm.processForcedAction(); continue; }
      const ph = bm._phase;
      if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
      else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
    } });
  return {log};
}));
// 回合开始／结束：真实 startTurn、endTurn（OTB）；T 在双方，EXPIRE 一回合到期
cases.push(makeCase('turn.start_end', {troop: 2, holders: ['a1', 'e0']}, () => {
  const {bm, a, e} = battle(2);
  a.addState(T); e.addState(T); e.addState(EXPIRE);
  for (const x of [a, e]) { x.need_refresh = true; x.refresh(); }
  const log = capture(() => { bm.startTurn(); bm.endTurn(); });
  return {log, after: [a, e].map(x => [key(x), x._states.slice()])};
}));
// KRZ 热缓存：先暖 typestates，再加／去状态，不 refresh 就跑 onTurnStart；然后 refresh 再跑一次
cases.push(makeCase('krz.hot_cache', {troop: 2, holder: 'a1'}, () => {
  const {a} = battle(2);
  a.addState(T); a.need_refresh = true; a.refresh();
  const log = capture(() => {
    a.typestates('turnStartState'); mark('warm');
    a.addState(T2); mark('added T2, no refresh');
    a.onTurnStartStateEffects(); mark('refresh next');
    a.refresh(); a.onTurnStartStateEffects(); mark('remove T');
    a.removeState(T); a.onTurnStartStateEffects(); mark('refresh again');
    a.refresh(); a.onTurnStartStateEffects();
  });
  return {log};
}));
// 自然到期（removeStatesAuto）与技能驱散（直接 removeState）
cases.push(makeCase('remove.expire_vs_dispel', {troop: 2, holder: 'a1'}, () => {
  const {a} = battle(2);
  a.addState(EXPIRE); a.addState(T);
  const log = capture(() => { a.updateStateTurns(); a.removeStatesAuto(2); mark('dispel T'); a.removeState(T); });
  return {log};
}));
// 胜／逃／败：只对我方（含后备）跑，且在原 endBattle 之前
for (const [name, result] of [['victory', 0], ['escape', 1], ['defeat', 2]]) {
  cases.push(makeCase('end.' + name, {troop: 2, result, holders: ['a1', 'a8', 'e0']}, () => {
    const {bm, a, b, e} = battle(2);
    a.addState(T); b.addState(T); e.addState(T);
    const scene = w.SceneManager.goto; w.SceneManager.goto = () => {};
    let log;
    try { log = capture(() => bm.endBattle(result)); } finally { w.SceneManager.goto = scene; }
    return {log};
  }));
}
// Phase 2a: native lifecycle and cached phase lists. No production JS is translated here.
for (const kind of ['actor', 'enemy']) {
  cases.push(makeCase('lifecycle.' + kind, {troop: 2, kind}, () => {
    const {bm, a, e} = battle(2), h = kind === 'actor' ? a : e, origin = kind === 'actor' ? e : a;
    bm._subject = origin;
    const describe = (phase, sid, holder) => mark('life', phase, sid, key(holder), key(holder.stateOrigin(sid)), holder.isStateAffected(sid));
    w.__life = describe;
    const saved = [T, T2, EXPIRE].map(id => [id, Object.assign({}, w.$dataStates[id].customEffectEval)]);
    for (const id of [T, T2, EXPIRE]) for (const phase of ['addState', 'removeState', 'leaveState'])
      w.$dataStates[id].customEffectEval[phase] = `__life('${phase}', ${id}, a);`;
    let log;
    try {
      log = capture(() => {
        h.addState(T); mark('reapply'); h.addState(T); mark('dispel'); h.removeState(T); h.removeState(T);
        mark('expire'); h.addState(EXPIRE); h._stateTurns[EXPIRE] = 0; h.removeStatesAuto(2);
        mark('nested add'); h.clearResult();
        w.$dataStates[T].customEffectEval.addState += `target.addState(${T2});`;
        h.addState(T); mark('nested absent', h.isStateAffected(T2)); h.removeState(T); h.clearResult();
        mark('nested leave');
        h.addState(T); h.addState(T2);
        w.$dataStates[T].customEffectEval.removeState += `target.removeState(${T2});`;
        h._stateTurns[T] = 0; h.removeStatesAuto(0);
      });
    } finally { for (const [id, slots] of saved) w.$dataStates[id].customEffectEval = slots; }
    return {log};
  }));
}
cases.push(makeCase('mul.round_boundaries', {}, () => {
  const {a, e} = battle(2);
  const sid = testState('测试·乘数负半整数');
  for (const k of TYPES) w.$dataStates[sid].customEffectEval[k] = '';
  w.$dataStates[sid].customEffectEval.confirmState = 'if (value !== 0) { value = Math.round(value * 0.5); }';
  a.addState(sid); a.need_refresh = true; a.refresh();
  const action = new w.Game_Action(a); action.setSkill(1);
  const values = [-3, -1, 0, 1, 3].map(value => [value, action.customEffectEval(e, sid, 'confirmState', a, value)]);
  return {values};
}));
// Fix makeDamageValue as extension modules do; the real executeDamage still owns all four state phases.
cases.push(makeCase('damage.full_chain', {raw: 7, confirm: 2, react: 0.5, respond: 3, establish: 0.5}, () => {
  const {a, e} = battle(2), action = new w.Game_Action(a); action.setSkill(1);
  const saved = w.$dataStates[T].customEffectEval, log = [];
  w.__seDamage = (phase, value, target) => log.push([phase, value, target.result().critical, w.$gameVariables.value(27), w.$gameSwitches.value(28)]);
  w.$gameVariables.setValue(27, 314); w.$gameSwitches.setValue(28, true);
  w.$dataStates[T].customEffectEval = Object.fromEntries(Object.keys(saved).map(k => [k, '']));
  for (const [phase, rate] of [['confirm', 2], ['react', 0.5], ['respond', 3], ['establish', 0.5]]) {
    w.$dataStates[T].customEffectEval[phase + 'State'] = `__seDamage('${phase}', value, target); if (value !== 0) { value = Math.round(value * ${rate}); }`;
  }
  try {
    a.addState(T); e.addState(T);
    for (const x of [a, e]) { x.need_refresh = true; x.refresh(); }
    action.makeDamageValue = () => 7;
    action.itemCri = () => 1;
    const hp = e.hp; action.apply(e);
    return {log, hpDelta: e.hp - hp, hpDamage: e.result().hpDamage, critical: e.result().critical};
  } finally { w.$dataStates[T].customEffectEval = saved; delete w.__seDamage; }
}));
// Phase 2b: real constant bonus blocks, measured before adding any new translator.
// Four complete source shapes: local bonus, finalRate, final+critical, and final+critical followed by floor.
const BONUS_STATES = [34, 52, 1160, 1161, 1397, 1406, 1445, 1446, 1447, 1448, 1454, 1522, 1545, 1669, 1671, 1684,
  1717, 1718, 1719, 1720, 1766, 2525, 2526, 2529, 2539, 2556, 2563, 2565];
cases.push(makeCase('bonus.native_blocks', {states: BONUS_STATES, values: [-3, -1, 0, 1, 3, 7, 101], types: [0, 1, 2, 3]}, () => {
  const {a, e} = battle(2), action = new w.Game_Action(a); action.setSkill(1);
  const original = action.item().damage.type, rows = [];
  try {
    for (const sid of BONUS_STATES) for (const type of [0, 1, 2, 3]) for (const critical of [false, true]) for (const value of [-3, -1, 0, 1, 3, 7, 101]) {
      action.item().damage.type = type; e.result().critical = critical;
      const after = action.customEffectEval(e, sid, 'confirmState', a, value);
      rows.push({state: sid, type, critical, before: value, after});
    }
  } finally { action.item().damage.type = original; }
  return {rows};
}));
// Phase 2c: whole native value-only blocks, before translating any of them.
const VALUE_STATES = [543, 1228, 1259, 1375, 1420, 1421, 1422, 1424, 1441, 1442, 1451, 1540, 1668, 1701, 1702,
  1703, 1707, 1717, 1718, 1719, 1720, 1722, 1726, 1732, 1733, 1770, 1779, 1836, 2522, 2558, 2561, 2583, 2676, 2677, 2678];
const VALUE_REACT = new Set([1228, 1375, 1451, 1540, 1668, 1701, 1702, 1717, 1718, 1719, 1720, 1779, 2558, 2561]);
cases.push(makeCase('value.native_blocks', {states: VALUE_STATES, values: [-3, -1, 0, 1, 3, 7, 101],
  columns: ['state', 'phase', 'profile', 'type', 'hit', 'critical', 'before', 'random', 'after', 'draws']}, () => {
  const {a, e} = battle(2), action = new w.Game_Action(a); action.setSkill(1);
  const item = action.item(), originalType = item.damage.type, originalHit = item.hitType;
  const vars = [967, 965, 1181, 1184, 206, 966, 20];
  // [level, user mhp, target hp, target mhp, target def, target state count, variable values].
  const profiles = [
    [40, 1000, 800, 1000, 10, 3, [10, 10, 1250, 6, 1000, 1, 15]],
    [1, 1000, 0, 1000, 0, 0, [-10, -10, -20000, -200, -51000, -20, -1]],
    [30, 1000, 400, 1000, 10, 1, [0, 0, 0, 0, 0, 0, 7]],
    [31, 1000, 700, 1000, 1, 5, [1, 1, 999, 4, -49999, -10, 16]],
    [53, 1000, 401, 1000, 100, 10, [11, 11, 1000, 5, 50000, 2, 30]],
    [100, 1000, 9999, 10000, -10, 30, [100, 100, 99999, 999, 99999, 100, 100]]
  ];
  const property = (obj, key, value) => Object.defineProperty(obj, key, {configurable: true, value});
  const randomBefore = w.Math.random, oldError = w.Yanfly.Util.displayError, errors = [], rows = [];
  let draws = 0;
  w.Yanfly.Util.displayError = (error, code, message) => errors.push({error: String(error), message});
  function configure(p) {
    property(a, 'level', p[0]); property(a, 'mhp', p[1]);
    property(e, 'hp', p[2]); property(e, 'mhp', p[3]); property(e, 'def', p[4]);
    e.states = () => Array.from({length: p[5]}, (_, i) => w.$dataStates[i + 4]);
    vars.forEach((id, i) => w.$gameVariables.setValue(id, p[6][i]));
  }
  function measure(sid, profile, type, hit, critical, value, random) {
    item.damage.type = type; item.hitType = hit; e.result().critical = critical;
    draws = 0; w.Math.random = () => { draws++; return random; };
    const phase = VALUE_REACT.has(sid) ? 'react' : 'confirm';
    const after = action.customEffectEval(e, sid, phase + 'State', a, value);
    if (!Number.isFinite(after)) throw new Error('nonfinite native value ' + sid);
    rows.push([sid, phase, profile, type, hit, critical, value, random, after, draws]);
  }
  try {
    configure(profiles[0]);
    for (const sid of VALUE_STATES) for (const type of [0, 1, 2, 3]) for (const hit of [0, 1, 2])
      for (const critical of [false, true]) for (const value of [-3, -1, 0, 1, 3, 7, 101]) measure(sid, 0, type, hit, critical, value, 0.5);
    for (let profile = 1; profile < profiles.length; profile++) {
      configure(profiles[profile]);
      for (const sid of VALUE_STATES) for (const hit of [0, 1, 2]) for (const value of [-3, -1, 0, 1, 3, 7, 101])
        measure(sid, profile, 1, hit, true, value, 0.5);
    }
    configure(profiles[0]);
    for (const sid of [1441, 1703, 1707, 1732]) for (const random of [0, 0.500001, 0.8, 0.800001, 0.999999])
      for (const type of [0, 1, 2, 3]) for (const hit of [0, 1, 2]) for (const value of [-3, -1, 0, 1, 3, 7, 101])
        measure(sid, 0, type, hit, false, value, random);
    if (errors.length) throw new Error('native block errors: ' + JSON.stringify(errors));
    return {profiles, variables: vars, rows};
  } finally {
    item.damage.type = originalType; item.hitType = originalHit; w.Math.random = randomBefore; w.Yanfly.Util.displayError = oldError;
    for (const name of ['level', 'mhp']) delete a[name];
    for (const name of ['hp', 'mhp', 'def', 'states']) delete e[name];
  }
}));
// Phase 2d: native read-only action queries; no new translation until measured.
cases.push(makeCase('query.native_blocks', {states: [1047, 1048, 1834, 2544, 2545, 2711]}, () => {
  const {a, b, e} = battle(2), action = new w.Game_Action(a); action.setSkill(1);
  const item = action.item(), originalDamage = Object.assign({}, item.damage), originalMultiple = item.multipleElements;
  const rows = [], errors = [], oldError = w.Yanfly.Util.displayError;
  w.Yanfly.Util.displayError = (error, code, message) => errors.push({error: String(error), message});
  const values = [-101, -3, -1, 0, 0.5, 1, 3, 7, 101];
  // [elementId, multiple, attackElements, passive override, null, forced, added]
  const elements = [[1, [], [], 0, false, null, []], [2, [], [], 0, false, null, []],
    [0, [], [], 0, false, null, []], [-1, [], [2, 1], 0, false, null, []],
    [2, [1, 2, 1], [], 0, false, null, []], [1, [], [], 2, false, null, []],
    [2, [], [], 1, false, null, []], [1, [], [], 0, true, null, []],
    [1, [], [], 0, false, [], [1]], [2, [], [], 0, true, [1, 1, 16], []],
    [1, [], [], 0, false, [2], []], [2, [], [], 0, false, null, [1]]];
  const savedCache = a._passiveCache;
  try {
    for (let profile = 0; profile < elements.length; profile++) {
      const p = elements[profile]; item.damage.elementId = p[0]; item.multipleElements = p[1];
      a.attackElements = () => p[2]; a._passiveCache = Object.assign({}, savedCache, {damageElement: p[3]});
      a.isNullElement = () => p[4];
      if (p[5] === null) delete w.$gameTemp._forcedElements; else w.$gameTemp._forcedElements = p[5];
      w.$gameTemp._addedElements = p[6];
      for (const sid of [1047, 1048]) for (const type of [0, 1, 2, 3, 4, 5, 6]) for (const value of values) {
        item.damage.type = type;
        rows.push({state: sid, profile, type, before: value, elements: action.getItemElements(),
          after: action.customEffectEval(e, sid, 'reactState', e, value)});
      }
    }
    delete a.attackElements; delete a.isNullElement; a._passiveCache = savedCache;
    delete w.$gameTemp._forcedElements; delete w.$gameTemp._addedElements;
    // Actual party lists: battle slots exclude reserves; death-state membership,
    // rather than bare hp=0, determines aliveMembers (including enemy attackers).
    const party = [];
    for (const [inBattle, dead, hpZero] of [[true, [], false], [true, [8], false], [true, [1, 8], false],
      [true, [], true], [false, [8], false]]) {
      w.$gameParty._actors = w.eval('[1, 8, 9]'); w.$gameParty._battleMembers = w.eval('[1, 8, 0, 0, 0]'); w.$gameParty._inBattle = inBattle;
      for (const id of [1, 8, 9]) { const x = w.$gameActors.actor(id); x._states = w.eval(dead.includes(id) ? '[1]' : '[]'); x._hp = hpZero ? 0 : 100; }
      const profile = party.length, members = w.$gameParty.members().map(x => x.actorId());
      party.push({inBattle, dead, hpZero, members, alive: w.$gameParty.aliveMembers().map(x => x.actorId())});
      for (const enemyUser of [false, true]) for (const type of [0, 1, 2, 3, 4, 5, 6]) for (const value of values) {
        const act = new w.Game_Action(enemyUser ? e : a); act.setSkill(1); item.damage.type = type;
        rows.push({state: 1834, profile, enemyUser, type, before: value,
          after: act.customEffectEval(enemyUser ? a : e, 1834, 'confirmState', enemyUser ? e : a, value)});
      }
    }
    const defenders = [];
    for (const target of [e, a]) for (const hp of [0, 19, 20, 21, 100]) {
      Object.defineProperty(target, 'mhp', {value: 100, configurable: true}); target._hp = hp;
      const profile = defenders.length; defenders.push({enemy: target === e, hp, mhp: 100});
      for (const type of [0, 1, 2, 3, 4, 5, 6]) for (const value of values) {
        item.damage.type = type;
        rows.push({state: 2711, profile, type, before: value,
          after: action.customEffectEval(target, 2711, 'confirmState', a, value)});
      }
      delete target.mhp;
    }
    // Weapons and replacement attack are measured but stay JS pending that core.
    const weapons = [];
    for (const weaponType of [null, 2, 11, 1]) for (const replace of [0, 12]) for (const skill of [1, 12]) {
      a.weapons = () => weaponType === null ? [] : [{wtypeId: weaponType}];
      a._replaceAttackSkillId = replace; action.setSkill(skill);
      const profile = weapons.length; weapons.push({weaponType, replace, skill, isAttack: action.isAttack()});
      for (const sid of [2544, 2545]) for (const value of values) rows.push({state: sid, profile, before: value,
        after: action.customEffectEval(e, sid, 'confirmState', a, value)});
    }
    if (errors.length) throw new Error('native query errors: ' + JSON.stringify(errors));
    return {elements, party, defenders, weapons, rows};
  } finally {
    Object.assign(item.damage, originalDamage); item.multipleElements = originalMultiple;
    a._passiveCache = savedCache; delete a.attackElements; delete a.isNullElement; delete a.weapons;
    delete a.mhp; delete e.mhp;
    delete w.$gameTemp._forcedElements; delete w.$gameTemp._addedElements;
    w.Yanfly.Util.displayError = oldError;
  }
}));
// Phase 2e: whole constant gainTp blocks, including native slots/refresh and
// the real addState reapplication path. No translation precedes this measure.
cases.push(makeCase('tp.native_blocks', {states: [607, 609, 857, 1334, 1336]}, () => {
  const {a, e} = battle(2), rows = [], applyRows = [], errors = [];
  const oldError = w.Yanfly.Util.displayError;
  w.Yanfly.Util.displayError = error => errors.push(String(error && error.stack || error));
  const snapshot = b => ({hp: b.hp, mp: b.mp, tp: b.tp, cap: b.maxTp(), states: Array.from(b._states),
    turns: Object.assign({}, b._stateTurns), dirty: !!b.need_refresh,
    result: {hpAffected: b.result().hpAffected, hpDamage: b.result().hpDamage,
      mpDamage: b.result().mpDamage, tpDamage: b.result().tpDamage,
      success: b.result().success, addedStates: Array.from(b.result().addedStates), removedStates: Array.from(b.result().removedStates)}});
  const prepare = (b, tp, dead) => {
    b.clearStates(); b._tp = tp; b._hp = dead ? 0 : b.mhp; b._mp = b.mmp;
    b.need_refresh = true; b.refresh(); b.states(); b.typestates('turnStartState');
    // Warm the caches, then inject requested boundary resources without refresh.
    b._tp = tp; b._hp = dead ? 0 : b.mhp;
    b.clearResult(); Object.assign(b.result(), {hpAffected: true, hpDamage: 17, mpDamage: 19, tpDamage: 23, success: true});
  };
  let draws = 0; const oldRandom = w.Math.random;
  try {
    w.Math.random = () => { draws++; return 0.5; };
    for (const [kind, b] of [['actor', a], ['enemy', e]]) for (const sid of [607, 609, 857, 1334, 1336]) {
      const slot = sid >= 1334 ? 'addState' : 'battle';
      for (const tp of [-1, 0, 1, 150, 199, 200, 250]) for (const dead of [false, true]) {
        prepare(b, tp, dead); const before = snapshot(b); draws = 0;
        const log = capture(() => b.customEffectEval(sid, slot));
        rows.push({kind, state: sid, phase: slot === 'battle' ? 'battle' : 'apply', tp, dead,
          before, after: snapshot(b), draws, log});
      }
    }
    for (const [kind, b] of [['actor', a], ['enemy', e]]) for (const sid of [1334, 1336]) {
      prepare(b, 1, false); const before = snapshot(b); draws = 0;
      const log = capture(() => { b.addState(sid); b.addState(sid); });
      applyRows.push({kind, state: sid, before, after: snapshot(b), draws, log});
    }
  } finally { w.Math.random = oldRandom; w.Yanfly.Util.displayError = oldError; }
  if (errors.length) throw new Error('native TP errors: ' + JSON.stringify(errors));
  return {rows, applyRows};
}));
// 护盾一族（rules2）：React 时 HP 伤害>0 就播动画、移除自身，攻击元素不含本盾元素时伤害清零；Remove 写 _bubbleWrapCooldown（冻结源无读者）。
// 单块：customEffectEval 直调；连用：两个盾同时挂，走真实 onReactStateEffects 循环（KRZ 热缓存，前一个清零后后一个不再触发）；
// 实战：真实 Game_Action.apply 打两下（第一下被挡、第二下盾已去）；dirty＝出手前 need_refresh（addState 后 krz 总标 dirty，
// 破盾时 removeState 的 refresh 因而重建热列表，第二下不再挡）。
const SHIELDS = [[105, 8], [112, 4], [612, 5], [614, 10], [641, 4], [647, 9], [1039, 8]];
cases.push(makeCase('query.shield_blocks', {states: SHIELDS.map(s => s[0])}, () => {
  const {a, e} = battle(2), action = new w.Game_Action(a); action.setSkill(1);
  const item = action.item(), originalDamage = Object.assign({}, item.damage), originalMultiple = item.multipleElements;
  const errors = [], oldError = w.Yanfly.Util.displayError, oldAnim = e.startAnimation, oldRandom = w.Math.random;
  w.Yanfly.Util.displayError = (error, code, message) => errors.push({error: String(error), message});
  let anims = [];
  e.startAnimation = function (id) { anims.push(id); };
  const prep = sids => { e.clearStates(); e.clearResult(); delete e._bubbleWrapCooldown;
    for (const sid of sids) e.addState(sid); e.clearResult(); e.typestates('reactState'); anims = []; };
  const after = sids => ({states: sids.filter(s => e.isStateAffected(s)), anims: anims.slice(),
    removedStates: Array.from(e.result().removedStates), cooldown: e._bubbleWrapCooldown === undefined ? null : e._bubbleWrapCooldown});
  const rows = [], pairs = [], applies = [];
  try {
    w.Math.random = () => 0.5;
    a.attackElements = () => [];
    item.multipleElements = [];
    for (const [sid, el] of SHIELDS) for (const elementId of [el, 1, 0]) for (const type of [0, 1, 2, 3, 4, 5, 6]) for (const value of [-5, 0, 7]) {
      item.damage.elementId = elementId; item.damage.type = type; prep([sid]);
      const got = action.customEffectEval(e, sid, 'reactState', e, value);
      rows.push({state: sid, element: el, elementId, type, before: value, elements: action.getItemElements(), after: got, ...after([sid])});
    }
    item.damage.type = 1;
    for (const pair of [[105, 612], [112, 647], [641, 112]]) for (const elementId of [1, 8, 5, 4, 9]) {
      item.damage.elementId = elementId; prep(pair);
      const got = action.onReactStateEffects(e, 7);
      pairs.push({pair, order: e.typestates('reactState').map(s => s.id), elementId, before: 7, after: got, ...after(pair)});
    }
    Object.assign(item.damage, originalDamage); item.multipleElements = originalMultiple; delete a.attackElements;
    for (const [sid] of SHIELDS) {
      prep([sid]); const hits = [];
      for (let i = 0; i < 2; i++) {
        e.clearResult(); anims = []; const hp = e.hp, dirty = !!e.need_refresh; action.apply(e);
        hits.push({dirty, hpLoss: hp - e.hp, hpDamage: e.result().hpDamage, elements: action.getItemElements(), ...after([sid])});
      }
      applies.push({state: sid, hits});
    }
  } finally {
    Object.assign(item.damage, originalDamage); item.multipleElements = originalMultiple; delete a.attackElements;
    e.startAnimation = oldAnim; w.Math.random = oldRandom; w.Yanfly.Util.displayError = oldError;
    e.clearStates(); e.clearResult(); delete e._bubbleWrapCooldown;
  }
  if (errors.length) throw new Error('native shield errors: ' + JSON.stringify(errors));
  return {rows, pairs, applies};
}));
// 自动复活一族（rules3）：Custom Deselect Effect。单块：customEffectEval 直调、按序给随机数，记用掉几个；
// 实战：真实 Game_Action.apply 打死持有者，看状态有没有活过死亡、deselect 还跑不跑（KRZ 热缓存），以及弹字、结果槽、变量。
// 切片可达 11 块＋同模板的全游戏可达 6 块（163、494、1255、1258、1733、2712）；1301 强制行动、1317 公共事件不算这一模板。
const REVIVES = [114, 252, 1099, 1164, 1178, 1191, 1270, 1683, 1725, 1837, 2560, 163, 494, 1255, 1258, 1733, 2712];
const REVIVE_VAR_STATES = [1683, 1733, 2560];
cases.push(makeCase('revive.blocks', {states: REVIVES}, () => {
  const {a, e} = battle(2), action = new w.Game_Action(a); action.setSkill(1);
  const errors = [], oldError = w.Yanfly.Util.displayError, oldRandom = w.Math.random, oldPopup = w.Game_Battler.prototype.startDamagePopup;
  w.Yanfly.Util.displayError = (error, code, message) => errors.push({error: String(error), message});
  let anims = [], draws = 0, script = [], popups = [];
  const oldAnim = w.Game_Battler.prototype.startAnimation;
  w.Game_Battler.prototype.startAnimation = function (id) { anims.push(id); };
  w.Game_Battler.prototype.startDamagePopup = function () { const r = this.result(); popups.push({hpAffected: r.hpAffected, hpDamage: r.hpDamage, mpDamage: r.mpDamage, tpDamage: r.tpDamage, added: Array.from(r.addedStates), removed: Array.from(r.removedStates)}); };
  const VARS = [965, 966, 967, 1597, 1683];
  const snap = (t, sid) => { const r = t.result(); return {hp: t.hp, mp: t.mp, tp: t.tp, dead: t.isDead(), states: t._states.slice().sort((x, y) => x - y), anims: anims.slice(), draws, popups: popups.slice(),
    vars: VARS.map(v => w.$gameVariables.value(v)), result: {hpAffected: r.hpAffected, hpDamage: r.hpDamage, mpDamage: r.mpDamage, tpDamage: r.tpDamage, added: Array.from(r.addedStates), removed: Array.from(r.removedStates)}}; };
  const reset = (t, sid, hp, varv) => { t._states.length = 0; for (const k in t._stateTurns) delete t._stateTurns[k]; t.clearResult(); t._hp = t.mhp; t._mp = 10; t._tp = 20; t.need_refresh = true; t.refresh(); if (sid) t.addState(sid); t.clearResult();
    t.typestates('deselectState'); for (const v of VARS) w.$gameVariables.setValue(v, varv); anims = []; draws = 0; popups = []; };
  const rows = [], applies = [];
  // draws 只数块里直接的 Math.random：addState 的 resetStateCounts 走 randomInt（血为 0 时 removeState 的 refresh 也会先加上死亡），另有对照
  const oldInt = w.Math.randomInt;
  w.Math.randomInt = n => { const d = draws; try { return oldInt.call(w.Math, n); } finally { draws = d; } };
  try {
    w.Math.random = () => { const v = draws < script.length ? script[draws] : 0.5; draws++; return v; };
    for (const sid of REVIVES) for (const hpMode of ['alive', 'zero', 'dead']) for (const seq of [[0.05, 0.05], [0.95, 0.05], [0.05, 0.95], [0.95, 0.95], [0.15, 0.15], [0.4, 0.4], [0.5, 0.5], [0.6, 0.6]]) for (const varv of REVIVE_VAR_STATES.includes(sid) ? [0, 1, 2] : [0]) {
      const who = 'enemy', t = e;
      reset(t, sid, 0, varv); script = seq;
      if (hpMode === 'zero') t._hp = 0;
      if (hpMode === 'dead') { t._hp = 0; t._states.push(1); }
      const mhp = t.mhp, mmp = t.mmp, got = action.customEffectEval(t, sid, 'deselectState', t, 0);
      rows.push({state: sid, who, hpMode, seq, varv, value: got, ...snap(t, sid), mhp, mmp});
      t._states = t._states.filter(s => s !== 1);
    }
    // 实战：打死持有者（真实 apply），随机数在 deselect 前固定 0.5，deselect 时换成给定值
    const oldSel = w.Game_Action.prototype.onDeselectStateEffects;
    let at = 0.5;
    w.Game_Action.prototype.onDeselectStateEffects = function (...args) { const save = w.Math.random; draws = 0; w.Math.random = () => { draws++; return at; };
      try { return oldSel.apply(this, args); } finally { w.Math.random = save; } };
    for (const sid of REVIVES) for (const who of ['enemy', 'actor']) for (const r of [0.05, 0.95]) for (const dirtyWarm of [true, false]) {
      const t = who === 'enemy' ? e : a, u = who === 'enemy' ? a : e; const act = new w.Game_Action(u); act.setSkill(1);
      reset(t, sid, 0, 2); t._hp = 1; at = r; w.Math.random = () => 0.5;
      if (!dirtyWarm) { t.need_refresh = true; t.refresh(); t.typestates('deselectState'); }
      const dirty = !!t.need_refresh, mhp = t.mhp, mmp = t.mmp; t.clearResult(); act.apply(t);
      applies.push({state: sid, who, r, dirtyWarm, dirtyBefore: dirty, ...snap(t, sid), mhp, mmp});
      t._states = t._states.filter(s => s !== 1);
    }
    w.Game_Action.prototype.onDeselectStateEffects = oldSel;
  } finally {
    w.Math.randomInt = oldInt; w.Math.random = oldRandom; w.Yanfly.Util.displayError = oldError; w.Game_Battler.prototype.startAnimation = oldAnim; w.Game_Battler.prototype.startDamagePopup = oldPopup;
    a._states.length = 0; e._states.length = 0; a.clearResult(); e.clearResult();
  }
  if (errors.length) throw new Error('native revive errors: ' + JSON.stringify(errors));
  return {rows, applies};
}));
// 伤害 react／confirm 一族（rules4）：切片可达 15 块。单块：customEffectEval 直调，按序给随机数；实战：真实 apply 打一下。
// confirm／establish 的持有者是行动者，react／respond 的持有者是目标（YEP onPreDamage／onReact／onRespond／onPostDamage）。
const DAMAGE_BLOCKS = [[1060, 'react'], [1061, 'react'], [1299, 'establish'], [1302, 'react'], [1405, 'establish'], [1450, 'establish'], [1580, 'respond'], [1642, 'confirm'],
  [1666, 'confirm'], [1731, 'confirm'], [1828, 'react'], [2554, 'respond'], [2559, 'confirm'], [2562, 'react'], [2575, 'confirm']];
// EXTRA：每行再乘一层的附加条件（rules8 的新块要变 v206／暴击率／本击是否暴击）；老块传 [{}]，行数与内容不变。
function effectMeasure(DAMAGE_BLOCKS, EXTRA) {
  const {a, e} = battle(2), action = new w.Game_Action(a); action.setSkill(1);
  const item = action.item(), originalDamage = Object.assign({}, item.damage), originalHit = item.hitType;
  const errors = [], oldError = w.Yanfly.Util.displayError, oldRandom = w.Math.random, oldPopup = w.Game_Battler.prototype.startDamagePopup, oldInt = w.Math.randomInt;
  const oldCollapse = w.Game_Battler.prototype.performCollapse;
  w.Yanfly.Util.displayError = (error, code, message) => errors.push(String(error).slice(0, 60));
  let draws = 0, script = [], popups = [], collapses = 0;
  w.Math.randomInt = n => { const d = draws; try { return oldInt.call(w.Math, n); } finally { draws = d; } };
  w.Game_Battler.prototype.startDamagePopup = function () { const r = this.result(); popups.push({who: this === a ? 'a' : 'e', hpAffected: r.hpAffected, hpDamage: r.hpDamage, mpDamage: r.mpDamage, tpDamage: r.tpDamage, added: Array.from(r.addedStates), removed: Array.from(r.removedStates)}); };
  w.Game_Enemy.prototype.performCollapse = w.Game_Actor.prototype.performCollapse = function () { collapses++; };
  const VARS = [1174];
  const hard = (t, hp, mp, shield, xmx) => { t._states.length = 0; for (const k in t._stateTurns) delete t._stateTurns[k]; t.clearResult(); t._hp = 1; t.need_refresh = true; t.refresh();
    t._hp = hp === 'full' ? t.mhp : hp; t._mp = Math.min(mp, t.mmp); t._tp = 20; t._Shield = shield; if (xmx === undefined) delete t._xmx; else t._xmx = xmx; };
  const side = t => { const r = t.result(); return {hp: t.hp, mp: t.mp, tp: t.tp, dead: t.isDead(), shield: t._Shield, xmx: t._xmx === undefined ? null : t._xmx, states: t._states.slice().sort((x, y) => x - y),
    result: {hpAffected: r.hpAffected, hpDamage: r.hpDamage, mpDamage: r.mpDamage, tpDamage: r.tpDamage, added: Array.from(r.addedStates), removed: Array.from(r.removedStates)}}; };
  const rows = [], applies = [], actionStart = [];
  const TYPE = {react: 'target', respond: 'target', confirm: 'user', establish: 'user'};
  try {
    w.Math.random = () => { const v = draws < script.length ? script[draws] : 0.5; draws++; return v; };
    for (const [sid, phase] of DAMAGE_BLOCKS) for (const [dmgType, hitType] of [[1, 1], [1, 2], [1, 0], [2, 1], [3, 2], [0, 0]]) for (const value of [-5, 0, 7, 1000])
      for (const x of EXTRA) for (const [hp, mp, shield, xmx, v1174, seq] of [['full', 50, 0, undefined, 0, [0.5, 0.5, 0.5]], [100, 50, 20, 6, 2, [0.1, 0.9, 0.5]], [0, 0, 5000, 7, 12, [0.9, 0.1, 0.9]], [3, 1, 0, 4, 1, [0, 0.99, 0.25]]]) {
        const holder = TYPE[phase] === 'target' ? e : a;
        item.damage.type = dmgType; item.hitType = hitType;
        hard(a, 'full', 50, 0, undefined); hard(e, hp, mp, shield, xmx);
        if (holder === a) { a._hp = hp === 'full' ? a.mhp : Math.max(1, hp); }
        e._hp = hp === 'full' ? e.mhp : hp;
        const keep = e._hp; e._hp = Math.max(1, keep); holder.addState(sid); holder.clearResult(); e.clearResult(); a.clearResult();
        e._hp = keep; if (keep === 0) e._states.push(1);
        w.$gameVariables.setValue(1174, v1174);
        if (x.v206 !== undefined) w.$gameVariables.setValue(206, x.v206);
        if (x.cri !== undefined) Object.defineProperty(a, 'cri', {get: () => x.cri, configurable: true});
        if (x.crit !== undefined) e.result().critical = x.crit;
        script = seq; draws = 0; popups = []; collapses = 0; errors.length = 0;
        const before = {ahp: a.hp, amp: a.mp, amhp: a.mhp, ammp: a.mmp, aatk: a.atk, amat: a.mat, ashield: a._Shield, ehp: e.hp, emp: e.mp, emhp: e.mhp, emmp: e.mmp, eatk: e.atk, emat: e.mat, eshield: e._Shield};
        const got = action.customEffectEval(e, sid, phase + 'State', holder, value);
        rows.push({...(Object.keys(x).length ? {x} : {}), state: sid, phase, dmgType, hitType, value, hpIn: hp, mpIn: mp, shieldIn: shield, xmxIn: xmx === undefined ? null : xmx, v1174, seq, before, got, draws, popups: popups.slice(), collapses, sourceErrors: errors.slice(),
          a: side(a), e: side(e), vars: VARS.map(v => w.$gameVariables.value(v))});
      }
    // 同一族里另两个阶段：1450 行动开始写变量（Battler 版 target＝持有者）、1060 获得时累加 _Shield
    a._paramPlus[1] = 450000; a.need_refresh = true; a.refresh();
    w.$gameVariables.setValue(1174, 9); a.customEffectEval(1450, 'actionStartState');
    actionStart.push({mmp: a.mmp, v: w.$gameVariables.value(1174)});
    a._paramPlus[1] = 0; a.need_refresh = true; a.refresh();
    Object.assign(item.damage, originalDamage); item.hitType = originalHit;
    w.Math.random = () => 0.5;
    for (const [sid, phase] of DAMAGE_BLOCKS) for (const shield of [0, 5000]) for (const low of [false, true]) {
      const holder = TYPE[phase] === 'target' ? e : a;
      hard(a, 'full', 50, 0, undefined); hard(e, low ? 1 : 'full', 50, shield, undefined);
      holder.addState(sid); holder.clearResult(); e.clearResult(); a.clearResult(); holder.need_refresh = true; holder.refresh(); holder.typestates(phase + 'State');
      w.$gameVariables.setValue(1174, 2); popups = []; collapses = 0; errors.length = 0;
      const act = new w.Game_Action(a); act.setSkill(1);
      const before = {ahp: a.hp, amhp: a.mhp, ehp: e.hp, emhp: e.mhp, eshield: e._Shield};
      act.apply(e);
      applies.push({state: sid, phase, shield, low, before, popups: popups.slice(), collapses, sourceErrors: errors.slice(), a: side(a), e: side(e), vars: VARS.map(v => w.$gameVariables.value(v))});
    }
  } finally {
    Object.assign(item.damage, originalDamage); item.hitType = originalHit;
    w.Math.random = oldRandom; w.Math.randomInt = oldInt; w.Yanfly.Util.displayError = oldError; w.Game_Battler.prototype.startDamagePopup = oldPopup;
    delete w.Game_Enemy.prototype.performCollapse; delete w.Game_Actor.prototype.performCollapse;
    a._states.length = 0; e._states.length = 0; a.clearResult(); e.clearResult(); delete a._Shield; delete e._Shield;
    w.$gameVariables.setValue(1174, 0); w.$gameVariables.setValue(206, 0); delete a.cri;
  }
  return {rows, applies, actionStart};
}
cases.push(makeCase('effect.blocks', {blocks: DAMAGE_BLOCKS}, () => effectMeasure(DAMAGE_BLOCKS, [{}])));
// rules8：全游戏可达的伤害 react／confirm 块（切片外的套装、技能、防具备注推状态）。1749 的 user.criticalRate() 原版没有这个方法，量出来就是 TypeError。
const DAMAGE2_BLOCKS = [[38, 'confirm'], [50, 'confirm'], [97, 'confirm'], [250, 'react'], [381, 'react'], [720, 'react'], [908, 'react'], [1112, 'react'],
  [1257, 'confirm'], [1394, 'react'], [1407, 'establish'], [1538, 'react'], [1661, 'confirm'], [1749, 'confirm']];
const EXTRA2 = [{v206: 0, cri: 0.05, crit: false}, {v206: 50, cri: 0.4, crit: true}, {v206: 3, cri: 1, crit: true}];
cases.push(makeCase('effect2.blocks', {blocks: DAMAGE2_BLOCKS, extra: EXTRA2}, () => effectMeasure(DAMAGE2_BLOCKS, EXTRA2)));
// 其它／回合行动钩子两族（rules5）：直调 customEffectEval，看不抛错、改了什么。队友遍历、武器、字段、计数器都在这里。
cases.push(makeCase('hook.blocks', {}, () => {
  const {a, b, e} = battle(2), oldError = w.Yanfly.Util.displayError, oldPopup = w.Game_Battler.prototype.startDamagePopup, oldAnim = w.Game_Battler.prototype.startAnimation;
  const errors = []; let popups = [], anims = [];
  w.Yanfly.Util.displayError = (error) => errors.push(String(error).slice(0, 70));
  const name = t => t === a ? 'a' : t === b ? 'b' : t === e ? 'e' : '?';
  w.Game_Battler.prototype.startDamagePopup = function () { const r = this.result(); popups.push({who: name(this), hpAffected: r.hpAffected, hpDamage: r.hpDamage, mpDamage: r.mpDamage, tpDamage: r.tpDamage, added: Array.from(r.addedStates), removed: Array.from(r.removedStates)}); };
  w.Game_Battler.prototype.startAnimation = function (id) { anims.push([name(this), id]); };
  const oldCollapseE = w.Game_Enemy.prototype.performCollapse, oldCollapseA = w.Game_Actor.prototype.performCollapse;
  let collapses = [];
  w.Game_Enemy.prototype.performCollapse = w.Game_Actor.prototype.performCollapse = function () { collapses.push(name(this)); };
  const statesBefore = w.$dataStates.length;  // 用完摘掉，后面用例新建的测试状态号不能变
  const RES_RATE = fakeTrait(13, 1, 0, '测试·死亡率0'), RES_SET = fakeTrait(14, 1, 1, '测试·死亡抵抗');
  const units = [a, b, e];
  const reset = () => { for (const t of units) { t._states.length = 0; for (const k in t._stateTurns) delete t._stateTurns[k]; t.clearResult(); t._hp = 1000; t._mp = 10; t._tp = 20; t.need_refresh = true; t.refresh(); t._hp = 1000; }
    popups = []; anims = []; collapses = []; errors.length = 0; for (const t of units) { delete t._isMarked; delete t._baseDef; delete t._baseMdef; } };
  const snap = () => { const o = {sourceErrors: errors.slice(), popups: popups.slice(), anims: anims.slice(), collapses: collapses.slice()};
    for (const t of units) { const r = t.result(); o[name(t)] = {hp: t.hp, mp: t.mp, tp: t.tp, dead: t.isDead(), mhp: t.mhp, states: t._states.slice().sort((x, y) => x - y), marked: t._isMarked === undefined ? null : t._isMarked,
      added: Array.from(r.addedStates), removed: Array.from(r.removedStates), hpAffected: r.hpAffected, hpDamage: r.hpDamage, def: t.def}; }
    return o; };
  const out = {};
  const action = (user, skillId) => { const act = new w.Game_Action(user); act.setSkill(skillId); return act; };
  const place = (t, sid) => { t._states.push(sid); t.need_refresh = true; t.refresh(); t.clearResult(); };
  const hadWeapons = a.weapons;
  try {
    // 83 命之诅咒 respond：目标血为 0 才生效；行动者死亡率、抵抗
    out.s83 = [];
    for (const [tHp, extra] of [[1000, []], [0, []], [0, [RES_RATE]], [0, [RES_SET]]]) {
      reset(); place(e, 83); for (const x of extra) place(a, x); e._hp = tHp;
      const got = action(a, 1).customEffectEval(e, 83, 'respondState', e, 7);
      out.s83.push({tHp, extra: extra.length ? (extra[0] === RES_RATE ? 'rate' : 'resist') : '', got, ...snap()});
    }
    // 1067 标记字段；1068 记防御、恢复防御（def 只有 getter）；Battler 版 target＝持有者
    out.s1067 = []; reset(); place(e, 1067); e.customEffectEval(1067, 'addState'); out.s1067.push(snap()); e.customEffectEval(1067, 'removeState'); out.s1067.push(snap());
    out.s1068 = []; reset(); place(e, 1068); const def0 = e.def; e.customEffectEval(1068, 'addState'); out.s1068.push({def0, base: e._baseDef, ...snap()}); e.customEffectEval(1068, 'removeState'); out.s1068.push({def0, ...snap()});
    // 1072 挨打反击：this.isDamageAffected 不存在
    reset(); place(e, 1072); out.s1072 = {got: action(a, 1).customEffectEval(e, 1072, 'reactState', e, 7), ...snap()};
    // 1452 respond：user 是行动者，移的是行动者队友的 1451
    out.s1452 = [];
    for (const tHp of [1000, 0]) { reset(); place(e, 1452); place(a, 1451); place(b, 1451); e._hp = tHp;
      const got = action(a, 1).customEffectEval(e, 1452, 'respondState', e, 7); out.s1452.push({tHp, got, ...snap()}); }
    // 1711／1716 turn_start：else if 写法，后面的分支到不了；alone＝队里其他人都倒下
    out.turnStart = [];
    const others = h => h.friendsUnit().members().filter(m => m !== h);
    const fall = h => { for (const m of others(h)) { m._hp = 0; m._states.length = 0; m._states.push(1); } };
    const rise = h => { for (const m of others(h)) { m._states.length = 0; m._hp = 1000; } };
    for (const sid of [1711, 1716]) for (const holder of ['a', 'e']) for (const alone of [false, true]) for (const holderDead of [false, true]) {
      reset(); const h = holder === 'a' ? a : e; place(h, sid); if (alone) fall(h);
      for (const pre of [1713, 1718]) place(h, pre);
      if (holderDead) { h._hp = 0; h._states.push(1); }
      const alive = h.friendsUnit().aliveMembers().length;
      h.customEffectEval(sid, 'turnStartState');
      out.turnStart.push({sid, holder, alone, holderDead, alive, ...snap()});
      h._states.length = 0; rise(h);
    }
    // 1306 turn_end：每个活队友扣 ceil(hp*0.13)；学过 7305／7326 才加状态。敌人没有 hasSkill
    out.s1306 = [];
    for (const [holder, learned, alone, hp] of [['a', [], false, 1000], ['a', [7305], false, 1000], ['a', [7326], false, 77], ['a', [7305, 7326], true, 1000], ['e', [], false, 1000]]) {
      reset(); const h = holder === 'a' ? a : e; place(h, 1306); h._hp = hp; if (alone) fall(h);
      const alive = h.friendsUnit().aliveMembers().length;
      const keep = a._skills.slice(); for (const s of learned) a._skills.push(s); a.need_refresh = true; a.refresh();
      h.customEffectEval(1306, 'turnEndState');
      out.s1306.push({holder, learned, alone, hp, alive, ...snap()});
      rise(h);
      a._skills.length = 0; for (const s of keep) a._skills.push(s); a.need_refresh = true;
    }
    // 2544／2545 confirm：武器类型与普攻（skill 1 是攻击）
    out.weapon = [];
    for (const sid of [2544, 2545]) for (const [who, wt, skill] of [['a', 2, 1], ['a', 11, 1], ['a', 2, 5], ['a', 0, 1], ['e', 2, 1]]) {
      reset(); const u = who === 'a' ? a : e, t = who === 'a' ? e : a;
      a.weapons = () => wt ? [{wtypeId: wt}] : [];
      const act = action(u, skill); out.weapon.push({sid, who, wt, skill, isAttack: act.isAttack(), got7: act.customEffectEval(t, sid, 'confirmState', u, 7), got99: act.customEffectEval(t, sid, 'confirmState', u, 99), sourceErrors: errors.slice()});
    }
    delete a.weapons;
    // 2574 apply：把用户的计数清零，再给 108 号角色加等级；108 不在队也有对象
    out.s2574 = [];
    const a108 = w.$gameActors.actor(108);
    for (const [c, c108] of [[5, 7], [undefined, undefined]]) { reset(); a._stateCounter = a._stateCounter || {}; a108._stateCounter = a108._stateCounter || {};
      delete a._stateCounter[2401]; delete a108._stateCounter[2401]; if (c !== undefined) a._stateCounter[2401] = c; if (c108 !== undefined) a108._stateCounter[2401] = c108;
      a.customEffectEval(2574, 'addState'); out.s2574.push({c, c108, level: a108.level, after: a._stateCounter[2401], after108: String(a108._stateCounter[2401]), sourceErrors: errors.slice()}); }
    // 5576／5577 的 Custom Damage Formula（YEP_DamageCore）：标记不标记时伤害式走哪条，a.atkRate 不存在
    out.customFormula = [];
    for (const skill of [5576, 5577]) for (const marked of [false, true]) { reset(); w.Math.__r = 0; if (marked) e._isMarked = true;
      const act = action(a, skill), oldRnd = w.Math.random; w.Math.random = () => 0.5; let v = null, err = null;
      try { v = act.makeDamageValue(e, false); } catch (x) { err = String(x).slice(0, 60); }
      w.Math.random = oldRnd; out.customFormula.push({skill, marked, v, thrown: err, atk: a.atk, def: e.def, formula: w.$dataSkills[skill].damage.formula.slice(0, 60), sourceErrors: errors.slice()}); }
    // 1301 真实流程：普通序列里目标不死（immortal），deselect 时 hp 0 未倒下；事件跑完强制行动 7303
    out.s1301flow = [];
    { reset(); const bm = w.BattleManager; for (const u of [a, b]) u._hp = 300; place(e, 1301); e._hp = 1;
      const phase = runAction(bm, a, 1, 0);
      const q = w.$gameTemp._forceActionQueue ? JSON.parse(JSON.stringify(w.$gameTemp._forceActionQueue.list)) : null;
      out.s1301flow.push({step: 'after_action', phase, queue: q, ...snap(), immortalNow: e.isImmortal ? e.isImmortal() : null});
      // 收尾：解除 immortal 后才判定倒下，再跑预约的强制行动
      e.removeImmortal(); out.s1301flow.push({step: 'after_immortal', ...snap()});
      for (const m of [a, b, e]) m.clearResult();
      const troop = w.$gameTroop, inter = troop._interpreter;
      if (w.$gameTemp.isCommonEventReserved && w.$gameTemp.isCommonEventReserved()) { const ce = w.$gameTemp.reservedCommonEvent(); inter.setup(ce.list); w.$gameTemp.clearCommonEvent(); }
      for (let i = 0; i < 40; i++) { inter.update(); if (bm._phase === 'action' || bm._actionForcedBattler) break; }
      out.s1301flow.push({step: 'after_event', forced: bm._actionForcedBattler ? name(bm._actionForcedBattler) : null, forcedSkill: (bm._actionForcedBattler && bm._actionForcedBattler.currentAction()) ? bm._actionForcedBattler.currentAction().item().id : null, ...snap()}); }
    // 1301 deselect：实战打死持有者，看强制行动 7303 跑不跑（走 BattleManager 流程）
    out.s1301 = [];
    for (const low of [false, true]) { reset(); place(e, 1301); if (low) e._hp = 1; const bm = w.BattleManager; const before = e.hp;
      const act = action(a, 1); act.apply(e); const q = (bm._forcedActionQueue || bm._actionForcedBattler ? 1 : 0);
      out.s1301.push({low, before, queuedAny: q, ...snap()}); }
  } finally {
    delete a.weapons; w.Yanfly.Util.displayError = oldError; w.Game_Battler.prototype.startDamagePopup = oldPopup; w.Game_Battler.prototype.startAnimation = oldAnim;
    w.$dataStates.length = statesBefore;
    w.Game_Enemy.prototype.performCollapse = oldCollapseE; w.Game_Actor.prototype.performCollapse = oldCollapseA;
    for (const t of units) { t._states.length = 0; t.clearResult(); }
  }
  return out;
}));
// 切片可达剩余几族（rules6）：换装、必爆、公共事件、再生、改属性。预期内的原版报错记 sourceErrors。
cases.push(makeCase('rest.blocks', {}, () => {
  const {a, b, e} = battle(2), oldError = w.Yanfly.Util.displayError, oldPopup = w.Game_Battler.prototype.startDamagePopup, oldAnim = w.Game_Battler.prototype.startAnimation;
  const sourceErrors = []; let popups = [], anims = [], collapses = [];
  const statesBefore = w.$dataStates.length;
  w.Yanfly.Util.displayError = error => sourceErrors.push(String(error).slice(0, 70));
  const name = t => t === a ? 'a' : t === b ? 'b' : t === e ? 'e' : '?';
  w.Game_Battler.prototype.startDamagePopup = function () { const r = this.result(); popups.push({who: name(this), hpAffected: r.hpAffected, hpDamage: r.hpDamage, mpDamage: r.mpDamage, tpDamage: r.tpDamage}); };
  w.Game_Battler.prototype.startAnimation = function (id) { anims.push([name(this), id]); };
  const oldCollapseE = w.Game_Enemy.prototype.performCollapse, oldCollapseA = w.Game_Actor.prototype.performCollapse;
  w.Game_Enemy.prototype.performCollapse = w.Game_Actor.prototype.performCollapse = function () { collapses.push(name(this)); };
  const units = [a, b, e];
  const reset = () => { for (const t of units) { t._states.length = 0; for (const k in t._stateTurns) delete t._stateTurns[k]; t.clearResult(); t._hp = 1000; t._mp = 50; t._tp = 30; t.need_refresh = true; t.refresh(); t._hp = 1000; delete t._stateOrigin; }
    popups = []; anims = []; collapses = []; sourceErrors.length = 0; w.$gameTemp.clearCommonEvent(); w.$gameSystem._forceCritical = false; w.$gameSystem._forceNoCritical = false; };
  const place = (t, sid) => { t._states.push(sid); t.need_refresh = true; t.refresh(); t.clearResult(); };
  const res = t => ({hp: t.hp, mp: t.mp, tp: t.tp, dead: t.isDead(), states: t._states.slice().sort((x, y) => x - y)});
  const snap = () => ({sourceErrors: sourceErrors.slice(), popups: popups.slice(), anims: anims.slice(), collapses: collapses.slice(), reserved: w.$gameTemp._commonEventId || 0, a: res(a), b: res(b), e: res(e)});
  const action = (user, skillId) => { const act = new w.Game_Action(user); act.setSkill(skillId); return act; };
  const out = {};
  const oldRandom = w.Math.random;
  try {
    w.Math.random = () => 0.5;
    // 换装：apply／remove 的字段；同时两个；敌人；没 apply 就 remove
    out.costume = [];
    const look = () => ({battlerName: a.battlerName(), raw: a._battlerName, prev: a._prevBattlerName === undefined ? null : a._prevBattlerName, priority: a._priorityBattlerName === undefined ? null : a._priorityBattlerName, errors: sourceErrors.slice()});
    const base = a._battlerName;
    reset(); a._prevBattlerName = undefined; a.customEffectEval(66, 'addState'); out.costume.push({step: 'apply66', ...look()});
    a.customEffectEval(226, 'addState'); out.costume.push({step: 'apply226', ...look()});
    a.customEffectEval(226, 'removeState'); out.costume.push({step: 'remove226', ...look()});
    a.customEffectEval(66, 'removeState'); out.costume.push({step: 'remove66', ...look()});
    a.setBattlerImage(base); a._prevBattlerName = undefined;
    reset(); a.customEffectEval(66, 'removeState'); out.costume.push({step: 'remove_only', ...look()});
    a.setBattlerImage(base); a._prevBattlerName = undefined;
    reset(); e.customEffectEval(66, 'addState'); out.costume.push({step: 'enemy_apply', enemy: e.battlerName(), errors: sourceErrors.slice()});
    reset(); e.customEffectEval(66, 'removeState'); out.costume.push({step: 'enemy_remove', enemy: e.battlerName(), errors: sourceErrors.slice()});
    out.costumeBase = base;
    // 必爆：真实 apply，状态在目标身上
    out.crit = [];
    for (const [sid, skill, extra] of [[541, 1, 0], [755, 1, 0], [541, 5, 0], [541, 1, 755]]) { reset(); place(e, sid); if (extra) place(e, extra); e.typestates('selectState'); e.typestates('deselectState');
      const act = action(a, skill), itemCrit = !!act.item().damage.critical; const flags = []; const oldCri = w.Game_Action.prototype.itemCri;
      w.Game_Action.prototype.itemCri = function (t) { const v = oldCri.call(this, t); flags.push([w.$gameSystem._forceCritical, v]); return v; };
      act.apply(e); w.Game_Action.prototype.itemCri = oldCri;
      out.crit.push({sid, skill, extra, itemCrit, critical: e.result().critical, flags, forceAfter: w.$gameSystem._forceCritical, noAfter: w.$gameSystem._forceNoCritical, prev: act._prevForcedCriticalHit === undefined ? 'undefined' : act._prevForcedCriticalHit, errors: sourceErrors.slice()}); }
    // 公共事件预约
    out.reserve = [];
    const run = (sid, phase, holder, value, setup) => { reset(); place(holder, sid); if (setup) setup(); let got = null;
      if (['turnStartState', 'removeState', 'victory'].includes(phase)) holder.customEffectEval(sid, phase); else got = action(a, 1).customEffectEval(e, sid, phase, holder, value);
      return {sid, phase, value, got, v901: w.$gameVariables.value(901), ...snap()}; };
    const VAR = (id, x) => () => w.$gameVariables.setValue(id, x);
    out.reserve.push(run(1306, 'turnStartState', a, 0, VAR(901, 7)));
    out.reserve.push(run(1306, 'turnStartState', e, 0, VAR(901, 7)));
    out.troopSize = w.$gameTroop.members().length; out.mmpA = a.mmp;
    out.reserve.push(run(1307, 'removeState', a, 0));
    out.reserve.push({deadTroop: true, ...run(1307, 'removeState', a, 0, () => { for (const m of w.$gameTroop.members()) { m._hp = 0; m._states.length = 0; m._states.push(1); } })});
    for (const m of w.$gameTroop.members()) { m._states.length = 0; m._hp = 1000; }
    out.reserve.push(run(1317, 'deselectState', e, 0));
    out.reserve.push(run(1317, 'deselectState', e, 0, () => { e._hp = 0; }));
    out.reserve.push(run(1318, 'turnStartState', a, 0, VAR(1163, 0)));
    out.reserve.push(run(1318, 'turnStartState', a, 0, VAR(1163, 1)));
    out.reserve.push(run(1318, 'turnStartState', a, 0, VAR(1163, 2)));
    w.$gameVariables.setValue(1163, 0);
    for (const sid of [2007, 2009, 2011, 2026]) for (const value of [-1, 0, 7]) out.reserve.push(run(sid, 'reactState', e, value));
    out.reserve.push(run(2568, 'confirmState', a, 5, VAR(1584, 9998)));
    out.reserve.push(run(2568, 'confirmState', a, 5, VAR(1584, 9999)));
    w.$gameVariables.setValue(1584, 0);
    // 再生：来源是别人；来源倒下；来源是自己；有 207；打死
    out.regen = [];
    const setOrigin = (t, sid, src) => { t._stateOrigin = t._stateOrigin || {}; t._stateOrigin[sid] = src === 'self' ? undefined : (src.isActor() ? [0, src.actorId()] : [1, src.index()]); };
    for (const sid of [260, 1006]) for (const [mode, hp207, ehp] of [['other', false, 1000000], ['other', true, 1000000], ['self', false, 1000000], ['deadOrigin', false, 1000000], ['other', false, 1]]) {
      reset(); e._hp = ehp; e._states.push(sid); if (hp207) e._states.push(207); e.need_refresh = true; e.refresh(); e._hp = ehp;
      setOrigin(e, sid, mode === 'self' ? 'self' : a); if (mode === 'deadOrigin') { a._hp = 0; a._states.push(1); }
      const before = {amat: a.mat, emat: e.mat, ahp: a.hp, ehp: e.hp, el: e.elementRate(6), amhp: a.mhp};
      e.customEffectEval(sid, 'regenerateState');
      out.regen.push({sid, mode, hp207, ehpIn: ehp, before, ...snap()}); a._states.length = 0; a._hp = 1000;
    }
    // 改属性
    reset(); w.$gameVariables.setValue(980, 3); const g0 = w.$gameParty.gold(); e.customEffectEval(1423, 'victory'); out.gold = {g0, after: w.$gameParty.gold(), errors: sourceErrors.slice()};
    w.$gameParty.gainGold(g0 - w.$gameParty.gold()); w.$gameVariables.setValue(980, 0);
    out.tp = []; for (const tp of [0, 30, 80, 100]) { reset(); a._tp = tp; a.customEffectEval(1840, 'addState'); out.tp.push({tp, after: a.tp, hpAffected: a.result().hpAffected, tpDamage: a.result().tpDamage, maxTp: a.maxTp()}); }
    out.params = []; for (const who of ['a', 'e']) { reset(); const t = who === 'a' ? a : e; w.$gameVariables.setValue(1204, 2); const p3 = t.param(3), p5 = t.param(5), raw3 = t._paramPlus[3];
      t.customEffectEval(2003, 'addState'); const mid = [t.param(3), t.param(5), t._paramPlus[3], t._paramPlus[5]]; t.customEffectEval(2003, 'removeState');
      out.params.push({who, p3, p5, raw3, mid, end: [t.param(3), t.param(5), t._paramPlus[3], t._paramPlus[5]], v: w.$gameVariables.value(1204), errors: sourceErrors.slice()}); }
    w.$gameVariables.setValue(1204, 0);
  } finally {
    w.Math.random = oldRandom; w.Yanfly.Util.displayError = oldError; w.Game_Battler.prototype.startDamagePopup = oldPopup; w.Game_Battler.prototype.startAnimation = oldAnim;
    w.Game_Enemy.prototype.performCollapse = oldCollapseE; w.Game_Actor.prototype.performCollapse = oldCollapseA; w.$dataStates.length = statesBefore;
    for (const t of units) { t._states.length = 0; t.clearResult(); delete t._stateOrigin; }
    w.$gameTemp.clearCommonEvent(); w.$gameSystem._forceCritical = false; w.$gameSystem._forceNoCritical = false;
  }
  return JSON.parse(JSON.stringify(out, (k, v) => k === 'errors' ? (v.length ? v : undefined) : v).replace(/"errors":/g, '"sourceErrors":'));
}));
// rules8 第二批：全游戏可达的 regenerate、回合／行动钩子、改属性／变量、公共事件预约、其它。每块直调 customEffectEval，记结局（含字段、计数器、变量、预约）。
cases.push(makeCase('rest2.blocks', {}, () => {
  const {a, b, e} = battle(2), oldError = w.Yanfly.Util.displayError, oldPopup = w.Game_Battler.prototype.startDamagePopup, oldAnim = w.Game_Battler.prototype.startAnimation;
  const sourceErrors = []; let popups = [], anims = [], collapses = [];
  const statesBefore = w.$dataStates.length;
  w.Yanfly.Util.displayError = error => sourceErrors.push(String(error).slice(0, 70));
  const name = t => t === a ? 'a' : t === b ? 'b' : t === e ? 'e' : '?';
  w.Game_Battler.prototype.startDamagePopup = function () { const r = this.result(); popups.push({who: name(this), hpAffected: r.hpAffected, hpDamage: r.hpDamage, mpDamage: r.mpDamage, tpDamage: r.tpDamage}); };
  w.Game_Battler.prototype.startAnimation = function (id) { anims.push([name(this), id]); };
  const oldCollapseE = w.Game_Enemy.prototype.performCollapse, oldCollapseA = w.Game_Actor.prototype.performCollapse;
  w.Game_Enemy.prototype.performCollapse = w.Game_Actor.prototype.performCollapse = function () { collapses.push(name(this)); };
  const units = [a, b, e], VARS = [320, 1129, 1130, 1136, 1138, 1139, 1140, 1214];
  const reset = () => { for (const t of units) { t._states.length = 0; for (const k in t._stateTurns) delete t._stateTurns[k]; t.clearResult(); t._hp = 1000; t._mp = 50; t._tp = 30; t.need_refresh = true; t.refresh(); t._hp = 1000;
      delete t._stateOrigin; delete t._lastUsedSkill; delete t._reverenceMp; delete t._stackingPoison; t._stateCounter = {}; t._paramPlus = t._paramPlus.map((x, i) => i === 0 ? x : 0); t.need_refresh = true; t.refresh(); t._hp = 1000; }
    popups = []; anims = []; collapses = []; sourceErrors.length = 0; w.$gameTemp.clearCommonEvent(); for (const v of VARS) w.$gameVariables.setValue(v, 0); };
  const place = (t, sid) => { t._states.push(sid); t.need_refresh = true; t.refresh(); t.clearResult(); };
  const res = t => ({hp: t.hp, mp: t.mp, tp: t.tp, dead: t.isDead(), states: t._states.slice().sort((x, y) => x - y), counter: JSON.parse(JSON.stringify(t._stateCounter || {})),
    lastUsed: t._lastUsedSkill === undefined ? null : t._lastUsedSkill, rev: t._reverenceMp === undefined ? null : t._reverenceMp, plus: t._paramPlus.slice(), mmp: t.mmp, mhp: t.mhp, poison: t._stackingPoison === undefined ? null : t._stackingPoison});
  const snap = () => ({sourceErrors: sourceErrors.slice(), popups: popups.slice(), anims: anims.slice(), collapses: collapses.slice(), reserved: w.$gameTemp._commonEventId || 0,
    vars: VARS.map(v => w.$gameVariables.value(v)), a: res(a), b: res(b), e: res(e)});
  const oldRandom = w.Math.random;
  const out = {regen: [], hooks: []};
  try {
    w.Math.random = () => 0.5;
    const setOrigin = (t, sid, src) => { t._stateOrigin = t._stateOrigin || {}; t._stateOrigin[sid] = src === 'self' ? undefined : (src.isActor() ? [0, src.actorId()] : [1, src.index()]); };
    for (const sid of [224, 566, 577]) for (const [mode, hp207, ehp] of [['other', false, 1000000], ['other', true, 1000000], ['self', false, 1000000], ['deadOrigin', false, 1000000], ['other', false, 1]]) {
      reset(); e._hp = ehp; e._states.push(sid); if (hp207) e._states.push(207); e.need_refresh = true; e.refresh(); e._hp = ehp;
      setOrigin(e, sid, mode === 'self' ? 'self' : a); if (mode === 'deadOrigin') { a._hp = 0; a._states.push(1); }
      const before = {amat: a.mat, emat: e.mat, ahp: a.hp, ehp: e.hp, el: e.elementRate(6), amhp: a.mhp};
      e.customEffectEval(sid, 'regenerateState');
      out.regen.push({sid, mode, hp207, ehpIn: ehp, before, ...snap()}); a._states.length = 0; a._hp = 1000;
    }
    // Battler 版（持有者＝a）与 Action 版（a 行动者、e 目标）各阶段
    const hook = (sid, phase, holder, setup, label) => { reset(); place(holder, sid); if (setup) setup(); sourceErrors.length = 0;
      const pre = {a: {mhp: a.mhp, mmp: a.mmp}, e: {mhp: e.mhp, mmp: e.mmp}};  // 块开始时的上限（状态特性会改上限，结尾读到的不是块用的）
      let got = null;
      if (['addState', 'removeState', 'leaveState', 'turnStartState', 'turnEndState', 'actionStartState', 'actionEndState', 'battle'].includes(phase)) holder.customEffectEval(sid, phase);
      else { const act = new w.Game_Action(a); act.setSkill(1); got = act.customEffectEval(e, sid, phase, holder, 7); }
      out.hooks.push({sid, phase, label: label || '', holder: name(holder), got, pre, ...snap()}); };
    const VAR = (id, x) => () => w.$gameVariables.setValue(id, x);
    const MULTI = fs => () => fs.forEach(f => f());
    for (const who of [a, e]) for (const phase of ['actionStartState', 'turnStartState', 'turnEndState']) { hook(49, phase, who, null); }
    hook(49, 'actionStartState', a, () => { a._lastUsedSkill = 5; }, 'prev');
    for (const who of [a, e]) { hook(102, 'actionStartState', who, null); hook(102, 'initiateState', who, () => { who._reverenceMp = 80; }, 'rev80'); hook(102, 'initiateState', who, () => { who._reverenceMp = 20; }, 'rev20'); hook(102, 'initiateState', who, null, 'norev'); }
    for (const who of [a, e]) { hook(1741, 'turnStartState', who, null); hook(1742, 'turnEndState', who, null); }
    hook(1748, 'confirmState', a, null); hook(1748, 'confirmState', a, () => { a.attackCount = 3; }, 'count3'); delete a.attackCount;
    hook(1315, 'deselectState', e, null);
    for (const who of [a, e]) { hook(1778, 'battle', who, null); }
    for (const sid of [1769, 1772, 1776]) for (const who of [a, e]) for (const [v1136, pre] of [[0, null], [2, null], [2, 123], [3, 0]]) {
      hook(sid, 'addState', who, MULTI([VAR(1136, v1136), () => { if (pre !== null) who._stateCounter[sid] = pre; }]), 'v1136=' + v1136 + ',pre=' + pre); }
    for (const sid of [1771, 2033]) for (const who of [a, e]) hook(sid, 'addState', who, null);
    for (const who of [a, e]) for (const v1214 of [0, 5, 37]) { hook(2018, 'addState', who, VAR(1214, v1214), 'v=' + v1214); hook(2018, 'removeState', who, VAR(1214, v1214), 'v=' + v1214); hook(2018, 'leaveState', who, VAR(1214, v1214), 'v=' + v1214); }
  } finally {
    w.Math.random = oldRandom; w.Yanfly.Util.displayError = oldError; w.Game_Battler.prototype.startDamagePopup = oldPopup; w.Game_Battler.prototype.startAnimation = oldAnim;
    w.Game_Enemy.prototype.performCollapse = oldCollapseE; w.Game_Actor.prototype.performCollapse = oldCollapseA; w.$dataStates.length = statesBefore;
    for (const t of units) { t._states.length = 0; t.clearResult(); delete t._stateOrigin; t._stateCounter = {}; t._paramPlus = t._paramPlus.map((x, i) => i === 0 ? x : 0); }
    w.$gameTemp.clearCommonEvent(); for (const v of VARS) w.$gameVariables.setValue(v, 0);
  }
  return JSON.parse(JSON.stringify(out, (k, v) => k === 'errors' ? (v.length ? v : undefined) : v));
}));
// rules8 毒奶 732（regenerate）：来源者装备的法宝等级、叠毒字段 _stackingPoison、变量 320 一起算伤害。来源者是敌人时 origin.equips 不存在（TypeError）。
cases.push(makeCase('poison.blocks', {state: 732, armor: 3590}, () => {
  const {a, e} = battle(2), oldError = w.Yanfly.Util.displayError, oldPopup = w.Game_Battler.prototype.startDamagePopup, oldAnim = w.Game_Battler.prototype.startAnimation;
  const errors = []; let popups = [], anims = [], collapses = 0;
  w.Yanfly.Util.displayError = error => errors.push(String(error).slice(0, 70));
  w.Game_Battler.prototype.startDamagePopup = function () { const r = this.result(); popups.push({who: this === a ? 'a' : 'e', hpAffected: r.hpAffected, hpDamage: r.hpDamage}); };
  w.Game_Battler.prototype.startAnimation = function (id) { anims.push([this === a ? 'a' : 'e', id]); };
  const oldCollapseE = w.Game_Enemy.prototype.performCollapse, oldCollapseA = w.Game_Actor.prototype.performCollapse;
  w.Game_Enemy.prototype.performCollapse = w.Game_Actor.prototype.performCollapse = function () { collapses++; };
  const rows = [];
  try {
    const before = w.$gameParty.equipItems().slice();
    w.$gameParty.gainItem(w.$dataArmors[3590], 1);
    const item = w.$gameParty.equipItems().find(x => before.indexOf(x) < 0);
    const o16 = w.$gameActors.actor(16), slot = o16.equipSlots().indexOf(item.etypeId);  // 毒心专属克莱德（16），只有他有这个装备槽
    if (slot < 0) throw new Error('actor 16 没有装备类型 ' + item.etypeId);
    const gi = new w.Game_Item(); gi.setObject(item);
    const setup = {actor_none: () => {}, actor_equipped: () => { o16.forceChangeEquip(slot, item); }, enemy_origin: () => {}};
    const levels = [['none', 0], ['lv_init', 0], ['lv_up', 1e6]];
    const reset = who => { for (const t of [a, e]) { t._states.length = 0; t.clearResult(); t._hp = 1; t.need_refresh = true; t.refresh(); t._hp = t.mhp; t._mp = 50; delete t._stackingPoison; }
      o16.forceChangeEquip(slot, null); popups = []; anims = []; collapses = 0; errors.length = 0; };
    for (const [mode, fn] of Object.entries(setup)) for (const [lname, exp] of levels) {
      if (mode === 'actor_none' && lname !== 'none') continue;
      if (mode !== 'actor_none' && lname === 'none') continue;
      for (const stacks of [undefined, 3]) for (const v320 of [0, 500]) for (const ehp of ['full', 'low']) {
        reset(mode); fn(); if (exp) gi.gainExp(exp);
        w.$gameVariables.setValue(320, v320);
        e._states.push(732); e.need_refresh = true; e.refresh(); e.clearResult(); e._hp = ehp === 'full' ? e.mhp : 1;
        if (stacks !== undefined) e._stackingPoison = stacks;
        const origin = mode === 'enemy_origin' ? e : o16;
        e._stateOrigin = {732: origin === e ? undefined : [0, 16]};
        if (mode === 'enemy_origin') { const e2 = w.$gameTroop.members()[1] || e; e._stateOrigin = {732: e2 === e ? undefined : [1, e2.index()]}; }
        const org = mode === 'enemy_origin' ? (e._stateOrigin[732] === undefined ? e : w.$gameTroop.members()[e._stateOrigin[732][1]]) : o16;
        const pre = {omat: org.mat, ommp: org.mmp, level: mode === 'actor_none' ? 0 : gi.level(), ehp: e.hp};
        e.customEffectEval(732, 'regenerateState');
        const r = e.result();
        rows.push({mode, level: lname, stacks: stacks === undefined ? null : stacks, v320, ehpIn: ehp, pre, ehp: e.hp, dead: e.isDead(), field: e._stackingPoison === undefined ? null : e._stackingPoison,
          hpDamage: r.hpDamage, popups: popups.slice(), anims: anims.slice(), collapses, sourceErrors: errors.slice()});
        w.$gameVariables.setValue(320, 0);
      }
    }
    o16.forceChangeEquip(slot, null);
  } finally {
    w.Yanfly.Util.displayError = oldError; w.Game_Battler.prototype.startDamagePopup = oldPopup; w.Game_Battler.prototype.startAnimation = oldAnim;
    w.Game_Enemy.prototype.performCollapse = oldCollapseE; w.Game_Actor.prototype.performCollapse = oldCollapseA;
    for (const t of [a, e]) { t._states.length = 0; t.clearResult(); delete t._stackingPoison; delete t._stateOrigin; }
    w.$gameVariables.setValue(320, 0);
  }
  return {rows};
}));
// Supplemental 2e boundaries are separately runnable without repeating native22.
cases.push(...require('./state_effects_tp_context_probe.cjs').measureCases(host));
// 反击放最后：跑完后参照引擎的 location 会变成 undefined（反击路径上有插件动它），之后的新局建不起来
cases.push(makeCase('action.counter', {troop: 2, user: 'a1', skill: 'physical clone of 1', target: 'e0'}, () => {
  const {bm, a, e} = battle(2);
  a.addState(T); e.addState(T); e.addState(CNT);
  for (const x of [a, e]) { x.need_refresh = true; x.refresh(); }
  // 深拷贝丢掉 YEP 读备注时挂的函数（YEP_SkillMasteryLevels 的 masteryFormula 等），照原技能补回引用，不然熟练度结算报错 → terminate
  const src = w.$dataSkills[1], clone = Object.assign(w.JsonEx.makeDeepCopy(src), {id: w.$dataSkills.length, hitType: 1});
  for (const k of Object.keys(src)) if (typeof src[k] === 'function') clone[k] = src[k];
  const id = clone.id; w.$dataSkills.push(clone);
  const log = capture(() => runAction(bm, a, id, 0));
  return {log};
}));
process.exit(finish(host, 'state_effects.json', {hostScope: '真实 BattleManager／Game_Action／Scene_Battle.start（dsPassiveSkill 包装），Math.random 0.5；测试状态的效果只记录不改值', cases}) ? 0 : 1);
