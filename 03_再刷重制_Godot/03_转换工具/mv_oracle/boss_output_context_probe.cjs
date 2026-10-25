'use strict';
// 冻结原版输出上下文：脚本夹具通过真实apply/executeDamage/postDamageEval进入。
// __bossStep只提供测试脚本的资源操作与观察，不替换引擎结算或上下文方法。
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
const cases=[];
const specs=[];
function add(id,spec){specs.push({id,spec:{count:3,armor:true,host:'post',ops:[],...spec}});}
// 冒烟优先包含过去缺宿主的死亡/复活；--smoke不扩矩阵。
add('smoke.apply',{host:'apply',ops:[{op:'gain',who:'b',kind:'hp',value:-7}]});
add('smoke.post.set',{ops:[{op:'set',who:'b',kind:'mp',value:293}]});
add('smoke.death',{noIcon:true,ops:[{op:'damage',who:'b',kind:'hp',value:1000},{op:'gain',who:'b',kind:'hp',value:500}]});
if(!process.argv.includes('--smoke')){
 for(const hostName of ['apply','execute','post','none'])for(const count of [0,3])for(const armor of [false,true])for(const kind of ['hp','mp'])for(const op of ['gain','set'])
  add(`matrix.${hostName}.${count}.${+armor}.${kind}.${op}`,{host:hostName,count,armor,ops:[{op,who:'b',kind,value:op==='gain'?-7.9:292.1}]});
 for(const kind of ['hp','mp'])for(const op of ['gain','set'])for(const who of ['a','b','c'])for(const value of [-0.4,0,9.5])
  add(`domain.${kind}.${op}.${who}.${value}`,{ops:[{op,who,kind,value:op==='gain'?value:300+value}],hp:300});
 for(const actorTarget of [false,true])for(const op of ['gain','set','damage'])for(const shield of [3,50,1000])
  add(`shield.${+actorTarget}.${op}.${shield}`,{actorTarget,shield,ops:[{op,who:'b',kind:'hp',value:op==='set'?399:op==='gain'?-101:101}]});
 for(const kind of ['hp','mp']){
  add(`formula.${kind}`,{host:'apply',formula:`b.gain${kind==='hp'?'Hp':'Mp'}(-7.9);0`});
  add(`nested.${kind}`,{ops:[{op:'gain',who:'b',kind,value:-7},{op:'nested',source:'c',target:'b',ops:[{op:'gain',who:'b',kind,value:-7}]},{op:'gain',who:'b',kind,value:-7}]});
  add(`caught.${kind}`,{ops:[{op:'nested',source:'a',target:'c',ops:[{op:'gain',who:'c',kind,value:-7},{op:'throw'}]},{op:'gain',who:'b',kind,value:-7}]});
  add(`settled.${kind}`,{host:'apply',ops:[{op:'damage',who:'b',kind,value:7},{op:'gain',who:'b',kind,value:-7}]});
 }
}
const onlyIndex=process.argv.indexOf("--only"),filter=onlyIndex>=0?new RegExp(process.argv[onlyIndex+1]):null;
for(const {id,spec} of specs.filter(row=>!filter||filter.test(row.id)))cases.push(makeCase(id,spec,()=>{
 console.log("CASE_START "+id);
 newGame();errors.length=0;w.$gameSwitches.setValue(2494,true);w.$gameSystem.setDifficultyId(3);
 const ids=spec.count?[106,101,100,102,104].slice(0,spec.count):[1];
 w.$gameParty._actors=w.Array.from(ids);w.$gameParty._battleMembers=w.Array.from(ids.concat(Array(5-ids.length).fill(0)));
 w.$gameTroop.clear();w.CodexYunshang._acted=w.Array.from([]);w.BattleManager._actionBattlers=w.Array.from([]);w.BattleManager._nextTurnActionBattlers=w.Array.from([]);
 const a=new w.Game_Enemy(6,0,0),other=new w.Game_Enemy(6,0,0),c=new w.Game_Enemy(6,0,0),b=spec.actorTarget?w.$gameActors.actor(1):other;
 w.$gameTroop._enemies=w.Array.from([a,other,c]);w.$gameParty._inBattle=true;
 for(const x of [a,b,c]){x.onBattleStart();x.refresh();}
 D.syncArmor(a,spec.armor);if(spec.noIcon){a.addState(1);a.removeState(1);}
 for(const x of [a,b,c]){x._hp=Math.min(spec.hp||500,x.mhp);x._mp=Math.min(300,x.mmp);x._tp=0;x._shield=0;x.clearResult();}
 b._shield=spec.shield||0;
 const bs={a,b,c},rows=[],before=Object.fromEntries(Object.entries(bs).map(([k,x])=>[k,snap(x)]));
 const actionFor=(source,code)=>{const act=new w.Game_Action(source),item=JSON.parse(JSON.stringify(w.$dataSkills[1]));
  item.damage={...item.damage,type:1,formula:'0',custom:false,variance:0,critical:false};item.hitType=0;item.effects=[];item.tpGain=0;
  item.customBeforeEval='';item.customAfterEval='';item.customPreDamageEval='';item.customPostDamageEval=code;
  act.setSkill(1);act.item=()=>item;return act;};
 function run(ops,action){for(const op of ops){
  if(op.op==='throw')throw Error('boss-context-probe');
  if(op.op==='nested'){
   const saved=w.__bossStep,inner=actionFor(bs[op.source],'window.__bossStep();');
   w.__bossStep=()=>run(op.ops,inner);try{inner.applyPostDamageEval(bs[op.target],0);}finally{w.__bossStep=saved;}continue;
  }
  const x=bs[op.who],pre=snap(x),method=(op.op==='gain'?'gain':op.op==='set'?'set':'execute')+(op.kind==='hp'?'Hp':'Mp')+(op.op==='damage'?'Damage':'');
  if(op.op==='damage')action[method](x,op.value);else x[method](op.value);
  rows.push({op:{...op},before:pre,after:snap(x)});
 }}
 const action=actionFor(a,'window.__bossStep();');w.__bossStep=()=>run(spec.ops,action);
 w.BattleManager._subject=c; // stale/incorrect subject must never supply the source
 if(spec.host==='apply'){action.item().damage.formula=spec.formula||'window.__bossStep();0';action.item().customPostDamageEval='';action.apply(b);}
 else if(spec.host==='execute'){action.item().customPreDamageEval='window.__bossStep();';action.item().customPostDamageEval='';action.executeDamage(b,0);}
 else if(spec.host==='post')action.applyPostDamageEval(b,0);else run(spec.ops,action);
 if(errors.some(e=>e.thrown!=="boss-context-probe"))throw Error("unexpected native eval diagnostic: "+JSON.stringify(errors));
 if(spec.formula)rows.push({op:{op:'formula',who:'b'},before:before.b,after:snap(b)});
 if(!rows.length)throw Error("script fixture did not execute");
 // 上下文退出后直接扣同一目标，检查无残留来源/目标域。
 const pre=snap(b);b.gainHp(-1);rows.push({op:{op:'outside',who:'b',kind:'hp',value:-1},before:pre,after:snap(b)});
 return {rate:D.outputRate(a),icon:a.isStateAffected(2651),before,rows,after:Object.fromEntries(Object.entries(bs).map(([k,x])=>[k,snap(x)])),caught:errors.slice()};
}));
process.exit(finish(host,process.argv.includes('--smoke')?'boss_output_context_smoke.json':filter?'boss_output_context_selected.json':'boss_output_context.json',{scope:'Explicit ordinary action scopes; synthetic resource script inputs, native engine wrappers unchanged',cases})?0:1);
