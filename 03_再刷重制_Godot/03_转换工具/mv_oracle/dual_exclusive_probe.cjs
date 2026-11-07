'use strict';
// 双持专武只能装一把（installDualExclusiveRuntime，v0.62.10）：刘备（13，专武 2005／2006／2007 都带双持）、
// 紫霞（70，职业双持，专武 1548／1696）逐步换装（另一武器栏已有专武时 changeEquip 不换）、装备页候选可用与否
// （Window_EquipItem.isEnabled）、清空＋最强装备（第二栏跳过专武）、旧档同时装着两把时 refresh 只留前一把（其余退回背包）。
// 内存新游戏，固定随机数 0.5；只写 .sandbox/dual_exclusive.json。五乘区关掉（不读伤害，照登记检查要求写上）。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
w.eval('ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};');
w.eval('if(window.CodexZones)CodexZones.ENABLED=false;');
if(!w.KyoDualExclusive)throw new Error('installDualExclusiveRuntime 没装上');
const kindOf=e=>w.DataManager.isWeapon(e)?'weapon':'armor';
function baseOf(e){const db=w.DataManager.isWeapon(e)?w.$dataWeapons:w.$dataArmors;let o=e;
  for(let n=0;n<20&&o;n++){const b=o.originalBaseItemId||o.baseItemId;if(!b||b===o.id)return o.id;o=db[b];}throw new Error('基础编号循环 '+e.id);}
const J=o=>w.JSON.parse(w.JSON.stringify(o));
const brief=e=>e?{kind:kindOf(e),base:baseOf(e),params:Array.from(e.params)}:null;
function gain(kind,base){
  const db=kind==='weapon'?w.$dataWeapons:w.$dataArmors,before=w.$gameParty.equipItems().slice();
  w.$gameParty.gainItem(db[base],1);
  const e=w.$gameParty.equipItems().find(x=>before.indexOf(x)<0);
  if(!e)throw new Error('未生成装备 '+kind+base);
  return e;
}
const bag=()=>w.$gameParty.equipItems().map(e=>kindOf(e)+baseOf(e)).sort();
function snap(a,label,extra){
  a.refresh();
  const slots=Array.from(a.equipSlots());
  // 前两格的候选（etypeId 相符且能装）与装备页可用与否
  const cand=slots.slice(0,2).map((t,i)=>w.$gameParty.equipItems().filter(e=>e.etypeId===t&&a.canEquip(e))
    .map(e=>({base:baseOf(e),enabled:!!w.Window_EquipItem.prototype.isEnabled.call({_actor:a,_slotId:i},e)}))
    .sort((x,y)=>x.base-y.base||(x.enabled-y.enabled)));
  return Object.assign({label,dual:!!a.isDualWield(),slots,equips:a.equips().map(e=>e&&{kind:kindOf(e),base:baseOf(e)}),bag:bag(),candidates:cand},extra||{});
}
const LEVEL=80;   // 紫青宝剑*绝 1696 要 70 级
function fresh(aid){
  w.$gameParty._weapons={};w.$gameParty._armors={};
  w.$gameActors._data[aid]=null;const a=w.$gameActors.actor(aid);a.changeLevel(LEVEL,false);a._level=LEVEL;   // 新游戏有等级上限，直接写等级（只为过 req_level）
  // 入队自带的装备也清掉，从空身开始（卸下的进背包后再清背包）
  for(let i=0;i<a._equips.length;i++)a._equips[i].setObject(null);
  a.refresh();a.recoverAll();return a;
}
function find(kind,base){return w.$gameParty.equipItems().find(e=>kindOf(e)===kind&&baseOf(e)===base);}
const flows=[];
function flow(name,aid,gains,steps){
  const a=fresh(aid),made=gains.map(([k,b])=>gain(k,b));
  const out={name,actor:aid,gains:made.map(e=>({kind:kindOf(e),base:baseOf(e),params:Array.from(e.params),traits:J(e.traits)})),initial:snap(a,'initial'),steps:[]};
  for(const s of steps){
    if(s[0]==='optimize'||s[0]==='clear'){
      const flag=s[0]==='optimize'?'_optimizeEquipments':'_clearEquipments';
      w.$gameTemp[flag]=true;s[0]==='optimize'?a.optimizeEquipments():a.clearEquipments();w.$gameTemp[flag]=false;
      out.steps.push(snap(a,s[0],{op:s[0]}));
    }else if(s[0]==='force'){
      // 旧档：绕过 changeEquip 直接把两把专武放进两个武器栏（先放 s[1] 进 0 格让刘备变双持），再 refresh
      const [,b0,b1]=s,e0=find('weapon',b0),e1=find('weapon',b1);
      w.$gameParty.loseItem(e0,1);a._equips[0].setObject(e0);
      w.$gameParty.loseItem(e1,1);a._equips[1].setObject(e1);
      out.steps.push(snap(a,'force '+b0+' '+b1,{op:'force',bases:[b0,b1]}));
    }else{
      const [slot,kind,base]=s,item=base?find(kind,base):null;
      if(base&&!item)throw new Error('背包没有 '+kind+base);
      a.changeEquip(slot,item);
      out.steps.push(snap(a,s.join(' '),{op:'change',change:{slot,kind,base,ok:item?a.equips()[slot]===item:!a.equips()[slot]}}));
    }
  }
  flows.push(out);
}
// 刘备：0 格装 2005（变双持）→ 1 格装 2006 被挡 → 1 格装普通剑 2 → 0 格换 2006（同栏换专武不挡）→ 1 格再试 2007 被挡
// → 清空 → 最强（0 格挑专武、1 格跳过专武）→ 旧档两把专武 refresh 只留 0 格
flow('liubei',13,[['weapon',2005],['weapon',2006],['weapon',2007],['weapon',2]],[
  [0,'weapon',2005],[1,'weapon',2006],[1,'weapon',2],[0,'weapon',2006],[1,'weapon',2007],['clear'],['optimize'],['clear'],['force',2005,2007]]);
// 紫霞：职业双持，两栏都是武器
flow('zixia',70,[['weapon',1548],['weapon',1696],['weapon',2]],[
  [1,'weapon',1696],[0,'weapon',1548],[0,'weapon',2],[0,'weapon',1548],[1,'weapon',0],[0,'weapon',1548],['clear'],['optimize'],['clear'],['force',1696,1548]]);
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname,'.sandbox'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'.sandbox/dual_exclusive.json'),JSON.stringify({sourceIdentity:identity,level:LEVEL,flows},null,1));
console.log(JSON.stringify({flows:flows.length,steps:flows.reduce((n,f)=>n+f.steps.length,0)}));
process.exit(0);
