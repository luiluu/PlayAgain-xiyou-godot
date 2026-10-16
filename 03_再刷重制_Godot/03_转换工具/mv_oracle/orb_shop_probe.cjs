'use strict';
// 宝珠坊严格级参照：执行正式引擎 installNativeOrbRuntime 的随机序列（roll／rollInt）、鉴定、残片换神秘珠、分解、
// 暂存宝珠领取、神秘珠暂存箱领取，以及宝珠坊各页的行文（CodexYunshang.choose 收到的行与说明，换行后）。只写 .sandbox。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded()||!w.CodexOrbs)throw new Error('参照引擎启动失败');
w.Star.Achievement.Manager.init();
const O=w.CodexOrbs,C=O.config,toasts=[];
w.$.toaster=o=>toasts.push(String(o&&o.message));
const J=x=>JSON.parse(JSON.stringify(x));
const item=id=>w.$dataItems[id];
function setup(seed,floorVar){
  w.eval('SceneManager.initInput();ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};');
  w.$gameParty._weapons={};w.$gameParty._armors={};w.$gameParty._items={};
  w.$gameSystem._codexOrbRng={seed:seed,n:{}};toasts.length=0;
  if(floorVar!==undefined)w.$gameVariables.setValue(20,floorVar);
}
const bag=()=>{const o={};Object.keys(w.$gameParty._items).forEach(k=>{if(w.$gameParty._items[k])o[k]=w.$gameParty._items[k];});return o;};
const rngState=()=>J(w.$gameSystem._codexOrbRng);
const SEEDS=[0,7,655860619,4294967295];
const PEARLS=C.bands.map(b=>b.itemId);

// 1. 随机序列
const rolls=[];
for(const seed of SEEDS){setup(seed);
  for(const st of ['identify:3027','identify:3031','drop','fragment']){const v=[];for(let i=0;i<25;i++)v.push(O.roll(st));rolls.push({seed,stream:st,values:v});}
  const ints=[];for(let i=0;i<25;i++)ints.push(O.rollInt('fragment',1,2));rolls.push({seed,stream:'fragment',rollInt:[1,2],after:25,values:ints});}

// 2. 鉴定
const identify=[];
for(const seed of SEEDS)for(const id of PEARLS)for(const q of [1,7,30]){
  setup(seed);w.$gameParty.gainItem(item(id),q+2);
  const max=O.maxIdentify(id),quote=J(O.quoteIdentify(id,q)),res=J(O.identify(id,q));
  identify.push({seed,id,q,max,quote,result:res,bag:bag(),rng:rngState(),recent:J(w.$gameSystem._codexOrbRecent||null)});}
// 鉴定失败：数量无效、不足、可能产出的宝珠背包满
const identifyFail=[];
{setup(1);w.$gameParty.gainItem(item(3027),3);
  identifyFail.push({case:'not-pearl',quote:J(O.quoteIdentify(2947,1))});
  identifyFail.push({case:'zero',quote:J(O.quoteIdentify(3027,0))});
  identifyFail.push({case:'fraction',quote:J(O.quoteIdentify(3027,1.5))});
  identifyFail.push({case:'short',quote:J(O.quoteIdentify(3027,4))});
  const p=O.possible(3027);w.$gameParty.gainItem(item(p[3]),9998);
  identifyFail.push({case:'full',full:p[3],max:O.maxIdentify(3027),quote:J(O.quoteIdentify(3027,2)),one:J(O.quoteIdentify(3027,1))});
  identifyFail.push({case:'identify-full',result:J(O.identify(3027,2)),bag:bag(),rng:rngState()});}
const possible=PEARLS.map(id=>({id,possible:O.possible(id),probabilities:O.probabilities(id),legacy:O.legacyPoolOf(id)}));

// 3. 残片换神秘珠（层段按变量 20－1）
const buy=[];
for(const v20 of [0,1,2,8,14,20,26,27,40])for(const frag of [0,10,11,70]){
  setup(3,v20);if(frag)w.$gameParty.gainItem(item(C.fragment),frag);
  const b=O.progressBand();const row={v20,frag,band:b?b.itemId:null,price:b?O.pearlPrice(b):0,quote1:J(O.quoteBuy(1)),quote5:J(O.quoteBuy(5))};
  row.buy=J(O.buyPearl(1));row.bag=bag();buy.push(row);}
{setup(3,10);w.$gameParty.gainItem(item(C.fragment),50);w.$gameParty.gainItem(item(3028),9999);buy.push({case:'pearl-full',quote:J(O.quoteBuy(1))});}

// 4. 分解
const dismantle=[];
for(const id of [2947,2951,3016,56,2000,2030,3027,1]){setup(5);w.$gameParty.gainItem(item(id),4);
  dismantle.push({id,refund:O.refund(id),isOrb:O.isOrbItem(id),quote:J(O.quoteDismantle(id,3)),zero:J(O.quoteDismantle(id,0)),many:J(O.quoteDismantle(id,5)),result:J(O.dismantle(id,3)),bag:bag()});}
{setup(5);w.$gameParty.gainItem(item(2951),2);w.$gameParty.gainItem(item(C.fragment),9999-40);
  dismantle.push({case:'fragment-full',quote:J(O.quoteDismantle(2951,2)),one:J(O.quoteDismantle(2951,1))});}

