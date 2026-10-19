'use strict';
// Actual frozen YEP evaluation/apply and installed resource hooks, all fixtures in memory.
// This reference is a prerequisite for formula phase 2, not a claim of Godot support.
const crypto = require('crypto');
const {start, makeCase, finish} = require('./shared/host.cjs');
const host=start(), w=host.w, cases=[];
host.newGame();
w.$gameParty._inBattle=true;
w.ConfigManager.CombatDamageShow=true;
const subjectParams=[10000,101,100,100,100,100,100,100];
const targetParams=[10000,1000,100,100,100,100,100,100];
const result=b=>({hpAffected:b.result().hpAffected,hpDamage:b.result().hpDamage,
  mpDamage:b.result().mpDamage,tpDamage:b.result().tpDamage,success:b.result().success,
  missed:b.result().missed,evaded:b.result().evaded,critical:b.result().critical,
  addedStates:Array.from(b.result().addedStates),removedStates:Array.from(b.result().removedStates)});
const snapshot=b=>({resources:[b.hp,b.mp,b.tp],caps:[b.mhp,b.mmp,b.maxTp()],states:Array.from(b._states),
  stateTurns:{...b._stateTurns},buffs:Array.from(b._buffs),buffTurns:Array.from(b._buffTurns),
  alive:b.isAlive(),dead:b.isDead(),immortal:!!b.isImmortal(),result:result(b)});
