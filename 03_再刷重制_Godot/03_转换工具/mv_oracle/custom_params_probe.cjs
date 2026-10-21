'use strict';
// 装备 <Custom Parameters>（YEP_EquipCore evalParamPlus：每件装备在 paramPlus 里 eval 一次，user＝角色、v＝$gameVariables._data，
// 给 atk／maxhp／mhp 等局部变量赋值，按能力编号求和）：每种写法挑一件，单独装到切片角色身上（其余装备卸掉），
// 在 1／20／60 级量 evalParamPlus、paramPlus 与 param(0..7)；读变量的另在 20 级把变量设成两组值各量一次（未设的变量原版是 NaN，单列一行）。
// 内存新游戏，固定随机数 0.5；只写 .sandbox/custom_params.json。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
w.eval('ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};');
// 新游戏队伍等级上限 10；放到 99 才能量 20／60 级（同 actor_passive_probe）
w.eval('$gameParty.ActorMaxLevel=99;$dataActors.forEach(function(x){if(x)x.maxLevel=99;});');
// 量能力值前清 krz_state_re 的缓存（同 dual_wield_probe）
function clearParamCache(a){a._cacheBaseParam={};a._baseParamCache=[];a._ParamCache2=[];a._xparamCache2=[];a._sparamCache2=[];a._cacheParamBuffRate={};
  a.need_refresh_param=[1,1,1,1,1,1,1,1];a.need_refresh_xparam=[1,1,1,1,1,1,1,1,1,1];a.need_refresh_sparam=[1,1,1,1,1,1,1,1,1,1];a.need_refresh=true;a.refresh();}
const kindOf=e=>w.DataManager.isWeapon(e)?'weapon':'armor';
function baseOf(e){const db=w.DataManager.isWeapon(e)?w.$dataWeapons:w.$dataArmors;let o=e;
  for(let n=0;n<20&&o;n++){const b=o.originalBaseItemId||o.baseItemId;if(!b||b===o.id)return o.id;o=db[b];}throw new Error('基础编号循环 '+e.id);}
const J=o=>w.JSON.parse(w.JSON.stringify(o));
const num=x=>Number.isFinite(x)?x:null;  // NaN 写成 null
const LEVELS=[1,20,60],VAR_LEVEL=20;
// [写法, kind, 基础编号]：覆盖全部出现过的别名（maxhp／maxmp／mhp／mmp／atk／mat／def／mdf／agi／luk）、无效的 tp、
// 等级＋变量、变量后又被等级覆盖（最后一次赋值为准）、法宝同时读变量
// 每种写法给几件候选，取第一件有切片角色能装的
const PICKS=[['atk_only','weapon',[1595,1596,1600,1601]],['mat_only','weapon',[1598,1599]],
  ['maxhp_maxmp_def_mdf','armor',[130,131,132,133,134,135,4160,4161,4164,4165]],['luk_agi_def_mdf','armor',[4162,4166,4170,4174]],
  ['mhp_mmp_eight','weapon',[1925,2019,2020,2021]],['maxhp_atk_mat_agi','armor',[4188,4190,4192]],['tp_ignored','weapon',[78]],
  ['level_plus_vars','weapon',[1706,1707,1708,1709,1710]],['vars_then_level_override','weapon',[1926,1927]],['magic_vars_only','weapon',[74,75]]];
const SLICE_ACTORS=JSON.parse(fs.readFileSync(path.join(__dirname,'../xiyou_slice.json'),'utf8')).actors;
function snap(a,item,slot,label){
  clearParamCache(a);
  return {label,level:a.level,slot,
    equips:a.equips().map(e=>e&&{kind:kindOf(e),base:baseOf(e),params:Array.from(e.params),traits:J(e.traits),level:e.level==null?null:e.level}),
    evalPlus:Array.from({length:8},(_,i)=>num(a.evalParamPlus(item,i))),
    paramPlus:Array.from({length:8},(_,i)=>num(a.paramPlus(i))),
    params:Array.from({length:8},(_,i)=>num(a.param(i)))};
}
const cases=[];
for(const [name,kind,bases] of PICKS){
  const db=kind==='weapon'?w.$dataWeapons:w.$dataArmors;
  // 先挑能正常装上的（装备类型有槽、武器／防具类型与专属允许）；都不能时取有该槽的，直接写进槽位
  let base=0,aid=0,direct=false;
  for(const pass of [0,1]){
    for(const b of bases){
      if(!db[b]||!db[b].parameterEval)throw new Error('没有 Custom Parameters '+kind+b);
      aid=SLICE_ACTORS.find(id=>{const x=w.$gameActors.actor(id);return x.equipSlots().indexOf(db[b].etypeId)>=0&&(pass||x.canEquip(db[b]));});
      if(aid){base=b;direct=!!pass;break;}
    }
    if(aid)break;
  }
  if(!aid)throw new Error('切片角色都没有槽位 '+name);
  const src=db[base];
  w.$gameParty._weapons={};w.$gameParty._armors={};w.$gameActors._data[aid]=null;
  const a=w.$gameActors.actor(aid),slot=a.equipSlots().indexOf(src.etypeId);
  for(let i=0;i<a.equips().length;i++)a.forceChangeEquip(i,null);
  const before=w.$gameParty.equipItems().slice();
  w.$gameParty.gainItem(src,1);
  const item=w.$gameParty.equipItems().find(x=>before.indexOf(x)<0);
  if(!item)throw new Error('未生成装备 '+kind+base);
  // 专属给切片外角色的（如千古啸 req_actors 104）：本角色实例上停掉 releaseUnequippableItems，免得 refresh 又卸下
  if(direct){a.releaseUnequippableItems=function(){};a._equips[slot].setObject(item);a.refresh();}else a.forceChangeEquip(slot,item);
  if(a.equips()[slot]!==item)throw new Error('没装上 '+kind+base);
  const vars=[...new Set((src.parameterEval.match(/v\[(\d+)\]/g)||[]).map(s=>+s.slice(2,-1)))];
  const rows=[];
  for(const lv of LEVELS){a.changeLevel(lv,false);a.recoverAll();rows.push(Object.assign(snap(a,item,slot,'lv'+lv),{vars:null}));}
  if(vars.length){
    a.changeLevel(VAR_LEVEL,false);
    rows.push(Object.assign(snap(a,item,slot,'vars_unset'),{vars:Object.fromEntries(vars.map(v=>[v,null]))}));
    for(const [label,f] of [['vars_a',(v,i)=>5+i],['vars_b',(v,i)=>1000*(i+1)+7]]){
      const set=Object.fromEntries(vars.map((v,i)=>[v,f(v,i)]));
      for(const v of vars)w.$gameVariables.setValue(v,set[v]);
      rows.push(Object.assign(snap(a,item,slot,label),{vars:set}));
    }
    for(const v of vars)w.$gameVariables._data[v]=undefined;
  }
  cases.push({name,actor:aid,kind,base,direct,code:src.parameterEval,rows});
}
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname,'.sandbox'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'.sandbox/custom_params.json'),JSON.stringify({sourceIdentity:identity,maxLevel:99,cases},null,1));
console.log(JSON.stringify({cases:cases.length,rows:cases.reduce((n,c)=>n+c.rows.length,0)}));
process.exit(0);
