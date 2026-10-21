'use strict';
// 导入角色平衡模块（js/codex/runtime/installImportedBalanceRuntime.js）：141～166 造成的伤害结算 ×outgoingRate（163＝0.001，其余 0.01），
// 向下取整、不保底 1；143／144／145／157／160 禁用（行动对目标无效）。真实 BattleManager 与 Game_Action，Math.random 固定 0.5。
// 每个用例在战斗者实例上挂最外层记录：executeHpDamage／executeMpDamage（经模块缩放前的原始值）、gainHp／gainMp／setHp／setMp、
// regenerateHp，记每次调用的嵌套深度、传入值、前后 HP／MP／护盾与结果弹字，供 Godot 逐次重放同一原始值对照缩放结果。
// 只在内存里跑：新局与 BattleManager.setup；不渲染、不写存档。产物 .sandbox/imported_balance.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const B = w.CodexImportedBalance;
if (!B || typeof B.outgoingRate !== 'function') throw new Error('导入平衡模块未安装');
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
const key = b => !b ? null : b.isActor() ? 'a' + b.actorId() : 'e' + b.index();
const BIG_HP = 1e12;
// 反射用的测试状态：复制中毒（4）的已解析字段（含 YEP 的 customEffectEval 表），特性只留 22／5（魔法反射率 mrf）＝1、自定义效果清空；
// 与 Godot 测试的假状态同形。
const MRF_STATE = w.$dataStates.length;
{ const st = w.JsonEx.makeDeepCopy(w.$dataStates[4]);
  Object.assign(st, {id: MRF_STATE, name: '测试·魔法反射', traits: [{code: 22, dataId: 5, value: 1}], note: '', meta: {}, autoRemovalTiming: 0, iconIndex: 0});
  for (const k of Object.keys(st.customEffectEval || {})) st.customEffectEval[k] = '';
  w.$dataStates.push(st); }
// REC／HRG 测试状态（同形复制中毒 4、自定义效果清空，只留给定特性）：DOT 与再生都含目标的恢复效果率 REC（krz regenerateHp、
// installImportedBalanceRuntime 的 full／other 两值都是 floor(mhp×hrg×rec)）。Godot 按 setup.fake 的特性建同形状态。
const FAKE = {};
for (const [name, traits] of [['rec2', [{code: 23, dataId: 2, value: 2}]], ['rec06', [{code: 23, dataId: 2, value: 0.6}]],
  ['rec08', [{code: 23, dataId: 2, value: 0.8}]], ['hrg-5', [{code: 22, dataId: 7, value: -0.05}]], ['hrg+3', [{code: 22, dataId: 7, value: 0.03}]],
  ['hrg+5', [{code: 22, dataId: 7, value: 0.05}]]]) {
  const st = w.JsonEx.makeDeepCopy(w.$dataStates[4]);
  FAKE[name] = w.$dataStates.length;
  Object.assign(st, {id: FAKE[name], name: '测试·' + name, traits, note: '', meta: {}, autoRemovalTiming: 0, iconIndex: 0});
  for (const k of Object.keys(st.customEffectEval || {})) st.customEffectEval[k] = '';
  w.$dataStates.push(st);
}

