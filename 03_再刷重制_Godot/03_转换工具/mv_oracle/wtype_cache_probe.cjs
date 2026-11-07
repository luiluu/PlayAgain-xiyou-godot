'use strict';
// 【cc·rules·未经审查】wtype_cache_oracle 夹具的探针（newsrc2 补回）：原夹具（沙僧 82）出自没入库的 .sandbox/merge82_admission_probe_v5.cjs。
// wtype_probe 直接切 inBattle、跳过 Scene_Battle.start 的被动缓存刷新，148 号 10 级时 5600 的减耗缓存仍是 0（stale）；
// 这里同样搭到 stale，再照原版调一次 refreshPassiveCache（warmed），记两边的 MP 费用、consumeReduce、canUse（满 MP 与清零）。
// 只写 .sandbox/wtype_cache.json，拷成 tests/fixtures/wtype_cache_oracle.json。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const ACTOR=148,SKILL=5600,LEVEL=10;
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
w.eval('ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};');
let inb=false;w.$gameParty.inBattle=function(){return inb;};
function clearParamCache(a){a._cacheBaseParam={};a._baseParamCache=[];a._ParamCache2=[];a._xparamCache2=[];a._sparamCache2=[];a._cacheParamBuffRate={};
  a.need_refresh_param=[1,1,1,1,1,1,1,1];a.need_refresh_xparam=[1,1,1,1,1,1,1,1,1,1];a.need_refresh_sparam=[1,1,1,1,1,1,1,1,1,1];a.need_refresh=true;a.refresh();}
const a=w.$gameActors.actor(ACTOR),sk=w.$dataSkills[SKILL];
a.changeLevel(LEVEL,false);
inb=false;a.refresh();clearParamCache(a);inb=true;a.recoverAll();a._tp=a.maxTp();
function measure(){
  const c=a._passiveCache.consumeReduce;
  const consume=JSON.parse(JSON.stringify({bySkill:c.bySkill,byType:c.byType,all:c.all}));
  const out={canUse:!!a.canUse(sk),cost:{mp:a.skillMpCost(sk),tp:a.skillTpCost(sk)},consume};
  a._mp=0;a._tp=0;out.canUseEmpty=!!a.canUse(sk);a.recoverAll();a._tp=a.maxTp();
  return out;
}
const mp=a.mmp,stale=measure();
a.refreshPassiveCache();
const warmedFull=measure();
const warmed={consume:warmedFull.consume,cost:warmedFull.cost.mp,canUse:warmedFull.canUse,canUseEmpty:warmedFull.canUseEmpty};
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
const out={schemaVersion:1,sourceIdentity:identity,
  scope:'wtype probe switches inBattle directly after changeLevel without Scene_Battle.start cache phase; native before/after real refreshPassiveCache shown, canonical generated remains unchanged',
  actor:ACTOR,skill:SKILL,level:a.level,mp,stale,warmed,probe:'mv_oracle/wtype_cache_probe.cjs'};
fs.mkdirSync(path.join(__dirname,'.sandbox'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'.sandbox/wtype_cache.json'),JSON.stringify(out,null,1));
console.log(JSON.stringify({level:out.level,mp,stale,warmed}));
process.exit(0);
