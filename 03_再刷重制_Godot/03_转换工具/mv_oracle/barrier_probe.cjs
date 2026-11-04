'use strict';
// YEP_AbsorptionBarrier（吸收屏障）可达性参照（dot2）：全游戏数据里只有技能 10032 月之庇佑带 <Custom User Barrier>，它是 occasion 3（永不可用）的被动。
// 量：①全部数据对象解析出的屏障字段（有谁有）②10032 学会后 canUse／usableSkills／战斗开始／再生／回合结束的屏障点数 ③如果硬跑一次这个技能的屏障结算
// （applyItemUserEffect）得到多少。只在内存里跑；产物 .sandbox/barrier.json。
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
const errors = [];
w.Yanfly.Util.displayError = (error, code, message) => errors.push({error: String(error && error.message || error), message});
function battle() {
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
  return {a: w.$gameActors.actor(1), e: w.$gameTroop.members()[0]};
}
const total = b => b.barrierPoints();
const cases = [];
// 1) 全游戏数据里谁有屏障字段
cases.push(makeCase('census', {}, () => {
  newGame();
  const out = {};
  const nonEmpty = a => Array.isArray(a) ? a.some(x => x !== undefined && x !== '' && x !== 0) : !!a;
  for (const [name, table, kind] of [['skills', w.$dataSkills, 1], ['items', w.$dataItems, 1], ['actors', w.$dataActors, 2], ['classes', w.$dataClasses, 2],
    ['enemies', w.$dataEnemies, 2], ['weapons', w.$dataWeapons, 2], ['armors', w.$dataArmors, 2], ['states', w.$dataStates, 2]]) {
    const list = [];
    for (const o of table) {
      if (!o) continue;
      const f = kind === 1 ? ['targetBarrier', 'userBarrier', 'targetBarrierEval', 'userBarrierEval'] : ['battleStartBarrierPoints', 'barrierRegen', 'battleStartBarrierPointsEval', 'barrierRegenEval'];
      const pen = kind === 1 ? (o.barrierPenetrationRate !== w.Yanfly.Param.ABRPenRate || o.barrierPenetrationFlat !== w.Yanfly.Param.ABRPenFlat) : (o.barrierPenetrationRate !== 0 || o.barrierPenetrationFlat !== 0);
      const hits = f.filter(k => nonEmpty(o[k]));
      if (o.barrierPenetrationRateEval || o.barrierPenetrationFlatEval) hits.push('penEval');
      if (pen) hits.push('pen');
      if (hits.length) list.push({id: o.id, name: o.name, hits, userBarrierEval: o.userBarrierEval && o.userBarrierEval.map(s => s === undefined ? null : s)});
    }
    out[name] = list;
  }
  out.params = {state: w.Yanfly.Param.ABRState, clearPerBattle: w.Yanfly.Param.ABRClear, clearOnDeath: w.Yanfly.Param.ABRClearDeath, penRate: w.Yanfly.Param.ABRPenRate, penFlat: w.Yanfly.Param.ABRPenFlat, display0: w.Yanfly.Param.ABRDisplayZero};
  out.classSkill = w.$dataClasses[154].learnings.filter(l => l.skillId === 10032);
  const s = w.$dataSkills[10032];
  out.skill = {occasion: s.occasion, scope: s.scope, stypeId: s.stypeId, damageType: s.damage.type, effects: s.effects.length, mpCost: s.mpCost, tpCost: s.tpCost};
  return out;
}));
// 2) 10032 学会之后，战斗里能不能用、屏障点数有没有出现
cases.push(makeCase('reach.10032', {skill: 10032}, () => {
  const {a, e} = battle(), out = {};
  a._skills.push(10032); a.need_refresh = true; a.refresh();
  const item = w.$dataSkills[10032], act = new w.Game_Action(a);
  act.setSkill(10032);
  const look = tag => ({tag, barrier: total(a), perm: a._permBarrier, turn: a._turnBarrier ? a._turnBarrier.slice() : null});
  w.$gameParty._inBattle = false;
  out.menu = {hasSkill: a.hasSkill(10032), isLearned: a.isLearnedSkill(10032), canUse: a.canUse(item), occasionOk: a.isOccasionOk(item), listed: a.usableSkills().some(s => s.id === 10032), valid: act.isValid()};
  w.$gameParty._inBattle = true;
  out.battle = {canUse: a.canUse(item), occasionOk: a.isOccasionOk(item), listed: a.usableSkills().some(s => s.id === 10032), valid: act.isValid()};
  const track = [look('before')];
  a.onBattleStart(); track.push(look('battleStart'));
  for (let i = 0; i < 3; i++) { a.onTurnEnd(); a.regenerateAll(); track.push(look('turnEnd' + (i + 1))); }
  out.track = track;
  out.errors = errors.splice(0);
  return out;
}));
// 3) 假如真的结算一次（原版没有任何入口会这样做）：10032 给使用者的屏障点数
cases.push(makeCase('forced.10032', {skill: 10032}, () => {
  const {a, e} = battle(), out = {};
  a._skills.push(10032); a.need_refresh = true; a.refresh();
  w.$gameParty._inBattle = true;
  errors.length = 0;
  a._hp = 777; const act = new w.Game_Action(a); act.setSkill(10032);
  act.applyItemUserEffect(a);
  out.afterEffect = {barrier: total(a), perm: a._permBarrier, turn: a._turnBarrier.slice(), hp: a.hp, errors: errors.splice(0)};
  out.errors = errors.splice(0);
  return out;
}));
process.exit(finish(host, 'barrier.json', {scope: 'YEP_AbsorptionBarrier reachability on frozen source: only skill 10032 (occasion 3) carries a barrier tag', cases}) ? 0 : 1);
