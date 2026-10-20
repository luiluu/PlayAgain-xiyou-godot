'use strict';
// 战力（installCombatPowerRuntime v2）参照：装备评分 CodexCombatPower.equipment 的总分、三项与逐行明细；
// 角色战力 CodexCombatPower.actor（切片角色 1/30 级，新开局初始装备）的总分、自身、装备差与爆发/持续/有效生命/辅助。只写 .sandbox/power.json。
// 装备按特性/备注自动挑选：每种特性（代码:编号）、每种战力相关备注各取第一件，另加切片角色的初始装备；法宝（<Magic Weapon>）另记一类。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
// 重制版不移植五乘区成长修正（00_设计/数值平衡.md，用户 2026-10-12），参照里关掉，与伤害对照去掉 growth 一致
w.eval('ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};CodexZones.ENABLED=false;');
const P=w.CodexCombatPower;
const SLICE=JSON.parse(fs.readFileSync(path.join(__dirname,'../xiyou_slice.json'),'utf8'));
const NOTE_TAGS=['passiveHarmRi','passiveCrHarmRi','passiveELUP','SkETypeHarmRi','passiveHEUP','passiveAPLUS','passiveHarmRe','SkillCriPush','DBHPLSteal',
  'Element Amplify','Element Magnify','DepassiveHarmRe','passivePBST','passiveXPBST','passiveSPBST','AgainUse','SelfPhysRate','SelfElemRate','Passive State','Magic Weapon'];
function keys(o){
  // 只取战力会读的特性：21 能力倍率、22 附加能力、23 特殊能力按编号；其余按代码
  const out=(o.traits||[]).filter(t=>[11,13,14,21,22,23,32,33,34,61,62,64].includes(t.code)).map(t=>'t'+t.code+([21,22,23,62,64].includes(t.code)?':'+t.dataId:''));
  for(const tag of NOTE_TAGS)if(new RegExp('<'+tag,'i').test(o.note||''))out.push('n'+tag);
  return out;
}
const picked=new Map();
function want(kind,id,why){const k=kind+id;if(!picked.has(k))picked.set(k,{kind,id,why});}
for(const [kind,db] of [['weapon',w.$dataWeapons],['armor',w.$dataArmors]]){
  const seen={};
  for(let id=1;id<db.length;id++){const o=db[id];if(!o||!o.name)continue;
    for(const k of keys(o))if(!seen[k]){seen[k]=true;want(kind,id,k);}}
}
for(const aid of SLICE.actors){const a=w.$dataActors[aid];if(!a)continue;
  (a.equips||[]).forEach((id,slot)=>{if(id>0)want(slot===0?'weapon':'armor',id,'actor'+aid);});}
const gear=[];
for(const c of picked.values()){
  const o=(c.kind==='weapon'?w.$dataWeapons:w.$dataArmors)[c.id];
  const s=P.equipment(o);
  gear.push({kind:c.kind,id:c.id,why:c.why,name:o.name,magic:/<Magic Weapon>/i.test(o.note||''),total:s.total,parts:s.parts,
    rows:s.rows.map(x=>({label:x.label,parts:x.parts}))});
}
// 角色战力：切片角色（新开局的初始装备）1 级与 30 级，强制重算
const actors=[];
// 角色战力对照只含 1～18 号：Kyo 2026-10-20 定，这次重制先不移植战力系统、等重制完再重做，战力对照不覆盖 19～40 号
for(const id of SLICE.actors.filter(x=>x<=18)){const a=w.$gameActors.actor(id);if(!a)continue;
  for(const lv of [1,30]){a.changeLevel(lv,false);a.recoverAll();const p=P.actor(a,true),e=p.evaluation,o=p.ownEvaluation;
    actors.push({id,level:a.level,asked:lv,name:a.name(),equips:a.equips().map(x=>x?[w.DataManager.isWeapon(x)?'weapon':'armor',x.baseItemId||x.id,x.params]:null),
      total:p.total,self:p.self,gear:p.gear,gearScore:p.gearScore,parts:p.parts,selfParts:p.selfParts,
      full:{burst:e.burst,sustained:e.sustained,effectiveHp:e.effectiveHp,auxiliary:e.auxiliary,known:e.coverage.known,unknown:e.coverage.unknown.map(u=>u.id),schedule:e.schedule.map(x=>x.id)},
      own:{burst:o.burst,sustained:o.sustained,effectiveHp:o.effectiveHp,auxiliary:o.auxiliary,schedule:o.schedule.map(x=>x.id)}});}}
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname,'.sandbox'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'.sandbox/power.json'),JSON.stringify({sourceIdentity:identity,version:P.version,gear,actors},null,1));
console.log(JSON.stringify({actors:actors.length,gear:gear.length,magic:gear.filter(g=>g.magic).length,zero:gear.filter(g=>!g.total).length}));
process.exit(0);
