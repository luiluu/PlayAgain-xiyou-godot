'use strict';
// 商店买入（YEP_X_MoreCurrencies <Variable/Item x Buy Price: y>、<Proxy Buy: x>）：切片各图商店（事件指令 302/605）里的每件商品，
// 在几种持有状态下记正式 Window_ShopBuy.isEnabled（能否选）、Scene_Shop.maxBuy（最多买几个）与 Scene_Shop.doBuy 前后金币、变量、物品、
// 武器、防具的变化，以及插件解析出的买入价（variableBuyPrices/itemBuyPrices 的顺序）与是否画金币（item.price>0）。只写 .sandbox。
// 持有状态：zero 全空；exact 每种货币刚好够买 1 个（买 1 个）；short_<货币> 某一种比刚好够少 1；rich 每种都很多（买 min(2, maxBuy) 个）；
// 祝福进阶石另有 rich_v20_<n>（变量 20 设为 n，即进度层数 n−1）。其余状态变量 20 为 0。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
w.Star.Achievement.Manager.init(); // 正式 Scene_Boot.start 的成就提示初始化（获得物品会触发），仅内存。
const SLICE=JSON.parse(fs.readFileSync(path.join(__dirname,'../xiyou_slice.json'),'utf8'));
const TABLES=[w.$dataItems,w.$dataWeapons,w.$dataArmors];
const RICH=1000000;

// 切片各图商店（事件指令 302＋605）经正式 Scene_Shop.prepare（种族运行时把旧版进阶石换成正规 ID 并去重、
// 平衡运行时滤掉停用号角）后的商品，去重：[类型, ID, 价格类型, 指定价]；shops 记每家店整理前后的商品表
const goods=[],seen={},shops=[];
w.eval('ConfigManager.applyData({});DataManager.setupNewGame();');
for(const mid of SLICE.maps){
  const map=JSON.parse(fs.readFileSync(path.join(APP,'data',`Map${String(mid).padStart(3,'0')}.json`),'utf8'));
  for(const ev of map.events||[])if(ev)for(const page of ev.pages)for(let i=0;i<page.list.length;i++){
    const c=page.list[i];if(c.code!==302)continue;
    const raw=[c.parameters.slice(0,4).map(Number)];
    for(let j=i+1;j<page.list.length&&page.list[j].code===605;j++)raw.push(page.list[j].parameters.slice(0,4).map(Number));
    const sc=Object.create(w.Scene_Shop.prototype);sc.prepare(raw.map(x=>x.slice()),!!c.parameters[4]);
    const prepared=sc._goods.map(x=>x.slice(0,4).map(Number));
    shops.push({map:mid,event:ev.id,raw,prepared});
    for(const g of prepared){const key=g.join(',');if(TABLES[g[0]]&&TABLES[g[0]][g[1]]&&!seen[key]){seen[key]=true;goods.push(g);}}
  }
}

// 新游戏只开一次（每次重开太慢）；每例开始时清空背包（initAllItems），金币、用到的变量由 hold 设定。
w.eval('ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};');
w.Input._currentState=w.Input._currentState||{}; // isDebugThrough 读按键状态（无键盘，按不按都是假）
function setup(){w.$gameParty.initAllItems();}
// 带随机词缀的装备会再生成一层基础记录，按 originalBaseItemId 认原装备
function snap(){
  const count=list=>{const c={};list.forEach(x=>{const b=x.originalBaseItemId||x.baseItemId||x.id;c[b]=(c[b]||0)+1;});return c;};
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
// 持有：金币、各变量、各物品设成给定数量（物品按 gainItem 加，受物品上限限制）
function hold(gold,vars,items){
  w.$gameParty._gold=gold;
  for(const v in vars)w.$gameVariables.setValue(Number(v),vars[v]);
  for(const id in items){const it=w.$dataItems[Number(id)];w.$gameParty.gainItem(it,items[id]-w.$gameParty.numItems(it));}
}

const cases=[];
for(const g of goods){
  const item=TABLES[g[0]][g[1]];
  const price=g[2]===0?item.price:g[3];
  const vb=(item.variableBuyPrices||[]).slice(),ib=(item.itemBuyPrices||[]).slice();
  const need={gold:price,vars:{},items:{}};
  vb.forEach(v=>need.vars[v]=item.variableBuyPrice[v]);ib.forEach(i=>need.items[i]=item.itemBuyPrice[i]);
  const states=[['zero',0,{},{},1],['exact',need.gold,need.vars,need.items,1]];
  if(price>0)states.push(['short_gold',need.gold-1,need.vars,need.items,1]);
  for(const v of vb)states.push(['short_var'+v,need.gold,Object.assign({},need.vars,{[v]:need.vars[v]-1}),need.items,1]);
  for(const i of ib)states.push(['short_item'+i,need.gold,need.vars,Object.assign({},need.items,{[i]:need.items[i]-1}),1]);
  const richVars={},richItems={};vb.forEach(v=>richVars[v]=RICH);ib.forEach(i=>richItems[i]=9999);
  states.push(['rich',RICH*10,richVars,richItems,2]);
  // 祝福进阶石（installNativeRaceRuntime）：进度层数 = 变量 20 − 1（0～33）未到该阶段下限时不能买；在下限前后各量一次
  const rank=g[0]===0?w.$dataCodexRaces.stones.indexOf(item.id)+2:0;
  if(rank>=2){const lo=w.$dataCodexRaces.bands[rank-2][0];
    for(const v20 of [lo,lo+1])states.push(['rich_v20_'+v20,RICH*10,Object.assign({20:v20},richVars),richItems,2]);}
  for(const [name,gold,vars,items,number] of states){
    setup();w.$gameVariables.setValue(20,0);
    const zeroVars={},zeroItems={};vb.forEach(v=>zeroVars[v]=0);ib.forEach(i=>zeroItems[i]=0);
    hold(gold,Object.assign(zeroVars,vars),Object.assign(zeroItems,items));
    const wb=Object.create(w.Window_ShopBuy.prototype);wb._data=[item];wb._price=[price];wb._money=w.$gameParty.gold();
    const enabled=!!wb.isEnabled(item);
    const sc=Object.create(w.Scene_Shop.prototype);sc._buyWindow=wb;sc._item=item;sc._goods=[g];
    sc._goldWindow={value:()=>w.$gameParty.gold(),refresh(){},setItemBuy(){}}; // Scene_Shop.money() 读金钱窗
    const max=sc.maxBuy();
    let d=null,n=Math.min(number,max);
    if(enabled&&n>=1){const before=snap();sc.doBuy(n);d=delta(before,snap());}
    cases.push({goods:g,state:name,gold,vars,items,number:n,enabled,max,delta:d});
  }
}
const parsed=goods.map(g=>{const it=TABLES[g[0]][g[1]];return {goods:g,price:it.price,drawsGold:it.price>0,proxyBuy:it.proxyBuy||0,
  variableBuyPrices:(it.variableBuyPrices||[]).map(v=>[v,it.variableBuyPrice[v]]),itemBuyPrices:(it.itemBuyPrices||[]).map(i=>[i,it.itemBuyPrice[i]])};});
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname,'.sandbox'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'.sandbox/shop_buy.json'),JSON.stringify({sourceIdentity:identity,shops,goods:parsed,cases},null,1));
console.log(JSON.stringify({goods:goods.length,cases:cases.length,bought:cases.filter(c=>c.delta).length,
  withCurrency:parsed.filter(p=>p.variableBuyPrices.length||p.itemBuyPrices.length).length,proxy:parsed.filter(p=>p.proxyBuy).length}));
process.exit(0);
