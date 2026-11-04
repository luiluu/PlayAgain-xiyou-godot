'use strict';
// 【cc·八戒·未经审查】混乱类状态（restriction 1～3）：真实 BattleManager.processTurn 下，带 7（愤怒 r1）、8（混乱 r2）、9（魅惑 r3）的行动者这一回合做什么。
// 记：行动内容（技能号，预设了技能时是否被改成普攻）、目标（阵营＋序号）、随机数取用（prepare 和 makeTargets 各取几个）、状态回合数在这一回合前后的变化、
// 能否输入（canInput）、敌我双方、已倒下的队友会不会被选中（随机序列扫一遍）、强制行动（forceAction）是否绕过混乱。
// 产物 .sandbox/confusion.json，拷成 tests/fixtures/confusion_oracle.json（不进同步），专项 xiyou_confusion。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');
const stub = new Proxy(function () {}, {get: (_, k) => k === '_waitCount' ? 0 : (() => false), set: () => true});
const sprites = new Map();
w.Game_Battler.prototype.battler = function () {
  if (!sprites.has(this)) sprites.set(this, new Proxy({x: 0, y: 0, _homeX: 0, _homeY: 0, width: 64, height: 64, scale: {x: 1, y: 1}, anchor: {x: 0.5, y: 1}, opacity: 255},
    {get: (t, k) => k in t ? t[k] : (() => false), set: (t, k, v) => {t[k] = v; return true;}}));
  return sprites.get(this);
};
w.BattleManager.actionBattleHud = () => true;
w.BattleManager.otbDisplayWindow = () => stub;
if (!w.$) w.$ = {};
w.$.toaster = () => {};
// 随机序列：每次取一个，记次数；seq 为空时循环取固定值
let seq = [0.5], pos = 0, draws = 0;
const rnd = () => { draws++; const v = seq[pos % seq.length]; pos++; return v; };
w.Math.random = rnd;
const setSeq = s => { seq = s; pos = 0; draws = 0; };
const TROOP = 3;
function battle(partyIds) {
  newGame(); w.Math.random = rnd;  // newGame 会把 Math.random 重置成 0.5
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.$gameSwitches.setValue(2494, true);
  const party = partyIds || [1, 8, 9, 10];
  w.eval(`$gameParty._actors=[${party}]; $gameParty._battleMembers=[${party},0];`);
  for (const id of party) w.$gameActors.actor(id).changeLevel(60, false);
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.SceneManager._scene = {_otbDisplayWindow: stub};
  for (const t of w.$gameTroop.members()) t._paramPlus[0] = 1e9;
  for (const a of w.$gameParty.members()) a._paramPlus[0] = 1e9;
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  bm.startBattle(); bm.startTurn(); bm._phase = 'turn';
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) b.recoverAll();
  return bm;
}
function run(bm) {
  for (let i = 0; i < 20000; i++) {
    const ph = bm._phase;
    if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
    else if (ph === 'actionTargetList') bm.updateActionTargetList(); else if (ph === 'action') bm.updateAction(); else break;
  }
  bm._phase = 'turn';
}
const addS = (b, id, turns) => { b.addNewState(id); b._stateTurns[id] = turns; b.need_refresh_states = true; b.need_refresh_stateResistSet = true; b.need_refresh = true; b.refresh(); };
const tag = t => !t ? null : [t.isActor() ? 'a' : 'e', t.index()];
// 把 Game_Action.apply 钩住记录目标；prepare / makeTargets 分别记随机数取用次数
const log = {applied: [], prep: null, mk: null};
const oPrepare = w.Game_Action.prototype.prepare, oMake = w.Game_Action.prototype.makeTargets, oApply = w.Game_Action.prototype.apply;
w.Game_Action.prototype.prepare = function () { const d0 = draws; const before = this._item && this._item._itemId; oPrepare.call(this); log.prep = {before, after: this._item && this._item._itemId, kind: this.isAttack() ? 'attack' : this.isSkill() ? 'skill' : this.isItem() ? 'item' : 'none', draws: draws - d0}; };
w.Game_Action.prototype.makeTargets = function () { const d0 = draws; const t = oMake.call(this); log.mk = {draws: draws - d0, targets: t.map(tag)}; return t; };
w.Game_Action.prototype.apply = function (t) { log.applied.push(tag(t)); return oApply.call(this, t); };
const st = b => b._states.slice().sort((x, y) => x - y).map(s => [s, b._stateTurns[s] == null ? null : b._stateTurns[s]]);
const hp = () => ({a: w.$gameParty.members().map(x => x.hp), e: w.$gameTroop.members().map(x => x.hp)});
// 一回合：subject 带 state，可预设行动（skill 号），按真实 getNextSubject→makeActions→processTurn 链走
function turn(bm, sub, stateId, o = {}) {
  addS(sub, stateId, o.turns == null ? 3 : o.turns);
  log.applied = []; log.prep = null; log.mk = null;
  setSeq(o.seq || [0.5]);
  const canInput = sub.canInput(), canMove = sub.canMove(), conf = sub.isConfused(), lvl = sub.confusionLevel();
  sub.makeActions();  // 与 getNextSubject 一致
  const acts0 = sub._actions.map(a => a._item ? [a.isSkill() ? 's' : 'i', a._item._itemId] : null);
  if (o.skill && sub._actions[0]) { sub._actions[0].setSkill(o.skill); sub._actions[0].setTarget(o.target == null ? 0 : o.target); }
  const acts1 = sub._actions.map(a => a._item ? [a.isSkill() ? 's' : 'i', a._item._itemId] : null);
  const mp0 = sub.mp, h0 = hp(), s0 = st(sub);
  bm._subject = sub; bm._action = null; bm._phase = 'turn';
  bm.processTurn();
  const midPhase = bm._phase;
  run(bm);
  return {canInput, canMove, isConfused: conf, level: lvl, makeActionsActions: acts0, presetActions: acts1, phaseAfterProcessTurn: midPhase,
    prepare: log.prep, makeTargets: log.mk, applied: log.applied, mpSpent: mp0 - sub.mp, hpBefore: h0, hpAfter: hp(), statesBefore: s0, statesAfter: st(sub), draws, actionsLeft: sub._actions.length};
}
const cases = [];
const STATES = {7: 1, 8: 2, 9: 3};
for (const side of ['actor', 'enemy']) for (const [sid, lv] of Object.entries(STATES)) {
  // 固定随机 0.5（半数取整）、0.0、0.99 三种，看目标选择落在哪一侧
  for (const seqName of ['mid', 'low', 'high']) {
    const seq = {mid: [0.5], low: [0.0], high: [0.99]}[seqName];
    cases.push(makeCase(`${side}.state${sid}.${seqName}.noPreset`, {side, state: +sid, seq: seqName}, () => {
      const bm = battle(), sub = side === 'actor' ? w.$gameParty.members()[0] : w.$gameTroop.members()[0];
      return turn(bm, sub, +sid, {seq});
    }));
  }
  // 预设了非普攻技能（技能 4？取一个单体、全体各一个）：被改成普攻吗
  for (const [name, skill] of [['skill1', 2], ['skillAll', 8]]) {
    cases.push(makeCase(`${side}.state${sid}.preset.${name}`, {side, state: +sid, skill}, () => {
      const bm = battle(), sub = side === 'actor' ? w.$gameParty.members()[0] : w.$gameTroop.members()[0];
      return turn(bm, sub, +sid, {seq: [0.5], skill});
    }));
  }
}
// 目标序号扫描：随机取 0～0.95 一系列值，记每个值选到的目标（看是否包含已倒下的人、是否能选自己）
for (const side of ['actor', 'enemy']) for (const sid of Object.keys(STATES)) {
  cases.push(makeCase(`${side}.state${sid}.sweep`, {side, state: +sid}, () => {
    const out = [];
    for (const v of [0.0, 0.2, 0.26, 0.49, 0.5, 0.74, 0.76, 0.99]) {
      for (const second of [0.0, 0.6]) {
        const bm = battle(), units = side === 'actor' ? w.$gameParty.members() : w.$gameTroop.members();
        const sub = units[0];
        // 令各方各有一个已倒下的成员（序号 1）
        for (const m of [w.$gameParty.members()[1], w.$gameTroop.members()[1]]) { m.die(); m.need_refresh = true; m.refresh(); }
        const alive = [w.$gameParty.members().map(x => x.isAlive()), w.$gameTroop.members().map(x => x.isAlive()), w.$gameParty.aliveMembers().length, w.$gameTroop.aliveMembers().length];
        out.push({v, second, alive, r: turn(bm, sub, +sid, {seq: [v, second]}).makeTargets});
      }
    }
    return out;
  }));
}

