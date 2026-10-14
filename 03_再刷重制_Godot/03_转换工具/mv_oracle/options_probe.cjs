'use strict';
// 只读正式引擎，设置/跑步/指令记忆均在内存，不加载配置或玩家存档。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Applications/再刷一把：西游（mod_KYO）.app/Contents/Resources/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
w.eval('ConfigManager.applyData({});DataManager.setupNewGame();Input._currentState={};Graphics.boxWidth=1280;Graphics.boxHeight=720;');
const out={sourceIdentity:identity,defaults:{},rows:[],volume:[],dash:[],commands:[],skills:[],flags:[],speed:[],display:[]};
const symbols=['MapXy','codexSmartAI','alwaysDash','commandRemember','bgmVolume','bgsVolume','meVolume','seVolume','CombatDamageShow','CombatSkillAnimation','battleAniSpeed'];
for(const s of symbols)out.defaults[s]=w.ConfigManager[s];
const win=new w.Window_Options();
out.rows=win._list.map((e,i)=>({name:e.name,symbol:e.symbol,status:String(win.statusText(i))}));
for(const symbol of symbols.filter(s=>s.endsWith('Volume'))){
  win.select(win.findSymbol(symbol));
  for(const initial of [0,40,95,100])for(const op of ['processOk','cursorRight','cursorLeft']){
    w.ConfigManager[symbol]=initial;win[op](false);
    out.volume.push({symbol,initial,op,value:w.ConfigManager[symbol],status:String(win.statusText(win.index()))});
  }
}
for(const symbol of ['CombatDamageShow','CombatSkillAnimation']){
  win.select(win.findSymbol(symbol));
  for(const initial of [false,true])for(const op of ['processOk','cursorRight','cursorLeft']){
    w.ConfigManager[symbol]=initial;win[op](false);
    out.flags.push({symbol,initial,op,value:w.ConfigManager[symbol],status:String(win.statusText(win.index()))});
  }
}
win.select(win.findSymbol('battleAniSpeed'));
for(const initial of [1,2,3,4])for(const op of ['processOk','cursorRight','cursorLeft']){
  w.ConfigManager.battleAniSpeed=initial;win[op](false);
  out.speed.push({initial,op,value:w.ConfigManager.battleAniSpeed,status:String(win.statusText(win.index()))});
}
w.$gameParty._inBattle=true;
out.timing=[];
out.attackSequence={};
for(const key of ['setupActions','wholeActions','targetActions','followActions','finishActions'])out.attackSequence[key]=w.$dataSkills[1][key];
for(const value of [1,2,3,4]){
  w.ConfigManager.battleAniSpeed=value;
  const anim={},moving={};
  w.Sprite_Animation.prototype.setupRate.call(anim);
  anim._animation={frames:[[],[],[],[],[]]};w.Sprite_Animation.prototype.setupDuration.call(anim);
  w.Sprite_Battler.prototype.startMove.call(moving,10,20,30);
  w.BattleManager._logWindow={};
  w.BattleManager.actionWait(13);
  const wait=w.BattleManager._logWindow._waitCount;
  w.BattleManager.actionAniWait(13);
  const animationWait=w.BattleManager._logWindow._waitCount;
  w.BattleManager._subject=w.$gameActors.actor(1);w.BattleManager._logWindow._waitCount=0;w.BattleManager._logWindow.performAction=function(){};
  w.BattleManager.actionPerformAction();
  out.timing.push({value,animationRate:anim._rate,animationDuration5:anim._duration,movement:moving._movementDuration,wait,animationWait,performActionWait:w.BattleManager._logWindow._waitCount});
}
const actor=w.$gameActors.actor(1);
for(const enabled of [false,true]){
  w.ConfigManager.CombatDamageShow=enabled;
  w.ConfigManager.CombatSkillAnimation=enabled;
  for(const result of [{hpAffected:true,hpDamage:12},{hpAffected:true,hpDamage:-12},{mpDamage:12},{missed:true}]){
    actor.clearDamagePopup();actor.clearResult();Object.assign(actor.result(),result);actor.startDamagePopup();
    out.display.push({enabled,result,popups:actor._damagePopup.length});
  }
  actor._animations=[];actor.startAnimation(1,false,0);
  out.display.push({enabled,animationRequests:actor._animations.length});
}
for(const always of [false,true])for(const shift of [false,true]){
  w.ConfigManager.alwaysDash=always;w.Input._currentState.shift=shift;
  out.dash.push({always,shift,dashing:w.$gamePlayer.isDashButtonPressed()});
}
w.eval('$gameActors.actor(1).learnSkill(160);$gameActors.actor(1).learnSkill(161);$gameParty._actors=[1,8];$gameParty._inBattle=true;');
const a=w.$gameActors.actor(1);
for(const remember of [false,true]){
  w.ConfigManager.commandRemember=remember;a.setLastCommandSymbol('skill');a.setLastBattleSkill(w.$dataSkills[160]);
  const cmd=new w.Window_ActorCommand();cmd.setup(a);
  out.commands.push({remember,index:cmd.index(),symbol:cmd.currentSymbol(),ext:cmd.currentExt()});
  const sk=new w.Window_BattleSkill();sk.setActor(a);sk.setStypeId(1);sk.selectLast();
  out.skills.push({remember,id:sk.item()&&sk.item().id});
}
// 消息提醒（installV019UsabilityRuntime）：子页行、说明、开关操作、设置页状态文字、配置读写与自动提示分类。
{
  const U=w.CodexV019,nt={};
  w.ConfigManager.applyData({});
  nt.defaults={notices:Object.assign({},w.ConfigManager.codexNotices),skillLevel:w.ConfigManager.codexSkillLevelNotice};
  const sc=new w.Scene_CodexNotices();sc.create();
  const l=sc._list,h=sc._heading;
  nt.heading=[h.x,h.y,h.width,h.height];nt.list=[l.x,l.y,l.width,l.height,l.maxItems(),l.index()];
  nt.rows=l._list.map((c,i)=>({name:c.name,key:c.ext,hint:l.hintOf(c.ext),on:l.isOn(c.ext)}));
  nt.ops=[];
  for(let i=0;i<l.maxItems();i++){
    l.select(i);
    for(const op of ['toggle','cursorRight','cursorLeft','cursorLeft','toggle']){
      if(op==='toggle')l.toggleCurrent();else l[op]();
      nt.ops.push({index:i,op,index2:l.index(),on:l.isOn(l.extOf(i))});
    }
  }
  const oi=win.findSymbol('codexNotices');win.select(oi);
  nt.status=[];
  w.ConfigManager.applyData({});
  nt.status.push({off:[],text:String(win.statusText(oi))});
  for(const off of [['race'],['zhenqi','skillLevel'],['race','chest','zhenqi','points','drop','learn','dungeon','share','skillLevel']]){
    w.ConfigManager.applyData({codexNotices:Object.fromEntries(off.filter(k=>k!=='skillLevel').map(k=>[k,false])),codexSkillLevelNotice:!off.includes('skillLevel')});
    nt.status.push({off,text:String(win.statusText(oi))});
  }
  for(const op of ['cursorRight','cursorLeft']){win[op](false);nt.status.push({op,index:win.index(),text:String(win.statusText(oi))});}
  nt.saved=w.ConfigManager.makeData().codexNotices;nt.savedSkillLevel=w.ConfigManager.makeData().codexSkillLevelNotice;
  w.ConfigManager.applyData({codexNotices:{race:0,chest:null,zhenqi:false}});
  nt.loose=Object.assign({},w.ConfigManager.codexNotices);
  nt.classify=['宝箱收获：金币×3','获得 肝帝积分 +5','滑稽值＋1','抽奖券额外 +1','副本Boss专属掉落：XX','权能掉落','获得锻造材料','孙悟空已领悟 火眼金睛','副本挑战完成！','逃离副本','进入副本，关闭挂机','技能共享激活：光环','羁绊：师徒','装备出售完成','已保存到存档 1。','没药了']
    .map(message=>({message,key:U.classify({message})}));
  w.ConfigManager.applyData({});
  out.notices=nt;
}
// 核心里的杂项开关（rpg_windows/rpg_objects 改动）：只遇稀有/罕见/极其稀有、穿墙、对话跳过、禁用遇敌、步步遇敌、三条宣传行。
{
  const SYMS=['Boss','BOSS','boss','cq','wxxonoff','wxlonoff','wxtonoff','dhtg','ydgb','yd100'];
  const ms={rows:[],ops:[],persist:{},message:[],passable:[],troops:[],progress:[],execute:[]};
  w.ConfigManager.applyData({});
  for(const s of SYMS)ms.rows.push({symbol:s,value:w.ConfigManager[s]===undefined?null:w.ConfigManager[s],status:win.statusText(win.findSymbol(s))===undefined?null:String(win.statusText(win.findSymbol(s)))});
  for(const s of SYMS){
    win.select(win.findSymbol(s));
    for(const initial of [undefined,false,true])for(const op of ['processOk','cursorRight','cursorLeft']){
      w.ConfigManager[s]=initial;win[op](false);
      ms.ops.push({symbol:s,initial:initial===undefined?null:initial,op,value:w.ConfigManager[s]===undefined?null:w.ConfigManager[s],status:String(win.statusText(win.index()))});
    }
  }
  for(const s of SYMS)w.ConfigManager[s]=true;
  const saved=w.ConfigManager.makeData();
  ms.persist.saved=SYMS.filter(s=>s in saved);
  for(const s of SYMS)delete w.ConfigManager[s];
  w.ConfigManager.applyData(Object.fromEntries(SYMS.map(s=>[s,true])));
  ms.persist.applied=Object.fromEntries(SYMS.map(s=>[s,w.ConfigManager[s]===undefined?null:w.ConfigManager[s]]));
  w.ConfigManager.applyData({cq:1});ms.persist.cqTruthy=w.ConfigManager.cq;
  for(const dhtg of [undefined,false,true]){
    w.ConfigManager.dhtg=dhtg;const m={};w.Window_Message.prototype.clearFlags.call(m);
    ms.message.push({dhtg:dhtg===undefined?null:dhtg,showFast:m._showFast,lineShowFast:m._lineShowFast,pauseSkip:m._pauseSkip});
  }
  for(const cq of [false,true])for(const open of [false,true]){
    w.ConfigManager.cq=cq;
    ms.passable.push({cq,open,passable:w.Game_Map.prototype.isPassable.call({checkPassage:()=>open},1,1,2)});
  }
  const lists=[[10,5,1],[1],[5,5],[1,1,3],[2,1],[3]];
  const flags=[];for(const a of [false,true])for(const b of [false,true])for(const c of [false,true])flags.push({Boss:a,BOSS:b,boss:c});
  const realRandom=w.Math.random,realList=w.$gameMap.encounterList;
  for(const weights of lists){
    const sum=weights.reduce((x,y)=>x+y,0);
    w.$gameMap.encounterList=()=>weights.map((weight,i)=>({troopId:i+1,weight,regionSet:[]}));
    for(const f of flags)for(let r=0;r<sum;r++){
      Object.assign(w.ConfigManager,f);w.Math.random=()=>(r+0.5)/sum;
      ms.troops.push({weights,flags:f,random:r,troop:w.$gamePlayer.makeEncounterTroopId()});
    }
  }
  w.Math.random=realRandom;w.$gameMap.encounterList=realList;
  for(const f of flags)Object.assign(w.ConfigManager,{Boss:undefined,BOSS:undefined,boss:undefined});
  for(const yd100 of [undefined,true])for(const bush of [false,true]){
    w.ConfigManager.yd100=yd100;
    const isBush=w.$gameMap.isBush;w.$gameMap.isBush=()=>bush;
    ms.progress.push({yd100:!!yd100,bush,value:w.$gamePlayer.encounterProgressValue()});
    w.$gameMap.isBush=isBush;
  }
  for(const ydgb of [undefined,true]){
    w.ConfigManager.ydgb=ydgb;
    const list=w.$gameMap.encounterList,ev=w.$gameMap.isEventRunning,mk=w.$gamePlayer.makeEncounterCount,setup=w.BattleManager.setup,enc=w.BattleManager.onEncounter;
    let made=0,setups=0;
    w.$gameMap.encounterList=()=>[{troopId:1,weight:1,regionSet:[]}];w.$gameMap.isEventRunning=()=>false;
    w.$gamePlayer.makeEncounterCount=function(){made++;this._encounterCount=7;};w.BattleManager.setup=function(){setups++;};w.BattleManager.onEncounter=function(){};
    w.$gamePlayer._encounterCount=0;
    const result=w.$gamePlayer.executeEncounter();
    ms.execute.push({ydgb:!!ydgb,result,made,setups,count:w.$gamePlayer._encounterCount});
    w.$gameMap.encounterList=list;w.$gameMap.isEventRunning=ev;delete w.$gamePlayer.makeEncounterCount;w.BattleManager.setup=setup;w.BattleManager.onEncounter=enc;
  }
  for(const s of SYMS)delete w.ConfigManager[s];
  w.ConfigManager.applyData({});
  out.misc=ms;
}
// 屏蔽掉落（SiShiTan-PingBi-fix2 ＋ installUnifiedQualityRuntime）：子页行、整档切换与实际 makeDropItems 过滤。
{
  const pb={};
  w.$gameSystem._pingbiQuality=[false,false,false,false,false,false,false];
  pb.pinbi=w.$gameParty.isPinbi();
  const cw=new w.Window_PingbiCommands(0,0);
  pb.window=[cw.width,cw.height];
  pb.rows=[];
  for(const q of [[],[0],[0,1],[5],[5,6,7],[2,3,4],[0,1,2,3,4,5,6,7]]){
    w.$gameSystem._pingbiQuality=[0,1,2,3,4,5,6,7].map(i=>q.includes(i));cw.refresh();
    pb.rows.push({blocked:q,names:cw._list.map(c=>c.name),symbols:cw._list.map(c=>c.symbol)});
  }
  pb.toggles=[];
  w.$gameSystem._pingbiQuality=[false,false,false,false,false,false,false];
  for(const g of [0,0,4,1,4,4]){
    if(g===4&&pb.toggles.length===4)w.$gameSystem._pingbiQuality[6]=false;
    const before=w.$gameSystem._pingbiQuality.map(x=>!!x);
    cw.toggleQuality(g);
    pb.toggles.push({grade:g,before,after:w.$gameSystem._pingbiQuality.map(x=>!!x)});
  }
  // 实际掉落链：取每个旧档 0～8 各一件武器/防具，另一件无品质标记；全部 100% 掉落后看哪些留下
  const pick=[];
  for(const [kind,table] of [[2,w.$dataWeapons],[3,w.$dataArmors]]){
    for(let q=0;q<=8;q++){const it=table.find(x=>x&&x.meta&&x.meta.quality!==undefined&&Number(x.meta.quality)===q);if(it)pick.push({kind,id:it.id,quality:String(it.meta.quality)});}
    const none=table.find(x=>x&&x.meta&&x.meta.quality===undefined&&x.name);if(none)pick.push({kind,id:none.id,quality:null});
  }
  pb.candidates=pick;pb.filter=[];
  const eid=w.$dataTroops[2].members[0].enemyId,data=w.$dataEnemies[eid],saved=data.dropItems,realRandom=w.Math.random;
  for(const q of [[],[0,1],[2],[5,6,7],[0,1,2,3,4,5,6,7]]){
    w.$gameSystem._pingbiQuality=[0,1,2,3,4,5,6,7].map(i=>q.includes(i));
    data.dropItems=pick.map(p=>({kind:p.kind,dataId:p.id,denominator:1}));
    w.Math.random=()=>0;
    const e=new w.Game_Enemy(eid,0,0);
    const got=e.makeDropItems().map(it=>({kind:w.DataManager.isWeapon(it)?2:w.DataManager.isArmor(it)?3:1,id:it.id}));
    pb.filter.push({blocked:q,kept:pick.filter(p=>got.some(g=>g.kind===p.kind&&g.id===p.id)).map(p=>[p.kind,p.id])});
  }
  data.dropItems=saved;w.Math.random=realRandom;
  w.$gameSystem._pingbiQuality=[false,false,false,false,false,false,false];
  out.pingbi=pb;
}
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
fs.writeFileSync(path.join(__dirname,'.sandbox/options.json'),JSON.stringify(out,null,1));
process.stdout.write(JSON.stringify({notices:out.notices.rows.length,rows:out.rows.length,volume:out.volume.length,dash:out.dash.length,commands:out.commands,defaults:out.defaults})+'\n');
process.exit(0);
