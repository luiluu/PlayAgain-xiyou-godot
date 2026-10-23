'use strict';
// 异化工坊期二严格级参照：配置异化与穿戴限制。导出 CodexAlienation.config.templates 与云裳的可转移减益／可共享增益名单（Affixes 载入时补过）；
// 记录就绪判定 A.ready（20 种词条 × 队员）、可绑定队友、原生主动技能、可借技能、吞器供体；configure／clearConfiguration 的返回；
// 工坊「配置异化」各种页（jsdom 叠加层，含下拉框的选项与当前值）；换装备、能否装备、商店出售可否选、挂机卖出。只写 .sandbox。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded()||!w.CodexAlienation)throw new Error('参照引擎启动失败');
w.Star.Achievement.Manager.init();
const A=w.CodexAlienation,C=A.config,T=C.templates,Y=w.CodexYunshang,toasts=[];
w.$.toaster=o=>toasts.push(String(o&&o.message));
const J=x=>JSON.parse(JSON.stringify(x));
const doc=w.document;
const PARTY=[1,8,9,10];
// 给队员学的技能：从模板里挑出能当原生主动技能的前几个（Godot 测试照同一份 ID 学）
const activeOk=s=>s&&s.id>2&&s.stypeId!==4&&s.occasion!==3&&s.occasion!==2&&s.id!==C.ids.switch&&s.name;
const pick=(ids,n,f)=>ids.map(id=>w.$dataSkills[id]).filter(s=>activeOk(s)&&(!f||f(s))).slice(0,n).map(s=>s.id);
const atk1=pick(T.attack,3),l1=atk1.concat(pick(T.silence,8,s=>atk1.indexOf(s.id)<0).slice(0,2));
const LEARN={1:l1,8:pick(T.attack,400,s=>A.borrowable(s)&&l1.indexOf(s.id)<0).slice(0,2).concat(pick(T.possessionSkills,2,s=>T.attack.indexOf(s.id)<0)),9:T.wish.slice(),10:[]};
function setup(){
  A.closeWorkshop();
  w.eval('SceneManager.initInput();ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};');
  w.$gameParty._items={};w.$gameParty._weapons={};w.$gameParty._armors={};PARTY.forEach(id=>w.$gameParty.addActor(id));
  PARTY.forEach(id=>{const a=w.$gameActors.actor(id);a._equips.forEach((e,n)=>{if(e.object())a.forceChangeEquip(n,null);});LEARN[id].forEach(s=>a.learnSkill(s));});
  w.$gameParty._weapons={};w.$gameParty._armors={};toasts.length=0;
}
const actor=id=>w.$gameActors.actor(id);
function make(kind,id,origin,affix){const i=A.create(kind,id,origin,affix);w.$gameParty.gainItem(i,1);return i;}
// 普通独立武器（吞器供体候选）
function plain(id){const before=Object.keys(w.$gameParty._weapons).map(Number);w.$gameParty.gainItem(w.$dataWeapons[id],1);const made=Object.keys(w.$gameParty._weapons).map(Number).filter(x=>before.indexOf(x)<0)[0];return w.$dataWeapons[made];}
const BASE={blessing:['w',1523],pest:['a',1013]};
const baseOf=k=>BASE[k]||['w',1044];
const cfgOf=i=>J(A.mark(i).config||{});
const err=fn=>{try{const v=fn();return {ok:true};}catch(e){return {thrown:e.message};}};

// 1. 导出
const exportData={templates:{attack:T.attack,inversebone:T.inversebone,blessing:T.blessing,pestStates:T.pestStates,possessionSkills:T.possessionSkills,wish:T.wish,silence:T.silence,gearTraitCodes:T.gearTraitCodes},
  transferDebuffs:Y.config.transferDebuffs,shareBuffs:Y.config.shareBuffs,learn:LEARN};

// 2. 判定
setup();
const donors=[1,6,7].map(plain);
const actors={};
PARTY.forEach(id=>{const a=actor(id);actors[id]={originalActive:A.originalActive(a).map(s=>s.id),borrowable:A.nativeSkills(a).filter(s=>a._skills.indexOf(s.id)>=0&&A.borrowable(s)).map(s=>s.id),lifeCompatible:A.lifeCompatible(a)};});
const ghosts=donors.map(d=>{const g=A.effectGhost(d);return {name:d.name,ghost:g?{traits:g.traits,note:g.note}:null};});
const items={};Object.keys(A.affixes).forEach(k=>{const b=baseOf(k);items[k]=make(b[0],b[1],'boss',k);});
const ready={},binding={};
Object.keys(items).forEach(k=>{ready[k]=PARTY.map(id=>A.ready(actor(id),items[k]));});
['lifelink','possession','sacrifice','scapegoat','offer'].forEach(k=>{binding[k]=PARTY.map(id=>A.bindingOptions(actor(id),k).map(a=>a.actorId()));});
const needs={};Object.keys(items).forEach(k=>{needs[k]=!!A.needsConfiguration(items[k]);});