// 自动战斗（挂机）下的混乱角色：Game_Actor.makeActions 先走 makeAutoBattleActions（isAutoBattle 优先于混乱），
// OTB startOTBInput 因 canInput 假直接 startAction（不走 prepare），所以技能保持自动选的，只有目标走混乱。这里把自动选的技能钉成各 scope 的代表技能。
const pickSkills = () => { const by = {}; for (const sk of w.$dataSkills) { if (!sk || !sk.name || sk.mpCost || sk.tpCost || sk.id < 3 || sk.id > 400) continue; const m = String(sk.note || ''); if (/Custom|<Target|<Cast|Cooldown/i.test(m)) continue; if (!(sk.scope in by)) by[sk.scope] = sk.id; } return by; };
const SC = pickSkills();
for (const [sid, lv] of Object.entries(STATES)) for (const [scope, skillId] of Object.entries(SC)) {
  if (![1, 2, 4, 7, 8, 11].includes(+scope)) continue;
  cases.push(makeCase(`actor.auto.state${sid}.scope${scope}`, {state: +sid, scope: +scope, skill: skillId}, () => {
    const out = [];
    for (const v of [0.0, 0.6]) {
      const bm = battle(), sub = w.$gameParty.members()[0];
      sub.isAutoBattle = () => true;
      sub.makeAutoBattleActions = function () { this._actions[0].setSkill(skillId); this._actions[0].setTarget(0); this.setActionState('waiting'); };
      out.push({v, r: turn(bm, sub, +sid, {seq: [v, 0.3]})});
    }
    return {skill: skillId, runs: out.map(x => ({v: x.v, canInput: x.r.canInput, prepare: x.r.prepare, makeTargets: x.r.makeTargets, applied: x.r.applied, mpSpent: x.r.mpSpent, statesAfter: x.r.statesAfter}))};
  }));
}
// 强制行动绕过混乱
for (const side of ['actor', 'enemy']) cases.push(makeCase(`${side}.forceAction`, {side}, () => {
  const bm = battle(), sub = side === 'actor' ? w.$gameParty.members()[0] : w.$gameTroop.members()[0];
  addS(sub, 8, 3);
  setSeq([0.5]); log.applied = []; log.prep = null; log.mk = null;
  sub.forceAction(2, 0); bm.forceAction(sub);
  const r0 = {forced: sub._actions.length, bmPhase: bm._phase};
  bm.processForcedAction();
  run(bm);
  return {...r0, prepare: log.prep, makeTargets: log.mk, applied: log.applied, draws};
}));
// 状态回合：行动结束减 1（autoRemovalTiming 1）；7 / 2504 被打会解除；一回合多次
cases.push(makeCase('actor.state7.removedByDamage', {}, () => {
  const bm = battle(), sub = w.$gameParty.members()[0];
  addS(sub, 7, 3);
  setSeq([0.4]); const before = st(sub); sub.removeStatesByDamage();
  return {before, after: st(sub), affected: sub.isStateAffected(7)};
}));
// 状态号逐个：restriction 与自动解除设定（供对照 States.json）
cases.push(makeCase('states.table', {}, () => [7, 8, 9, 124, 1045, 1113, 1567, 1830, 2046, 2504, 2505, 2506, 2580].map(i => {
  const s = w.$dataStates[i]; return {id: i, restriction: s.restriction, autoRemovalTiming: s.autoRemovalTiming, minTurns: s.minTurns, maxTurns: s.maxTurns, removeByDamage: s.removeByDamage, removeByRestriction: s.removeByRestriction, removeAtBattleEnd: s.removeAtBattleEnd};
})));
// 全部 13 个状态：这些状态号作用下 isConfused / confusionLevel / canMove / canInput
cases.push(makeCase('states.flags', {}, () => [7, 8, 9, 124, 1045, 1113, 1567, 1830, 2046, 2504, 2505, 2506, 2580].map(i => {
  const bm = battle(), a = w.$gameParty.members()[0], e = w.$gameTroop.members()[0];
  addS(a, i, 3); addS(e, i, 3);
  return {id: i, actor: [a.isConfused(), a.confusionLevel(), a.canMove(), a.canInput(), a.restriction()], enemy: [e.isConfused(), e.confusionLevel(), e.canMove(), e.canInput(), e.restriction()]};
})));
process.exit(finish(host, 'confusion.json', {hostScope: '真实 processTurn 下带混乱类状态（restriction 1～3）的行动者这一回合', cases}) ? 0 : 1);
