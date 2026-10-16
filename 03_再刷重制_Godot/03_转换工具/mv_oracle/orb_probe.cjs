'use strict';
// 宝珠镶嵌严格级参照：执行正式引擎 installNativeOrbRuntime（孔数/孔类型/可镶/同类上限/套装）、YEP_X_AttachAugments
// （镶嵌、替换、取下的效果行）与 Star_EquipmentMosaic（<继承词缀> 并入装备备注标签）。宝珠直接给，不走掉落与鉴定。只写 .sandbox。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded()||!w.CodexOrbs)throw new Error('参照引擎启动失败');
w.Star.Achievement.Manager.init();
const O=w.CodexOrbs,toasts=[];
w.$.toaster=o=>toasts.push(String(o&&o.message));
const J=x=>JSON.parse(JSON.stringify(x));
function setup(seed){
  w.eval('SceneManager.initInput();ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};');
  w.$gameParty._weapons={};w.$gameParty._armors={};w.$gameParty._items={};
  w.$gameSystem._codexOrbRng={seed:seed,n:{}};toasts.length=0;
}
function gain(kind,base){
  const db=kind==='weapon'?w.$dataWeapons:w.$dataArmors,before=w.$gameParty.equipItems().slice();
  w.$gameParty.gainItem(db[base],1);
  const e=w.$gameParty.equipItems().find(x=>before.indexOf(x)<0);
  if(!e)throw new Error('未生成装备 '+kind+base);
  return e;
}
// 装备上与宝珠有关的全部字段（比对用）
function snap(e){return {params:J(e.params),traits:J(e.traits),elementAmplify:J(e.elementAmplify||{}),
  augmentSlots:J(e.augmentSlots||[]),augmentSlotEnable:J(e.augmentSlotEnable||[]),augmentSlotItems:J(e.augmentSlotItems||[]),
  meta:J(e.meta),price:e.price,name:e.name};}
function counts(ids){const o={};ids.forEach(id=>o[id]=w.$gameParty.numItems(w.$dataItems[id]));return o;}
const SEEDS=[0,1,655860619,2147483648,4294967295,123456789];

// 1. 孔数：固定种子、装备编号，调用正式 socketCount（暂改实例 id 后还原）
setup(1);
const wpn=gain('weapon',1),arm=gain('armor',1);
const socket=[];
for(const seed of SEEDS){w.$gameSystem._codexOrbRng={seed,n:{}};
  for(const eq of [wpn,arm]){const id=eq.id,row=[];for(let k=1;k<=60;k++){eq.id=k;row.push(O.socketCount(eq));}
    for(const k of [3000,4080,4999,12345]){eq.id=k;row.push(O.socketCount(eq));}eq.id=id;
    socket.push({seed,kind:eq===wpn?'weapon':'armor',ids:Array.from({length:60},(_,i)=>i+1).concat([3000,4080,4999,12345]),counts:row});}}

// 2. 孔类型：每个装备类型各取一件（武器取前几件）
const types=[];
for(let id=1;id<w.$dataWeapons.length&&types.length<3;id++)if(w.$dataWeapons[id]&&w.$dataWeapons[id].name)types.push({kind:'weapon',base:id,etypeId:w.$dataWeapons[id].etypeId,type:O.socketType(w.$dataWeapons[id])});
const seenEtype={};
for(let id=1;id<w.$dataArmors.length;id++){const a=w.$dataArmors[id];if(!a||!a.name||seenEtype[a.etypeId])continue;seenEtype[a.etypeId]=1;types.push({kind:'armor',base:id,etypeId:a.etypeId,type:O.socketType(a)});}

// 3. 获得即排孔：同一种子下按获得先后
const layout=[];
for(const seed of [7,655860619]){setup(seed);
  for(const [kind,base] of [['weapon',1],['weapon',2],['weapon',5],['armor',1],['armor',2],['armor',3]].concat(types.filter(t=>t.kind==='armor').slice(0,8).map(t=>['armor',t.base]))){
    const e=gain(kind,base);layout.push({seed,kind,base,id:e.id,etypeId:e.etypeId,augmentSlots:J(e.augmentSlots),augmentSlotEnable:J(e.augmentSlotEnable),augmentSlotItems:J(e.augmentSlotItems)});}}