// 3. configure
const configure=[];
function conf(name,k,c){const r0=err(()=>A.configure(items[k],c));configure.push({name,affix:k,config:c,result:r0,saved:cfgOf(items[k]),ready:PARTY.map(id=>A.ready(actor(id),items[k])),details:A.details(items[k])});}
const L1=LEARN[1],L8=LEARN[8];
conf('mimic-ok','mimic',{actorId:1,replace:L1[0]});
conf('mimic-not-learned','mimic',{actorId:1,replace:L8[0]});
conf('mimic-not-member','mimic',{actorId:2,replace:L1[0]});
conf('faceless-ok','faceless',{actorId:1,pairs:[{replaceId:L1[0],ownerId:8,skillId:L8[0]}]});
conf('faceless-two','faceless',{actorId:1,pairs:[{replaceId:L1[0],ownerId:8,skillId:L8[0]},{replaceId:L1[1],ownerId:8,skillId:L8[1]}]});
conf('faceless-dup','faceless',{actorId:1,pairs:[{replaceId:L1[0],ownerId:8,skillId:L8[0]},{replaceId:L1[0],ownerId:8,skillId:L8[1]}]});
conf('faceless-self','faceless',{actorId:1,pairs:[{replaceId:L1[0],ownerId:1,skillId:L1[1]}]});
conf('faceless-empty','faceless',{actorId:1,pairs:[]});
conf('lifelink-ok','lifelink',{actorId:1,partnerId:8});
conf('lifelink-self','lifelink',{actorId:1,partnerId:1});
conf('possession-ok','possession',{actorId:1,partnerId:8});
conf('possession-noskill','possession',{actorId:8,partnerId:10});
conf('offer-noghost','offer',{actorId:1,partnerId:8});
const SIL=L1.filter(id=>T.silence.indexOf(id)>=0),NOSIL=L1.filter(id=>T.silence.indexOf(id)<0);
conf('silence-ok','silence',{actorId:1,skillId:SIL[0]});
conf('silence-attack','silence',{actorId:1,skillId:NOSIL[0]});
conf('erosion-ok','erosion',{actorId:1,skillId:L1[0]});
conf('swallow-ok','swallow',{actorId:1,donorId:donors[0].id});
conf('swallow-missing','swallow',{actorId:1,donorId:99999});
configure.push({name:'reserved',reserved:donors.map(d=>A.reserved(d)),canOperate:donors.map(d=>A.canOperate(d)),bound:donors.map(d=>A.bound(d))});
configure.push({name:'clear',result:err(()=>A.clearConfiguration(items.swallow)),saved:cfgOf(items.swallow),reserved:donors.map(d=>A.reserved(d))});

// 4. 工坊配置页
function dump(el){const out=[];(function walk(n,depth){for(const c of n.children){const tag=c.tagName.toLowerCase(),row={tag,depth};if(c.className)row.class=c.className;
  if(['p','h1','h2','h3','span','button','summary','legend'].indexOf(tag)>=0)row.text=c.textContent;if(tag==='button')row.disabled=!!c.disabled;if(c.hidden)row.hidden=true;
  if(tag==='label')row.text=c.childNodes[0]&&c.childNodes[0].nodeType===3?c.childNodes[0].textContent:'';
  if(tag==='select'){row.options=Array.from(c.options).map(o=>o.textContent);row.value=c.selectedIndex>=0?c.options[c.selectedIndex].textContent:null;}
  out.push(row);if(['button','p','span','h1','h2','h3','summary','legend','select'].indexOf(tag)<0)walk(c,depth+1);}})(el,0);return out;}
