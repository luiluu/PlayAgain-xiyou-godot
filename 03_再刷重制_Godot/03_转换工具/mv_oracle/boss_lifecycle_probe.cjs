'use strict';
// 冻结原版Boss快照与2651生命周期。真实接口，全内存新局，仅写.sandbox。
const {start,makeCase,finish}=require('./shared/host.cjs');
const host=start(),{w,newGame}=host,D=w.CodexBossDifficulty;
// 与既有enemy_book_defeat_probe相同：只补精灵占位，不替换数值或生命周期方法。
const sprites=new Map();
w.Game_Battler.prototype.battler=function(){
  if(!sprites.has(this))sprites.set(this,new Proxy({}, {get:(t,k)=>k in t?t[k]:(()=>false),set:(t,k,v)=>{t[k]=v;return true;}}));
  return sprites.get(this);
};
function fresh(count=0){
  newGame();w.$gameSwitches.setValue(2494,true);
  const ids=count?[106,101,100,102,104].slice(0,count):[1];
  w.$gameParty._actors=w.Array.from(ids);w.$gameParty._battleMembers=w.Array.from(ids.concat(Array(5-ids.length).fill(0)));
  ids.forEach(id=>{const a=w.$gameActors.actor(id);a._level=37;});
  w.$gameSystem.setDifficultyId(3);w.$gameParty._inBattle=false;w.$gameTroop.clear();
  w.BattleManager._actionBattlers=[];w.BattleManager._nextTurnActionBattlers=[];
}
function snap(e,name){return {name,id:e.enemyId(),count:e._codexBossStrongCount,boss:D.isBoss(e),rate:D.attributeRate(e),armor:D.hasHyperArmor(e),
  hp:e.hp,mp:e.mp,param:Array.from({length:8},(_,i)=>e.param(i)),states:Array.from(e._states),turns:Object.fromEntries(Object.entries(e._stateTurns).filter(([id])=>e.isStateAffected(+id)))};}
const cases=[];
for(const count of [0,1,3,5])for(const id of [1,6,947])cases.push(makeCase(`setup.${count}.${id}`,{count,id},()=>{
  fresh(count);const e=new w.Game_Enemy(id,0,0),rows=[snap(e,'setup')];
  w.$gameParty._inBattle=true;e.onBattleStart();e.refresh();rows.push(snap(e,'cached'));
  for(let i=0;i<3;i++)rows.push(snap(e,'repeat'+i));
  e.addState(4);e.refresh();rows.push(snap(e,'debuff'));e.removeState(4);e.refresh();rows.push(snap(e,'removed'));
  w.$gameParty._battleMembers=w.Array.from([1,0,0,0,0]);rows.push(snap(e,'party_changed'));
  return {rows};
}));
for(const count of [0,3])cases.push(makeCase(`turns.${count}`,{count},()=>{
  fresh(count);w.$gameTroop.setup(1);const e=w.$gameTroop.members()[0];e.transform(6);const rows=[snap(e,'setup')];
  for(let n=1;n<=6;n++){if(n===2){e.addState(6);e.addState(7);e.addState(4);}w.$gameTroop.increaseTurn();rows.push(snap(e,'turn'+n));
    if(n===2){for(const op of ['removeState','eraseState','removeStateCompletely']){e[op](2651);rows.push(snap(e,op));}
      for(const id of [6,7,8,10,4]){e.addState(id);rows.push(snap(e,'add'+id));}
      e.addNewState(6);rows.push(snap(e,'direct6'));e.recoverAll();rows.push(snap(e,'recover'));}}
  // 真实endBattle包装与原流程，不替换数值或清理方法。
  w.BattleManager.endBattle(1);rows.push(snap(e,'end'));return {rows};
}));
for(const count of [0,3])for(const turn of [0,1,2,3])cases.push(makeCase(`transform.${count}.${turn}`,{count,turn},()=>{
  fresh(count);w.$gameTroop.setup(1);const e=w.$gameTroop.members()[0];
  w.$gameParty._inBattle=true;e.onBattleStart();e.refresh();
  for(let n=0;n<turn;n++)w.$gameTroop.increaseTurn();
  const rows=[snap(e,'before')];for(const id of [6,1,947,6]){e.transform(id);rows.push(snap(e,'to'+id));}return {rows};
}));
for(const mode of ['death','hidden_death','hp0','remove_dead','recover'])cases.push(makeCase('death.'+mode,{mode},()=>{
  fresh(3);w.$gameTroop.setup(1);const e=w.$gameTroop.members()[0];e.transform(6);w.$gameTroop.increaseTurn();w.$gameTroop.increaseTurn();
  const rows=[snap(e,'armor')];if(mode==='hidden_death')e.hide();
  if(mode==='hp0')e._hp=0;else e.addState(1);rows.push(snap(e,'dead'));
  if(mode==='remove_dead'){e.removeState(2651);rows.push(snap(e,'remove'));}
  if(mode==='recover')e.recoverAll();else e.removeState(1);rows.push(snap(e,'revive'));
  D.syncArmor(e,true);rows.push(snap(e,'sync'));return {rows};
}));
for(const count of [0,3])cases.push(makeCase('armor_edges.'+count,{count},()=>{
  fresh(count);w.$gameTroop.setup(1);const e=w.$gameTroop.members()[0];e.transform(6);
  w.$gameTroop.increaseTurn();w.$gameTroop.increaseTurn();const rows=[snap(e,'armor')];
  e.gainHp(-123);rows.push(snap(e,'damage'));e.addDebuff(2,3);rows.push(snap(e,'debuff'));
  e.removeBuff(2);rows.push(snap(e,'remove_debuff'));e.addState(77);rows.push(snap(e,'hp_state'));
  e.removeState(77);rows.push(snap(e,'remove_hp_state'));return {rows};
}));
const controls=w.$dataStates.filter(Boolean).map(s=>({id:s.id,control:D.isControlState(s.id)}));
process.exit(finish(host,'boss_lifecycle.json',{scope:'Boss attributes/cache and2651 lifecycle only;output contexts separate',controls,cases})?0:1);
