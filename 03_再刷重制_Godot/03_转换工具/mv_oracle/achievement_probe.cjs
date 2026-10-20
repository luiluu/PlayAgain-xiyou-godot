'use strict';
// 成就（Star_AchievementSystem＋Star_AchievementShowPic＋installKyoAchievementRuntime）：定义表、GetAcReward 的全局（ConfigManager.SAchievementS）
// 与本局（$gameParty.SAchievementS）记录、得到物品自动达成（含 CodexEconomy 改记）、弹窗数据、成就界面窗口布局与逐项绘制。
// 时间固定为 2026-01-02 03:04:05；配置只在内存（ConfigManager.applyData），不写盘。只写 .sandbox/achievements.json。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
w.eval('ConfigManager.applyData({});Graphics.width=1280;Graphics.height=720;Graphics.boxWidth=1280;Graphics.boxHeight=720;'+
  'var __D=Date;Date=function(){return arguments.length?new (Function.prototype.bind.apply(__D,[null].concat([].slice.call(arguments))))():new __D(2026,0,2,3,4,5);};Date.now=function(){return new Date().getTime();};');
const S=w.Star.AchievementSystem,M=w.Star.Achievement.Manager;
w.Scene_Boot.prototype.start.call({});  // Star_AchievementShowPic：AchievementManager.init（PopupManager 要真场景，只量通知）
const popups=[];M.on(item=>popups.push(JSON.parse(JSON.stringify(item))));
w.SceneManager._scene=new w.Scene_Base();
// 弹窗：连续两条的窗口位置、大小（Tween 初值即刻生效）、标题与说明的绘制
const popupWindows=()=>w.SceneManager._scene.children.filter(c=>c instanceof w.Star.Achievement.Window_AchievementPopup);
const defs=[];
for(let i=0;i<S.Achievement.length;i++){const a=S.Achievement[i];if(!a)continue;
  defs.push({id:i,name:a.AcName,type:a.AcType,icon:a.AcIconId,trigger:a.AcTriggerT,items:a.AcItemReward.map(Number),weapons:a.AcWeaponReward.map(Number),
    armors:a.AcArmorReward.map(Number),eval:a.AcEvalReward,evalText:a.AcEvalRewardText,show:a.AcShowText});}
const lists=k=>S[k].map((e,i)=>e?{slot:i,acId:e.AcId,items:e.AcItem.map(Number)}:null).filter(Boolean);
const out={sourceIdentity:identity,types:S.AchievementTypeList,defs,itemLists:lists('AchievementItemList'),weaponLists:lists('AchievementWeaponList'),armorLists:lists('AchievementArmomList'),
  popupItems:M._items.map(x=>({id:x.id,icon:x.icon,title:x.title})),popupSettings:w.Star.Achievement.settings,steps:[]};
const cfg=()=>JSON.parse(JSON.stringify(w.ConfigManager.SAchievementS||{}));
const party=()=>JSON.parse(JSON.stringify(w.$gameParty.SAchievementS||null));
const bag=ids=>Object.fromEntries(ids.map(id=>[id,w.$gameParty.numItems(w.$dataItems[id])]));
const step=(label,extra)=>{out.steps.push(Object.assign({label,config:cfg(),party:party(),popups:popups.splice(0).map(p=>p.id)},extra||{}));};
// 1. 新开局：首次达成 2，再达成一次，新开局后再达成（全局已有：本局补记、弹窗、时间不变），全局有本局无时得物品不补记
w.DataManager.setupNewGame();
step('new_game');
S.GetAcReward(2);step('reward_2');
S.GetAcReward(2);step('reward_2_again');
w.DataManager.setupNewGame();step('new_game_2');
S.GetAcReward(2);step('reward_2_new_game');
S.GetAcReward(51);S.GetAcReward(84);step('reward_51_84');
{const before=popupWindows().length;S.GetAcReward(3);S.GetAcReward(4);
  out.popupLayout=popupWindows().map(p=>({id:p.item.id,x:p.x,y:p.y,width:p.width,height:p.height,opacity:p.opacity,contentsOpacity:p.contentsOpacity,padding:p.standardPadding(),fontSize:p.standardFontSize()}));
  step('reward_3_4');}
