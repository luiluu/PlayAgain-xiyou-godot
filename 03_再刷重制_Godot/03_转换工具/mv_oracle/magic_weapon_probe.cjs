'use strict';
// 法宝每级成长（CP_MagicWeapon paramPlus：每件法宝加 item.level() × paramPlusPerLevel，成长在载入时从数据库原件备注
// <mhp Param +N per Level> 解析一次）：八重樱 92 入队自带的赤染樱（armor 4518，另有最大生命 ×1.2 特性）在法宝 1／7／40 级，
// 以及别的角色装上各项成长不同的法宝、头部法宝、无专属法宝时的能力值与 paramPlus。等级存在独立装备实例上（object().level），
// 这里直接改实例等级。内存新游戏，固定随机数 0.5；只写 .sandbox/magic_weapon.json。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
w.eval('ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};');
// 量能力值前清 krz_state_re 的缓存（同 dual_wield_probe）
function clearParamCache(a){a._cacheBaseParam={};a._baseParamCache=[];a._ParamCache2=[];a._xparamCache2=[];a._sparamCache2=[];a._cacheParamBuffRate={};
  a.need_refresh_param=[1,1,1,1,1,1,1,1];a.need_refresh_xparam=[1,1,1,1,1,1,1,1,1,1];a.need_refresh_sparam=[1,1,1,1,1,1,1,1,1,1];a.need_refresh=true;a.refresh();}
const kindOf=e=>w.DataManager.isWeapon(e)?'weapon':'armor';
function baseOf(e){const db=w.DataManager.isWeapon(e)?w.$dataWeapons:w.$dataArmors;let o=e;
  for(let n=0;n<20&&o;n++){const b=o.originalBaseItemId||o.baseItemId;if(!b||b===o.id)return o.id;o=db[b];}throw new Error('基础编号循环 '+e.id);}
const J=o=>w.JSON.parse(w.JSON.stringify(o));
const LEVEL=30;
function fresh(aid){
  w.$gameParty._weapons={};w.$gameParty._armors={};
  w.$gameActors._data[aid]=null;const a=w.$gameActors.actor(aid);a.changeLevel(LEVEL,false);a.recoverAll();return a;
}
function snap(a,label){
  clearParamCache(a);
  return {label,
    equips:a.equips().map(e=>e&&{kind:kindOf(e),base:baseOf(e),params:Array.from(e.params),traits:J(e.traits),
      magic:!!w.CP.MagicWeaponManager.isMagicWeapon(e),level:e.level,perLevel:e.paramPlusPerLevel?Array.from(e.paramPlusPerLevel):null}),
    paramPlus:Array.from({length:8},(_,i)=>a.paramPlus(i)),
    params:Array.from({length:8},(_,i)=>a.param(i))};
}
const cases=[];
// 92 入队自带赤染樱：先量 Init Level，再改实例等级
{
  const a=fresh(92),slot=a.equips().findIndex(e=>e&&baseOf(e)===4518);
  if(slot<0)throw new Error('92 没有赤染樱');
  const rows=[];
  for(const lv of [null,7,40]){if(lv!=null)a.equips()[slot].level=lv;rows.push(Object.assign(snap(a,lv==null?'init':'lv'+lv),{slot,setLevel:lv}));}
  cases.push({name:'yae_setup',actor:92,rows});
}
// 别的角色装上法宝（武器类法宝 73～75 都带 <Custom Parameters> 读变量，Godot 未做，不选）：[名, 角色, kind, 基础编号, 等级表]；放进与装备类型相同的第一格（forceChangeEquip 不查专属）
for(const [name,aid,kind,base,levels] of [['zhuxian_mixed',162,'armor',123,[null,3]],['luoyun_nonexclusive',1,'armor',121,[null,12]],
  ['obito_mask_head',88,'armor',1906,[null,5]],['yae_sakura_on_lv1',92,'armor',4518,[null]]]){
  const a=fresh(aid),db=kind==='weapon'?w.$dataWeapons:w.$dataArmors,before=w.$gameParty.equipItems().slice();
  w.$gameParty.gainItem(db[base],1);
  const item=w.$gameParty.equipItems().find(x=>before.indexOf(x)<0);
  if(!item)throw new Error('未生成装备 '+kind+base);
  const slot=a.equipSlots().indexOf(item.etypeId);
  if(slot<0)throw new Error(aid+' 没有装备类型 '+item.etypeId);
  a.forceChangeEquip(slot,item);
  if(a.equips()[slot]!==item)throw new Error('没装上 '+kind+base);
  const rows=[];
  for(const lv of levels){if(lv!=null)item.level=lv;rows.push(Object.assign(snap(a,lv==null?'init':'lv'+lv),{slot,setLevel:lv}));}
  cases.push({name,actor:aid,rows});
}
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname,'.sandbox'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'.sandbox/magic_weapon.json'),JSON.stringify({sourceIdentity:identity,level:LEVEL,cases},null,1));
console.log(JSON.stringify({cases:cases.length,rows:cases.reduce((n,c)=>n+c.rows.length,0)}));
process.exit(0);
