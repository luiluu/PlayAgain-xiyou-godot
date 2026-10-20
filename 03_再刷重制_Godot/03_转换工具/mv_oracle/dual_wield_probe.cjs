'use strict';
// 双持装备槽（特性 55 → YEP_EquipCore equipSlots 第 2 格改为武器；YEP_ItemCore convertInitEquips／grabInitEquips）：
// 刘备（13，专属剑 2005 带双持）与曼德斯（26，职业双持）的槽位类型、初始装备、逐步换装（含卸下不符的副手）、
// 装备页候选、能力值与普通攻击动画（weapons()[0]／[1]）。内存新游戏，固定随机数 0.5；只写 .sandbox/dual_wield.json。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
w.eval('ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};');
// 量能力值前清 krz_state_re 的缓存（同 wtype_probe）
function clearParamCache(a){a._cacheBaseParam={};a._baseParamCache=[];a._ParamCache2=[];a._xparamCache2=[];a._sparamCache2=[];a._cacheParamBuffRate={};
  a.need_refresh_param=[1,1,1,1,1,1,1,1];a.need_refresh_xparam=[1,1,1,1,1,1,1,1,1,1];a.need_refresh_sparam=[1,1,1,1,1,1,1,1,1,1];a.need_refresh=true;a.refresh();}
const kindOf=e=>w.DataManager.isWeapon(e)?'weapon':'armor';
// 基础编号：独立装备的 baseItemId 可能指向另一件独立装备（入队时装上的件卸下后再生成一次），一直追到数据库原件
function baseOf(e){const db=w.DataManager.isWeapon(e)?w.$dataWeapons:w.$dataArmors;let o=e;
  for(let n=0;n<20&&o;n++){const b=o.originalBaseItemId||o.baseItemId;if(!b||b===o.id)return o.id;o=db[b];}throw new Error('基础编号循环 '+e.id);}
