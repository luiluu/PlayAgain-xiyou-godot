'use strict';
const {start,makeCase,finish}=require('./shared/host.cjs');
const host=start(),{w,newGame}=host,D=w.CodexBossDifficulty;
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
function add(id,spec){specs.push({id,spec:{count:3,armor:true,sideArmor:true,state:1341,phase:'reactState',origin:'c',target:'b',outer:true,ops:[{op:'gain',who:'b',kind:'hp',value:-7.9}],...spec}});}
add('smoke.origin1341',{origin:'a'});
add('smoke.reflect2550',{state:2550,ops:[{op:'gain',who:'a',kind:'hp',value:-7.9}]});
add('smoke.ordinary',{state:2,origin:'c'});
if(!process.argv.includes('--smoke')){
 for(const state of [1341,2550,2])for(const kind of ['hp','mp'])for(const op of ['gain','set'])for(const who of ['a','b','c'])
  add(`matrix.${state}.${kind}.${op}.${who}`,{state,ops:[{op,who,kind,value:op==='gain'?-7.9:292.1}]});
 for(const state of [1341,2550,2])for(const origin of ['a','b','c','none'])add(`origin.${state}.${origin}`,{state,origin,ops:[{op:'gain',who:state===2550?'a':'b',kind:'hp',value:-7.9}]});
 for(const state of [1341,2550])for(const phase of ['confirmState','respondState'])add(`ordinary.${state}.${phase}`,{state,phase});
 for(const state of [1341,2550])for(const sideArmor of [false,true])for(const count of [0,3])add(`rate.${state}.${+sideArmor}.${count}`,{state,sideArmor,count,ops:[{op:'gain',who:state===2550?'a':'b',kind:'mp',value:-7.9}]});
 for(const state of [1341,2550])for(const shield of [3,1000])add(`shield.${state}.${shield}`,{state,shield,ops:[{op:'gain',who:state===2550?'a':'b',kind:'hp',value:-101}]});
 add('different_target',{target:'c',ops:[{op:'gain',who:'c',kind:'hp',value:-7.9}]});
 add('heal',{ops:[{op:'gain',who:'b',kind:'hp',value:9.5}]});
 add('tp',{state:2550,ops:[{op:'gain',who:'a',kind:'tp',value:-7.9}]});
 add('no_outer1341',{outer:false,origin:'a'});
 add('no_outer2550',{outer:false,state:2550,ops:[{op:'gain',who:'a',kind:'hp',value:-7.9}]});
}
const cases=[];
for(const {id,spec} of specs)cases.push(makeCase(id,spec,()=>{
 console.log('CASE_START '+id);newGame();errors.length=0;w.$gameSwitches.setValue(2494,true);w.$gameSystem.setDifficultyId(3);
 const ids=spec.count?[106,101,100].slice(0,spec.count):[1];w.$gameParty._actors=w.Array.from(ids);w.$gameParty._battleMembers=w.Array.from(ids.concat(Array(5-ids.length).fill(0)));
 w.$gameTroop.clear();w.CodexYunshang._acted=w.Array.from([]);w.BattleManager._actionBattlers=w.Array.from([]);w.BattleManager._nextTurnActionBattlers=w.Array.from([]);
 const a=new w.Game_Enemy(6,0,0),b=new w.Game_Enemy(6,0,0),c=new w.Game_Enemy(6,0,0);w.$gameTroop._enemies=w.Array.from([a,b,c]);w.$gameParty._inBattle=true;
 for(const x of [a,b,c]){x.onBattleStart();x.refresh();}D.syncArmor(a,spec.armor);D.syncArmor(b,spec.sideArmor);
 for(const x of [a,b,c]){x._hp=Math.min(300,x.mhp);x._mp=Math.min(300,x.mmp);x._tp=20;x._shield=0;x.clearResult();}
 (spec.state===2550?a:b)._shield=spec.shield||0;
 const bs={a,b,c},rows=[],before=Object.fromEntries(Object.entries(bs).map(([k,x])=>[k,snap(x)]));
 const saved=w.$dataStates[spec.state],state=JSON.parse(JSON.stringify(saved));state.customEffectEval[spec.phase]='window.__bossReactStep();';w.$dataStates[spec.state]=state;
 b.clearStateOrigin(spec.state);if(spec.origin!=='none')b.setStateOrigin(spec.state,bs[spec.origin]);
 w.__bossReactStep=()=>{for(const op of spec.ops){const x=bs[op.who],pre=snap(x),method=(op.op==='gain'?'gain':'set')+({hp:'Hp',mp:'Mp',tp:'Tp'}[op.kind]);x[method](op.value);rows.push({op:{...op},before:pre,after:snap(x)});}};
 const action=new w.Game_Action(a),item=JSON.parse(JSON.stringify(w.$dataSkills[1]));action.setSkill(1);action.item=()=>item;
 let returned;w.__bossReactCall=()=>{returned=action.customEffectEval(bs[spec.target],spec.state,spec.phase,b,17);};item.customPostDamageEval='window.__bossReactCall();';w.BattleManager._subject=c;
 try{if(spec.outer)action.applyPostDamageEval(bs[spec.target],0);else w.__bossReactCall();}finally{w.$dataStates[spec.state]=saved;}
 if(errors.length)throw Error('unexpected eval diagnostic '+JSON.stringify(errors));if(rows.length!==spec.ops.length)throw Error('host did not execute');
 const pre=snap(b);b.gainHp(-1);rows.push({op:{op:'outside',who:'b',kind:'hp',value:-1},before:pre,after:snap(b)});
 return {returned,before,rows,after:Object.fromEntries(Object.entries(bs).map(([k,x])=>[k,snap(x)]))};
}));
process.exit(finish(host,process.argv.includes('--smoke')?'boss_react_smoke.json':'boss_react.json',{scope:'Native Action customEffectEval special react1341/2550 domains; synthetic resource scripts, original hosts unchanged',cases})?0:1);
