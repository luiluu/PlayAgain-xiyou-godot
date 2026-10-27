'use strict';
const {start,makeCase,finish}=require('./shared/host.cjs');
const host=start(),{w,newGame}=host,H=w.CodexHonghuang;
const specs=[1654,1656,1674,1683,1718].map(item=>({id:'book.'+item,item,actor:1}));
if(!process.argv.includes('--smoke'))for(const actor of [106,1,2])specs.push({id:'limit.'+actor,actor,sequence:[1654,1656,1674,1683,1718]});
function snap(a){return {skills:Array.from(a._skills),powers:Array.from(H.learnedPowers(a)),class:H.powerClass(a),limit:H.powerLimit(a),
 param:Array.from({length:8},(_,i)=>a.param(i)),xparam:Array.from({length:10},(_,i)=>a.xparam(i)),sparam:Array.from({length:10},(_,i)=>a.sparam(i)),
 elements:Array.from({length:15},(_,i)=>w.CodexElements.bonus(a,i+1)),maxTp:a.maxTp(),preserveTp:a.isPreserveTp(),actionPlus:Array.from(a.actionPlusSet()),
 forgetTokens:w.$gameParty.numItems(w.$dataItems[H.FORGET_ITEM])};}
function refresh(a){a.refreshPassiveSkillCache();a.initPassiveCache();a.refreshPassiveCache();a.refresh();}
const cases=specs.map(spec=>makeCase(spec.id,spec,()=>{
 console.log('CASE_START '+spec.id);newGame();w.$gameVariables.setValue(9,999);const a=w.$gameActors.actor(spec.actor);a._level=37;
 a._equips.forEach((_,i)=>a.changeEquip(i,null));a._states=new w.Array();a._paramPlus=w.Array.from([0,0,0,0,0,0,0,0]);refresh(a);a.recoverAll();
 const before=snap(a),rows=[];
 for(const itemId of spec.sequence||[spec.item]){
  const item=w.$dataItems[itemId],effect=item.effects.find(e=>e.code===43),skill=effect.dataId,action=new w.Game_Action(a);action.setItem(itemId);
  const pre=snap(a),allowed=action.testItemEffect(a,effect),reason=H.powerLearnReason(a,skill);
  action.apply(a);refresh(a);a.recoverAll();const learned=snap(a),repeatAllowed=action.testItemEffect(a,effect),repeatReason=H.powerLearnReason(a,skill);
  a.learnSkill(skill);refresh(a);const repeat=snap(a);
  let ordinary=null,missingToken=null,paid=null;
  if(!spec.sequence){a.forgetSkill(skill);refresh(a);ordinary=snap(a);missingToken=H.forgetLearnedPower(a,skill);w.$gameParty.gainItem(w.$dataItems[H.FORGET_ITEM],1);paid=H.forgetLearnedPower(a,skill);refresh(a);a.recoverAll();}
  rows.push({item:itemId,skill,pre,allowed,reason,learned,repeatAllowed,repeatReason,repeat,ordinary,missingToken,paid,after:snap(a)});
 }
 return {before,rows,after:snap(a),registry:Array.from(H.powerSkills())};
}));
process.exit(finish(host,process.argv.includes('--smoke')?'power_books_smoke.json':'power_books.json',{scope:'Fresh newGame per case; native learn/test/apply/ordinary-forget/paid-forget hosts; empty gear level37 variable9=999; no MV save migration',cases})?0:1);
