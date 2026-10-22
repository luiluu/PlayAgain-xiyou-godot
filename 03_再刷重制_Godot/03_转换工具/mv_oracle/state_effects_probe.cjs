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
// Supplemental 2e boundaries are separately runnable without repeating native22.
cases.push(...require('./state_effects_tp_context_probe.cjs').measureCases(host));
// 反击放最后：跑完后参照引擎的 location 会变成 undefined（反击路径上有插件动它），之后的新局建不起来
cases.push(makeCase('action.counter', {troop: 2, user: 'a1', skill: 'physical clone of 1', target: 'e0'}, () => {
  const {bm, a, e} = battle(2);
  a.addState(T); e.addState(T); e.addState(CNT);
  for (const x of [a, e]) { x.need_refresh = true; x.refresh(); }
  const id = w.$dataSkills.length; w.$dataSkills.push(Object.assign(w.JsonEx.makeDeepCopy(w.$dataSkills[1]), {id, hitType: 1}));
  const log = capture(() => runAction(bm, a, id, 0));
  return {log};
}));
process.exit(finish(host, 'state_effects.json', {hostScope: '真实 BattleManager／Game_Action／Scene_Battle.start（dsPassiveSkill 包装），Math.random 0.5；测试状态的效果只记录不改值', cases}) ? 0 : 1);