const stub=new Proxy(function(){},{get:(_t,k)=>k==='_waitCount'?0:(()=>false),set:()=>true});
function fixture(setup) {
  w.BattleManager.setup(157,true,false);
  w.BattleManager._logWindow=stub;w.BattleManager._spriteset=stub;w.BattleManager._statusWindow=stub;
  w.BattleManager.startBattle();
  const enemy=w.$gameTroop.members()[0];
  const a=setup.pair==='enemy_actor'?enemy:w.$gameActors.actor(1);
  const b=setup.pair==='actor_enemy'?enemy:setup.pair==='self'?a:w.$gameActors.actor(8);
  for(const [battler,params] of [[a,subjectParams],[b,targetParams]]) {
    // Same fixed-cap fixtures as the retained 48 cases; hook chain remains native.
    battler.param=i=>params[i];battler.maxTp=()=>200;
    battler._states=new w.Array();battler._stateTurns={};battler._buffs=new w.Array(8).fill(0);battler._buffTurns=new w.Array(8).fill(0);
    battler._immortalState=false;battler._hp=10000;battler._mp=100;battler._tp=55;
    battler._shield=0;battler.clearResult();battler._damagePopup=[];
  }
  if(setup.deathResist) {
    const original=b.isStateResist;
    b.isStateResist=function(id){return id===1 || original.call(this,id);};
  }
  if(setup.permanent) {b._states=w.Array.of(995);b._stateTurns={995:7};}
  if(setup.capState) {
    // Synthetic state fixture: removal changes the native param getter immediately.
    // Separate from fixed-cap cases; exposes the order of reads after HP death.
    const id=29999;
    w.$dataStates[id]={...w.$dataStates[2],id,name:'formula-cap-fixture',meta:{},note:'',traits:new w.Array()};
    b._states=w.Array.of(id);b._stateTurns={[id]:4};
    b.param=i=>targetParams[i]*(i===1 && b.isStateAffected(id)?2:1);
  }
  b._hp=setup.resources[0];b._mp=setup.resources[1];b._tp=setup.resources[2];
  b._immortalState=!!setup.immortal;
  if(setup.buffs) {b._buffs[1]=2;b._buffTurns[1]=5;}
  if(setup.removedDeath) b.result().pushRemovedState(1);
  if(setup.alreadyDead) {b._states=w.Array.of(1);b._stateTurns={1:9};b._hp=0;}
  w.BattleManager._subject=a;w.BattleManager._targets=w.Array.of(b);w.BattleManager._allTargets=w.Array.of(b);
  const action=new w.Game_Action(a);action.setSkill(setup.skill||857);
  if(setup.formula) {
    const original=action.item();
    const item={...original,damage:{...original.damage,custom:true,formula:setup.formula}};
    action.item=()=>item;
  }
  if(setup.mode==='miss') action.itemHit=()=>0;
  if(setup.mode==='evade') {action.itemHit=()=>1;action.itemEva=()=>1;}
  const journal=[],diagnostics=[];
  let draws=0;
  w.Math.random=()=>{draws++;return 0.5;};
  for(const battler of new Set([a,b])) for(const [method,resource] of [['gainHp','hp'],['gainMp','mp'],['gainTp','tp']]) {
    const original=battler[method];
    battler[method]=function(delta){
      const entry={receiver:this===a?'a':'b',resource,requestedDelta:delta,before:snapshot(this)};
      journal.push(entry);
      try {return original.call(this,delta);} finally {
        entry.after=snapshot(this);entry.actualDelta=this[resource]-entry.before.resources[{hp:0,mp:1,tp:2}[resource]];
      }
    };
  }
  const display=w.Yanfly.Util.displayError;
  w.Yanfly.Util.displayError=(error,_code,label)=>{if(!setup.throwRead)throw error;diagnostics.push({label,message:String(error.message||error)});};
  const originalMastery=a.skillMasteryLevel;
  if(setup.throwRead) a.skillMasteryLevel=()=>{throw Error('formula-read-fixture');};
  let value=null;
  const before={a:snapshot(a),b:snapshot(b)};
  try {
    if(setup.mode==='eval'||!setup.mode) value=action.evalDamageFormula(b);
    else if(setup.mode==='repeat') {action.apply(b);action.apply(b);}
    else if(setup.mode==='reflect') {w.BattleManager._action=action;w.BattleManager.invokeMagicReflection(a,b);}
    else if(setup.mode==='counter') {
      const prior=b.attackSkillId;b.attackSkillId=()=>857;
      try{w.BattleManager.invokeCounterAttack(a,b);}finally{b.attackSkillId=prior;}
    } else action.apply(b);
    const after={a:snapshot(a),b:snapshot(b)};
    b._damagePopup=[];b.startDamagePopup();
    const popup=b._damagePopup.map(x=>({hpAffected:x.hpAffected,hpDamage:x.hpDamage,mpDamage:x.mpDamage,tpDamage:x.tpDamage,
      missed:x.missed,evaded:x.evaded,addedStates:Array.from(x.addedStates),removedStates:Array.from(x.removedStates)}));
    return {value,before,after,journal,randomDraws:draws,diagnostics,popup,
      formulaSHA256:crypto.createHash('sha256').update(action.item().damage.formula).digest('hex')};
  } finally {
    w.Yanfly.Util.displayError=display;a.skillMasteryLevel=originalMastery;
    // Instance wrappers and fixture overrides must not accumulate across cases.
    for(const battler of new Set([a,b])) for(const key of ['gainHp','gainMp','gainTp','param','maxTp','isStateResist']) delete battler[key];
    w.Math.random=()=>0.5;
  }
}
module.exports={host,fixture};
if(require.main===module){
for(const skill of [857,858,4013]) for(const pair of ['actors','enemy_actor','actor_enemy','self'])
for(const resources of [[10000,220,123],[450,1,1],[3000,0,0],[3001,201,200]]) for(const immortal of [false,true]) {
  const setup={skill,pair,resources,immortal,mode:'eval'};
  cases.push(makeCase(`eval.${skill}.${pair}.${resources.join('_')}.${immortal}`,setup,()=>fixture(setup)));
}
for(const flags of [{deathResist:true},{permanent:true},{capState:true,buffs:true},{removedDeath:true},{alreadyDead:true}]) {
  const setup={pair:'actors',resources:[450,1500,123],mode:'eval',...flags};
  cases.push(makeCase('boundary.'+Object.keys(flags).join('_'),setup,()=>fixture(setup)));
}
for(const mode of ['apply','miss','evade']) for(const resources of [[10000,220,123],[450,1,1]]) {
  const setup={pair:'enemy_actor',resources,mode};
  cases.push(makeCase(`${mode}.${resources.join('_')}`,setup,()=>fixture(setup)));
}
for(const [id,formula,throwRead] of [
  ['zero','b.gainHp(0); b.gainMp(0); b.gainTp(0); value=1;',false],
  ['lazy','if(false){b.gainHp(-99);} value=2;',false],
  ['after_write_error','b.gainHp(-7); value=a.skillMasteryLevel(1); b.gainMp(-9);',true],
  ['before_write_error','value=a.skillMasteryLevel(1); b.gainHp(-7);',true],
  ['repeated','b.gainHp(-3000); b.gainMp(-4); b.gainTp(-3); b.gainHp(0); value=b.mp;',false]]) {
  const setup={pair:'actors',resources:[450,220,123],mode:'eval',formula,throwRead};
  cases.push(makeCase('language.'+id,setup,()=>fixture(setup)));
}
process.exit(finish(host,'formula_effects.json',{hostScope:'ordered-resource-reference-only',cases})?0:1);

}
