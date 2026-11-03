'use strict';
// 真实YEP数值行动序列入口；只读冻结源、内存新局，只写.sandbox。
const {start,makeCase,finish}=require('./shared/host.cjs');
const host=start(),{w,newGame}=host,D=w.CodexBossDifficulty;
w.eval('CodexZones.ENABLED=false;');  // 五乘区（CodexZones）重制不移植（O-044），探针宿主默认开着；关掉让参照不含成长修正（tools50 确认关与不关产物一致或已更新夹具）
w.BattleManager.otbDisplayWindow=()=>({createReturnedBattlerSprite(){}});
const sprites=new Map();
w.Game_Battler.prototype.battler=function(){
 if(!sprites.has(this))sprites.set(this,new Proxy({}, {get:(t,k)=>k in t?t[k]:(()=>false),set:(t,k,v)=>{t[k]=v;return true;}}));return sprites.get(this);
};
const snap=b=>{const r=b.result();return {hp:b.hp,mp:b.mp,tp:b.tp,shield:b.shield,dirty:!!b.need_refresh,states:Array.from(b._states),
 result:Object.fromEntries(['hpAffected','hpDamage','mpDamage','tpDamage','addedStates','removedStates'].map(k=>[k,Array.isArray(r[k])?Array.from(r[k]):r[k]]))};};
const specs=[];
const add=(id,spec)=>specs.push({id,spec:{count:3,armor:true,entry:'process',kind:'HP',change:'-7',selector:'TARGETS',targets:['b','c'],...spec}});
add('smoke.hp',{entry:'direct'});add('smoke.mp',{kind:'MP'});add('smoke.lethal',{targets:['b'],change:'-1000'});
if(!process.argv.includes('--smoke')){
 for(const entry of ['process','direct'])for(const count of [0,3])for(const armor of [false,true])for(const kind of ['HP','MP'])for(const change of ['-7','+0','+9'])
  add(`matrix.${entry}.${count}.${+armor}.${kind}.${change}`,{entry,count,armor,kind,change});
 for(const kind of ['HP','MP'])for(const selector of ['USER','ENEMIES','ENEMY 1','ACTORS','ACTOR 0','FIRST','NONE'])
  add(`selector.${kind}.${selector}`,{kind,selector,targets:['b']});
 for(const kind of ['HP','MP']){
  add(`repeat.${kind}`,{kind,targets:['b','b','c']});
  add(`self.${kind}`,{kind,targets:['a','b']});
  add(`stale.${kind}`,{kind,stale:true});
  add(`empty.${kind}`,{kind,targets:[]});
  add(`actorSource.${kind}`,{kind,actorSource:true});
  add(`ordinarySource.${kind}`,{kind,enemy:1});
  add(`percent.${kind}`,{kind,change:'-10%'});
  add(`variable.${kind}`,{kind,change:'-VAR 20',variable:7.9});
 }
 add('interleaved.results',{targets:['b'],interleaved:true});
 for(const actorTarget of [false,true])for(const shield of [3,50,1000])
  add(`shield.${+actorTarget}.${shield}`,{actorTarget,shield,targets:['b'],change:'-101'});
}
const onlyAt=process.argv.indexOf('--only'),only=onlyAt>=0?new RegExp(process.argv[onlyAt+1]):null;
const cases=specs.filter(row=>!only||only.test(row.id)).map(({id,spec})=>makeCase(id,spec,()=>{
 console.log('CASE_START '+id);newGame();w.$gameSwitches.setValue(2494,true);w.$gameSystem.setDifficultyId(3);
 const ids=spec.count?[106,101,100,102,104].slice(0,spec.count):[1];
 w.$gameParty._actors=w.Array.from(ids);w.$gameParty._battleMembers=w.Array.from(ids.concat(Array(5-ids.length).fill(0)));
 w.$gameTroop.clear();w.CodexYunshang._acted=w.Array.from([]);w.BattleManager._actionBattlers=w.Array.from([]);w.BattleManager._nextTurnActionBattlers=w.Array.from([]);
 const boss=new w.Game_Enemy(spec.enemy||6,0,0),actor=w.$gameActors.actor(1),other=new w.Game_Enemy(6,0,0),c=new w.Game_Enemy(6,0,0);
 const a=spec.actorSource?actor:boss,b=spec.actorTarget?actor:other,bs={a,b,c};
 for(const x of w.$gameParty.battleMembers())if(!Object.values(bs).includes(x))bs['p'+x.actorId()]=x;
 w.$gameTroop._enemies=w.Array.from([boss,other,c]);w.$gameParty._inBattle=true;
 for(const x of new Set([boss,actor,other,c,...Object.values(bs)])){x.onBattleStart();x.refresh();}
 D.syncArmor(boss,spec.armor);
 for(const x of new Set([boss,actor,other,c,...Object.values(bs)])){x._hp=Math.min(500,x.mhp);x._mp=Math.min(300,x.mmp);x._tp=0;x._shield=0;x.clearResult();}
 b._shield=spec.shield||0;
 const BM=w.BattleManager,action=new w.Game_Action(a);action.setSkill(1);BM._action=action;BM._subject=spec.stale?c:a;
 BM._targets=w.Array.from(spec.targets.map(k=>bs[k]));BM._allTargets=BM._targets.slice();
 if(spec.variable!==undefined)w.$gameVariables.setValue(20,spec.variable);
 const before=Object.fromEntries(Object.entries(bs).map(([k,v])=>[k,snap(v)]));
 const command=spec.kind+' '+spec.change,args=w.Array.from([spec.selector]);
 const resolved=BM.makeActionTargets(spec.selector).map(x=>Object.entries(bs).find(([,v])=>v===x)?.[0]||'party');
 const returned=spec.entry==='direct'?BM[spec.kind==='HP'?'actionHpModify':'actionMpModify'](command,args):BM.processActionSequence(command,args);
 if(spec.interleaved){action.executeMpDamage(b,5);BM._targets=w.Array.from([c]);BM.processActionSequence(command,args);}
 const after=Object.fromEntries(Object.entries(bs).map(([k,v])=>[k,snap(v)]));
 const outsideBefore=snap(b);b.gainHp(-1);const outsideAfter=snap(b);
 return {rate:D.outputRate(a),resolved,returned,before,after,outsideBefore,outsideAfter};
}));
process.exit(finish(host,process.argv.includes('--smoke')?'boss_sequence_smoke.json':only?'boss_sequence_selected.json':'boss_sequence.json',
 {scope:'Numeric YEP processActionSequence/actionHpModify/actionMpModify; no generic EVAL host migration claim',cases})?0:1);
