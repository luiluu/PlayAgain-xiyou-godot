'use strict';
// dev.031 核查：真实 MOG 实时获得／胜利锁与 Bailong 单次 apply 精确伤害；只写 .sandbox。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Applications/再刷一把：西游（mod_KYO）.app/Contents/Resources/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
const stub=new Proxy(function(){},{get:()=>function(){},set:()=>true});
function setup(){
  w.eval('ConfigManager.applyData({});DataManager.setupNewGame();$gameSystem.setDifficultyId(3);Math.random=function(){return 0.99;};');
  w.$gameParty._actors=[];[1,8,10,9].forEach(id=>w.$gameParty.addActor(id));
  for(const id of [1,8,10,9]){const a=w.$gameActors.actor(id);[6168,5980,5548].concat(id===1?[2571,2786]:[]).forEach(k=>a.learnSkill(k));a.refresh();a.recoverAll();}
  w.BattleManager.setup(222,true,false);w.$gameParty._inBattle=true;w.Math.random=()=>0.5;
  w.Game_Battler.prototype.startDamagePopup=function(){};
  w.BattleManager._logWindow=stub;w.BattleManager._spriteset=stub;
}
const out={sourceIdentity:identity};
out.format=[0,9999,1e4,1.5e4,123456789,1e12,25e15,3e28].map(value=>({value,text:String(w.Star_Record.prototype.formatDamage(value))}));
out.record=[false,true].map(establish=>{
  setup();w.ConfigManager.CombatDamageRecordKey=true;
  w.eval('BattleDamageLog=0;BattleDamageLog1=0;BattleDamageLog2=0;BattleDamageLog3=0;BattleDamageLog4=0;BattleDamageLog5=0;Record=null;');
  const a=w.$gameActors.actor(1),t=w.$gameTroop.members()[0];
  if(establish)a.addState(1460);
  // 无画面时只固定命中、会心与分散度，其余仍跑正式 Game_Action.apply 和真实记录插件。
  const saved=w.$dataSkills[1];w.$dataSkills[1]=w.JsonEx.makeDeepCopy(saved);
  Object.assign(w.$dataSkills[1],{hitType:0,successRate:100});Object.assign(w.$dataSkills[1].damage,{variance:0,critical:false});
  const act=new w.Game_Action(a);act.setSkill(1);act.apply(t);
  w.Window_BattleLog.prototype.displayActionResults.call(stub,a,t);
  w.$dataSkills[1]=saved;
  return {establish,hp:t.hp,total:w.BattleDamageLog,slots:[1,2,3,4,5].map(i=>w['BattleDamageLog'+i])};
});
out.drops=[false,true].map(enabled=>{
  setup();w.ConfigManager.MOG_TrPopUpBattle_Key=enabled;
  const t=w.$gameTroop.members()[0],it=w.$dataItems[1];
  t._treasure={checked:true,needPopup:false,item:[it]};
  const sprite=new w.Sprite();sprite._enemy=t;sprite.height=96;
  const before=w.$gameParty.numItems(it);
  // Spriteset_Battle.treasurePopupR 只在设置开启时创建 SpriteEnemyTrP。
  if(enabled)new w.SpriteEnemyTrP(sprite);
  const onCollapse=w.$gameParty.numItems(it)-before;
  w.BattleManager._rewards={items:[it]};w.BattleManager.gainDropItems();
  return {enabled,onCollapse,afterVictory:w.$gameParty.numItems(it)-before,lock:w.$gameTemp._trBatDropLock};
});
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname,'.sandbox'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'.sandbox/drop_record.json'),JSON.stringify(out,null,1));
console.log(JSON.stringify({records:out.record,drops:out.drops}));
process.exit(0);