// 4. 可镶列表与可选性（Window_AugmentItemList：includes＋isEnabled）
const fam=i=>O.config.families[i].ids;
const GEMS=[fam(0)[0],fam(0)[2],fam(1)[0],fam(14)[1],fam(10)[0],fam(10)[3],fam(13)[0],56,441,2000,2030,3027,1];
function forceSlots(e,type,n){e.augmentSlots=[];e.augmentSlotEnable=[];e.augmentSlotItems=[];for(let i=0;i<n;i++){e.augmentSlots.push(type);e.augmentSlotEnable.push(true);e.augmentSlotItems.push('none');}}
function listOf(e,slot){const win=new w.Window_AugmentItemList(0,172,640,548);win.setItem(e,slot);
  return win._data.map(it=>({id:it?it.id:null,enabled:win.isEnabled(it)}));}
const lists=[];
setup(9);GEMS.forEach(id=>w.$gameParty.gainItem(w.$dataItems[id],2));
{const e=gain('weapon',1);forceSlots(e,'武器宝珠',3);
  lists.push({label:'weapon3-empty',slots:[0,1,2].map(s=>listOf(e,s))});
  w.ItemManager.applyAugmentEffects(e,w.$dataItems[fam(0)[0]],0,1);
  lists.push({label:'weapon3-edge0',slots:[0,1,2].map(s=>listOf(e,s)),counts:counts(GEMS)});
  e.augmentSlotEnable[2]=false;
  lists.push({label:'weapon3-slot2-disabled',slots:[2].map(s=>listOf(e,s))});
  const a=gain('armor',1);forceSlots(a,'防具宝珠',2);
  lists.push({label:'armor2-empty',slots:[0,1].map(s=>listOf(a,s))});}

// 5. 镶嵌/替换/取下的效果（applyAugmentEffects gain=1），逐颗宝珠在新装备上做
const install=[];
const CASES=[['weapon',1,'武器宝珠',[fam(0)[0]]],['weapon',1,'武器宝珠',[fam(2)[4]]],['weapon',1,'武器宝珠',[fam(14)[2]]],['weapon',1,'武器宝珠',[fam(15)[1]]],
  ['weapon',1,'武器宝珠',[56]],['weapon',1,'武器宝珠',[441]],['weapon',1,'武器宝珠',[2000]],['weapon',1,'武器宝珠',[2030]],
  ['armor',1,'防具宝珠',[fam(10)[0]]],['armor',1,'防具宝珠',[fam(11)[4]]],['armor',1,'防具宝珠',[fam(12)[2]]],['armor',1,'防具宝珠',[fam(13)[3]]],
  ['weapon',1,'武器宝珠',[fam(0)[0],fam(0)[3]],'replace'],['weapon',1,'武器宝珠',[2000,56],'replace'],['weapon',1,'武器宝珠',[fam(0)[1],null],'remove'],
  ['weapon',1,'武器宝珠',[2030,null],'remove'],['armor',1,'防具宝珠',[fam(10)[2],null],'remove'],
  ['weapon',1,'武器宝珠',[fam(10)[0]],'wrong-type'],['armor',1,'防具宝珠',[fam(0)[0]],'wrong-type']];
for(const [kind,base,type,gems,mode] of CASES){
  setup(11);GEMS.concat(gems.filter(Boolean)).forEach(id=>w.$gameParty.gainItem(w.$dataItems[id],1));
  const e=gain(kind,base);forceSlots(e,type,2);const before=snap(e),steps=[];
  for(const id of gems){toasts.length=0;const c0=counts(GEMS.concat(gems.filter(Boolean)));
    const ok=w.ItemManager.applyAugmentEffects(e,id?w.$dataItems[id]:null,0,1);
    steps.push({gem:id,result:ok===false?false:true,after:snap(e),counts:counts(GEMS.concat(gems.filter(Boolean))),countsBefore:c0,toasts:toasts.slice()});}
  // 同一件装备同类第二颗（孔 1）
  let second=null;
  if(!mode&&O.spec(gems[0])){toasts.length=0;w.$gameParty.gainItem(w.$dataItems[gems[0]],1);
    const ok=w.ItemManager.applyAugmentEffects(e,w.$dataItems[gems[0]],1,1);second={result:ok===false?false:true,after:snap(e),toasts:toasts.slice()};}
  install.push({kind,base,type,gems,mode:mode||'install',before,steps,second});
}