function battle(actorId, troop) {
  newGame();
  w.eval('$gameParty._actors=[];');
  w.$gameParty.addActor(actorId); w.$gameParty.addActor(1);
  for (const id of [actorId, 1]) {
    const a = w.$gameActors.actor(id); a.changeLevel(50, false); a._paramPlus[0] = BIG_HP; a.recoverAll();
  }
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(troop, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  w.CodexYunshang._acted = [];  // installNativeYunshangRuntime.prepareAction 需要（同 review_fix_probe）
  for (const e of w.$gameTroop.members()) e._paramPlus[0] = BIG_HP;
  // krz 能力值缓存：加值后要先 need_refresh＋refresh，回满才按新上限
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  bm._subject = w.$gameActors.actor(actorId);  // YEP 记状态来源用 BattleManager._subject（实战行动中即行动者）
  return {bm, a: w.$gameActors.actor(actorId), ally: w.$gameActors.actor(1), foes: w.$gameTroop.members()};
}
const snap = b => ({key: key(b), hp: b.hp, mp: b.mp, shield: Number(b._shield || 0)});
// 在指定对象上挂最外层记录（实例方法，位于模块包装之外，所见即缩放前原值）。
function record(fn, battlers) {
  const log = [], restore = [];
  let depth = 0;
  for (const b of battlers) {
    for (const m of ['gainHp', 'gainMp', 'setHp', 'setMp', 'regenerateHp']) {
      const own = Object.prototype.hasOwnProperty.call(b, m), old = b[m];
      b[m] = function (...args) {
        const row = {fn: m, target: key(this), depth, args: args.map(Number), before: snap(this)};
        log.push(row); depth++;
        try { return old.apply(this, args); } finally { depth--; row.after = snap(this); row.popup = {hp: this.result().hpDamage, mp: this.result().mpDamage}; }
      };
      restore.push(() => { if (own) b[m] = old; else delete b[m]; });
    }
  }
  for (const m of ['executeHpDamage', 'executeMpDamage']) {
    const old = w.Game_Action.prototype[m];
    w.Game_Action.prototype[m] = function (target, value) {
      const row = {fn: m, subject: key(this.subject()), target: key(target), depth, args: [Number(value)], before: snap(target)};
      log.push(row); depth++;
      try { return old.apply(this, arguments); } finally { depth--; row.after = snap(target); row.popup = {hp: target.result().hpDamage, mp: target.result().mpDamage}; }
    };
    restore.push(() => { w.Game_Action.prototype[m] = old; });
  }
  try { fn(); } finally { restore.reverse().forEach(f => f()); }
  return log;
}
// 真实 BattleManager.startAction → 序列各阶段，直到行动结束（同 sequence_probe）
function act(bm, user, skillId, targetIndex) {
  const action = new w.Game_Action(user); action.setSkill(skillId); action.setTarget(targetIndex);
  user._actions = [action]; bm._subject = user; bm._action = null;
  bm.startAction();
  for (let i = 0; i < 20000; i++) {
    const ph = bm._phase;
    if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
    else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
  }
}
// 测试用技能：复制技能 1 的已解析字段（吸血、冷却等插件表），只改伤害类型／公式／范围／命中类型与使用效果，浮动 0、不暴击；
// 追加进 $dataSkills（新编号）以便插件按 Game_Item 取到对象
const customIds = new Map();
const custom = (type, formula, scope, hitType, effects = []) => {
  const k = JSON.stringify([type, formula, scope, hitType, effects]);
  if (!customIds.has(k)) {
    const id = w.$dataSkills.length;
    w.$dataSkills.push(Object.assign(w.JsonEx.makeDeepCopy(w.$dataSkills[1]), {id, name: '测试', scope, hitType, effects,
      damage: {type, formula, elementId: 0, variance: 0, critical: false}}));
    customIds.set(k, id);
  }
  return w.$dataSkills[customIds.get(k)];
};
function applyItem(user, item, target) {
  const action = new w.Game_Action(user); action.setSkill(item.id);
  target.result().clear(); action.apply(target);
}
const cases = [];
const ACTORS = [141, 142, 163, 143, 1];
const SKILLS = {141: [9909, 9910], 142: [10098, 10099, 10100], 163: [9933], 143: [10116], 1: [1]};
const ALL = [...ACTORS, 144, 145, 146, 157, 160, 166, 140, 167];
cases.push(makeCase('module.rates', {actors: ALL, disabled: B.disabledActorIds, horns: B.disabledHornIds},
  () => ({rates: ALL.map(id => B.outgoingRate(id)), disabled: ALL.map(id => B.isDisabledActor(id)), imported: B.importedActorIds})));
for (const id of ACTORS) {
  for (const skill of [1, ...SKILLS[id]].filter((v, i, a) => a.indexOf(v) === i)) {
    cases.push(makeCase(`action.a${id}.s${skill}`, {actor: id, skill, troop: 2, target: 0}, () => {
      const {bm, a, ally, foes} = battle(id, 2); a.learnSkill(skill);
      const log = record(() => act(bm, a, skill, 0), [a, ally, ...foes]);
      return {log, after: [a, ally, ...foes].map(snap)};
    }));
  }
}
for (const id of [141, 163, 143, 1]) {
  const items = {
    hp: custom(1, '123457', 1, 0), all: custom(1, '123457', 2, 0), mp: custom(2, '3457', 1, 0), drain: custom(5, '54321', 1, 0),
    heal: custom(3, '1000', 7, 0), mpdrain: custom(6, '777', 1, 0)};
  for (const [name, item] of Object.entries(items)) {
    cases.push(makeCase(`item.a${id}.${name}`, {actor: id, troop: 2, type: item.damage.type, formula: item.damage.formula, scope: item.scope}, () => {
      const {a, ally, foes} = battle(id, 2);
      if (name === 'heal') ally.setHp(1);
      const targets = name === 'all' ? foes : name === 'heal' ? [ally] : [foes[0]];
      const log = record(() => targets.forEach(t => applyItem(a, item, t)), [a, ally, ...foes]);
      return {log, after: [a, ally, ...foes].map(snap)};
    }));
  }
  cases.push(makeCase(`shield.a${id}`, {actor: id, troop: 2, shield: 1000, formula: '200003'}, () => {
    const {a, ally, foes} = battle(id, 2); foes[0].addShield(1000);
    const log = record(() => applyItem(a, custom(1, '200003', 1, 0), foes[0]), [a, ally, ...foes]);
    return {log, after: [a, ally, ...foes].map(snap)};
  }));
  cases.push(makeCase(`reflect.a${id}`, {actor: id, troop: 2, skill: 1, mrfState: 'trait 22/5 = 1'}, () => {
    const {bm, a, ally, foes} = battle(id, 2); foes[0].addState(MRF_STATE); foes[0].refresh();
    const log = record(() => act(bm, a, 1, 0), [a, ally, ...foes]);
    return {log, after: [a, ally, ...foes].map(snap)};
  }));
  for (const [name, cmd] of [['hp', ['HP -1003', ['TARGETS']]], ['mp', ['MP -103', ['TARGETS']]], ['hpPct', ['HP -1%', ['TARGETS']]]]) {
    cases.push(makeCase(`sequence.a${id}.${name}`, {actor: id, troop: 2, command: cmd}, () => {
      const {bm, a, ally, foes} = battle(id, 2);
      const action = new w.Game_Action(a); action.setSkill(1);
      bm._subject = a; bm._action = action; bm._targets = [foes[0]]; bm._allTargets = [foes[0]];
      const log = record(() => { bm.processActionSequence(cmd[0], cmd[1]); }, [a, ally, ...foes]);
      return {log, after: [a, ally, ...foes].map(snap)};
    }));
  }
  // DOT：本行动给敌人附加中毒（4，hrg −0.1），状态来源记为行动者；随后 regenerateHp
  cases.push(makeCase(`dot.a${id}`, {actor: id, troop: 2, state: 4}, () => {
    const {a, ally, foes} = battle(id, 2);
    const item = custom(0, '0', 1, 0, [{code: 21, dataId: 4, value1: 1, value2: 0}]);
    applyItem(a, item, foes[0]);
    const origin = foes[0].stateOrigin ? key(foes[0].stateOrigin(4)) : null;
    const log = record(() => { foes[0].regenerateHp(); }, [a, ally, ...foes]);
    return {origin, states: foes[0]._states.slice(), hrg: foes[0].hrg, rec: foes[0].rec, mhp: foes[0].mhp, log, after: [a, ally, ...foes].map(snap)};
  }));
}
// REC≠1 的再生（稳定新键，旧 dot.* 不动）：setup.states 依次 [状态, 附加者]，附加者 null 表示直接 addState（无来源）；
// 状态写 fake 名或真实编号，fake 名的特性见 setup.fake。target：e0 敌人或 a1 同伴（同伴先把 HP 降到一半，正再生才看得到）。
const recCases = [
  ['dot.rec.a141.mixed', 141, 'e0', [['rec2', null], [4, 'a141'], ['hrg-5', 'a1']]],
  ['dot.rec.a141.only', 141, 'e0', [['rec06', null], [4, 'a141']]],
  ['dot.rec.a1.plain', 1, 'e0', [['rec06', null], [4, 'a1'], ['hrg+3', null]]],
  ['regen.rec.actor', 141, 'a1', [['rec08', null], ['hrg+5', null]]],
];
for (const [id, actor, target, states] of recCases) {
  const fake = {};
  for (const [st] of states) if (typeof st === 'string') fake[st] = {id: FAKE[st], traits: w.$dataStates[FAKE[st]].traits};
  cases.push(makeCase(id, {actor, troop: 2, target, states, fake}, () => {
    const {bm, a, ally, foes} = battle(actor, 2);
    const t = target === 'a1' ? ally : foes[0];
    const by = k => k === null ? null : k === 'a1' ? ally : a;
    for (const [st, src] of states) {
      const sid = typeof st === 'string' ? FAKE[st] : st, u = by(src);
      if (u) { bm._subject = u; applyItem(u, custom(0, '0', 1, 0, [{code: 21, dataId: sid, value1: 1, value2: 0}]), t); }
      else { bm._subject = null; t.addState(sid); }
    }
    if (target === 'a1') t.setHp(Math.floor(t.mhp / 2));
    t.need_refresh = true; t.refresh();
    const origins = t._states.map(sid => [sid, t.stateOrigin ? key(t.stateOrigin(sid)) : null]);
    const log = record(() => { t.regenerateHp(); }, [a, ally, ...foes]);
    return {origins, states: t._states.slice(), hrg: t.hrg, rec: t.rec, mhp: t.mhp, log, after: [a, ally, ...foes].map(snap)};
  }));
}
// 各行动者夹具开战后双方的生命／魔法上限（Godot 重放时按它截资源）
for (const id of ACTORS) cases.push(makeCase(`caps.a${id}`, {actor: id, troop: 2}, () => {
  const {a, ally, foes} = battle(id, 2);
  return {caps: [a, ally, ...foes].map(b => ({key: key(b), mhp: b.mhp, mmp: b.mmp}))};
}));
// 无行动上下文的直接 gainHp（如回合事件）不缩放；敌人打导入角色不缩放
cases.push(makeCase('direct.gainHp.noContext', {actor: 141, troop: 2}, () => {
  const {a, ally, foes} = battle(141, 2);
  const log = record(() => { foes[0].gainHp(-1003); a.gainHp(-1003); }, [a, ally, ...foes]);
  return {log, after: [a, ally, ...foes].map(snap)};
}));
cases.push(makeCase('enemy.hits.a141', {actor: 141, troop: 2, formula: '123457'}, () => {
  const {a, ally, foes} = battle(141, 2);
  const action = new w.Game_Action(foes[0]); action.setSkill(custom(1, '123457', 1, 0).id);
  const log = record(() => { a.result().clear(); action.apply(a); }, [a, ally, ...foes]);
  return {log, after: [a, ally, ...foes].map(snap)};
}));
process.exit(finish(host, 'imported_balance.json', {hostScope: '真实 BattleManager／Game_Action（Math.random 0.5），战斗者实例上记录最外层结算调用', cases}) ? 0 : 1);
