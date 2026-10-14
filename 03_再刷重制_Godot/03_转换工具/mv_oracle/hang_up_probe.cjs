'use strict';
// 正式版挂机子页/正常战后规则/神话星级的内存探针；不加载存档，只写 .sandbox。
const fs = require('fs'), path = require('path');
const {boot} = require('./hboot.cjs');
const {sourceIdentity} = require('./source_identity.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Applications/再刷一把：西游（mod_KYO）.app/Contents/Resources/app.nw';
const identity = sourceIdentity(APP), r = boot(APP, {tolerant:true, log:false}), w = r.window;
if (r.errors.length || !w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败');
w.eval('ConfigManager.applyData({});ConfigManager.SAchievementS=new Array(10000).fill(true);DataManager.setupNewGame();Input._currentState={};Graphics.boxWidth=1280;Graphics.boxHeight=720;$gameParty._battleMembers=[8,10,9,0,0];Star.XdRsData_hangUp.ActSkilllist=$gameActors.actor(8);');
const out = {sourceIdentity:identity, windows:{}, counts:[], order:[], recovery:[], stars:[], sell:{}};
const plain = x => JSON.parse(w.JSON.stringify(x));
function windowData(win) {
  // MOG_MenuBackground 在 Scene_MenuBase.update 中覆写窗口 opacity（构造时尚为255）。
  w.SceneManager._mback=true;
  w.Window_Base.prototype.update.call(win);
  return {rect:[win.x,win.y,win.width,win.height], rows:win._list.map((e,i)=>[e.name,String(win.statusText ? win.statusText(i) : '')]), opacity:win.opacity};
}
for (const [kind,klass] of [['actors_count','Star_Window_AutomaticCombatAct'], ['counts','Star_Window_AutomaticCombatSkills'],
  ['medication','Star_Window_AutomaticMedication'], ['sell','Star_Window_SellWeapon']]) out.windows[kind]=windowData(new w[klass]());
const cw = new w.Star_Window_AutomaticCombatSkills(); cw.select(0);
for(let i=0;i<22;i++){cw.processOk();out.counts.push(Number(cw.statusText(0)));}
// 重复技能、提前一位、表按回合取值（禁智能AI，避免伤害评分影响）。
w.eval('$gameParty._XdRsData_hangUp_ActSkills={};Star.XdRsData_hangUp.ActSkilltemporary={};$gameParty._XdRsData_hangUp_ActSkills[$gameActors.actor(8).name()+1]=2;$gameParty._XdRsData_hangUp_ActSkills[$gameActors.actor(8).name()+2]=1;');
const ow = new w.Star_Window_AutomaticCombatSkill(); out.windows.order=windowData(ow);
for(const index of [2,2,1]){ow.select(index);ow.processOk();out.order.push({index,values:ow.GetActSkills.map((e,i)=>Number(ow.statusText(i))),table:plain(w.$gameParty._XdRsData_hangUp_ActSkill)});}
w.eval('$gameParty._items={1:9,2:8,137:7};');
for(const [kind,klass] of [['hp','Star_Window_GetHpItems'],['mp','Star_Window_GetMpItems']]) out.windows[kind]=windowData(new w[klass]());
// 药品参数：各角色固定同一能力与 rec/pha，隔离用户决定不移植的 growth。
const cases = [
  {name:'below_threshold',hp:[100,600,1000],mp:[100,600,1000],hpV:50,mpV:50,hpIds:[1],mpIds:[2],items:{1:20,2:20}},
  {name:'at_threshold',hp:[500,501,1000],mp:[500,501,1000],hpV:50,mpV:50,hpIds:[1],mpIds:[2],items:{1:20,2:20}},
  {name:'exhaustion',hp:[100,1000,1000],mp:[100,1000,1000],hpV:50,mpV:50,hpIds:[1],mpIds:[2],items:{1:1,2:1}},
  {name:'revive',hp:[0,1000,1000],mp:[1000,1000,1000],hpV:50,mpV:50,hpIds:[1,137],mpIds:[],items:{1:20,137:1}}
];
for(const c of cases){
  w.eval('DataManager.setupNewGame();$gameParty._battleMembers=[8,10,9,0,0];$gameParty._items={};$gameParty._XdRsData_hangUp_SellWeapon={SellQuality:0};XdRsData.hangUp.GuaJiStartBettleOk=true;XdRsData.hangUp.SBterminate=function(){};$gameParty.refrishHangUp=function(){};');
  for(let i=0;i<3;i++){
    const a=w.$gameActors.actor([8,10,9][i]); a.param=id=>id<2?1000:100; a.sparam=()=>1;
    a._hp=c.hp[i];a._mp=c.mp[i];a._states=w.JSON.parse(JSON.stringify(c.hp[i]===0?[1]:[]));
  }
  w.$gameParty._items=w.JSON.parse(JSON.stringify(c.items));
  w.$gameParty._XdRsData_hangUp_RecoveryHMP=w.JSON.parse(JSON.stringify({HpV:c.hpV,MpV:c.mpV,GetHpArrItems:c.hpIds.map(id=>[true,id,'ZL']),GetMpArrItems:c.mpIds.map(id=>[true,id])}));
  w.Scene_Battle.prototype.terminate.call(new w.Scene_Battle());
  out.recovery.push({...c,after:{hp:[8,10,9].map(id=>w.$gameActors.actor(id).hp),mp:[8,10,9].map(id=>w.$gameActors.actor(id).mp),items:plain(w.$gameParty._items)}});
}
// 七档卖出开关的部分/全开状态，及所有旧档星级；直接调用已安装模块。
w.eval('$gameParty._XdRsData_hangUp_SellWeapon={SellQuality:1,quality12:true};');
const sw=new w.Star_Window_SellWeapon();out.sell.partial=windowData(sw);sw.select(7);sw.processOk();out.sell.off=windowData(sw);sw.processOk();out.sell.on=windowData(sw);
for(const [kind,table] of [['weapon',w.$dataWeapons],['armor',w.$dataArmors],['item',w.$dataItems],['skill',w.$dataSkills]]){
  const base=table.find(e=>e && e.name);
  for(let q=0;q<=15;q++){
    const item=base, previous=item.meta.quality;item.meta.quality=String(q);
    out.stars.push({kind,quality:q,stars:w.CodexQuality.stars(item),label:w.CodexQuality.label(item)});
    item.meta.quality=previous;
  }
}
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
fs.writeFileSync(path.join(__dirname,'.sandbox/hang_up.json'),JSON.stringify(out,null,1));
process.stdout.write(JSON.stringify({windows:Object.keys(out.windows).length,recovery:out.recovery.length,stars:out.stars.length,errors:r.errors})+'\n');
process.exit(0);
