'use strict';
// 新建内存装备/角色，对照品质、词缀、插槽、强化与套装；仅写 .sandbox/equipment.json。
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {boot}=require('./hboot.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Applications/再刷一把：西游（mod_KYO）.app/Contents/Resources/app.nw';
const r=boot(APP,{tolerant:true,log:false}),w=r.window;
w.eval('ConfigManager.applyData({}); DataManager.setupNewGame(); $gameSystem.setDifficultyId(3); ConfigManager.SAchievementS=new Array(10000).fill(true);');
const out={releaseVersion:w.nw.App.manifest.releaseVersion,sourceHashes:{},gear:[],upgrades:[],sets:[],suitDefinitions:w.JSON.parse(w.JSON.stringify(w.$dataEquipSuits))};
for(const name of ['YEP_ItemCore','ItemQuality','DreamX_RandomPrefixesSuffixes','YEP_X_ItemUpgradeSlots','GT_EquipSuitCore']){
 const rel='js/plugins/'+name+'.js';out.sourceHashes[rel]=crypto.createHash('sha256').update(fs.readFileSync(path.join(APP,rel))).digest('hex');
}
function brief(e){return {name:e.name,params:Array.from(e.params),traits:w.JSON.parse(w.JSON.stringify(e.traits)),price:e.price,icon:e.iconIndex,quality:Number(e.meta.quality||0),slots:e.upgradeSlots,originalSlots:e.originalUpgradeSlots??e.upgradeSlots,boost:e.boostCount||0,elementAmplify:w.JSON.parse(w.JSON.stringify(e.elementAmplify||{})),note:e.note};}
function make(kind,id,roll){w.Math.random=()=>roll;w.$gameParty.RomDreamX=new w.Array();w.$gameParty.RomDreamXNum=0;const table=kind==='weapon'?w.$dataWeapons:w.$dataArmors,base=table[id];const e=w.DreamX.RandomPrefixSuffix.isConfiguredForPrefixSuffix(base)?w.DreamX.RandomPrefixSuffix.makeItem(base):w.DataManager.registerNewItem(base);return e;}
for(const [kind,id] of [['weapon',2],['weapon',56],['armor',52],['armor',57],['armor',235],['armor',236],['armor',240],['armor',336],['armor',337]]){
 for(const roll of [0,0.5,0.99]){const e=make(kind,id,roll);out.gear.push({kind,id,roll,...brief(e)});}
}
for(const itemId of [258,262,266,270,170,242]){const e=make('weapon',2,0.5),item=w.$dataItems[itemId];w.$gameParty._items[itemId]=1;w.ItemManager.applyIUSEffects(e,item);out.upgrades.push({kind:'weapon',id:2,itemId,...brief(e)});}
for(const ids of [[235],[235,236],[240],[336,337]]){
 const a=w.$gameActors.actor(1);a.changeLevel(30,false);a._equips.forEach(x=>x.setObject(null));
 for(const id of ids){const e=make('armor',id,0.99);a._equips[a.equipSlots().indexOf(e.etypeId)].setObject(e);}
 a.refreshEquipSuit();a.initPassiveCache();a.refreshPassiveCache();a.refresh();
 out.sets.push({armorIds:ids,equips:Array.from(a.equips(),e=>e&&{id:e.id,base:e.originalBaseItemId||e.baseItemId,params:Array.from(e.params)}),params:Array.from({length:8},(_,i)=>a.param(i)),xparams:Array.from({length:10},(_,i)=>a.xparam(i)),sparams:Array.from({length:10},(_,i)=>a.sparam(i)),states:Array.from(a.states(),s=>s.id),skills:Array.from(a.skills(),s=>s.id),bResult:Array.from({length:3},(_,i)=>[a.equipSuitBonusParamEdit('bResult',i,0),a.equipSuitBonusParamEdit('bResult',i,1)])});
}
fs.writeFileSync(path.join(__dirname,'.sandbox/equipment.json'),JSON.stringify(out,null,2));
console.log(JSON.stringify({gear:out.gear.map(({kind,id,roll,name,params,quality,slots})=>({kind,id,roll,name,params,quality,slots})),upgrades:out.upgrades.map(({itemId,name,params,slots,boost,elementAmplify})=>({itemId,name,params,slots,boost,elementAmplify})),sets:out.sets}));process.exit(0);
