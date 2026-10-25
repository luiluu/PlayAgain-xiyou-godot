'use strict';
// 冻结原版普通HP/MP结算入口；内存新局，只写.sandbox。不替换任何数值方法。
const {start,makeCase,finish}=require('./shared/host.cjs');
const host=start(),{w,newGame}=host,D=w.CodexBossDifficulty;
// 仅省略OTB复活行动条绘图，沿用otb_probe的无界面宿主。
w.BattleManager.otbDisplayWindow=function(){return {createReturnedBattlerSprite:function(){}};};
const sprites=new Map();
w.Game_Battler.prototype.battler=function(){
  if(!sprites.has(this))sprites.set(this,new Proxy({}, {get:(t,k)=>k in t?t[k]:(()=>false),set:(t,k,v)=>{t[k]=v;return true;}}));
  return sprites.get(this);
};
// 冻结库没有MP伤害技能；克隆普通技能，仅把damage.type设成入口边界输入，不替换引擎方法。
const skills={};
for(const [name,type] of [['hp',1],['mp',2],['hpDrain',5],['mpDrain',6]]){
  const original=w.$dataSkills.find(s=>s&&s.damage.type===type);
  if(original){skills[name]=original.id;continue;}
  const rec=JSON.parse(JSON.stringify(w.$dataSkills[1]));rec.id=w.$dataSkills.length;rec.damage.type=type;
  w.$dataSkills.push(rec);skills[name]=rec.id;
}
function snap(b){const r=b.result();return {hp:b.hp,mp:b.mp,tp:b.tp,shield:b.shield,states:Array.from(b._states),
  result:Object.fromEntries(['hpAffected','hpDamage','mpDamage','tpDamage','success','missed','evaded','critical','addedStates','removedStates'].map(k=>[k,Array.isArray(r[k])?Array.from(r[k]):r[k]]))};}
const cases=[];
function add(id,spec){cases.push(makeCase(id,spec,()=>{
  newGame();w.$gameSwitches.setValue(2494,true);w.$gameSystem.setDifficultyId(3);
  const ids=spec.count?[106,101,100,102,104].slice(0,spec.count):[1];
  w.$gameParty._actors=w.Array.from(ids);w.$gameParty._battleMembers=w.Array.from(ids.concat(Array(5-ids.length).fill(0)));
  ids.forEach(id=>w.$gameActors.actor(id)._level=37);
  w.$gameParty._inBattle=false;w.$gameTroop.clear();w.BattleManager._actionBattlers=w.Array.from([]);w.BattleManager._nextTurnActionBattlers=w.Array.from([]);
  const e=new w.Game_Enemy(spec.enemy||6,0,0),other=new w.Game_Enemy(1,0,0),actor=w.$gameActors.actor(1);
  w.$gameTroop._enemies=w.Array.from([e,other]);
  w.$gameParty._inBattle=true;for(const b of [e,other,actor]){b.onBattleStart();b.refresh();}
  D.syncArmor(e,spec.armor);
  if(spec.noIcon){e.addState(1);e.removeState(1);}
  const source=spec.actorSource?actor:e,target=spec.self?source:spec.actorTarget?actor:other;
  for(const b of [e,other,actor]){b._hp=Math.min(500,b.mhp);b._mp=Math.min(300,b.mmp);b._tp=0;b._shield=0;b.clearResult();}
  target._shield=spec.shield||0;
  const action=new w.Game_Action(source);action.setSkill(skills[spec.kind+(spec.drain?'Drain':'')]);
  const before={source:snap(source),target:snap(target)};
  action[spec.kind==='hp'?'executeHpDamage':'executeMpDamage'](target,spec.value);
  return {rate:D.outputRate(source),armor:D.hasHyperArmor(e),icon:e.isStateAffected(2651),before,after:{source:snap(source),target:snap(target)}};
}));}
for(const count of [0,1,3,5])for(const armor of [false,true])for(const kind of ['hp','mp'])for(const value of [7.9,0,-7])
  add(`basic.${count}.${+armor}.${kind}.${value}`,{count,armor,kind,value});
for(const kind of ['hp','mp'])for(const value of [0.9,1000,-19.5])for(const self of [false,true])
  add(`drain.${kind}.${value}.${+self}`,{count:3,armor:true,kind,value,self,drain:true});
for(const actorTarget of [false,true])for(const shield of [3,50])for(const value of [7,101])
  add(`shield.${+actorTarget}.${shield}.${value}`,{count:3,armor:true,kind:'hp',value,actorTarget,shield});
for(const kind of ['hp','mp'])for(const extra of [{enemy:1},{enemy:947},{actorSource:true},{noIcon:true},{self:true}])
  add(`edge.${kind}.${Object.keys(extra)[0]}.${Object.values(extra)[0]}`,{count:3,armor:true,kind,value:11,...extra});
process.exit(finish(host,'boss_output.json',{scope:'Ordinary executeHpDamage/executeMpDamage only; direct resource contexts not yet ported',skills,cases})?0:1);
