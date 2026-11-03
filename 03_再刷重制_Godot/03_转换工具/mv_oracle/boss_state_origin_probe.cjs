'use strict';
const {start,makeCase,finish}=require('./shared/host.cjs');
const host=start(),{w,newGame}=host,D=w.CodexBossDifficulty;
w.eval('CodexZones.ENABLED=false;');  // 五乘区（CodexZones）重制不移植（O-044），探针宿主默认开着；关掉让参照不含成长修正（tools50 确认关与不关产物一致或已更新夹具）
w.BattleManager.otbDisplayWindow=()=>({createReturnedBattlerSprite(){}});
const sprites=new Map();
w.Game_Battler.prototype.battler=function(){
 if(!sprites.has(this))sprites.set(this,new Proxy({}, {get:(t,k)=>k in t?t[k]:(()=>false),set:(t,k,v)=>{t[k]=v;return true;}}));return sprites.get(this);
};
const errors=[];
w.Yanfly.Util.displayError=(e,code,kind)=>errors.push({kind,thrown:String(e.message||e)});
function snap(b){const r=b.result();return {hp:b.hp,mp:b.mp,tp:b.tp,shield:b.shield,dirty:!!b.need_refresh,states:Array.from(b._states),
 result:Object.fromEntries(['hpAffected','hpDamage','mpDamage','tpDamage','addedStates','removedStates'].map(k=>[k,Array.isArray(r[k])?Array.from(r[k]):r[k]]))};}
