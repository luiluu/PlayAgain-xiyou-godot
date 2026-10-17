'use strict';
const fs=require('fs'),path=require('path');
const {APP,makeCase}=require('./host.cjs');
module.exports=function stock(host) {
  const {w,newGame,encode,restore}=host;
  const cases=[];
  const command=(...args)=>new w.Game_Interpreter().pluginCommand('ShopInventory',args);
  const inventory=id=>w.$gameSystem.getInventoryById(id);
  const item=w.$dataItems[1911], armor=w.$dataArmors[133], unmanaged=w.$dataItems[1];
  function shop(group,goods=[[0,1911,1,10]]) {
    if(group!==null)command('apply',group);
    const sc=Object.create(w.Scene_Shop.prototype);
    sc.prepare(goods.map(g=>g.slice()),false);
    sc._item=(goods[0][0]===2?w.$dataArmors:w.$dataItems)[goods[0][1]];
    const wb=Object.create(w.Window_ShopBuy.prototype);
    wb._data=[sc._item];wb._price=[goods[0][2]===0?sc._item.price:goods[0][3]];wb._money=w.$gameParty.gold();wb._inventory=sc._inventory;
    sc._buyWindow=wb;sc._goldWindow={value:()=>w.$gameParty.gold(),refresh(){},setItemBuy(){}};
    return sc;
  }
  function snap(sc) {return {stock:sc._inventory?sc._inventory.getStock(sc._item):null,
    enabled:!!sc._buyWindow.isEnabled(sc._item),max:sc.maxBuy(),gold:w.$gameParty.gold(),
    owned:w.$gameParty.numItems(sc._item),nextInventory:w.$gameTemp.nextInventoryId??null};}
  const fixture=()=>{newGame();w.$gameParty._gold=10000000;};
  cases.push(makeCase('stock.purchase-reopen-sell',{item:1911,group:'oracle_shared',price:10},()=>{
    fixture();const sc=shop('oracle_shared'),trace=[snap(sc)];sc.doBuy(2);trace.push(snap(sc));
    const reopened=shop('oracle_shared');trace.push(snap(reopened));reopened.doBuy(3);trace.push(snap(reopened));
    reopened.doSell(1);trace.push(snap(reopened));return {trace};
  }));
  cases.push(makeCase('stock.group-scope',{item:1911,groups:['shared_A','shared_B']},()=>{
    fixture();const a=shop('shared_A');a.doBuy(2);const b=shop('shared_B'),again=shop('shared_A');
    return {a:inventory('shared_A').getStock(item),b:inventory('shared_B').getStock(item),sameObject:a._inventory===again._inventory,nextConsumed:w.$gameTemp.nextInventoryId===null,
      ungrouped:shop(null)._inventory===null};
  }));
  cases.push(makeCase('stock.cancel-preview',{item:1911,group:'cancel'},()=>{
    fixture();const sc=shop('cancel'),before=snap(sc);for(let i=0;i<5;i++){sc.maxBuy();sc._buyWindow.isEnabled(item);}
    return {before,after:snap(shop('cancel'))};
  }));
  cases.push(makeCase('stock.affordability',{item:1911,group:'poor',price:10},()=>{
    fixture();w.$gameParty._gold=9;const sc=shop('poor');return snap(sc);
  }));
  cases.push(makeCase('stock.memory-roundtrip',{item:1911,group:'persist'},()=>{
    fixture();shop('persist').doBuy(2);const before=inventory('persist').getStock(item),encoded=encode();restore(encoded);
    return {before,after:snap(shop('persist')),prototypeRestored:inventory('persist') instanceof w.Game_ShopInventory};
  }));
  cases.push(makeCase('stock.restock-reset',{item:1911,group:'reset'},()=>{
    fixture();shop('reset').doBuy(2);const trace=[inventory('reset').getStock(item)];command('restockAll','reset');trace.push(inventory('reset').getStock(item));
    shop('reset').doBuy(1);command('resetAll');const existsBeforeRead=w.$gameSystem.existsInventory('reset');trace.push(inventory('reset').getStock(item));return {trace,existsBeforeRead};
  }));
  cases.push(makeCase('stock.clamp-and-type',{items:[1911,1],armors:[133]},()=>{
    fixture();const inv=inventory('types');inv.setStock(item,-100);const low=inv.getStock(item);inv.setStock(item,10000);
    inv.loseStock(armor,1);return {low,high:inv.getStock(item),armor:inv.getStock(armor),armorMax:inv.getStockMax(armor),unmanaged:inv.isStockManaged(unmanaged),unmanagedStock:inv.getStock(unmanaged)};
  }));
  cases.push(makeCase('stock.time-restock',{item:77,interval:30,mode:'T',fixtureClock:'Graphics.frameCount/60'},()=>{
    fixture();const timed=w.$dataItems[77],inv=inventory('timed');inv.loseStock(timed,5);w.$gameSystem.registerInventorySupplySchedule('timed',timed);const trace=[];
    for(const seconds of [29,30,90,150]){w.Graphics.frameCount=seconds*60;w.$gameSystem.updateInventorySupplier();trace.push({seconds,stock:inv.getStock(timed)});}
    return {trace};
  }));
  cases.push(makeCase('stock.no-restock',{item:150,interval:0},()=>{
    fixture();const inv=inventory('never'),it=w.$dataItems[150];inv.loseStock(it,1);w.$gameSystem.registerInventorySupplySchedule('never',it);
    w.Graphics.frameCount=36000;w.$gameSystem._battleCount=999;w.$gameSystem.updateInventorySupplier();return {stock:inv.getStock(it)};
  }));
  cases.push(makeCase('stock.supply-speed-command',{group:'speed',commandSpeed:3},()=>{
    fixture();command('supplySpeed','speed','3');const inv=inventory('speed');return {raw:String(inv._supplySpeed),interval:String(inv.getSupplyInterval(item))};
  }));
  for(const id of [77,150])cases.push(makeCase('stock.currency-and-stock.'+id,{goods:[0,id,0,0],group:'oracle_currency_'+id},()=>{
    fixture();const it=w.$dataItems[id],sc=shop('oracle_currency_'+id,[[0,id,0,0]]);
    for(const v of it.variableBuyPrices||[])w.$gameVariables.setValue(v,1000000);
    for(const id of it.itemBuyPrices||[])w.$gameParty.gainItem(w.$dataItems[id],9999);
    const before=snap(sc),vars=Object.fromEntries((it.variableBuyPrices||[]).map(v=>[v,w.$gameVariables.value(v)])),itemMoney=Object.fromEntries((it.itemBuyPrices||[]).map(id=>[id,w.$gameParty.numItems(w.$dataItems[id])]));
    if(before.enabled&&before.max>0)sc.doBuy(1);
    return {before,after:snap(sc),currencies:(it.variableBuyPrices||[]).map(v=>[v,vars[v],w.$gameVariables.value(v)]),itemCurrencies:(it.itemBuyPrices||[]).map(id=>[id,itemMoney[id],w.$gameParty.numItems(w.$dataItems[id])]),prepared:sc._goods};
  }));
  for(const id of [77,150])cases.push(makeCase('stock.currency-short.'+id,{goods:[0,id,0,0],short:'变量或物品货币少1'},()=>{
    fixture();const it=w.$dataItems[id];
    for(const v of it.variableBuyPrices||[])w.$gameVariables.setValue(v,Math.max(0,it.variableBuyPrice[v]-1));
    for(const k of it.itemBuyPrices||[])w.$gameParty.gainItem(w.$dataItems[k],Math.max(0,it.itemBuyPrice[k]-1));
    const sc=shop('short_'+id,[[0,id,0,0]]),before=snap(sc);return {before,after:snap(sc)};
  }));
  cases.push(makeCase('stock.pending-overwrite',{groups:['pending_A','pending_B']},()=>{
    fixture();command('apply','pending_A');command('apply','pending_B');const first=shop(null),second=shop(null);
    return {first:first._inventory.id,second:second._inventory,nextInventory:w.$gameTemp.nextInventoryId};
  }));
  cases.push(makeCase('stock.timer-memory-roundtrip',{item:77,interval:30},()=>{
    fixture();const it=w.$dataItems[77],inv=inventory('saved_timer');inv.loseStock(it,5);w.$gameSystem.registerInventorySupplySchedule('saved_timer',it);
    w.Graphics.frameCount=29*60;restore(encode());const trace=[inventory('saved_timer').getStock(it)];
    w.Graphics.frameCount=30*60;w.$gameSystem.updateInventorySupplier();trace.push(inventory('saved_timer').getStock(it));return {trace};
  }));
  // 八戒 2026-10-17：独立装备（4279 代购 8018）买入扣商品库存、卖出所得实例不回商品库存；二十层后索礼商店（正式组名、正式商品）买到售完再重开。
  const payCurrencies=it=>{for(const v of it.variableBuyPrices||[])w.$gameVariables.setValue(v,1000000);for(const k of it.itemBuyPrices||[])w.$gameParty.gainItem(w.$dataItems[k],9999);};
  cases.push(makeCase('stock.gear-buy-sell',{goods:[2,4279,0,0],group:'gear'},()=>{
    fixture();const base=w.$dataArmors[4279];payCurrencies(base);const sc=shop('gear',[[2,4279,0,0]]),before=snap(sc);sc.doBuy(1);const after=snap(sc);
    const armors=w.$gameParty.armors().map(a=>[a.id,a.baseItemId]);const inst=w.$gameParty.armors()[0];sc._item=inst||base;if(inst)sc.doSell(1);
    const inv=inventory('gear');return {armors,before,after,instanceSold:!!inst,baseAfterSell:inv.getStock(base),armorKeys:Object.keys(inv._armorStock).length,ownedAfterSell:w.$gameParty.armors().length};
  }));
  for(const [id,group] of [[1912,'群仙俯首购买'],[1916,'天宫之寒购买']])cases.push(makeCase('stock.floor-shop.'+id,{goods:[0,id,0,0],group},()=>{
    fixture();const it=w.$dataItems[id];payCurrencies(it);const sc=shop(group,[[0,id,0,0]]),trace=[snap(sc)];sc.doBuy(2);trace.push(snap(sc));
    const again=shop(group,[[0,id,0,0]]);trace.push(snap(again));again.doBuy(again.maxBuy());trace.push(snap(again));trace.push(snap(shop(group,[[0,id,0,0]])));
    const otherGroup=shop('其它组',[[0,id,0,0]]);trace.push(snap(otherGroup));return {trace};
  }));
  // 来源目录全量扫描只记定义；是否在切片可玩由实现车道单独确认。
  const catalog=[];
  for(const [kind,table,file] of [['item',w.$dataItems,'Items'],['weapon',w.$dataWeapons,'Weapons'],['armor',w.$dataArmors,'Armors']]){
    const source=JSON.parse(fs.readFileSync(path.join(APP,'data',file+'.json'),'utf8'));
    for(const raw of source)if(raw){const it=table[raw.id];if(it&&it.shopStockCountMax!==undefined)catalog.push({kind,id:it.id,name:it.name,max:it.shopStockCountMax,interval:it.shopStockSupplyInterval,mode:it.shopStockSupplyMode});}
  }
  const locations=[];
  for(const file of fs.readdirSync(path.join(APP,'data')).filter(f=>/^Map\d{3}\.json$/.test(f)).sort()){
    const map=JSON.parse(fs.readFileSync(path.join(APP,'data',file),'utf8'));
    for(const ev of map.events||[])if(ev)ev.pages.forEach((pg,page)=>pg.list.forEach((c,index)=>{
      if(c.code===356&&/^ShopInventory\s/.test(c.parameters[0]))locations.push({map:Number(file.slice(3,6)),event:ev.id,page,index,command:c.parameters[0]});
    }));
  }
  for(const ce of w.$dataCommonEvents)if(ce)(ce.list||[]).forEach((c,index)=>{if(c.code===356&&/^ShopInventory\s/.test(c.parameters[0]))locations.push({common:ce.id,index,command:c.parameters[0]});});
  return {hostScope:'真实Scene_Shop/Window_ShopBuy与插件命令；无渲染，库存/扣款/补货/JsonEx仅内存；time为游戏帧，不是墙钟',catalog,locations,cases};
};
