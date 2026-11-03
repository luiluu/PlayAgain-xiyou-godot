'use strict';
// Original event313 and menu-effect entry, with old result slots deliberately retained.
const {start,makeCase,finish}=require('./shared/host.cjs');
const host=start(),{w,newGame}=host;
w.eval('CodexZones.ENABLED=false;');  // 五乘区（CodexZones）重制不移植（O-044），探针宿主默认开着；关掉让参照不含成长修正（tools50 确认关与不关产物一致或已更新夹具）
w.Game_Battler.prototype.battler=function(){return new Proxy({}, {get:()=>()=>false,set:()=>true});};
const errors=[];w.Yanfly.Util.displayError=(e,code,kind)=>errors.push({kind,thrown:String(e.message||e)});
function snap(a,name){const r=a.result();return {name,hp:a.hp,mp:a.mp,tp:a.tp,states:Array.from(a._states),turns:{...a._stateTurns},result:Object.fromEntries(['hpAffected','hpDamage','mpDamage','tpDamage','addedStates','removedStates'].map(k=>[k,Array.isArray(r[k])?Array.from(r[k]):r[k]]))};}
const cases=[];
for(const entry of ['event313','menuEffect'])for(const sid of [1334,1336])for(const tp of [10,95])cases.push(makeCase(`${entry}.${sid}.${tp}`,{entry,sid,tp},()=>{
 newGame();errors.length=0;w.$gameParty._actors=w.Array.from([1]);w.$gameParty._inBattle=false;w.BattleManager._subject=null;
 const a=w.$gameActors.actor(1);a._states=new w.Array();a._stateTurns={};a._skills=new w.Array();a._equips.forEach(e=>e.setObject(null));a.refresh();
 for(const [key,value] of Object.entries({mhp:1000,mmp:300}))Object.defineProperty(a,key,{configurable:true,get:()=>value});
 a._hp=500;a._mp=100;a._tp=tp;a.clearResult();Object.assign(a.result(),{hpAffected:true,hpDamage:17,mpDamage:4,tpDamage:9});a.result().addedStates.push(44);a.result().removedStates.push(18);
 const action=new w.Game_Action(a);action.setSkill(1);const item=JSON.parse(JSON.stringify(w.$dataSkills[1]));item.hitType=0;action.item=()=>item;
 const interpreter=new w.Game_Interpreter();
 function step(remove){if(entry==='event313'){interpreter._params=w.Array.from([0,1,remove?1:0,sid]);interpreter.command313();}else if(remove)action.itemEffectRemoveState(a,{dataId:sid,value1:1,value2:0});else action.itemEffectAddNormalState(a,{dataId:sid,value1:1,value2:0});}
 const rows=[snap(a,'before')];step(false);rows.push(snap(a,'add'));step(false);rows.push(snap(a,'reapply'));step(true);rows.push(snap(a,'remove'));step(false);rows.push(snap(a,'blocked_reapply'));a.clearResult();rows.push(snap(a,'clear'));step(false);rows.push(snap(a,'after_clear_add'));
 if(errors.length)throw Error(JSON.stringify(errors));return {rows};
}));
process.exit(finish(host,'state_operation.json',{scope:'actual event313 and itemEffectAddNormalState / RemoveState for1334/1336; original old result slots',cases})?0:1);
