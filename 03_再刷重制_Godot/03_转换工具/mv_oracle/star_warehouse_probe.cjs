'use strict';
// 星级仓库（Star_Warehouse 通用仓库，Map041 黄金大厅 EV1）：在正式引擎里建出存放／取出两个画面（Scene_StarSaveWarehouse／Scene_StarWarehouse），
// 用列表窗的 processOk 逐件存入、换局（setupNewGame，配置里的 GetEq／GetPet 留在内存）后取出，记录列表、背包、宠物、仓库、声音与提示。
// 摆法：新局 1/8/9/10；背包放普通武器（本体 2）、PushDct 武器（本体 52）、普通防具（本体 2）、锁定武器（本体 3，名字加 [锁定]）、
// 吞器异化武器（配置借用另一件本体 2 武器作供体）；宠物 3 只（敌人 1／2／3），第 2 只出战。只写 .sandbox/star_warehouse.json。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded()||!w.Scene_StarWarehouse||!w.CodexAlienation)throw new Error('参照引擎启动失败');
const A=w.CodexAlienation,J=x=>JSON.parse(JSON.stringify(x)),toasts=[],sounds=[],saves=[];
w.$.toaster=o=>toasts.push(String(o&&o.message));
['playOk','playCancel','playBuzzer','playEquip','playCursor'].forEach(k=>{w.SoundManager[k]=function(){sounds.push(k);};});
const save0=w.ConfigManager.save;w.ConfigManager.save=function(){saves.push(J({GetEq:(this.GetEq||[]).length,GetPet:(this.GetPet||[]).length}));};
// 说明窗的 Galv 物品说明精灵要读当前场景；无画面引擎不画说明，只量数据
w.Window_StarItemList.prototype.updateHelp=function(){};
w.eval('SceneManager.initInput();ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};');
const Pt=()=>w.$gameParty;
Pt()._items={};Pt()._weapons={};Pt()._armors={};
const gain=(db,id)=>{const before=new Set((db===w.$dataWeapons?Pt().weapons():Pt().armors()));Pt().gainItem(db[id],1);return (db===w.$dataWeapons?Pt().weapons():Pt().armors()).find(i=>!before.has(i));};
const plainW=gain(w.$dataWeapons,2),pushW=gain(w.$dataWeapons,52),plainA=gain(w.$dataArmors,2),lockW=gain(w.$dataWeapons,3),donor=gain(w.$dataWeapons,2);
lockW.name+='[锁定]';
const swallowBase=Number(Object.keys(A.config.pools).find(k=>k.startsWith('w:')&&A.config.pools[k].includes('swallow')&&w.$dataWeapons[Number(k.slice(2))]).slice(2));
const alienW=A.create('w',swallowBase,'boss','swallow');Pt().gainItem(alienW,1);
A.mark(alienW).config={actorId:1,donorId:donor.id};
const pets=[1,2,3].map(id=>w.Star.PetSystem.GetingPet(new w.Game_Enemy(id,0,0)));
Pt().Pets=w.eval("[]");pets.forEach(p=>Pt().Pets.push(p));Pt().GTWar=pets[1];
const gearRow=i=>i&&{kind:w.DataManager.isWeapon(i)?'w':'a',id:i.id,base:i.baseItemId||0,name:i.name,mark:A.mark(i)?J(A.mark(i)):null};
const petRow=p=>p?{enemy:p._enemyId,name:p.name()}:null;
// 角色标记挂在物件上（换局后 $dataWeapons 回到原长，独立装备编号会重复）
[['plain',plainW],['push',pushW],['armor',plainA],['locked',lockW],['donor',donor],['alien',alienW]].forEach(([k,i])=>{i._probeRole=k;});
const roleOf=i=>i&&(i._probeRole||'?');
let sc=null;
function open(cls){sc=new cls();w.SceneManager._scene=sc;sc.create();sc._categoryWindow.update();}
function pick(sym){sc._categoryWindow.selectSymbol(sym);sc._categoryWindow.update();sounds.length=0;sc._categoryWindow.processOk();}
const list=()=>(sc._itemWindow._data||[]).map(i=>i&&(sc._itemWindow._category==='equip'?Object.assign(gearRow(i),{role:roleOf(i)}):petRow(i)));
function snap(label,extra){return Object.assign({label,category:sc._itemWindow._category,index:sc._itemWindow.index(),active:sc._itemWindow.active,list:list(),
  bag:{weapons:Pt().weapons().map(i=>Object.assign(gearRow(i),{role:roleOf(i)})),armors:Pt().armors().map(i=>Object.assign(gearRow(i),{role:roleOf(i)}))},
  pets:(Pt().Pets||[]).map(petRow),war:petRow(Pt().GTWar),
  GetEq:(w.ConfigManager.GetEq||[]).map(i=>Object.assign(gearRow(i),{role:roleOf(i)})),GetPet:(w.ConfigManager.GetPet||[]).map(petRow),
  reservedDonor:A.reserved(donor),sounds:sounds.slice(),toasts:toasts.splice(0),saves:saves.splice(0)},extra||{});}
