'use strict';
// dsPassiveSkill 两个没读的被动标签（passive1）：<passiveGUARD>（技能 10089 苍龙*破晓，Game_Actor.isGuard 恒真）、
// <passiveXPBSTEX条件追加能力值>（技能 968 EX2:20,HPUP,40；3886 EX9:50,MPUP,100）。
// 量：isGuard、受伤时的防御折减（Game_Action.makeDamageValue 对比有无）、guard 状态对照；xparam(2)／xparam(9) 随 HP／MP 比例的变化、战斗里外。
// 报错一律放 sourceErrors（合并同步按这个字段名拦截）。只在内存里跑；产物 .sandbox/passive.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');
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
const sourceErrors = [];
w.Yanfly.Util.displayError = (error, code, message) => sourceErrors.push({text: String(error && error.message || error), message});
function battle(inBattle) {
  if (w.$gameParty) w.$gameParty._inBattle = false;
  newGame();
  w.eval('$gameParty._actors=[];');
  for (const id of [1, 8]) w.$gameParty.addActor(id);
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(2, true, true);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.CodexYunshang._acted = [];
  for (const id of [1, 8]) { const a = w.$gameActors.actor(id); a.need_refresh = true; a.refresh(); a.recoverAll(); }
  for (const e of w.$gameTroop.members()) { e._paramPlus[0] = 1e9; e.need_refresh = true; e.refresh(); e.recoverAll(); }
  w.$gameParty._inBattle = !!inBattle;
  return {a: w.$gameActors.actor(1), b: w.$gameActors.actor(8), e: w.$gameTroop.members()[0]};
}
const learn = (a, ids) => { a._skills = a._skills.filter(s => ![968, 3886, 10089, 3219, 4924].includes(s)).concat(ids); a.need_refresh = true; a.refresh(); };
const cases = [];
cases.push(makeCase('guard', {skill: 10089}, () => {
  const out = {rows: []};
  for (const inBattle of [false, true]) for (const learned of [false, true]) for (const stun of [false, true]) {
    const {a, e} = battle(inBattle); sourceErrors.length = 0;
    learn(a, learned ? [10089] : []);
    if (stun) { const rs = w.$dataStates.findIndex(x => x && x.restriction === 4 && x.autoRemovalTiming === 0); a.addState(rs); a.need_refresh = true; a.refresh(); }  // 不能行动的状态
    const row = {inBattle, learned, stun, isGuard: a.isGuard(), canMove: a.canMove(), grd: a.grd, specialFlagGuard: a.specialFlag(a.constructor.FLAG_ID_GUARD)};
    // 受伤：同一击打在 a 身上
    const act = new w.Game_Action(e); act.setSkill(1);
    const rnd = w.Math.random; w.Math.random = () => 0.5;
    try { row.damage = act.makeDamageValue(a, false); } catch (x) { row.damage = null; sourceErrors.push({text: String(x).slice(0, 80), message: 'makeDamageValue'}); }
    w.Math.random = rnd;
    row.sourceErrors = sourceErrors.slice();
    out.rows.push(row);
  }
  // 对照：不学、挂标准防御状态（state 2＝特殊标志 guard）后的受伤
  { const {a, e} = battle(true); learn(a, []);
    const st = w.$dataStates.findIndex(s => s && s.traits && s.traits.some(t => t.code === 62 && t.dataId === 1));  // FLAG_ID_GUARD 的特性
    out.guardState = st;
    const act = new w.Game_Action(e); act.setSkill(1); const rnd = w.Math.random; w.Math.random = () => 0.5;
    const base = act.makeDamageValue(a, false);
    if (st > 0) { a.addState(st); a.need_refresh = true; a.refresh(); }
    const guarded = act.makeDamageValue(a, false); w.Math.random = rnd;
    out.compare = {base, guarded, isGuard: a.isGuard(), grd: a.grd};
  }
  return out;
}));
cases.push(makeCase('xpbstex', {skills: [968, 3886]}, () => {
  const out = {rows: []};
  const hpMp = [[1, 1], [0.5, 1], [0.4, 1], [0.39, 1], [0.1, 1], [1, 0.99], [1, 0.5], [1, 0]];
  for (const inBattle of [false, true]) for (const ids of [[], [968], [3886], [968, 3886]]) for (const [hr, mr] of hpMp) {
    const {a} = battle(inBattle); sourceErrors.length = 0;
    learn(a, ids);
    a._hp = Math.max(1, Math.round(a.mhp * hr)); a._mp = Math.round(a.mmp * mr); a.need_refresh = true;
    const row = {inBattle, ids, hr: a.hpRate(), mr: a.mpRate(), xparam2: a.xparam(2), xparam9: a.xparam(9), cri: a.cri, trg: a.trg, xparam0: a.xparam(0), xparam7: a.xparam(7), xparam8: a.xparam(8)};
    row.sourceErrors = sourceErrors.slice();
    out.rows.push(row);
  }
  out.notes = [968, 3886].map(id => ({id, note: w.$dataSkills[id].note.split('\n').filter(l => /passive/i.test(l))}));
  return out;
}));
// 顺带：TPUP／TPLW 条件（passivePBSTEX2:50%,TPUP,100：技能 3219 4924 4925），atk＝参数 2
cases.push(makeCase('pbstex_tp', {skills: [3219, 4924]}, () => {
  const out = {rows: []};
  for (const ids of [[], [3219], [4924]]) for (const tpRate of [0, 0.5, 0.99, 1]) {
    const {a} = battle(true); sourceErrors.length = 0; learn(a, ids);
    a._tp = Math.round(a.maxTp() * tpRate); a.need_refresh = true; a.refresh();
    out.rows.push({ids, tp: a.tp, maxTp: a.maxTp(), tpRate: a.tpRate(), atk: a.atk, param2: a.param(2), sourceErrors: sourceErrors.slice()});
  }
  out.notes = [3219, 4924].map(id => ({id, note: w.$dataSkills[id].note.split('\n').filter(l => /passive/i.test(l))}));
  return out;
}));
process.exit(finish(host, 'passive.json', {scope: 'dsPassiveSkill passiveGUARD / passiveXPBSTEX on frozen source', cases}) ? 0 : 1);
