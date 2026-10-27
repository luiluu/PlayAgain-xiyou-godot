'use strict';
// Integration-only native host measurements; synthetic scripts isolate the merged helpers.
const {start,makeCase,finish}=require('./shared/host.cjs');
const host=start(),{w,newGame}=host,D=w.CodexBossDifficulty;
w.BattleManager.otbDisplayWindow=()=>({createReturnedBattlerSprite(){}});
w.Game_Battler.prototype.battler=function(){return new Proxy({}, {get:()=>()=>false,set:()=>true});};
w.Game_Battler.prototype.startDamagePopup=function(){};
w.Game_Battler.prototype.startAnimation=function(){};
w.Game_Battler.prototype.performCollapse=function(){};
const errors=[];w.Yanfly.Util.displayError=(e,code,kind)=>errors.push({kind,thrown:String(e.message||e)});
function snap(b){const r=b.result();return {hp:b.hp,shield:b.shield,dirty:!!b.need_refresh,states:Array.from(b._states),result:Object.fromEntries(['hpAffected','hpDamage','mpDamage','tpDamage','addedStates','removedStates'].map(k=>[k,Array.isArray(r[k])?Array.from(r[k]):r[k]]))};}
const cases=[];
for(const op of ['poison','gain','add'])for(const count of [0,3])for(const shield of [0,20])cases.push(makeCase(`${op}.${count}.${shield}`,{op,count,shield},()=>{
 newGame();errors.length=0;w.$gameSwitches.setValue(2494,true);w.$gameSystem.setDifficultyId(3);
 const ids=count?[106,101,100]:[1];w.$gameParty._actors=w.Array.from(ids);w.$gameParty._battleMembers=w.Array.from(ids.concat(Array(5-ids.length).fill(0)));
 w.$gameTroop.clear();w.CodexYunshang._acted=w.Array.from([]);w.BattleManager._actionBattlers=w.Array.from([]);w.BattleManager._nextTurnActionBattlers=w.Array.from([]);
 const a=new w.Game_Enemy(6,0,0),b=new w.Game_Enemy(6,0,0);w.$gameTroop._enemies=w.Array.from([a,b]);w.$gameParty._inBattle=true;
 for(const x of [a,b]){x.onBattleStart();x.refresh();}D.syncArmor(a,true);
 for(const x of [a,b])for(const [key,v] of Object.entries({mhp:5000,mmp:300,atk:7,mat:3}))Object.defineProperty(x,key,{configurable:true,get:()=>v});
 for(const x of [a,b]){x._hp=300;x._mp=300;x._tp=20;x._shield=0;x.clearResult();}
 b._shield=shield;
 const old=w.$dataStates[2997],s=JSON.parse(JSON.stringify(w.$dataStates[2]));s.id=2997;s.customEffectEval=Object.fromEntries(Object.keys(s.customEffectEval).map(k=>[k,'']));s.customEffectEval.addState='user.gainHp(-7.9);';w.$dataStates[2997]=s;
 const oldOuter=w.$dataStates[2998],outer=JSON.parse(JSON.stringify(s));outer.id=2998;outer.customEffectEval.addState='';outer.customEffectEval.battle=op==='add'?'user.addState(2997);':'user.gainHp(-7.9);';w.$dataStates[2998]=outer;
 b.setStateOrigin(2998,a);b.setStateOrigin(460,a);w.BattleManager._subject=a;
 if(op==='poison'){b._states=w.Array.from([460]);b._stackingPoison=1;}
 const before=snap(b);
 try{if(op==='poison')b.regenerateStateEffects(460);else b.customEffectEval(2998,'battle');}
 finally{w.$dataStates[2997]=old;w.$dataStates[2998]=oldOuter;}
 if(errors.length)throw Error(JSON.stringify(errors));
 return {rate:D.outputRate(a),before,after:snap(b)};
}));
process.exit(finish(host,'state_merge_context.json',{scope:'merged poison / gain_steps / nested add_state under native Boss origin domains',cases})?0:1);