// 列表上选第 i 项按确定（Window_Selectable.processOk：允许时先放确定音，再调 onItemOk）
function ok(i){sounds.length=0;sc._itemWindow.activate();sc._itemWindow.select(i);sc._itemWindow.processOk();}
const steps=[];
// 1. 存放画面：开场（分类窗激活）、装备列表
open(w.Scene_StarSaveWarehouse);
steps.push(snap('save_open',{categoryActive:sc._categoryWindow.active,categoryIndex:sc._categoryWindow.index(),commands:sc._categoryWindow._list.map(c=>[c.name,c.symbol])}));
pick('equip');
steps.push(snap('save_equip_list',{categorySounds:sounds.slice()}));
// 2. 依次存入：普通武器、PushDct、锁定、供体、异化（每次按当时列表里的位置找）
const at=k=>sc._itemWindow._data.findIndex(i=>i&&roleOf(i)===k);
for(const k of ['plain','push','locked','donor','alien']){ok(at(k));steps.push(snap('deposit_'+k));}
// 3. 宠物：点出战宠物、存第 1 只
sounds.length=0;sc._itemWindow.processCancel();
const cancelSounds=sounds.slice();
pick('Pet');
steps.push(snap('save_pet_list',{cancelSounds}));
ok(Pt().Pets.indexOf(Pt().GTWar));steps.push(snap('deposit_war_pet'));
ok(0);steps.push(snap('deposit_pet0'));
// 4. 空列表：宠物只剩出战那只以外的一只，再存掉，然后点空格（index 超出）
ok(Pt().Pets.findIndex(p=>p!==Pt().GTWar));steps.push(snap('deposit_pet_rest'));
// 5. 换局：新局后配置还在内存；背包先放一件本体 2 武器，看取出的编号
w.eval('DataManager.setupNewGame();');
Pt()._items={};Pt()._weapons={};Pt()._armors={};
const fresh=gain(w.$dataWeapons,2);fresh._probeRole='fresh';
open(w.Scene_StarWarehouse);
pick('equip');
steps.push(snap('load_equip_list',{dataWeaponsLength:w.$dataWeapons.length}));
for(const k of ['plain','alien']){const before=w.$dataWeapons.length;ok(at(k));steps.push(snap('withdraw_'+k,{dataWeaponsBefore:before}));}
sc._itemWindow.processCancel();
pick('Pet');
steps.push(snap('load_pet_list'));
ok(0);steps.push(snap('withdraw_pet0'));
// 6. 空格：仓库宠物取光后点第 1 格
ok(0);steps.push(snap('withdraw_pet_last'));
ok(0);steps.push(snap('withdraw_empty'));
w.ConfigManager.save=save0;
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname,'.sandbox'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'.sandbox/star_warehouse.json'),JSON.stringify({sourceIdentity:identity,swallowBase,steps},null,1));
console.log(JSON.stringify({steps:steps.length,labels:steps.map(s=>s.label)}));
process.exit(0);