const specs=[];
function add(id,spec){specs.push({id,spec:{count:3,armor:true,phase:'turnEndState',origin:'a',outer:'none',ops:[{op:'gain',who:'b',kind:'hp',value:-7.9}],...spec}});}
add('smoke.origin',{});
add('smoke.low_shadows',{origin:'c',outer:'b'});
add('smoke.death',{ops:[{op:'gain',who:'b',kind:'hp',value:-1000},{op:'gain',who:'b',kind:'hp',value:500}]});
if(!process.argv.includes('--smoke')){
 for(const phase of ['addState','removeState','leaveState','turnStartState','turnEndState','regenerateState','actionStartState','actionEndState','battle','victory','escape','defeat'])
  for(const origin of ['a','c','b','none','missing'])add(`phase.${phase}.${origin}`,{phase,origin,outer:'b'});
 for(const count of [0,3])for(const armor of [false,true])for(const kind of ['hp','mp'])for(const op of ['gain','set'])
  for(const who of ['a','b','c'])add(`matrix.${count}.${+armor}.${kind}.${op}.${who}`,{count,armor,ops:[{op,who,kind,value:op==='gain'?-7.9:292.1}]});
 for(const actorTarget of [false,true])for(const shield of [3,50,1000])add(`shield.${+actorTarget}.${shield}`,{actorTarget,shield,ops:[{op:'gain',who:'b',kind:'hp',value:-101}]});
 add('heal',{ops:[{op:'gain',who:'b',kind:'hp',value:9.5}]});
 add('tp',{ops:[{op:'gain',who:'b',kind:'tp',value:-7.9}]});
 add('nested.low',{outer:'b',ops:[{op:'gain',who:'b',kind:'hp',value:-7},{op:'nested',origin:'c',ops:[{op:'gain',who:'b',kind:'hp',value:-7}]},{op:'gain',who:'b',kind:'hp',value:-7}]});
 add('nested.caught',{ops:[{op:'nested',origin:'c',ops:[{op:'gain',who:'b',kind:'hp',value:-7},{op:'throw'}]},{op:'gain',who:'b',kind:'hp',value:-7}]});
}
const cases=[];
for(const {id,spec} of specs)cases.push(makeCase(id,spec,()=>{
 console.log('CASE_START '+id);newGame();errors.length=0;w.$gameSwitches.setValue(2494,true);w.$gameSystem.setDifficultyId(3);
 const ids=spec.count?[106,101,100].slice(0,spec.count):[1];
 w.$gameParty._actors=w.Array.from(ids);w.$gameParty._battleMembers=w.Array.from(ids.concat(Array(5-ids.length).fill(0)));
 w.$gameTroop.clear();w.CodexYunshang._acted=w.Array.from([]);w.BattleManager._actionBattlers=w.Array.from([]);w.BattleManager._nextTurnActionBattlers=w.Array.from([]);
 const a=new w.Game_Enemy(6,0,0),other=new w.Game_Enemy(6,0,0),c=new w.Game_Enemy(6,0,0),b=spec.actorTarget?w.$gameActors.actor(1):other;
 w.$gameTroop._enemies=w.Array.from([a,other,c]);w.$gameParty._inBattle=true;
 for(const x of [a,b,c]){x.onBattleStart();x.refresh();}
 D.syncArmor(a,spec.armor);
 for(const x of [a,b,c]){x._hp=Math.min(300,x.mhp);x._mp=Math.min(300,x.mmp);x._tp=20;x._shield=0;x.clearResult();}
 b._shield=spec.shield||0;
 const bs={a,b,c},rows=[],before=Object.fromEntries(Object.entries(bs).map(([k,x])=>[k,snap(x)]));
 // Only script-bearing state data is synthetic; the native customEffectEval host and wrappers stay intact.
 const stateId=2998, savedState=w.$dataStates[stateId],state=JSON.parse(JSON.stringify(w.$dataStates[2]));
 state.id=stateId;state.customEffectEval=Object.fromEntries(Object.keys(state.customEffectEval).map(k=>[k,'']));
 state.customEffectEval[spec.phase]='window.__stateOriginStep();';w.$dataStates[stateId]=state;
 function setOrigin(origin){b.clearStateOrigin(stateId);if(origin==='missing')b._stateOrigin[stateId]=w.Array.from([1,999]);else if(origin!=='none')b.setStateOrigin(stateId,bs[origin]);}
 function run(ops){for(const op of ops){
  if(op.op==='throw')throw Error('boss-state-origin-probe');
  if(op.op==='nested'){const saved=w.__stateOriginStep,old=b._stateOrigin[stateId];setOrigin(op.origin);w.__stateOriginStep=()=>run(op.ops);try{b.customEffectEval(stateId,spec.phase);}finally{w.__stateOriginStep=saved;b._stateOrigin[stateId]=old;}continue;}
  const x=bs[op.who],pre=snap(x),method=(op.op==='gain'?'gain':'set')+({hp:'Hp',mp:'Mp',tp:'Tp'}[op.kind]);x[method](op.value);rows.push({op:{...op},before:pre,after:snap(x)});
 }}
 setOrigin(spec.origin);w.__stateOriginStep=()=>run(spec.ops);w.BattleManager._subject=c;
 try{
  if(spec.outer==='none')b.customEffectEval(stateId,spec.phase);
  else {const action=new w.Game_Action(a),item=JSON.parse(JSON.stringify(w.$dataSkills[1]));action.setSkill(1);action.item=()=>item;item.customPostDamageEval='target.customEffectEval(2998,"'+spec.phase+'");';action.applyPostDamageEval(bs[spec.outer],0);}
 }finally{w.$dataStates[stateId]=savedState;}
 if(errors.some(e=>e.thrown!=='boss-state-origin-probe'))throw Error('unexpected eval diagnostic '+JSON.stringify(errors));
 const pre=snap(b);b.gainHp(-1);rows.push({op:{op:'outside',who:'b',kind:'hp',value:-1},before:pre,after:snap(b)});
 return {rate:D.outputRate(a),before,rows,after:Object.fromEntries(Object.entries(bs).map(([k,x])=>[k,snap(x)])),caught:errors.slice()};
}));
process.exit(finish(host,process.argv.includes('--smoke')?'boss_state_origin_smoke.json':'boss_state_origin.json',{scope:'Battler customEffectEval native stateOrigin domain; synthetic state scripts, original wrappers unchanged',cases})?0:1);
