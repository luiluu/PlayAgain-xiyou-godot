'use strict';
// 冻结原版定向生命周期；只写 .sandbox，全内存新局，不访问玩家存档。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host=start(), {w,newGame}=host;
let trace=[];
const native=w.Game_BattlerBase.prototype.addParam;
w.Game_BattlerBase.prototype.addParam=function(i,n) { native.call(this,i,n); trace.push({i,n,hp:this.hp,mp:this.mp}); };
function fresh() {
  newGame(); const a=w.$gameActors.actor(1);
  a._equips.forEach(e=>e.setObject(null)); a._skills=new w.Array(); a._states=new w.Array();
  a._paramPlus=w.Array.from([0,0,0,0,0,0,0,0]); a._level=3; a.refresh(); a.recoverAll(); trace=[]; return a;
}
function snap(a,name) { return {name,level:a.level,plus:Array.from({length:8},(_,i)=>a.paramPlus(i)),param:Array.from({length:8},(_,i)=>a.param(i)),hp:a.hp,mp:a.mp,states:Array.from(a._states),trace:trace.splice(0)}; }
const cases=[];
for(const mode of ['dispel','forced_expire']) cases.push(makeCase('1612.'+mode,{forcedTiming:mode==='forced_expire'?2:null},()=>{
  let a=fresh();const rows=[snap(a,'before')];a.addState(1612);rows.push(snap(a,'apply'));
  a.addState(1612); rows.push(snap(a,'reapply'));
  a._level=5;a.refresh();a._hp=a.mhp;a._mp=a.mmp;rows.push(snap(a,'level5'));
  if(mode==='forced_expire'){const old=w.$dataStates[1612].autoRemovalTiming;w.$dataStates[1612].autoRemovalTiming=2;try{a._stateTurns[1612]=0;a.removeStatesAuto(2);}finally{w.$dataStates[1612].autoRemovalTiming=old;}}else a.removeState(1612);
  rows.push(snap(a,'remove'));a.removeState(1612);rows.push(snap(a,'remove_absent'));
  a.addState(1612);rows.push(snap(a,'apply5'));
  const saved=host.encode();host.restore(saved);a=w.$gameActors.actor(1);rows.push(snap(a,'save'));
  a.removeState(1612);rows.push(snap(a,'after_save_remove'));a.recoverAll();rows.push(snap(a,'recover'));return {rows};
}));
for(const mode of ['alive','hp0','dead_state','both','self']) cases.push(makeCase('1768.'+mode,{},()=>{
  let a=fresh();a.addState(1768);const b=mode==='self'?a:new w.Game_Enemy(1,0,0);
  if(['hp0','both','self'].includes(mode)) b._hp=0;
  if(['dead_state','both'].includes(mode)) b._states.push(1);
  const action=new w.Game_Action(a);action.setSkill(1);const rows=[snap(a,'before')];
  action.offApplyStateEffects(b);rows.push(snap(a,'conclude'));
  action.offApplyStateEffects(b);rows.push(snap(a,'repeat'));
  const saved=host.encode();host.restore(saved);a=w.$gameActors.actor(1);rows.push(snap(a,'save'));return {rows};
}));
process.exit(finish(host,'param_states.json',{scope:'Frozen1612 lifecycle and1768 native offApplyStateEffects; actor host only',states:[1612,1768].map(id=>({id,note:w.$dataStates[id].note,autoRemovalTiming:w.$dataStates[id].autoRemovalTiming})),cases})?0:1);
