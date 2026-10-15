'use strict';
// 核查 dev.039：执行正式引擎七档一键出售、物品锁定/置顶，以及七层回城格四向通行度。只写 .sandbox。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
w.Star.Achievement.Manager.init();
function setup(){w.eval('SceneManager.initInput();ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};');w.$gameParty._weapons={};w.$gameParty._armors={};w.$gameParty._items={};w.$gameParty._gold=1000;}
function fixture(s){
  const db=s.kind==='weapon'?w.$dataWeapons:w.$dataArmors;
  const before=w.$gameParty.equipItems().slice();w.$gameParty.gainItem(db[s.base],1);
  const e=w.$gameParty.equipItems().find(x=>before.indexOf(x)<0);
  if(!e)throw new Error('未生成装备 '+s.label);
  e.meta=w.JSON.parse(JSON.stringify(e.meta));
  if(s.quality===null)delete e.meta.quality;else e.meta.quality=String(s.quality);
  e.price=s.price;e.name=s.label+(s.locked?'[锁定]':'');e._auditLabel=s.label;
  if(s.worn){w.$gameActors.actor(1)._equips[0].setObject(e);w.$gameParty.loseItem(e,1);}
  return e;
}
const onekey=[];
for(let grade=0;grade<7;grade++){
  setup();const specs=[];
  for(let q=0;q<16;q++)for(const locked of [false,true])specs.push({label:'q'+q+(locked?'L':''),kind:q%2?'weapon':'armor',base:1,quality:q,price:101+q*2,locked});
  specs.push({label:'zero',kind:'weapon',base:1,quality:0,price:0,locked:false},
    {label:'missing',kind:'weapon',base:1,quality:null,price:90,locked:false},
    {label:'worn',kind:'weapon',base:1,quality:0,price:999,locked:false,worn:true},
    {label:'reward',kind:'weapon',base:73,quality:0,price:0,locked:false});
  const records=specs.map(fixture),before=w.$gameParty.equipItems().slice(),g=w.$gameParty.gold(),v=w.$gameVariables.value(201);
  const sc=Object.create(w.Scene_Shop.prototype);sc.OnekeySellDe=()=>{};sc._goldWindow={refresh(){}};sc._statusWindow={refresh(){}};
  sc.sellUnifiedQuality(grade);
  const after=w.$gameParty.equipItems();
  onekey.push({grade,specs,sold:before.filter(e=>after.indexOf(e)<0).map(e=>e._auditLabel).sort(),remaining:after.map(e=>e._auditLabel).sort(),gold:w.$gameParty.gold()-g,var201:w.$gameVariables.value(201)-v,worn:!!w.$gameActors.actor(1).equips().find(e=>e&&e._auditLabel==='worn')});
}
setup();const scene=Object.create(w.Scene_Item.prototype);let current;
scene.item=()=>current;scene._itemActionWindow={activate(){},refresh(){}};scene._itemWindow={refresh(){}};
const marks=[];
for(const [id,op] of [[1,'lock'],[2,'top'],[1,'top'],[1,'lock'],[2,'top']]){
  current=w.$dataItems[id];if(op==='lock')scene.onSetLock();else scene.onItemTop();
  marks.push({id,op,locks:Array.from(w.$gameParty.ItemSpLock||[]),tops:Array.from(w.$gameParty.TopItem||[])});
}
for(let id=1;id<=3;id++)w.$gameParty.gainItem(w.$dataItems[id],1);
w.$gameParty.ItemSpLock=w.JSON.parse('[3]');w.$gameParty.TopItem=w.JSON.parse('[1,2]');
const list=Object.create(w.Window_ItemList.prototype);list._category='item';list.makeItemList();
const listOrder=list._data.filter(Boolean).map(e=>({id:e.id,name:e.name}));
// O-030：正式列表只按物品 ID 标记，会连带同编号装备；保留测量，Godot 明确登记为优化差异。
setup();const equip=fixture({label:'collision',kind:'weapon',base:1,quality:1,price:100,locked:false});
w.$gameParty.ItemSpLock=w.JSON.parse(JSON.stringify([equip.id]));w.$gameParty.TopItem=w.JSON.parse(JSON.stringify([equip.id]));
const gearList=Object.create(w.Window_ItemList.prototype);gearList._category='weapon';gearList.makeItemList();
const collision={id:equip.id,name:equip.name};
const win=new w.Window_OnekeySellCommand();
const layout={rect:[win.x,win.y,win.width,win.height],lineHeight:win.lineHeight(),padding:win.padding,commands:win._list.map(e=>e.name)};
// 正式 Game_Map / Game_Player 的通行判断，不替换地块规则。
w.$dataMap=JSON.parse(fs.readFileSync(path.join(APP,'data/Map004.json'),'utf8'));w.$gameMap.setup(4);
const passability=[{x:12,y:18},{x:14,y:23}].map(p=>({...p,dirs:[2,4,6,8].map(d=>w.$gamePlayer.isMapPassable(p.x,p.y,d))}));
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
fs.writeFileSync(path.join(__dirname,'.sandbox/item_marks.json'),JSON.stringify({sourceIdentity:identity,onekey,marks,listOrder,collision,layout,passability},null,1));
console.log(JSON.stringify({cases:onekey.length,marks:marks.length,layout,passability}));process.exit(0);
