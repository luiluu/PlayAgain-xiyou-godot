'use strict';
// dev.031 核查：真实 MOG 实时获得／胜利锁与 Bailong 单次 apply 精确伤害；只写 .sandbox。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
w.eval('CodexZones.ENABLED=false;');  // 五乘区（CodexZones）重制不移植（O-044），探针宿主默认开着；关掉让参照不含成长修正（tools51 确认关与不关产物一致或已更新夹具）
if(r.errors.length||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
w.Star.Achievement.Manager.init(); // 正式 Scene_Boot.start 的成就提示初始化，仅内存。
const stub=new Proxy(function(){},{get:()=>function(){},set:()=>true});
function setup(){
  w.eval('ConfigManager.applyData({});DataManager.setupNewGame();$gameSystem.setDifficultyId(3);Math.random=function(){return 0.99;};');
  w.eval('$gameParty._actors=[];[1,8,10,9].forEach(function(id){$gameParty.addActor(id);});');
  for(const id of [1,8,10,9]){const a=w.$gameActors.actor(id);[6168,5980,5548].concat(id===1?[2571,2786]:[]).forEach(k=>a.learnSkill(k));a.refresh();a.recoverAll();}
  w.eval('if(!$dataMap)$dataMap={displayName:"",events:[],data:[],width:1,height:1,note:"",meta:{},encounterList:[],tilesetId:1};');
  w.BattleManager.setup(222,true,false);w.$gameParty._inBattle=true;w.Math.random=()=>0.5;
  w.Game_Battler.prototype.startDamagePopup=function(){};
  w.BattleManager._logWindow=stub;w.BattleManager._spriteset=stub;
  w.BattleManager.otbDisplayWindow=function(){return stub;};
  w.BattleManager.startBattle();
}
const out={sourceIdentity:identity};
out.format=[0,9999,1e4,1.5e4,123456789,1e12,25e15,3e28].map(value=>({value,text:String(w.Star_Record.prototype.formatDamage(value))}));
out.record=[false,true].map(establish=>{
  setup();w.ConfigManager.CombatDamageRecordKey=true;
  w.eval('BattleDamageLog=0;BattleDamageLog1=0;BattleDamageLog2=0;BattleDamageLog3=0;BattleDamageLog4=0;BattleDamageLog5=0;Record=null;');
  const a=w.$gameActors.actor(1),t=w.$gameTroop.members()[0];
  if(establish){a.addState(1460);a.refresh();} // krz_state_re 的状态缓存到下一次 refresh 才更新。
  // 记录测量固定基础伤害 100，避免尚未移植的正式路线／成长平衡影响记录模块的对照。
  // 仍跑真实 Game_Action.apply、Establish 与 Bailong gainHp/displayActionResults 链。
  const saved=w.$dataSkills[14];w.$dataSkills[14]=w.JsonEx.makeDeepCopy(saved); // 正式的固定伤害测试技能，单次 apply。
  Object.assign(w.$dataSkills[14],{hitType:0,successRate:100});Object.assign(w.$dataSkills[14].damage,{variance:0,critical:false});
  const act=new w.Game_Action(a);act.setSkill(14);act.makeDamageValue=function(){return 100;};act.apply(t);
  w.Window_BattleLog.prototype.displayActionResults.call(stub,a,t);
  w.$dataSkills[14]=saved;
  return {establish,skill:14,baseDamage:100,hp:t.hp,total:w.BattleDamageLog,slots:[1,2,3,4,5].map(i=>w['BattleDamageLog'+i]),states:a._states.slice()};
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