const brief=e=>e?{kind:kindOf(e),base:baseOf(e)}:null;
const J=o=>w.JSON.parse(w.JSON.stringify(o));
const instances={};   // 实例 id → 实例属性（Godot 测试用同样的属性重建）
function gain(kind,base){
  const db=kind==='weapon'?w.$dataWeapons:w.$dataArmors,before=w.$gameParty.equipItems().slice();
  w.$gameParty.gainItem(db[base],1);
  const e=w.$gameParty.equipItems().find(x=>before.indexOf(x)<0);
  if(!e)throw new Error('未生成装备 '+kind+base);
  instances[kind+':'+e.id]={kind,base,params:Array.from(e.params),traits:J(e.traits)};
  return e;
}
function bag(){return w.$gameParty.equipItems().map(e=>({kind:kindOf(e),base:baseOf(e)})).sort((x,y)=>(x.kind+x.base)<(y.kind+y.base)?-1:1);}
function snap(a,label,extra){
  clearParamCache(a);
  const slots=Array.from(a.equipSlots());
  const cand=slots.slice(0,3).map((t,i)=>w.$gameParty.equipItems().filter(e=>e.etypeId===t&&a.canEquip(e)).map(baseOf));
  return Object.assign({label,dual:!!a.isDualWield(),slotType:a.slotType(),slots,
    slotNames:slots.map(t=>w.$dataSystem.equipTypes[t]),
    equips:a.equips().map(e=>e&&Object.assign(brief(e),{params:Array.from(e.params),traits:J(e.traits)})),bag:bag(),candidates:cand,
    params:Array.from({length:8},(_,i)=>a.param(i)),xparams:Array.from({length:10},(_,i)=>a.xparam(i)),
    weapons:a.weapons().map(baseOf),attackAnimationId1:a.attackAnimationId1(),attackAnimationId2:a.attackAnimationId2()},extra||{});
}
function fresh(aid){
  w.$gameParty._weapons={};w.$gameParty._armors={};
  w.$gameActors._data[aid]=null;const a=w.$gameActors.actor(aid);a.changeLevel(LEVEL,false);a.recoverAll();return a;
}
const LEVEL=20;   // 匕首 27 要 20 级
const flows=[];
// 换装步骤：[槽, kind, base]（base 0 卸下）；在背包里找同基础编号的第一件实例。只走装备页能选的组合（candidates）：
// MV changeEquip 先与背包交换再查槽位类型，类型不符时物品被吞掉；装上不能装备的会立即被卸回背包——界面上都选不到，不测
function step(a,slot,kind,base){
  let item=null;
  if(base){item=w.$gameParty.equipItems().find(e=>kindOf(e)===kind&&baseOf(e)===base);if(!item)throw new Error('背包没有 '+kind+base+' '+JSON.stringify(bag())+JSON.stringify(a.equips().map(brief)));}
  a.changeEquip(slot,item);
  return {slot,kind,base,ok:item?a.equips()[slot]===item:!a.equips()[slot]};
}
function flow(name,aid,gains,steps){
  const a=fresh(aid),made=gains.map(([k,b])=>gain(k,b));
  const out={name,actor:aid,gains:made.map(e=>instances[kindOf(e)+':'+e.id]),initial:snap(a,'initial'),steps:[]};
  for(const s of steps){
    if(s[0]==='optimize'||s[0]==='clear'){
      const flag=s[0]==='optimize'?'_optimizeEquipments':'_clearEquipments';
      w.$gameTemp[flag]=true;s[0]==='optimize'?a.optimizeEquipments():a.clearEquipments();w.$gameTemp[flag]=false;
      out.steps.push(snap(a,s[0],{op:s[0]}));
    }else out.steps.push(snap(a,s.join(' '),{op:'change',change:step(a,...s)}));
  }
  flows.push(out);
}
// 第二把武器用没有 <Custom Parameters>、不是专属的：YEP customParamPlus（如新手水果刀 1595 的 atk = user.level * 2）Godot 未实现，另登记
// 刘备装不了匕首 27（候选里没有，Godot 同），只放在背包里比候选；
// 刘备：副手盾 → 装 2005 变双持（盾被卸回背包）→ 副手位装第二把武器 → 换掉 2005（第二把武器被卸）→ 再装 → 清空 → 最强
flow('liubei',13,[['armor',70],['weapon',2005],['weapon',2],['weapon',27],['weapon',1386]],[
  [1,'armor',70],[0,'weapon',2005],[1,'weapon',2],[1,'weapon',1386],[0,'weapon',2],
  [1,'armor',70],[0,'weapon',2005],[1,'weapon',1386],[1,'weapon',0],[1,'weapon',2],['clear'],['optimize']]);
// 曼德斯：职业双持，第 2 格一直是武器
flow('manders',26,[['armor',70],['weapon',27],['weapon',1386],['weapon',2]],[
  [0,'weapon',27],[1,'weapon',1386],[0,'weapon',0],['clear'],['optimize']]);
// 初始装备：initIndependentEquips(编号表)，按 convertInitEquips（第 1 项武器；双持时第 2 项也查武器表）与 grabInitEquips 分槽
const inits=[];
for(const [aid,ids] of [[13,[2005,70]],[13,[27,1386]],[26,[27,1386]],[26,[27,70]],[26,[1,1,0,0,0,0]],[13,[2,0,0,0,0,null,174]],[26,[0,1386,0,174]]]){
  const a=fresh(aid);a.initIndependentEquips(ids.slice());
  inits.push(Object.assign({actor:aid,ids},snap(a,'init')));
}
// 初始入队时的实际装备（Game_Actor.setup）
const setups=[13,26].map(aid=>{const a=fresh(aid);return Object.assign({actor:aid},snap(a,'setup'));});
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname,'.sandbox'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'.sandbox/dual_wield.json'),JSON.stringify({sourceIdentity:identity,level:LEVEL,flows,inits,setups},null,1));
console.log(JSON.stringify({flows:flows.length,steps:flows.reduce((n,f)=>n+f.steps.length,0),inits:inits.length,gear:Object.keys(instances).length}));
process.exit(0);