// 5. 暂存宝珠（旧档孔位重排退回、背包满时）与神秘珠暂存箱
const returns=[];
{setup(9);w.$gameSystem._codexOrbReturns={'item 2947':3,'item 56':2,'item 99999':1,'weapon 1':1};w.$gameParty.gainItem(item(2947),9998);
  returns.push({step:'pending',pending:O.pendingReturns(),box:J(w.$gameSystem._codexOrbReturns)});
  returns.push({step:'claim',gained:O.claimReturns(),box:J(w.$gameSystem._codexOrbReturns),bag:bag(),weapons:Object.keys(w.$gameParty._weapons).length});
  w.$gameParty.loseItem(item(2947),5);
  returns.push({step:'claim-again',gained:O.claimReturns(),box:J(w.$gameSystem._codexOrbReturns),bag:bag()});}
const inbox=[];
{setup(9);w.$gameSystem._codexOrbInbox={'3027':2,'3029':1,'2947':4};w.$gameParty.gainItem(item(3027),9998);
  inbox.push({gained:O.claimDrops(),box:J(w.$gameSystem._codexOrbInbox),bag:bag()});}

// 6. 宝珠坊各页（stub CodexBinding.openMenu／CodexYunshang.choose，按行文点选）
let screens=[],cur=null;
w.CodexYunshang.choose=function(scene,rows,ok,cancel,info){cur={rows,ok,cancel,info};screens.push({info:J(info||[]),rows:rows.map(x=>({label:x.label,enabled:x.enabled!==false}))});};
let home=null;w.CodexBinding.openMenu=function(b){home=b;return true;};
const scene={popScene(){screens.push({popped:true});}};
function pick(label){const r=cur.rows.find(x=>x.label===label);if(!r)throw new Error('找不到行 '+label+' 现有 '+cur.rows.map(x=>x.label).join('|'));cur.ok(r);}
function back(){cur.cancel();}
function flow(name,prep,steps){screens=[];prep();toasts.length=0;if(!O.open())throw new Error('打不开宝珠坊');home(scene);
  for(const s of steps){if(s==='<')back();else pick(s);}
  return {name,screens,toasts:toasts.slice(),bag:bag(),rng:rngState()};}
const pages=[];
pages.push(flow('home-empty',()=>setup(11,1),['鉴定神秘珠','尚无未鉴定神秘珠','残片换神秘珠','残片不足（每枚 11）','分解宝珠','尚无可分解的背包宝珠','楼层与品质分布','1～6层：神秘珠·尘封','返回分布表','<','套装图谱与当前配装','焚雷：烈焰／雷霆／灵慧','查看当前队伍此套装','返回套装列表','<','返回']));
pages.push(flow('identify',()=>{setup(11,15);w.$gameParty.gainItem(item(3029),12);w.$gameParty.gainItem(item(3027),1);w.$gameParty.gainItem(item(C.fragment),40);},
  ['鉴定神秘珠','神秘珠·玄藏 ×12','鉴定 5 枚','确认鉴定 5 枚','<','神秘珠·玄藏 ×7','鉴定 7 枚','取消','<','<','<']));
pages.push(flow('identify-result-detail',()=>{setup(12,15);w.$gameParty.gainItem(item(3031),2);},
  ['鉴定神秘珠','神秘珠·太初 ×2','鉴定 1 枚','确认鉴定 1 枚']));
{const f=pages[pages.length-1];const res=cur.rows.filter(x=>!x.back);if(res.length){cur.ok(res[0]);f.screens.push(...screens.slice(f.screens.length));}}
pages.push(flow('buy',()=>{setup(13,15);w.$gameParty.gainItem(item(C.fragment),120);},['残片换神秘珠','兑换 1 枚（33 残片）','确认兑换 1 枚','<','兑换 2 枚（66 残片）','取消','返回']));
pages.push(flow('dismantle',()=>{setup(14,3);w.$gameParty.gainItem(item(2951),6);w.$gameParty.gainItem(item(56),1);w.$gameParty.gainItem(item(2000),2);},
  ['分解宝珠','宝珠·锋刃·归真 ×6','分解 5 颗 → 155 残片','确认分解 5 颗','<','宝珠:黑荆棘 ×2','分解 2 颗 → 6 残片','取消','返回','<','<']));
pages.push(flow('returns',()=>{setup(15,3);w.$gameSystem._codexOrbReturns={'item 2947':2,'item 56':1};w.$gameParty.gainItem(item(2947),9999);},
  ['领取暂存宝珠（2颗）','宝珠·锋刃·凝砂 ×2','领取这一种','再次领取','返回宝珠坊','返回']));
pages.push(flow('home-inbox',()=>{setup(16,30);w.$gameSystem._codexOrbInbox={'3031':2};w.$gameParty.gainItem(item(3030),3);w.$gameParty.gainItem(item(C.fragment),7);},['返回']));

if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
const out={sourceIdentity:identity,config:{fragment:C.fragment,legacyShare:C.legacyShare,dropRate:C.dropRate,pearlPrice:C.pearlPrice,refund:C.refund},
  rolls,identify,identifyFail,possible,buy,dismantle,returns,inbox,pages};
fs.writeFileSync(path.join(__dirname,'.sandbox/orb_shop.json'),JSON.stringify(out,null,1));
console.log(JSON.stringify({rolls:rolls.length,identify:identify.length,buy:buy.length,dismantle:dismantle.length,pages:pages.map(p=>p.name+':'+p.screens.length)}));process.exit(0);
