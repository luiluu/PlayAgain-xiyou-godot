'use strict';
// 修炼界面（Star_ActorAttributePlusPoints）严格级参照：执行正式插件的 PoLites 表、Window_AddLittleConfirm.makeCommandList、
// Scene_ActorAttributePlusPoints.onConfirmOk 与 Game_Actor.paramBaseBoost，记录每次修炼后的指令行文、提示、精魂、
// pushattribute（存档字段）与八项能力值。窗口只用最小替身（指令行文照原方法生成），不建真实窗口。只写 .sandbox。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded()||!w.Scene_ActorAttributePlusPoints)throw new Error('参照引擎启动失败');
const S=w.Star.ActorAttributePlusPoints,toasts=[];
w.$.toaster=o=>toasts.push(String(o&&o.message));
const J=x=>JSON.parse(JSON.stringify(x===undefined?null:x));
const PARTY=[1,8,9];

function setup(gold,prep){
  w.eval('SceneManager.initInput();ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};');
  PARTY.forEach(id=>w.$gameParty.addActor(id));w.$gameParty._gold=0;w.$gameParty.gainGold(gold);toasts.length=0;
  if(prep)prep();
}
// 最小场景替身：_indexWindow 选哪位、_confirmWindow 用原版 makeCommandList 生成行（addCommand 记行文）
function makeScene(xiulian){
  if(xiulian===null)delete S.XiuLian;else S.XiuLian=xiulian;
  const scene=Object.create(w.Scene_ActorAttributePlusPoints.prototype);scene._idx=0;scene._cur=0;
  scene._indexWindow={index:()=>scene._idx,activate(){}};
  scene._statusWindow={setupWhenCheck(){}};
  scene._goldWindow={setupWhenCheck(){}};
  const cw=Object.create(w.Window_AddLittleConfirm.prototype);
  cw.XiuLian=S.XiuLian||[0,1,2,3,4,5,6,7];
  cw.Actor=w.$gameParty.members()[0];
  cw.lines=[];
  cw.addCommand=function(name,symbol){this.lines.push(name);};
  cw.refresh=function(){};cw.activate=function(){};cw.index=()=>scene._cur;
  const make=cw.makeCommandList;
  cw.makeCommandList=function(a){this.lines=[];make.call(this,a);};
  scene._confirmWindow=cw;
  w.SceneManager._scene=scene;
  scene.select=i=>{scene._idx=i;cw.makeCommandList(w.$gameParty.members()[i]);};
  scene.select(0);
  return scene;
}
const params=a=>[0,1,2,3,4,5,6,7].map(i=>a.param(i));
const bases=a=>[0,1,2,3,4,5,6,7].map(i=>a.paramBase(i));
const snapshot=scene=>({lines:scene._confirmWindow.lines.slice(),gold:w.$gameParty._gold,
  members:w.$gameParty.members().map(a=>({id:a.actorId(),push:J(a.pushattribute),params:params(a),bases:bases(a)}))});
// steps：['actor',n] 换队员；['buy',行号] 选行确认
function flow(name,gold,xiulian,steps,prep){
  setup(gold,prep);const scene=makeScene(xiulian);
  const out={name,gold,xiulian,start:snapshot(scene),steps:[]};
  for(const [op,n] of steps){
    toasts.length=0;
    if(op==='actor')scene.select(n);
    else{scene._cur=n;scene.onConfirmOk();}
    out.steps.push({op,n,toasts:toasts.slice(),...snapshot(scene)});
  }
  return out;
}

const table=[];
for(let i=0;i<=100;i++){const p=S.PoLites[i];if(p)table.push(J(p));}

const flows=[];
// 魔塔教师（Map082 EV4）：买两项，同一项再买一次（已满），换队员
flows.push(flow('map082',1000000000,[8,9,14,15],[['buy',0],['buy',1],['buy',0],['actor',1],['buy',3],['actor',0]]));
// 魔塔教师（Map084 EV10）：精魂不够
flows.push(flow('map084-poor',300000000,[10,11,12,13],[['buy',0],['buy',1],['buy',2]]));
// 二十六层小萝莉三页：命脉强化（10 亿）、免费、三级（15 亿一级）
flows.push(flow('map180-p0',2500000000,[33,34,35,36,37,38,39,40],[['buy',0],['buy',7],['buy',3]]));
flows.push(flow('map180-p1',0,[41,42,43,44,45,46,47,48],[['buy',0],['buy',1],['buy',2],['buy',3],['buy',4],['buy',5],['buy',6],['buy',7],['buy',0],['actor',2],['buy',6]]));
flows.push(flow('map180-p2',5000000000,[49,50,51,52,53,54,55,56],[['buy',0],['buy',0],['buy',0],['buy',0],['buy',1]]));
// 没设 XiuLian（默认 0～7）
flows.push(flow('default',600000000,null,[['buy',2]]));
// 人物图鉴等先把 0～7 写成 [0,0]（没有能力编号）之后再修炼
flows.push(flow('book-first',600000000,[8,9,14,15],[['buy',2]],()=>{w.$gameParty.members().forEach(a=>{a.pushattribute=[];for(let i=0;i<8;i++)a.pushattribute[i]=[0,0];});}));

// 存档往返：JsonEx 序列化后 pushattribute 与能力值不变
setup(1000000000);{const scene=makeScene([8,9,14,15]);scene._cur=0;scene.onConfirmOk();}
const a1=w.$gameActors.actor(1),raw=w.JsonEx.stringify(a1),back=w.JsonEx.parse(raw);
const save={push:J(a1.pushattribute),params:params(a1),reloaded:{push:J(back.pushattribute),params:params(back)}};

if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
const out={sourceIdentity:identity,currencyUnit:w.TextManager.currencyUnit,party:PARTY,table,flows,save};
fs.mkdirSync(path.join(__dirname,'.sandbox'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'.sandbox/training.json'),JSON.stringify(out,null,1));
console.log(JSON.stringify({table:table.length,flows:flows.map(f=>f.name+':'+f.steps.length)}));process.exit(0);
