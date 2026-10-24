'use strict';
// 精魂（金钱）上下限严格级参照：执行正式 Game_Party.gainGold／loseGold／maxGold（YEP_CoreEngine「Gold Max」与正式版 rpg_objects 改过的下限）、
// Yanfly.Util.toGroup 与 JsonEx 存档往返，记录 YEP 金钱显示参数（Gold Font Size、Gold Overlap、Digit Grouping）。只写 .sandbox。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
w.eval('SceneManager.initInput();ConfigManager.applyData({});DataManager.setupNewGame();');
const P=w.$gameParty;

// 每段：起始精魂（直接写 _gold），依次 gainGold（负数即 loseGold），记每步之后的精魂
const SEQS=[
  ['cap',0,[5000000000000]],
  ['over_999m',900000000,[200000000,1500000000,-1500000000]],
  ['near_max',999999999000,[999,1,1000,-999999999999]],
  ['below_zero',100,[-50,-100,-99999999,-1]],
  ['from_floor',0,[-200000000000,99999999]],
  ['training_15e8',5000000000,[-1500000000,-1500000000,-1500000000]],
];
const seqs=SEQS.map(([name,start,steps])=>{P._gold=start;return {name,start,steps,after:steps.map(a=>{P.gainGold(a);return P._gold;})};});
const GROUP=[0,999,1000,-1000,12345,999999999,1500000000,999999999999,-99999999,1000000001499];
const groups=GROUP.map(v=>[v,w.Yanfly.Util.toGroup(v)]);

// 存档往返：$gameParty 经 JsonEx 序列化后精魂不变（大于 2^31）
const saves=[999999999999,2147483648,-99999999].map(g=>{P._gold=g;const back=w.JsonEx.parse(w.JsonEx.stringify(P));return [g,back._gold];});

if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
const Y=w.Yanfly.Param;
const out={sourceIdentity:identity,maxGold:P.maxGold(),goldFontSize:Y.GoldFontSize,goldOverlap:Y.GoldOverlap,digitGroup:Y.DigitGroup,
  goldIcon:w.Yanfly.Icon.Gold,currencyUnit:w.TextManager.currencyUnit,seqs,groups,saves};
fs.mkdirSync(path.join(__dirname,'.sandbox'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'.sandbox/gold.json'),JSON.stringify(out,null,1));
console.log(JSON.stringify({maxGold:out.maxGold,seqs:seqs.map(s=>s.name+':'+s.after.join('/'))}));process.exit(0);