const host=()=>doc.getElementById('alien-workshop');
function scopeFor(spec){const parts=spec.split('/');let root=host();if(parts.length>1){root=Array.from(root.querySelectorAll('fieldset')).find(f=>f.querySelector('legend').textContent.indexOf(parts[0])===0);}return {root,label:parts[parts.length-1]};}
function step(s){
  if(s[0]==='@'){host().querySelectorAll('.alien-list button')[Number(s.slice(1))].onclick();return;}
  if(s.indexOf('sel:')===0){const m=/^sel:(.+)#(\d+)$/.exec(s),sc=scopeFor(m[1]);const lab=Array.from(sc.root.querySelectorAll('label')).find(l=>l.childNodes[0].textContent===sc.label);const sel=lab.querySelector('select');sel.selectedIndex=Number(m[2]);if(sel.onchange)sel.onchange();return;}
  const b=Array.from(host().querySelectorAll('button')).find(x=>x.textContent===s);if(!b)throw new Error('找不到按钮 '+s+' 现有 '+Array.from(host().querySelectorAll('button')).map(x=>x.textContent).join('|'));if(b.disabled)throw new Error('按钮不可点 '+s);b.onclick();}
function flow(name,prep,steps){setup();const made=prep();toasts.length=0;A.openWorkshop();const screens=[dump(host())];
  for(const s of steps){step(s);screens.push(host()?dump(host()):null);}
  return {name,made,steps,screens,toasts:toasts.slice(),configs:A.owned().filter(A.mark).map(i=>({name:i.name,config:cfgOf(i)}))};}
const pages=[];
const S=C.ids.stone,gain=(id,n)=>w.$gameParty.gainItem(w.$dataItems[id],n);
// 本体八项属性随参照抄（独立装备的属性浮动不在本参照范围）
const one=(k,extra)=>()=>{if(extra)extra();const b=baseOf(k),i=make(b[0],b[1],'boss',k);return [{affix:k,kind:b[0],base:b[1],params:J(i.params)}];};
pages.push(flow('bound',one('lifelink'),['配置异化','sel:绑定队友#1','保存配置','配置异化','sel:使用角色#1','sel:绑定队友#2','保存配置','配置异化','解除配置']));
pages.push(flow('skill',one('silence'),['配置异化','sel:作用技能#1','保存配置','配置异化','sel:使用角色#1','保存配置']));
pages.push(flow('swallow',()=>{[1,6].forEach(plain);return one('swallow')();},['配置异化','sel:借用武器#1','保存配置','配置异化','解除配置']));
pages.push(flow('mimic',one('mimic'),['配置异化','sel:替换原生技能#2','保存配置','配置异化','sel:使用角色#3','保存配置']));
pages.push(flow('faceless',one('faceless'),['配置异化','sel:借入技能 1/替换原生技能#1','sel:借入技能 1/来源角色#0','sel:借入技能 1/借入技能#1','保存配置','配置异化','sel:借入技能 2/替换原生技能#2','sel:借入技能 2/来源角色#1','sel:借入技能 2/来源角色#0','保存配置','配置异化','取消']));
pages.push(flow('possession',one('possession'),['配置异化','保存配置']));

// 5. 穿戴与出售
const equip=[];
{setup();const slot=0;w.$gameParty.ActorMaxLevel=99;PARTY.forEach(id=>{w.$dataActors[id].maxLevel=99;actor(id).changeLevel(40,false);});
  // 找一名能装备兼容池里某把武器的队员
  let a=null,key=null;for(const id of PARTY){key=Object.keys(C.pools).find(k=>k[0]==='w'&&actor(id).canEquip(w.$dataWeapons[Number(k.slice(2))]));if(key){a=actor(id);break;}}
  const eb=Number(key.slice(2));equip.push({step:'actor',actorId:a.actorId()});
  const mim=make('w',eb,'boss','mimic'),inv=make('w',eb,'boss','inversebone'),pr=make('w',eb,'boss','prayer');
  equip.push({step:'base',base:eb,weapon:w.$dataWeapons[eb].name});
  const can=i=>({canEquip:a.canEquip(i),ready:A.ready(a,i)});
  equip.push({step:'not-ready',affix:'mimic',...can(mim),change:a.changeEquip(slot,mim)!==false&&a.equips()[slot]===mim});
  A.configure(mim,{actorId:a.actorId(),replace:A.originalActive(a)[0].id});
  equip.push({step:'configured',...can(mim),change:a.changeEquip(slot,mim)!==false&&a.equips()[slot]===mim});
  const other=a.equips().map((e,n)=>n).filter(n=>n!==slot&&a.equipSlots()[n]===a.equipSlots()[slot]);
  const akey=Object.keys(C.pools).find(k=>k[0]==='a'&&a.canEquip(w.$dataArmors[Number(k.slice(2))])&&a.equipSlots().indexOf(w.$dataArmors[Number(k.slice(2))].etypeId)>0);
  const ab=Number(akey.slice(2)),arm=make('a',ab,'boss','hollow'),aslot=a.equipSlots().indexOf(w.$dataArmors[ab].etypeId);
  equip.push({step:'second',armor:ab,slot:aslot,...can(arm),change:a.changeEquip(aslot,arm)!==false&&a.equips()[aslot]===arm});
  equip.push({step:'swap-in-same-slot',...can(inv),change:a.changeEquip(slot,inv)!==false&&a.equips()[slot]===inv});
  gain(S,1);A.reroll(pr);
  equip.push({step:'pending',change:a.changeEquip(slot,pr)!==false&&a.equips()[slot]===pr,unequip:a.changeEquip(slot,null)!==false&&a.equips()[slot]===null});
  A.resolve(false);
  equip.push({step:'after-resolve',unequip:a.changeEquip(slot,null)!==false&&!a.equips()[slot]});
  const sellable=i=>{const win=Object.create(w.Window_ShopSell.prototype);return !!w.Window_ShopSell.prototype.isEnabled.call(win,i);};
  equip.push({step:'sell',alien:sellable(inv),plain:sellable(plain(1))});
  equip.push({step:'hangup',hasHook:!!(w.XdRsData&&w.XdRsData.hangUp&&w.XdRsData.hangUp.doSell)});}

if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
const out={sourceIdentity:identity,export:exportData,actors,ghosts,ready,binding,needs,configure,pages,equip};
fs.writeFileSync(path.join(__dirname,'.sandbox/alien_config.json'),JSON.stringify(out,null,1));
console.log(JSON.stringify({learn:LEARN,configure:configure.length,pages:pages.map(p=>p.name+':'+p.screens.length)}));process.exit(0);