// 6. 角色身上：同类只算阶位最高 3 件（allTraits 过滤）与套装
function wear(slots){setup(13);const a=w.$gameActors.actor(1);a.releaseUnequippableItems=function(){};
  if(JSON.stringify(a.equipSlots())!==JSON.stringify(Array.from({length:19},(_,i)=>i+1)))throw new Error('角色1装备槽不是 1..19');
  for(let i=0;i<a._equips.length;i++)a._equips[i].setObject(null);
  const worn=[];
  for(const s of slots){const eq=gain(s.kind,s.base);forceSlots(eq,s.kind==='weapon'||[1,2,17].indexOf(eq.etypeId)>=0?'武器宝珠':'防具宝珠',s.gems.length);
    s.gems.forEach((g,i)=>{w.$gameParty.gainItem(w.$dataItems[g],1);w.ItemManager.applyAugmentEffects(eq,w.$dataItems[g],i,1);});
    a._equips[s.slot].setObject(eq);w.$gameParty.loseItem(eq,1);worn.push({slot:s.slot,kind:s.kind,base:s.base,gems:s.gems,equip:snap(eq)});}
  a.refresh();
  // krz_state_re 缓存 paramRate／xparam，宝珠是先镶后穿，刷新标记要手动置上（正式游戏里由 augmentRefreshParty 置）
  a.need_refresh_paramrate=[1,1,1,1,1,1,1,1];a.need_refresh_xparam=[1,1,1,1,1,1,1,1,1,1];
  const kept=a.allTraits().filter(t=>t._codexOrb).map(t=>({code:t.code,dataId:t.dataId,value:t.value,orb:t._codexOrb}));
  const all=[];a.equips().forEach((eq,i)=>{if(eq)eq.traits.forEach(t=>{if(t._codexOrb)all.push({slot:i,code:t.code,dataId:t.dataId,value:t.value,orb:t._codexOrb});});});
  // 套装通用效果：CodexDamage.calculate 的 terminal（finalMultiplier）；普通攻击与一个魔法技能，对 1 号敌人
  const foe=new w.Game_Enemy(1,0,0),damage=[1,DMG_SKILL].map(id=>{const act=new w.Game_Action(a);act.setSkill(id);
    const res=w.CodexDamage.calculate(act,foe,{reference:true,critical:false});return {skill:id,terminal:res.breakdown.terminal};});
  return {worn,kept,all,damage,paramRate:[0,1,2,3,4,5,6,7].map(i=>a.paramRate(i)),xparam:[0,1,2,3,4,5,6,7,8,9].map(i=>a.xparam(i)),
    sets:J(O.activeSets(a)),general:J(O.generalSet(a))};}
const DMG_SKILL=w.$dataSkills.findIndex(k=>k&&k.damage&&k.damage.type===1&&k.hitType===2&&/a\.mat/.test(k.damage.formula));
const armorBases=types.filter(t=>t.kind==='armor'&&[1,2,17].indexOf(t.etypeId)<0);
const slotOf=t=>t.etypeId-1;
const guard=fam(10),life=fam(11),speed=fam(13);
const actor=[];
// 五件防具都镶玄甲：阶位 1/4/2/5/2 → 留 5、4、第一个 2
actor.push({label:'guard-cap',...wear(armorBases.slice(0,5).map((t,i)=>({kind:'armor',base:t.base,slot:slotOf(t),gems:[guard[[0,3,1,4,1][i]]]})))});
// 三件不超上限；另带长生两件
actor.push({label:'guard3-life2',...wear(armorBases.slice(0,5).map((t,i)=>({kind:'armor',base:t.base,slot:slotOf(t),gems:i<3?[guard[i]]:[life[i]]})))});
// 两类各四件，且一件同时镶两类
actor.push({label:'two-families',...wear(armorBases.slice(0,5).map((t,i)=>({kind:'armor',base:t.base,slot:slotOf(t),gems:i===4?[life[0]]:[speed[i],life[4-i]]})))});
// 套装：武器 锋刃＋鹰眼，防具 玄甲 → 剑魄 3 件（阶位取最低）；秘锋 2 件
actor.push({label:'sets',...wear([{kind:'weapon',base:1,slot:0,gems:[fam(0)[3],fam(14)[1]]},{kind:'armor',base:armorBases[0].base,slot:slotOf(armorBases[0]),gems:[guard[2]]}])});
actor.push({label:'sets-legacy-mix',...wear([{kind:'weapon',base:1,slot:0,gems:[fam(6)[4],56]},{kind:'armor',base:armorBases[0].base,slot:slotOf(armorBases[0]),gems:[life[1]]}])});

const W=new w.Window_AugmentItemList(0,172,640,548);
const params=w.PluginManager.parameters('YEP_X_AttachAugments');
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
const out={sourceIdentity:identity,config:{sockets:O.config.sockets,familyCap:O.config.familyCap},params,
  listWindow:{rect:[W.x,W.y,W.width,W.height],lineHeight:W.lineHeight(),maxCols:W.maxCols()},socket,types,layout,lists,install,actor};
fs.writeFileSync(path.join(__dirname,'.sandbox/orbs.json'),JSON.stringify(out,null,1));
console.log(JSON.stringify({socket:socket.length,types:types.length,layout:layout.length,lists:lists.length,install:install.length,actor:actor.length}));process.exit(0);
