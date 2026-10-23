'use strict';
// 异化工坊严格级参照：导出 installAlienation* 的配置与 20 条词条说明；执行正式引擎的 attach／craft／reroll／resolve／dismantle 与失败返回；
// 在 jsdom 里打开工坊（A.openWorkshop，DOM 叠加层），按按钮文字点选，逐步记录叠加层的结构（标签、文字、按钮可否点、class）、账本与背包。只写 .sandbox。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded()||!w.CodexAlienation)throw new Error('参照引擎启动失败');
w.Star.Achievement.Manager.init();
const A=w.CodexAlienation,C=A.config,toasts=[];
w.$.toaster=o=>toasts.push(String(o&&o.message));
const J=x=>JSON.parse(JSON.stringify(x));
const doc=w.document;
function setup(){
  A.closeWorkshop();
  w.eval('SceneManager.initInput();ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};');
  w.$gameParty._items={};w.$gameParty._weapons={};w.$gameParty._armors={};[1,8].forEach(id=>w.$gameParty.addActor(id));toasts.length=0;
}
const bag=()=>{const o={};Object.keys(w.$gameParty._items).forEach(k=>{if(w.$gameParty._items[k])o[k]=w.$gameParty._items[k];});return o;};
// 背包里的异化装备（工坊列表的来源），按 owned 顺序
const gear=()=>A.owned().filter(A.mark).map(i=>({name:i.name,kind:A.kind(i),base:A.baseId(i),mark:J(A.mark(i))}));
const ledger=()=>J(A.ledger());
// 新建一件异化装备放进背包；记下本体名字与八项属性，Godot 测试照抄（独立装备的随机前后缀不在本参照范围）
function make(kind,id,origin,affix,extra){const i=A.create(kind,id,origin,affix);w.$gameParty.gainItem(i,1);if(extra)extra(i);return i;}
function itemRow(i){return {kind:A.kind(i),base:A.baseId(i),plainName:A.mark(i).plainName,params:J(i.params||[]),origin:A.mark(i).origin,affix:A.mark(i).affix,uid:A.mark(i).uid,name:i.name};}

// 1. 配置与词条
const config={ids:C.ids,energyCost:C.energyCost,pools:C.pools,bossOnly:C.bossOnly,mobSources:(C.mobSources||[]).map(s=>({mapId:s.mapId})),
  affixes:Object.keys(A.affixes).map(k=>({key:k,name:A.affixes[k].name,benefit:A.affixes[k].benefit,cost:A.affixes[k].cost})),
  boundKeys:A.advanced&&A.advanced.boundKeys,skillKeys:A.advanced&&A.advanced.skillKeys,
  mapNames:(C.mobSources||[]).map(s=>w.$dataMapInfos[s.mapId]&&w.$dataMapInfos[s.mapId].name)};

// 2. 直接调用
const err=fn=>{try{return {ok:J(fn())};}catch(e){return {error:e.message};}};
const calls=[];
{setup();
  calls.push({step:'craft-short',r:err(()=>A.craft(1))});
  w.$gameParty.gainItem(w.$dataItems[C.ids.energy],45);
  calls.push({step:'craft-2',r:err(()=>A.craft(2)),bag:bag()});
  calls.push({step:'craft-1',r:err(()=>A.craft(1))});
  const a=make('w',1042,'mob','inversebone'),b=make('a',1013,'boss','pest');
  calls.push({step:'made',items:[itemRow(a),itemRow(b)],ledger:ledger(),details:[A.details(a),A.details(b)],pool:[A.mark(a).pool,A.mark(b).pool]});
  calls.push({step:'attach-bad',r:err(()=>A.create('w',1042,'mob','pest'))});
  calls.push({step:'reroll',r:err(()=>A.reroll(a)),bag:bag(),ledger:ledger()});
  calls.push({step:'reroll-pending',r:err(()=>A.reroll(b))});
  calls.push({step:'craft-pending',r:err(()=>A.craft(1))});
  calls.push({step:'resolve-new',r:err(()=>A.resolve(true)&&true),gear:gear(),ledger:ledger()});
  calls.push({step:'reroll-no-stone',r:err(()=>A.reroll(a))});
  calls.push({step:'dismantle-boss',r:err(()=>A.dismantle(b)),bag:bag(),gear:gear()});
  w.$gameParty.gainItem(w.$dataItems[C.ids.stone],1);
  calls.push({step:'reroll-2',r:err(()=>A.reroll(a)),ledger:ledger()});
  calls.push({step:'resolve-old',r:err(()=>A.resolve(false)&&true),gear:gear(),ledger:ledger()});
  const c=make('w',1042,'mob','mimic');c.name=c.name+'[锁定]';
  calls.push({step:'locked',canOperate:A.canOperate(c),locked:A.locked(c),r:err(()=>A.dismantle(c))});
  const d=make('w',1042,'mob','hollow');w.$gameActors.actor(1).changeEquip(0,d);
  calls.push({step:'equipped',equipped:w.$gameActors.actor(1).equips()[0]===d,owned:A.owned().indexOf(d)>=0,canOperate:A.canOperate(d)});
  calls.push({step:'needs-config',mimic:A.needsConfiguration(c),hollow:A.needsConfiguration(d),inverse:!!A.needsConfiguration(a)});
}

