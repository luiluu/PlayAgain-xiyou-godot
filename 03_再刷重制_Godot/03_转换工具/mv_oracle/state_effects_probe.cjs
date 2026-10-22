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
