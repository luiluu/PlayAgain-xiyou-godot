'use strict';
// Native menu eligibility/consume/apply/global/reservation and CE1317, with render-only UI observed.
const {start,makeCase,finish}=require('./shared/host.cjs');
const host=start(),{w,newGame}=host;
const smoke=[
 {id:'learn.below',item:1461,limit:2,pre:[6301]},
 {id:'reject.zero',item:1460,limit:0,pre:[]},
 {id:'reject.full',item:1461,limit:1,pre:[6301]},
 {id:'repeat.full',item:1460,limit:1,pre:[6301]},
 {id:'cancel.full',item:1461,limit:1,pre:[6301],cancel:true}
];
const extra=[
 {id:'repeat.below',item:1460,limit:3,pre:[6301]},
 {id:'learn.last-slot',item:1461,limit:2,pre:[6301],times:2},
 {id:'learn.two-books',item:1460,sequence:[1460,1461,1462],limit:2,pre:[]},
 {id:'ordinary.unlimited',item:15,limit:0,pre:[6301]},
 {id:'power.unlimited',item:1654,limit:0,pre:[6301]},
 {id:'passive.with-powers',item:1461,limit:1,pre:[6301,7238,7240,7245]},
 {id:'power.class-full',item:1683,limit:99,pre:[7238,7240,7245,7246]},
 {id:'direct.learn',item:1461,limit:0,pre:[],direct:true},
 {id:'selected.other-full',item:1461,limit:1,pre:[],selected:1,selectedPre:[6301]},
 {id:'selected.other-empty',item:1461,limit:1,pre:[6301],selected:1,selectedPre:[]},
 {id:'reject.overwrite-slot',item:1461,limit:1,pre:[6301],reserved:1316},
 {id:'missing.book',item:1461,limit:1,pre:[],missing:true}
];
let messages=[],wentMap=false;
if(w.$)w.$.toaster=arg=>messages.push(String(arg.message));
w.SceneManager.goto=scene=>{if(scene===w.Scene_Map)wentMap=true;else throw Error('unexpected scene');};
function snap(a,item){return {skills:Array.from(a._skills),passives:Array.from(a.skills().filter(k=>k.stypeId===5).map(k=>k.id)),book:w.$gameParty.numItems(w.$dataItems[item]),reserved:w.$gameTemp._commonEventId||0,wentMap,messages:messages.slice()};}
const cases=(process.argv.includes('--smoke')?smoke:smoke.concat(extra)).map(spec=>makeCase(spec.id,spec,()=>{
 console.log('CASE_START '+spec.id);newGame();const a=w.$gameActors.actor(2),selected=w.$gameActors.actor(spec.selected||2);
 w.$gameVariables.setValue(9,spec.limit);spec.pre.forEach(id=>a.learnSkill(id));
 if(spec.selected)spec.selectedPre.forEach(id=>selected.learnSkill(id));w.$gameParty.setTargetActor(selected);
 const sequence=spec.sequence||Array(spec.times||1).fill(spec.item);sequence.forEach(id=>{if(!spec.missing)w.$gameParty.gainItem(w.$dataItems[id],3);});
 if(spec.reserved)w.$gameTemp.reserveCommonEvent(spec.reserved);messages=[];wentMap=false;const before=snap(a,spec.item),rows=[];
 for(const itemId of sequence){const item=w.$dataItems[itemId],scene=Object.create(w.Scene_ItemBase.prototype);
  Object.assign(scene,{item:()=>item,user:()=>a,itemTargetActors:()=>w.Array.from([a]),playSeForItem:()=>{},checkGameover:()=>{},_actorWindow:{activate(){},refresh(){}},hideSubWindow(){}});
  const allowed=scene.canUse(),pre=snap(a,itemId);
  if(spec.cancel)scene.onActorCancel();else if(spec.direct)a.learnSkill(item.effects.find(e=>e.code===43).dataId);else scene.onActorOk();
  const after=snap(a,itemId);let event=null;
  if(w.$gameTemp._commonEventId===1317){const interpreter=new w.Game_Interpreter();const setup=interpreter.setupReservedCommonEvent();interpreter.update();event={setup,running:interpreter.isRunning(),after:snap(a,itemId)};}
  rows.push({item:itemId,allowed,pre,after,event});
 }
 return {before,rows,after:snap(a,sequence[sequence.length-1]),selectedPassives:Array.from(selected.skills().filter(k=>k.stypeId===5).map(k=>k.id))};
}));
process.exit(finish(host,process.argv.includes('--smoke')?'book_capacity_smoke.json':'book_capacity.json',{scope:'Native Scene_ItemBase onActorOk/cancel, native eligibility/use/apply/global and CE1317 interpreter; UI rendering/sound observed only. Actor2 keeps new-game skills. Selected actor mismatch explicitly sampled.',cases})?0:1);