// 3. 工坊叠加层（工坊记住的选中项 selected 是运行时变量，跨打开、跨读档都保留；各路线按顺序跑，承接上一条）
function dump(el){const out=[];(function walk(n,depth){for(const c of n.children){const tag=c.tagName.toLowerCase(),row={tag,depth};if(c.className)row.class=c.className;
  if(['p','h1','h2','h3','span','button','summary','legend'].indexOf(tag)>=0)row.text=c.textContent;if(tag==='button')row.disabled=!!c.disabled;if(c.hidden)row.hidden=true;
  out.push(row);if(['button','p','span','h1','h2','h3','summary','legend'].indexOf(tag)<0)walk(c,depth+1);}})(el,0);return out;}
const host=()=>doc.getElementById('alien-workshop');
function click(label){if(label[0]==='@'){const list=host().querySelectorAll('.alien-list button');list[Number(label.slice(1))].onclick();return;}const b=Array.from(host().querySelectorAll('button')).find(x=>x.textContent===label);if(!b)throw new Error('找不到按钮 '+label+' 现有 '+Array.from(host().querySelectorAll('button')).map(x=>x.textContent).join('|'));if(b.disabled)throw new Error('按钮不可点 '+label);b.onclick();}
function flow(name,prep,steps){setup();const items=(prep()||[]).map(itemRow);toasts.length=0;A.openWorkshop();const screens=[dump(host())];
  for(const s of steps){if(s==='Escape'){const e=new w.KeyboardEvent('keydown',{key:'Escape'});w.dispatchEvent(e);}else click(s);screens.push(host()?dump(host()):null);}
  return {name,items,steps,screens,toasts:toasts.slice(),bag:bag(),gear:gear(),ledger:ledger()};}
const E=C.ids.energy,S=C.ids.stone,gain=(id,n)=>w.$gameParty.gainItem(w.$dataItems[id],n);
const pages=[];
pages.push(flow('empty',()=>{},['返回']));
pages.push(flow('list',()=>{gain(E,45);const a=make('w',1042,'mob','inversebone'),b=make('a',1013,'boss','pest');return [a,b];},
  ['@1','20点能量 → 1颗异化石','使用1颗异化石重抽','采用新异化','分解为5点能量','取消','分解为5点能量','确认分解','Escape']));
pages.push(flow('keep-old',()=>{gain(S,1);const a=make('a',2605,'mob','faceless');return [a];},['使用1颗异化石重抽','保留旧异化','返回']));
pages.push(flow('locked-equipped',()=>{gain(S,2);const a=make('w',1042,'mob','mimic');a.name=a.name+'[锁定]';const b=make('w',1044,'boss','hollow');w.$gameActors.actor(1).changeEquip(0,b);const c=make('w',1047,'boss','lifelink');return [a,b,c];},
  ['@2','返回']));
pages.push(flow('recent',()=>{const l=A.ledger();for(let n=0;n<12;n++)l.recent.push({name:'测试装备'+n,origin:n%3?'mob':'boss',uid:'x'+n,kind:'w',id:1});const a=make('w',1042,'boss','void');return [a];},['返回']));
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
const out={sourceIdentity:identity,config,calls,pages};
fs.writeFileSync(path.join(__dirname,'.sandbox/alien_workshop.json'),JSON.stringify(out,null,1));
console.log(JSON.stringify({affixes:config.affixes.length,calls:calls.length,pages:pages.map(p=>p.name+':'+p.screens.length)}));process.exit(0);
