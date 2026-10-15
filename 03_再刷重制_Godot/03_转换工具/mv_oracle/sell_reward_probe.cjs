'use strict';
// 出售报酬（YEP_X_MoreCurrencies）：商店 Scene_Shop.doSell（普通出售与 Star_ShopOnekey 一键出售共用）与
// 挂机自动卖出 XdRsData.hangUp.doSell，卖出后金币、变量、物品、武器、防具的变化。只写 .sandbox。
// 按备注自动挑选：每张表各种 <Variable/Item/Weapon/Armor x Sell Price: y> 的第一件、多个备注的第一件、无备注且有价格的第一件、无备注且 0 价的第一件（不能卖）。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Applications/再刷一把：西游（mod_KYO）.app/Contents/Resources/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
w.Star.Achievement.Manager.init(); // 正式 Scene_Boot.start 的成就提示初始化（获得物品会触发），仅内存。
const TAG=/<(VARIABLE|ITEM|WEAPON|ARMOR)[ ](\d+)[ ]SELL PRICE:[ ](\d+)>/ig;
const TABLES={item:w.$dataItems,weapon:w.$dataWeapons,armor:w.$dataArmors};
function pick(kind){
  const db=TABLES[kind],seen={},out=[];
  for(let id=1;id<db.length;id++){
    const o=db[id];if(!o||!o.name)continue;
    const tags=[...String(o.note||'').matchAll(TAG)].map(m=>m[1].toUpperCase());
    let key=tags.length>1?'multi':tags.length===1?tags[0]:(o.price>0?'none':'zero');
    if(key&&!seen[key]){seen[key]=true;out.push(id);}
  }
  return out;
}
function setup(){
  w.eval('ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};');
  w.$gameParty._gold=1000;
  w.Input._currentState=w.Input._currentState||{}; // isDebugThrough 读按键状态（无键盘，按不按都是假）
}
function snap(){
  const count=list=>{const c={};list.forEach(x=>{const b=x.baseItemId||x.id;c[b]=(c[b]||0)+1;});return c;};
  return {gold:w.$gameParty.gold(),vars:w.$gameVariables._data.slice(),items:Object.assign({},w.$gameParty._items),
    weapons:count(w.$gameParty.weapons()),armors:count(w.$gameParty.armors())};
}
function delta(a,b){
  const d={gold:b.gold-a.gold,vars:{},items:{},weapons:{},armors:{}};
  const n=Math.max(a.vars.length,b.vars.length);
  for(let i=1;i<n;i++){const x=(a.vars[i]||0),y=(b.vars[i]||0);if(x!==y)d.vars[i]=y-x;}
  for(const k of ['items','weapons','armors'])for(const id of new Set(Object.keys(a[k]).concat(Object.keys(b[k])))){const v=(b[k][id]||0)-(a[k][id]||0);if(v)d[k][id]=v;}
  return d;
}
const cases=[];
for(const kind of ['item','weapon','armor'])for(const id of pick(kind))for(const via of ['shop','hangUp']){
  setup();
  const base=TABLES[kind][id],number=kind==='item'?3:1;
  const bag=()=>kind==='weapon'?w.$gameParty.weapons():w.$gameParty.armors();
  const had=kind==='item'?[]:bag();
  w.$gameParty.gainItem(base,number);
  // 独立装备：取背包里刚生成的实例（卖价按实例的 price）
  const item=kind==='item'?base:bag().filter(x=>had.indexOf(x)<0).pop();
  if(!item)throw new Error('没拿到实例 '+kind+' '+id+' '+JSON.stringify(bag().map(x=>[x.id,x.baseItemId])));
  // 出售列表能否选（YEP_ShopMenuCore：canSell 由 MoreCurrencies 的卖出报酬备注设为真，0 价也可卖）
  const enabled=!!w.Window_ShopSell.prototype.isEnabled.call(Object.create(w.Window_ShopSell.prototype),item);
  const before=snap();
  if(via==='shop'){const sc=Object.create(w.Scene_Shop.prototype);sc._item=item;sc.doSell(number);}
  else w.XdRsData.hangUp.doSell(number,item);
  const d=delta(before,snap());
  cases.push({kind,id,via,number,enabled,price:item.price,instanceBase:item.baseItemId||item.id,note:String(base.note||'').match(TAG)||[],delta:d});
}
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname,'.sandbox'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'.sandbox/sell_rewards.json'),JSON.stringify({sourceIdentity:identity,cases},null,1));
console.log(JSON.stringify({cases:cases.length,sample:cases.slice(0,4)}));
process.exit(0);
