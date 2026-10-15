'use strict';
// 战力（installCombatPowerRuntime v2）参照：装备评分 CodexCombatPower.equipment 的总分、三项与逐行明细。只写 .sandbox/power.json。
// 装备按特性/备注自动挑选：每种特性（代码:编号）、每种战力相关备注各取第一件，另加切片角色的初始装备；法宝（<Magic Weapon>）另记一类。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Applications/再刷一把：西游（mod_KYO）.app/Contents/Resources/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
w.eval('ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};');
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
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname,'.sandbox'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'.sandbox/power.json'),JSON.stringify({sourceIdentity:identity,version:P.version,gear},null,1));
console.log(JSON.stringify({gear:gear.length,magic:gear.filter(g=>g.magic).length,zero:gear.filter(g=>!g.total).length}));
process.exit(0);
