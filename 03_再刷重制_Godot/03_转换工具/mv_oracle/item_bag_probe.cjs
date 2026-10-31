'use strict';
// installItemBagContinuationRuntime：物品页用道具的结果提示、预约公共事件跑完后回物品页、换装卡 CE1343 当场跑完。
// 真走原版 Scene_Item.useItem／Scene_ItemBase.checkCommonEvent／Game_Interpreter.setupReservedCommonEvent／
// Scene_Map.update／Scene_Map.stop／Scene_Item.create／start 的包装；窗口与场景是替身（只记调用），
// 地图解释器逐步 update、文字窗读完即清。产物 .sandbox/item_bag.json，手工复制为 tests/fixtures/item_bag_oracle.json。
const {start,makeCase,finish}=require('./shared/host.cjs');
const host=start(),{w,newGame}=host;
w.eval(`
Game_Map.prototype.updateInterpreter = function() {};
ImageManager.isReady = function() { return true; };
Game_CharacterBase.prototype.isAnimationPlaying = function() { return false; };
Game_CharacterBase.prototype.isBalloonPlaying = function() { return false; };
Game_Player.prototype.areFollowersGathering = function() { return false; };
Game_Event.prototype.checkEventTriggerAuto = function() {};
`);
// 大厅（Map004）新局时有自动执行事件挂着 _starting；替身地图不跑它们，所以关掉自动触发、开局清掉，免得 isEventRunning 一直为真
let trace=[];
if(w.$)w.$.toaster=o=>trace.push({t:'toast',text:String(o&&o.message||'')});
w.SceneManager.goto=cls=>trace.push({t:'goto',scene:cls===w.Scene_Map?'Scene_Map':cls===w.Scene_Item?'Scene_Item':String(cls&&cls.name)});
w.SceneManager.push=cls=>trace.push({t:'push',scene:String(cls&&cls.name)});
w.SceneManager.isSceneChanging=()=>false;
// 未知方法一律空操作的场景替身（原版函数经 prototype 显式调用时，里面的 this.xxx() 落到空操作）
// live＝true 时原型链上的方法照常执行（用道具的场景），否则只认替身自己的属性（地图、回到的物品页）
function stub(proto,own,live){
 const o=Object.assign(Object.create(proto),own);
 return new Proxy(o,{get(t,k){if(typeof k==='symbol'||Object.prototype.hasOwnProperty.call(t,k)||live&&k in t)return t[k];if(k==='constructor')return proto.constructor;return function(){};},set(t,k,v){t[k]=v;return true;}});
}
// Window_ItemList.includes：item＝普通物品（itypeId 1），keyItem＝重要物品（2）
function list(item){return w.$gameParty.items().filter(i=>i.itypeId===item.itypeId);}
const symbol=item=>item.itypeId===2?'keyItem':'item';
function itemScene(item,actor,index,live){
 return stub(w.Scene_Item.prototype,{
  item:()=>item,user:()=>actor,itemTargetActors:()=>w.Array.from(item.scope===0?[]:[actor]),
  playSeForItem(){},checkGameover(){},_actorWindow:{refresh(){},activate(){},hide(){},deactivate(){}},
  _categoryWindow:{currentSymbol:()=>symbol(item),selectSymbol(s){trace.push({t:'category',symbol:s});},deactivate(){trace.push({t:'categoryDeactivate'});}},
  _itemWindow:{_index:index,index(){return this._index;},redrawCurrentItem(){},refresh(){this._data=list(item);},setCategory(s){trace.push({t:'setCategory',symbol:s});},
   maxItems(){return (this._data||[]).length;},select(i){this._index=i;trace.push({t:'select',index:i,item:(this._data[i]||{}).id||0});},activate(){trace.push({t:'itemActivate'});}},
  _helpWindow:{setText(t){trace.push({t:'help',text:String(t)});}}
 },live);
}
// 地图替身：Scene_Map.update 外面一串插件包装会读 this.xxx.yyy()，未知属性给一个层层空操作的替身
const deep=new Proxy(function(){},{get:(t,k)=>k===Symbol.toPrimitive?()=>0:typeof k==='symbol'?undefined:deep,apply:()=>undefined});
const mapScene=new Proxy(Object.create(w.Scene_Map.prototype),{get(t,k){if(typeof k==='symbol'||Object.prototype.hasOwnProperty.call(t,k))return t[k];if(k==='constructor')return w.Scene_Map;return deep;},set(t,k,v){t[k]=v;return true;}});
function party(){return Array.from(w.$gameParty._actors);}
function runMap(spec){
 const interp=w.$gameMap._interpreter,steps=[];
 const setup=interp.setupReservedCommonEvent();
 for(let i=0;i<4000;i++){
  if(w.$gameMessage.isBusy()){steps.push(w.$gameMessage._texts.join('\n'));w.$gameMessage.clear();}
  interp.update();
  // 正式版同一帧里 updateTransferPlayer 就 goto(Scene_Map)（换场景中，包装直接返回）；新地图场景 onMapLoaded 才 performTransfer。
  // 替身没有这一步，这里照做：先过 Scene_Map.stop（下一个是 Scene_Map，不清预约），再载图、performTransfer。
  if(w.$gamePlayer.isTransferring()){
   steps.push('#transfer:'+w.$gamePlayer._newMapId);
   w.SceneManager._nextScene=Object.create(w.Scene_Map.prototype);try{w.Scene_Map.prototype.stop.call(mapScene);}catch(e){}w.SceneManager._nextScene=null;
   w.DataManager.loadMapData(w.$gamePlayer._newMapId);w.$gamePlayer.performTransfer();w.$gameMap.events().forEach(e=>e.clearStartingFlag());
  }
  w.Scene_Map.prototype.update.call(mapScene);
  if(trace.some(e=>e.t==='goto'&&e.scene==='Scene_Item'))break;
  if(!interp.isRunning()&&!w.$gameMessage.isBusy()&&!w.$gameTemp.isCommonEventReserved()){w.Scene_Map.prototype.update.call(mapScene);break;}
 }
 return {setup,running:interp.isRunning(),messages:steps,mapId:w.$gameMap.mapId(),position:[w.$gamePlayer.x,w.$gamePlayer.y]};
}
const specs=[
 {id:'hp.damaged',item:1,actor:1,damage:300,index:0},
 {id:'tp.consumable',item:532,actor:1,index:0},
 {id:'tp.durable',item:789,actor:1,index:0},
 {id:'horn.recruit',item:10,actor:1,index:1,stock:2},
 {id:'horn.last',item:10,actor:1,index:1,stock:1},
 {id:'horn.owned',item:10,actor:1,index:1,stock:2,preActor:11},
 {id:'lamp.same-map',item:4,actor:1,index:0},
 {id:'lamp.other-map',item:7,actor:1,index:0},
 {id:'horn.scene-change',item:10,actor:1,index:1,stock:2,sceneChange:true},
 {id:'wardrobe.inline',item:2475,actor:1,index:0},
 {id:'wardrobe.swap',item:2476,actor:1,index:0,pre:[6801]}
];
const cases=specs.map(spec=>makeCase(spec.id,spec,()=>{
 newGame();w.$gameMap.events().forEach(e=>e.clearStartingFlag());trace=[];
 const actor=w.$gameActors.actor(spec.actor),item=w.$dataItems[spec.item];
 if(spec.damage)actor.setHp(actor.mhp-spec.damage);
 (spec.pre||[]).forEach(id=>actor.learnSkill(id));
 if(spec.preActor)w.$gameParty.addActor(spec.preActor);
 w.$gameParty.gainItem(w.$dataItems[2],1);w.$gameParty.gainItem(item,spec.stock||1);
 w.$gameParty.setTargetActor(actor);
 const before={party:party(),count:w.$gameParty.numItems(item),hp:actor.hp,tp:actor.tp,skills:Array.from(actor._skills)};
 const scene=itemScene(item,actor,spec.index,true);scene._itemWindow.refresh();
 w.Scene_Item.prototype.useItem.call(scene);
 const used={trace:trace.slice(),reserved:w.$gameTemp._commonEventId||0,count:w.$gameParty.numItems(item),skills:Array.from(actor._skills),tp:actor.tp,hp:actor.hp};
 trace=[];let map=null,bag=null;
 if(spec.sceneChange){w.SceneManager._nextScene=Object.create(w.Scene_Battle.prototype);try{w.Scene_Map.prototype.stop.call(mapScene);}catch(e){}w.SceneManager._nextScene=null;}
 if(used.trace.some(e=>e.t==='goto'&&e.scene==='Scene_Map')){
  map=runMap(spec);map.trace=trace.slice();trace=[];
  if(map.trace.some(e=>e.t==='goto'&&e.scene==='Scene_Item')){
   const page=itemScene(item,actor,0);
   w.Scene_Item.prototype.create.call(page);w.Scene_Item.prototype.start.call(page);
   bag={trace:trace.slice(),index:page._itemWindow._index,data:(page._itemWindow._data||[]).map(i=>i.id)};
  }
 }
 return {before,used,map,bag,after:{party:party(),count:w.$gameParty.numItems(item),skills:Array.from(actor._skills)}};
}));
process.exit(finish(host,'item_bag.json',{scope:'Native installItemBagContinuationRuntime wrappers (Scene_Item.useItem, checkCommonEvent, setupReservedCommonEvent, Scene_Map.update/stop, Scene_Item.create/start) with stub windows; map interpreter stepped, messages cleared as read.',cases})?0:1);
