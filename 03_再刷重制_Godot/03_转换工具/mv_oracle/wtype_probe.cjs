'use strict';
// 技能武器类型要求（Game_Actor.isSkillWtypeOk，经 dsPassiveSkill 的 isWtypeEquipped）：切片角色（10 级）× 默认装备／裸装／各武器类型的第一件
// × 角色已学技能＋几招有武器要求的技能，记战斗中 canUse（满 MP/TP）。只写 .sandbox/wtype.json。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Applications/再刷一把：西游（mod_KYO）.app/Contents/Resources/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
w.eval('ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};');
const SLICE=JSON.parse(fs.readFileSync(path.join(__dirname,'../xiyou_slice.json'),'utf8'));
w.$gameParty.inBattle=function(){return true;};
const firstOfType={};for(let id=1;id<w.$dataWeapons.length;id++){const o=w.$dataWeapons[id];if(o&&o.name&&o.wtypeId>0&&!firstOfType[o.wtypeId])firstOfType[o.wtypeId]=id;}
const EXTRA=[101,160,162,164,3641,3644,2106];
const cases=[];
for(const aid of SLICE.actors){const a=w.$gameActors.actor(aid);if(!a)continue;a.changeLevel(10,false);
  const variants=[['default',null],['naked',0]].concat(Object.keys(firstOfType).map(t=>['wtype'+t,firstOfType[t]]));
  const original=a._equips.map(e=>e.object());
  for(const [name,wid] of variants){
    if(name!=='default'){a._equips.forEach((e,i)=>e.setObject(i===0&&wid?w.$dataWeapons[wid]:null));}
    a.refresh();a.recoverAll();a._tp=a.maxTp();
    const ids=[...new Set(a.skills().map(s=>s.id).concat(EXTRA))].filter(id=>{const s=w.$dataSkills[id];return s&&(s.occasion===0||s.occasion===1);});
    for(const id of ids)cases.push({actor:aid,variant:name,weapon:wid,skill:id,canUse:!!a.canUse(w.$dataSkills[id]),level:a.level,mmp:a.mmp,wtypeOk:!!a.isSkillWtypeOk(w.$dataSkills[id])});
    a._equips.forEach((e,i)=>e.setObject(original[i]||null));
  }
}
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname,'.sandbox'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'.sandbox/wtype.json'),JSON.stringify({sourceIdentity:identity,firstOfType,cases},null,1));
console.log(JSON.stringify({cases:cases.length,blocked:cases.filter(c=>!c.wtypeOk).length,firstOfType}));
process.exit(0);
