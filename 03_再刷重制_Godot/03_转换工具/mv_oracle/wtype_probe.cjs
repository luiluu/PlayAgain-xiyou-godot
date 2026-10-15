'use strict';
// 技能武器类型要求（Game_Actor.isSkillWtypeOk，经 dsPassiveSkill 的 isWtypeEquipped）：切片角色（10 级）× 默认装备／裸装／各武器类型的第一件
// × 角色已学技能＋几招有武器要求的技能，记战斗中 canUse（满 MP/TP，及 MP/TP 清零时）。只写 .sandbox/wtype.json。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
w.eval('ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};');
const SLICE=JSON.parse(fs.readFileSync(path.join(__dirname,'../xiyou_slice.json'),'utf8'));
// 搭装备、升级在战斗外做：krz_state_re 在战斗中用 _ParamCache2 缓存属性，只在 need_refresh 时重算，战斗中 changeLevel 不触发，
// 会让 10 级角色的 MP 上限停在 1 级值（真实游戏只在胜利结算时于战斗中升级，战后恢复）。量 canUse 前照正式版 Z.refresh 的写法清缓存。
let inb=false;w.$gameParty.inBattle=function(){return inb;};
function clearParamCache(a){a._cacheBaseParam={};a._baseParamCache=[];a._ParamCache2=[];a._xparamCache2=[];a._sparamCache2=[];a._cacheParamBuffRate={};
  a.need_refresh_param=[1,1,1,1,1,1,1,1];a.need_refresh_xparam=[1,1,1,1,1,1,1,1,1,1];a.need_refresh_sparam=[1,1,1,1,1,1,1,1,1,1];a.need_refresh=true;a.refresh();}
const firstOfType={};for(let id=1;id<w.$dataWeapons.length;id++){const o=w.$dataWeapons[id];if(o&&o.name&&o.wtypeId>0&&!firstOfType[o.wtypeId])firstOfType[o.wtypeId]=id;}
const EXTRA=[101,160,162,164,3641,3644,2106];
const cases=[];
for(const aid of SLICE.actors){const a=w.$gameActors.actor(aid);if(!a)continue;a.changeLevel(10,false);
  const variants=[['default',null],['naked',0]].concat(Object.keys(firstOfType).map(t=>['wtype'+t,firstOfType[t]]));
  const original=a._equips.map(e=>e.object());
  for(const [name,wid] of variants){
    if(name!=='default'){a._equips.forEach((e,i)=>e.setObject(i===0&&wid?w.$dataWeapons[wid]:null));}
    inb=false;a.refresh();clearParamCache(a);inb=true;a.recoverAll();a._tp=a.maxTp();
    const ids=[...new Set(a.skills().map(s=>s.id).concat(EXTRA))].filter(id=>{const s=w.$dataSkills[id];return s&&(s.occasion===0||s.occasion===1);});
    for(const id of ids){const sk=w.$dataSkills[id],full=!!a.canUse(sk);a._mp=0;a._tp=0;const empty=!!a.canUse(sk);a.recoverAll();a._tp=a.maxTp();
      cases.push({actor:aid,variant:name,weapon:wid,skill:id,canUse:full,canUseEmpty:empty,level:a.level,mmp:a.mmp,wtypeOk:!!a.isSkillWtypeOk(sk)});}
    inb=false;a._equips.forEach((e,i)=>e.setObject(original[i]||null));
  }
}
// 冲突标签夹具：正式 refreshPassiveCache 的解析顺序是装备→技能→状态；SkETypeAll 优先于 SkEquipType。
const priority=[];
for(const all of [false,true]){
  const a=new w.Game_Actor(1), equipMeta={SkEquipType:'2'}, skillMeta={SkEquipType:'5'};
  if(all)skillMeta.SkETypeAll='2';
  const weapon=Object.assign({},w.$dataWeapons[2],{wtypeId:2,meta:equipMeta});
  a.equips=()=>[weapon];a.skills=()=>[{meta:skillMeta,note:''}];a.states=()=>[];
  a.initPassiveCache();a.refreshPassiveCache();
  priority.push({equipMeta,skillMeta,weaponType:2,answers:[1,2,5,7].map(t=>!!a.isWtypeEquipped(t))});
}
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname,'.sandbox'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'.sandbox/wtype.json'),JSON.stringify({sourceIdentity:identity,firstOfType,cases,priority},null,1));
console.log(JSON.stringify({cases:cases.length,blocked:cases.filter(c=>!c.wtypeOk).length,firstOfType}));
process.exit(0);