// 配置存取：makeData 带 SAchievementS，applyData 读回（缺省 {}）
const made=w.ConfigManager.makeData();
out.config={madeHas:Object.keys(made.SAchievementS||{}).sort()};
w.ConfigManager.applyData({});out.config.emptyApply=cfg();
w.ConfigManager.applyData(made);out.config.reapply=cfg();
// 2. 得到物品自动达成：每个物品清单里的每个物品（全局与本局都清空后 gainItem +1），另测 -1（失去也触发）与全局已有时
const gains=[];
const ids=[...new Set(out.itemLists.flatMap(l=>l.items))].sort((a,b)=>a-b);
for(const id of ids)for(const amount of [1,-1]){
  w.ConfigManager.SAchievementS={};w.DataManager.setupNewGame();popups.splice(0);
  w.$gameParty.gainItem(w.$dataItems[id],amount);
  gains.push({id,amount,config:Object.keys(cfg()).filter(k=>!k.endsWith('Time')).map(Number).sort((a,b)=>a-b),
    party:Object.keys(party()||{}).map(Number).sort((a,b)=>a-b),popups:popups.splice(0).map(p=>p.id),bag:bag([id,188,2201])});
}
out.gains=gains;
w.ConfigManager.SAchievementS={105:true};w.DataManager.setupNewGame();popups.splice(0);
w.$gameParty.gainItem(w.$dataItems[325],1);
out.gainConfigOnly={config:cfg(),party:party(),popups:popups.splice(0).map(p=>p.id)};
// 3. kyo专属（143）：测试模式未开时 GetAcReward 不记
w.ConfigManager.SAchievementS={};w.DataManager.setupNewGame();popups.splice(0);
S.GetAcReward(143);out.kyo={registered:!!S.Achievement[143],def:defs.find(d=>d.id===143)||null,config:cfg(),party:party(),popups:popups.splice(0).map(p=>p.id),
  codexTestMode:!!(w.CodexTestMode&&w.CodexTestMode.enabled())};
// 4. 成就界面（CE431 SceneManager.push(Scene_AchievementBook)）：全局有 1、2、22（22 本局无）、51（本局有、带时间），其余未得
w.ConfigManager.SAchievementS={};w.DataManager.setupNewGame();
S.GetAcReward(1);S.GetAcReward(22);S.GetAcReward(51);
w.$gameParty.SAchievementS[22]=false;w.ConfigManager.SAchievementS[2]=true;  // 2：全局有、无时间、本局无
popups.splice(0);
const scene=new w.Scene_AchievementBook();w.SceneManager._scene=scene;scene.create();
const rect=win=>({x:win.x,y:win.y,width:win.width,height:win.height,lineHeight:win.lineHeight(),padding:win.standardPadding(),textPadding:win.textPadding()});
const ui={typeWindow:rect(scene._indexTypeWindow),indexWindow:rect(scene._indexWindow),countWindow:rect(scene._NocWindow),
  typeIndex:scene._indexTypeWindow.index(),typeActive:scene._indexTypeWindow.active,indexActive:scene._indexWindow.active,indexIndex:scene._indexWindow.index()};
const record=win=>{const calls=[];
  win.drawText=function(t,x,y,mw,al){calls.push({f:'text',t:String(t),x,y,w:mw,align:al||'left',size:this.contents.fontSize});};
  win.drawTextEx=function(t,x,y){calls.push({f:'textEx',t:String(t),x,y});return 0;};
  win.drawIcon=function(id,x,y,s){calls.push({f:'icon',id,x,y,scale:s||1});};
  return calls;};
const numCalls=record(scene._NocWindow);scene._NocWindow.refresh();ui.count=numCalls;
ui.typeItems=[];{const c=record(scene._indexTypeWindow);scene._indexTypeWindow.refresh();ui.typeItems=c;}
ui.pages=[];
for(let t=0;t<out.types.length;t++){
  scene._indexTypeWindow.select(t);scene.update();
  const calls=record(scene._indexWindow);scene._indexWindow.refresh();
  ui.pages.push({type:out.types[t],ids:scene._indexWindow._list.map(a=>a.id),maxItems:scene._indexWindow.maxItems(),calls:calls.filter(c=>c.y<scene._indexWindow.contentsHeight()*2)});
}
// 确定进入列表、取消回到类型
scene._indexTypeWindow.select(1);scene.update();scene.onRangeOk();
ui.afterOk={typeActive:scene._indexTypeWindow.active,indexActive:scene._indexWindow.active,index:scene._indexWindow.index(),ids:scene._indexWindow._list.map(a=>a.id)};
scene.OnCancel();
ui.afterCancel={typeActive:scene._indexTypeWindow.active,indexActive:scene._indexWindow.active,index:scene._indexWindow.index(),typeIndex:scene._indexTypeWindow.index()};
out.ui=ui;
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname,'.sandbox'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'.sandbox/achievements.json'),JSON.stringify(out,null,1));
console.log(JSON.stringify({defs:defs.length,steps:out.steps.length,gains:gains.length,kyo:out.kyo,ui:{typeWindow:ui.typeWindow,indexWindow:ui.indexWindow,countWindow:ui.countWindow,count:ui.count}}));
process.exit(0);
