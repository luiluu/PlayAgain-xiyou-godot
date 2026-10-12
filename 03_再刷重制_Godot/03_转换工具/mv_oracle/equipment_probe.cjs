'use strict';
// 新建内存装备/角色，对照品质、词缀、插槽、强化与套装；仅写 .sandbox/equipment.json。
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {boot}=require('./hboot.cjs');
const {sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Applications/再刷一把：西游（mod_KYO）.app/Contents/Resources/app.nw';
const r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||w.CodexRuntime.status().some(m=>m.state!=='installed')||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
w.eval('ConfigManager.applyData({}); DataManager.setupNewGame(); $gameSystem.setDifficultyId(3); ConfigManager.SAchievementS=new Array(10000).fill(true);');
const out={sourceIdentity:sourceIdentity(APP),releaseVersion:w.nw.App.manifest.releaseVersion,sourceHashes:{},gear:[],upgrades:[],sets:[],runewords:[],suitDefinitions:w.JSON.parse(w.JSON.stringify(w.$dataEquipSuits))};
for(const name of ['YEP_ItemCore','ItemQuality','DreamX_RandomPrefixesSuffixes','YEP_X_ItemUpgradeSlots','GT_EquipSuitCore','Star_RomGetItems']){
 const rel='js/plugins/'+name+'.js';out.sourceHashes[rel]=crypto.createHash('sha256').update(fs.readFileSync(path.join(APP,rel))).digest('hex');
}
function brief(e){return {name:e.name,params:Array.from(e.params),traits:w.JSON.parse(w.JSON.stringify(e.traits)),price:e.price,icon:e.iconIndex,quality:Number(e.meta.quality||0),slots:e.upgradeSlots,originalSlots:e.originalUpgradeSlots??e.upgradeSlots,boost:e.boostCount||0,elementAmplify:w.JSON.parse(w.JSON.stringify(e.elementAmplify||{})),note:e.note,runewords:Array.from(e._codexRunewords||[])};}
function make(kind,id,roll){w.Math.random=()=>roll;w.$gameParty.RomDreamX=new w.Array();w.$gameParty.RomDreamXNum=0;w.$gameParty.RomDreamXs=new w.Array();w.$gameParty.RomDreamXsNum=0;const table=kind==='weapon'?w.$dataWeapons:w.$dataArmors,base=table[id];const e=w.DreamX.RandomPrefixSuffix.isConfiguredForPrefixSuffix(base)?w.DreamX.RandomPrefixSuffix.makeItem(base):w.DataManager.registerNewItem(base);return e;}
for(const [kind,id] of [['weapon',2],['weapon',56],['weapon',667],['weapon',725],['armor',12],['armor',52],['armor',57],['armor',235],['armor',236],['armor',240],['armor',336],['armor',337]]){
 for(const roll of [0,0.5,0.99]){const e=make(kind,id,roll);out.gear.push({kind,id,roll,...brief(e)});}
}
// 每一种正式生效材料选一个类型匹配的基础装备；随机强化额外覆盖两端。
for(const item of w.$dataItems){
 if(!item)continue;
 for(const kind of ['weapon','armor']){
  const effects=kind==='weapon'?item.upgradeWeaponEffect:item.upgradeArmorEffect;
  if(!effects||!effects.some(line=>line.trim()))continue;
  const types=kind==='weapon'?item.upgradeWeaponType:item.upgradeArmorType;
  const table=kind==='weapon'?w.$dataWeapons:w.$dataArmors;
  const base=table.find(e=>e&&e.name&&(!e.baseItemId)&&(!e.originalBaseItemId)&&(types.includes(0)||types.includes(kind==='weapon'?e.wtypeId:e.atypeId)));
  if(!base)throw new Error('missing equipment for material '+item.id+' '+kind);
  for(const roll of (effects.some(line=>/random /i.test(line))?[0,0.5,0.99]:[0.5])){
   const e=make(kind,base.id,0.5);w.Math.random=()=>roll;
   w.$gameParty._items[item.id]=1;w.ItemManager.applyIUSEffects(e,item);
   out.upgrades.push({kind,id:base.id,itemId:item.id,roll,...brief(e)});
  }
 }
}
for(const recipe of w.$dataStarEMosaicOpt){
 if(!recipe||!recipe.EMosaicZID.length)continue;
 for(const kind of ['weapon','armor']){
  if(!(kind==='weapon'?recipe.EMosaicWId:recipe.EMosaicAId))continue;
  const table=kind==='weapon'?w.$dataWeapons:w.$dataArmors;
  const base=table.find(e=>e&&e.name&&(kind==='weapon'?e.wtypeId:e.atypeId)&&!e.baseItemId&&!e.originalBaseItemId&&(kind==='weapon'?recipe.EMosaicWtepy.includes(e.wtypeId):recipe.EMosaicAtepy.includes(e.etypeId)));
  if(!base)throw new Error('missing base for recipe '+recipe.id);
  const e=make(kind,base.id,0.5);e.slotsAppliedId=w.Array.from(recipe.EMosaicZID);
  w.CodexRuneword.check(e);
  const once=brief(e);w.CodexRuneword.check(e);
  if(JSON.stringify(once)!==JSON.stringify(brief(e)))throw new Error('repeat runeword '+recipe.id);
  out.runewords.push({recipeId:recipe.id,kind,id:base.id,materials:Array.from(recipe.EMosaicZID),...brief(e)});
 }
}
for(const ids of [[235],[235,236],[240],[336,337],[637]]){
 const a=w.$gameActors.actor(1);a.changeLevel(30,false);a._equips.forEach(x=>x.setObject(null));
 // 条件固定在内存中的测试角色，单独观察套装规则；不由职业/等级卸下试验装备。
 a.canEquip=()=>true;
 a.refreshEquipSuit();a.initPassiveCache();a.refreshPassiveCache();a.refresh();
 const before={params:Array.from({length:8},(_,i)=>a.param(i)),xparams:Array.from({length:10},(_,i)=>a.xparam(i)),sparams:Array.from({length:10},(_,i)=>a.sparam(i)),skills:Array.from(a.skills(),s=>s.id)};
 for(const id of ids){const e=w.$dataArmors[id];a._equips[a.equipSlots().indexOf(e.etypeId)].setObject(e);}
 a.refreshEquipSuit();a.initPassiveCache();a.refreshPassiveCache();a.refresh();
 out.sets.push({armorIds:ids,before,activeStates:Array.from(a._equipSuitsStateIDs||[]),equips:Array.from(a.equips(),e=>e&&{id:e.id,base:e.originalBaseItemId||e.baseItemId,params:Array.from(e.params)}),params:Array.from({length:8},(_,i)=>a.param(i)),xparams:Array.from({length:10},(_,i)=>a.xparam(i)),sparams:Array.from({length:10},(_,i)=>a.sparam(i)),states:Array.from(a.states(),s=>s.id),skills:Array.from(a.skills(),s=>s.id),bResult:Array.from({length:3},(_,i)=>[a.equipSuitBonusParamEdit('bResult',i,0),a.equipSuitBonusParamEdit('bResult',i,1)])});
}
fs.writeFileSync(path.join(__dirname,'.sandbox/equipment.json'),JSON.stringify(out,null,2));
console.log(JSON.stringify({gear:out.gear.length,upgrades:out.upgrades.length,materials:new Set(out.upgrades.map(r=>r.itemId)).size,sets:out.sets.length}));process.exit(0);
