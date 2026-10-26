'use strict';
// Capture actual native menu state-machine callbacks; the shared choice renderer is observed at its data boundary.
const {start,makeCase,finish}=require('./shared/host.cjs');
const host=start(),{w,newGame}=host,H=w.CodexHonghuang,bookIds=[1654,1656,1674,1683,1718];
const specs=[
 {id:'cancel.actors',steps:['cancel']},
 {id:'cancel.confirm.answer',steps:[0,0,1,'cancel','cancel']},
 {id:'cancel.confirm.key',steps:[0,0,'cancel','cancel','cancel']},
 {id:'forget.success',steps:[0,0,0,0]},
 {id:'forget.token-removed',steps:[0,0,'lose-token',0,0]},
 {id:'empty',empty:true,steps:['cancel']}
];
let current=null,pages=[],sceneEvents=[];
w.CodexYunshang.choose=(scene,rows,ok,cancel,info)=>{current={rows,ok,cancel};pages.push({info:Array.from(info||[]),rows:rows.map(r=>({label:r.label,enabled:r.enabled!==false}))});};
function snap(){return {tokens:w.$gameParty.numItems(w.$dataItems[3044]),books:bookIds.map(id=>w.$gameParty.numItems(w.$dataItems[id])),members:w.$gameParty.allMembers().map(a=>({actor:a.actorId(),powers:Array.from(H.learnedPowers(a))}))};}
const cases=specs.map(spec=>makeCase(spec.id,spec,()=>{
 console.log('CASE_START '+spec.id);newGame();w.$gameSwitches.setValue(2494,true);w.$gameVariables.setValue(9,999);w.$gameParty._actors=w.Array.from([1,106,2]);w.$gameParty._battleMembers=w.Array.from([1,106,2,0,0]);
 if(!spec.empty){w.$gameActors.actor(1).learnSkill(7238);w.$gameActors.actor(2).learnSkill(7240);}
 w.$gameParty.gainItem(w.$dataItems[3044],1);pages=[];sceneEvents=[];current=null;
 const scene={_itemWindow:{deactivate(){sceneEvents.push('list.deactivate');},refresh(){sceneEvents.push('list.refresh');}},_itemActionWindow:{hide(){sceneEvents.push('action.hide');},deactivate(){sceneEvents.push('action.deactivate');}},activateItemWindow(){sceneEvents.push('list.activate');}};
 const before=snap();H.openPowerForget(scene);const states=[snap()];
 for(const step of spec.steps){if(step==='lose-token'){w.$gameParty.loseItem(w.$dataItems[3044],1);states.push(snap());continue;}
  if(step==='cancel')current.cancel();else {const row=current.rows[step];if(!row||row.enabled===false)throw Error('invalid menu test selection');current.ok(row);}states.push(snap());}
 return {before,pages:JSON.parse(JSON.stringify(pages)),states,sceneEvents:sceneEvents.slice(),after:snap()};
}));
process.exit(finish(host,'power_books_menu.json',{scope:'Native CodexHonghuang.openPowerForget callbacks and native paid-forget; renderer data boundary; no old-save migration or screenshot claim',cases})?0:1);
