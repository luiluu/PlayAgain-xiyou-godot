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
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
fs.writeFileSync(path.join(__dirname,'.sandbox/options.json'),JSON.stringify(out,null,1));
process.stdout.write(JSON.stringify({rows:out.rows.length,volume:out.volume.length,dash:out.dash.length,commands:out.commands,defaults:out.defaults})+'\n');
process.exit(0);
