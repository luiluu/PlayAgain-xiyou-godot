'use strict';
// Stage review 50: native in-memory save/reload and
// counterattack source. The frozen source stays read-only; no player saves.
const {start, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host, cases = [];
const evalThrown = [];
w.Yanfly.Util.displayError = e => evalThrown.push(String(e && e.stack || e));
function measure(id, fn) {
  const first = evalThrown.length;
  const observed = fn();
  if (first !== evalThrown.length) throw new Error(evalThrown.slice(first).join('\n'));
  cases.push({id, observed, errors:[]});
}
function phaseValue(a, b) {
  const action = new w.Game_Action(a); action.setSkill(1);
  const confirm = action.customEffectEval(b, 1712, 'confirmState', a, 100);
  const value = action.customEffectEval(b, 1779, 'reactState', b, confirm);
  return {confirm, value, aStates: Array.from(a._states), bStates: Array.from(b._states),
    confirmStates: Array.from(a.typestates('confirmState')).map(s => s.id),
    reactStates: Array.from(b.typestates('reactState')).map(s => s.id)};
}
measure('save.state_effects', () => {
  newGame();
  let a = w.$gameActors.actor(1), b = w.$gameActors.actor(8);
  a.addState(1712); b.addState(1779);
  for (const x of [a, b]) { x.need_refresh = true; x.refresh(); }
  const before = phaseValue(a, b), encoded = host.encode();
  host.restore(encoded);
  a = w.$gameActors.actor(1); b = w.$gameActors.actor(8);
  return {before, after: phaseValue(a, b)};
});
// Counter goes last: this frozen plugin chain changes the emulated location.
measure('counter.state_origin', () => {
  newGame();
  // The engine's Array has MV.contains; a Node-owned [] does not.
  w.eval('$gameSwitches.setValue(2494,true); $gameParty._actors = []; $gameParty._battleMembers = null; $gameParty.addActor(154); $gameParty.addActor(1); $gameParty.initializeBattleMembers();');
  const bm = w.BattleManager;
  const stub = new Proxy(function () {}, {get: (_, key) => key === '_waitCount' ? 0 : (() => false), set: () => true});
  const sprites = new Map();
  w.Game_Battler.prototype.battler = function () {
    if (!sprites.has(this)) sprites.set(this, new Proxy({x:0,y:0,_homeX:0,_homeY:0,width:64,height:64,
      scale:{x:1,y:1},anchor:{x:.5,y:1},opacity:255}, {get:(t,k)=>k in t?t[k]:(()=>false),set:(t,k,v)=>{t[k]=v;return true;}}));
    return sprites.get(this);
  };
  bm.setup(2, false, false); bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  bm.actionBattleHud = () => true; bm.otbDisplayWindow = () => stub;
  w.$gameParty._inBattle = true; w.CodexYunshang._acted = [];
  const battleMembers = Array.from(w.$gameParty.battleMembers(), x => x.actorId());
  if (!battleMembers.includes(154)) throw new Error('154 is not a deployed battle member: '+JSON.stringify(battleMembers));
  const a = w.$gameActors.actor(154), e = w.$gameTroop.members()[0];
  a.addState(92); e._paramPlus[0] = 1e9;
  for (const x of [a, e]) { x.need_refresh = true; x.refresh(); x.recoverAll(); }
  // recoverAll clears temporary barrier, so attach it after the resource fixture.
  a.addState(92); a.need_refresh = true; a.refresh();
  bm._subject = e;
  const initial = new w.Game_Action(e); initial.setAttack(); bm._action = initial; e._actions = [initial];
  const counterRate = a.cnt, beforeStates = Array.from(e._states), originCalls = [];
  const originalOrigin = e.setStateOrigin;
  e.setStateOrigin = function(state, source) {
    originCalls.push({state,sourceActor:source && source.isActor() ? source.actorId():null,inBattle:w.$gameParty.inBattle()});
    return originalOrigin.apply(this, arguments);
  };
  bm.invokeCounterAttack(e, a);
  const origin = e.stateOrigin(522), hp = e.hp;
  const sourceActor = origin && origin.isActor() ? origin.actorId() : null;
  e.regenerateHp();
  return {actor:154,state:522,battleMembers,counterRate,attackSkill:a.attackSkillId(),beforeStates,originCalls,rawOrigin:e._stateOrigin[522],originActor:sourceActor,hasState:e.isStateAffected(522),
    maxHp:e.mhp,hpBeforeRegen:hp,hpAfterRegen:e.hp,hpDelta:e.hp-hp,sourceRate:w.CodexImportedBalance.outgoingRate(a)};
});
process.exit(finish(host, 'stage50_review.json', {hostScope:'内存JsonEx往返与真实BattleManager.invokeCounterAttack，154实际出战', cases}) ? 0 : 1);
