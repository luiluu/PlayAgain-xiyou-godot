'use strict';
const {start,makeCase,finish}=require('./shared/host.cjs');
const host=start(),{w,newGame}=host,H=w.CodexHonghuang;
function snap(a){return {skills:Array.from(a._skills),powers:Array.from(H.learnedPowers(a)),class:H.powerClass(a),limit:H.powerLimit(a),
 param:Array.from({length:8},(_,i)=>a.param(i)),xparam:Array.from({length:10},(_,i)=>a.xparam(i)),sparam:Array.from({length:10},(_,i)=>a.sparam(i)),
 elements:Array.from({length:15},(_,i)=>w.CodexElements.bonus(a,i+1)),maxTp:a.maxTp(),preserveTp:a.isPreserveTp(),actionPlus:Array.from(a.actionPlusSet()),
 forgetTokens:w.$gameParty.numItems(w.$dataItems[H.FORGET_ITEM])};}
function refresh(a){a.refreshPassiveSkillCache();a.initPassiveCache();a.refreshPassiveCache();a.refresh();}
const books=[1654,1656,1674,1683,1718],specs=[];
for(const actor of [106,1,2])for(const mode of ['apply','direct','effect'])for(let rotate=0;rotate<5;rotate++)specs.push({id:`capacity.${actor}.${mode}.${rotate}`,actor,mode,items:books.slice(rotate).concat(books.slice(0,rotate))});
const cases=specs.map(spec=>makeCase(spec.id,spec,()=>{
 console.log('CASE_START '+spec.id);newGame();w.$gameVariables.setValue(9,999);const a=w.$gameActors.actor(spec.actor);a._level=37;
 a._equips.forEach((_,i)=>a.changeEquip(i,null));a._states=new w.Array();a._paramPlus=w.Array.from([0,0,0,0,0,0,0,0]);refresh(a);a.recoverAll();
 const rows=[],before=snap(a);
 function learn(itemId,mode){const item=w.$dataItems[itemId],effect=item.effects.find(e=>e.code===43),skill=effect.dataId,action=new w.Game_Action(a);action.setItem(itemId);
  const pre=snap(a),allowed=action.testItemEffect(a,effect),reason=H.powerLearnReason(a,skill);
  if(mode==='apply')action.apply(a);else if(mode==='effect')action.itemEffectLearnSkill(a,effect);else a.learnSkill(skill);
  refresh(a);a.recoverAll();return {item:itemId,skill,allowed,reason,pre,after:snap(a)};
 }
 for(const item of spec.items)rows.push(learn(item,spec.mode));
 const first=rows[0].skill,ordinaryBefore=snap(a);a.forgetSkill(first);refresh(a);const ordinaryAfter=snap(a);
 const clone=w.JsonEx.makeDeepCopy(a);clone.forgetSkill(first);refresh(clone);const cloneAfter=snap(clone);
 const missing=H.forgetLearnedPower(a,first);w.$gameParty.gainItem(w.$dataItems[H.FORGET_ITEM],2);
 const paid=H.forgetLearnedPower(a,first);refresh(a);a.recoverAll();const paidAfter=snap(a),again=H.forgetLearnedPower(a,first),againAfter=snap(a);
 const blocked=rows.find(r=>!r.allowed),relearn=learn(blocked?blocked.item:spec.items[0],spec.mode);
 return {before,rows,ordinaryBefore,ordinaryAfter,cloneAfter,missing,paid,paidAfter,again,againAfter,relearn,after:snap(a)};
}));
process.exit(finish(host,'power_books_boundary.json',{scope:'45 fresh cases: five cyclic book orders, three native learning hosts, three actor classes; canonical ordinary-forget protection vs clone; paid removal and capacity reuse; no UI or old-save migration',cases})?0:1);
