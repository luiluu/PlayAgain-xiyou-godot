'use strict';
// 只读正式引擎：YEP_BattleEngineCore 解析后每个技能/物品的五段行动序列（setup/whole/target/follow/finish）。
// 输出每项 JSON 文本的 SHA-1 与少量全文样本，供转换器 yepSeq 逐项对照；只写 .sandbox/sequences.json。
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Applications/再刷一把：西游（mod_KYO）.app/Contents/Resources/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
const out={sourceIdentity:identity,skills:{},items:{},samples:{},repeats:{}};
const PH=['setupActions','wholeActions','targetActions','followActions','finishActions'];
const digest=o=>crypto.createHash('sha1').update(JSON.stringify(PH.map(k=>o[k]||[]))).digest('hex');
for(const [key,table] of [['skills',w.$dataSkills],['items',w.$dataItems]]){
  for(const o of table){if(o)out[key][o.id]=digest(o);}
}
for(const id of [1,2,160,65,104])out.samples['s'+id]=PH.map(k=>w.$dataSkills[id][k]);
out.repeats.notOne=w.$dataSkills.filter(o=>o&&o.repeats!==1).length+w.$dataItems.filter(o=>o&&o.repeats!==1).length;
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname,'.sandbox'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'.sandbox/sequences.json'),JSON.stringify(out));
process.stdout.write(JSON.stringify({skills:Object.keys(out.skills).length,items:Object.keys(out.items).length,repeatsNotOne:out.repeats.notOne})+'\n');
process.exit(0);
