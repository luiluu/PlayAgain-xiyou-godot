'use strict';
// 只读正式引擎：YEP_BattleEngineCore 解析后每个技能/物品的五段行动序列（setup/whole/target/follow/finish）。
// 输出每项 JSON 文本的 SHA-1 与少量全文样本，供转换器 yepSeq 逐项对照；只写 .sandbox/sequences.json。
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
w.eval('CodexZones.ENABLED=false;');  // 五乘区（CodexZones）重制不移植（O-044），探针宿主默认开着；关掉让参照不含成长修正（tools51 确认关与不关产物一致或已更新夹具）
if(r.errors.length||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
const out={sourceIdentity:identity,skills:{},items:{},samples:{},repeats:{}};
const PH=['setupActions','wholeActions','targetActions','followActions','finishActions'];
const digest=o=>crypto.createHash('sha1').update(JSON.stringify(PH.map(k=>o[k]||[]))).digest('hex');
for(const [key,table] of [['skills',w.$dataSkills],['items',w.$dataItems]]){
  for(const o of table){if(o)out[key][o.id]=digest(o);}
}
for(const id of [1,2,160,65,104])out.samples['s'+id]=PH.map(k=>w.$dataSkills[id][k]);
out.repeats.notOne=w.$dataSkills.filter(o=>o&&o.repeats!==1).length+w.$dataItems.filter(o=>o&&o.repeats!==1).length;
// ---- 规则实跑：真实 BattleManager 行动机（日志窗/精灵组用空代理），记录每次 ACTION EFFECT 的目标与序列附加的状态 ----
// 场景同 smart_ai_probe（普通难度、出战 1/8/9/10、10 级），敌群 222（三只 20 万血，Lv10 打不死，避免 IMMORTAL 差异）。
{
  const PARTY=[1,8,9,10],TROOP=222,LEVEL=10;
  const stub=new Proxy(function(){},{get:(t,k)=>k==='_waitCount'?0:(()=>false),set:()=>true});
  const setup=()=>{
    w.eval('ConfigManager.applyData({});DataManager.setupNewGame();$gameSystem.setDifficultyId(3);for(var i=1;i<5000;i++)if($gameVariables._data[i]===undefined)$gameVariables._data[i]=0;');
    w.eval('$gameParty._actors=[];'+JSON.stringify(PARTY)+'.forEach(function(id){$gameParty.addActor(id);});');
    for(const id of PARTY){const a=w.$gameActors.actor(id);[6168,5980,5548].concat([1,2,3,4,5,6,7,52].includes(id)?[2571,2786]:[]).forEach(k=>a.learnSkill(k));a.changeLevel(LEVEL,false);a.refresh();a.recoverAll();}
    const BM=w.BattleManager;
    if(!w.$dataMap)w.$dataMap={displayName:'',events:[],data:[],width:1,height:1,note:'',meta:{},encounterList:[],tilesetId:1};
    w.Math.random=()=>0.99;BM.setup(TROOP,true,false);BM._logWindow=stub;BM._spriteset=stub;BM._statusWindow=stub;
    try{BM.startBattle();}catch(e){out.startError=String(e&&e.stack||e).slice(0,500);}
    w.Math.random=()=>0.5;
    w.$gameParty._inBattle=true;w.$gameTroop._turnCount=1;
  };
  // 只关掉画面上的伤害弹字（LGP_BetterDamagePopup 需要精灵层）；不影响结算。
  w.Game_Battler.prototype.startDamagePopup=function(){};
  // 移动/跳跃等画面指令要战斗精灵：给一个空精灵（记住被写入的数值，方法一律无作用）。
  const sprite=()=>{const store={x:0,y:0,_homeX:0,_homeY:0,width:64,height:64,scale:{x:1,y:1},anchor:{x:0.5,y:1},opacity:255};
    return new Proxy(store,{get:(t,k)=>k in t?t[k]:(()=>false),set:(t,k,v)=>{t[k]=v;return true;}});};
  const sprites=new Map();
  w.BattleManager.actionBattleHud=function(){return true;};
  w.Game_Battler.prototype.battler=function(){if(!sprites.has(this))sprites.set(this,sprite());return sprites.get(this);};
  const key=b=>b.isActor()?'a'+b.actorId():'e'+b.index();
  const RULE=/^(ADD_STATE|ADD STATE|REMOVE_STATE|REMOVE STATE)[ ](\d+(?:\s*,\s*\d+)*)/i;
  const pick=[],seen=new Set(),add=id=>{if(!seen.has(id)&&w.$dataSkills[id]&&![3,4,5,6].includes(w.$dataSkills[id].scope)&&w.$dataSkills[id].scope>0){seen.add(id);pick.push(id);}};
  [1,2,160,65,104].forEach(add);
  const groups={};
  for(const o of w.$dataSkills){
    if(!o)continue;
    const lines=[].concat(o.setupActions,o.wholeActions,o.targetActions,o.followActions,o.finishActions);
    for(const l of lines){
      const n=String(l[0]);let g=null;
      if(/^if /i.test(n))g='if:'+n.slice(3).replace(/\d+/g,'N').replace(/\/\/.*$/,'').trim();
      else if(RULE.test(n))g='state:'+n.split(' ')[0].toUpperCase()+':'+String((l[1]||[])[0]||'').toUpperCase();
      else if(/^(HP|MP|TP)[ ]/i.test(n))g='gain:'+n.split(' ')[0].toUpperCase()+':'+String((l[1]||[])[0]||'').toUpperCase();
      else if(/^(ADD|REMOVE)[ ].*[ ](BUFF|DEBUFF)/i.test(n))g='buff';
      else if(/^ACTION EFFECT$/i.test(n)&&l[1]&&l[1][0])g='effect:'+String(l[1][0]).toUpperCase();
      if(g){(groups[g]=groups[g]||[]);if(groups[g].length<3&&!groups[g].includes(o.id))groups[g].push(o.id);}
    }
  }
  Object.values(groups).forEach(list=>list.forEach(add));
  const refs=o=>{const t=JSON.stringify([o.setupActions,o.wholeActions,o.targetActions,o.followActions,o.finishActions]);
    return {skills:[...t.matchAll(/_skills\.includes\((\d+)\)|hasSkill\((\d+)\)/g)].map(m=>+(m[1]||m[2])),states:[...t.matchAll(/user\._states\.includes\((\d+)\)/g)].map(m=>+m[1]),
      rule:[...t.matchAll(/(?:ADD|REMOVE)[ _]STATE[ ](\d+(?:\s*,\s*\d+)*)/gi)].flatMap(m=>m[1].split(',').map(Number))};};
  const run=(userKey,id,variant)=>{
    setup();
    const o=w.$dataSkills[id],rf=refs(o);
    const user=userKey==='e0'?w.$gameTroop.members()[0]:w.$gameActors.actor(+userKey.slice(1));
    if(variant==='learned'){rf.skills.forEach(k=>user.learnSkill&&user.learnSkill(k));rf.states.forEach(k=>user.addState(k));user.refresh();}
    const all=w.$gameParty.battleMembers().concat(w.$gameTroop.members());
    const before=Object.fromEntries(all.map(b=>[key(b),b._states.slice()]));
    const action=new w.Game_Action(user);action.setSkill(id);action.setTarget(0);
    user._actions=[action];const BM=w.BattleManager;BM._subject=user;BM._logWindow=stub;BM._spriteset=stub;BM._action=null;
    const invoked=[],inv=BM.invokeAction;BM.invokeAction=function(su,t){invoked.push(key(t));return inv.call(this,su,t);};
    let error=null,madeTargets=null;
    try{
      BM.startAction();
      madeTargets=(BM._allTargets||[]).map(key);
      for(let i=0;i<20000;i++){const ph=BM._phase;if(ph==='phaseChange')BM.updatePhase();else if(ph==='actionList')BM.updateActionList();else if(ph==='actionTargetList')BM.updateActionTargetList();else break;}
    }catch(e){error=String(e&&e.stack||e).slice(0,600);}
    BM.invokeAction=inv;
    const changed={};
    for(const b of all){const k=key(b);const add=b._states.filter(x=>!before[k].includes(x)&&rf.rule.includes(x)),rem=before[k].filter(x=>!b._states.includes(x)&&rf.rule.includes(x));if(add.length||rem.length)changed[k]={add,rem};}
    return {user:userKey,skill:id,variant,targets:madeTargets,invoked,states:changed,cnt:all.map(b=>b.cnt>0||b.mrf>0?key(b):null).filter(Boolean),error};
  };
  out.rules=[];
  for(const id of pick){
    out.rules.push(run('a1',id,'base'));
    const rf=refs(w.$dataSkills[id]);
    if(rf.skills.length||rf.states.length)out.rules.push(run('a1',id,'learned'));
  }
  for(const id of [1,2,160])out.rules.push(run('e0',id,'base'));
  out.ruleGroups=groups;
  // 数值／复活边界必须跑真实 actionXXX；原 rules 只比较目标与状态，无法发现数值溢出或资源夹值错误。
  const operations=[
    {id:'hp_percent',commands:[['HP -50%',['TARGETS']]]},
    {id:'hp_revive',dead:true,commands:[['HP +50',['TARGETS']]]},
    {id:'hp_var_large',variable:1e20,commands:[['HP +VAR 20',['TARGETS']]]},
    {id:'hp_var_small',variable:1e-7,commands:[['HP +VAR 20',['TARGETS']]]},
    {id:'mp_percent',commands:[['MP -50%',['TARGETS']]]},
    {id:'tp_clamp',commands:[['TP +150',['TARGETS']],['TP +150',['TARGETS']]]},
    {id:'buff_turns',commands:[['ADD ATK BUFF',['TARGETS','3']],['ADD ATK BUFF',['TARGETS','7']],['REMOVE ATK BUFF',['TARGETS']]]},
    {id:'debuff_cap',commands:[['ADD DEF DEBUFF',['TARGETS','3']],['ADD DEF DEBUFF',['TARGETS','7']],['ADD DEF DEBUFF',['TARGETS','2']]]},
    {id:'hp_buff_refresh',commands:[['ADD HP BUFF',['TARGETS','3']],['HP +100%',['TARGETS']],['REMOVE HP BUFF',['TARGETS']]]}
  ];
  w.BattleManager.otbDisplayWindow=function(){return stub;}; // 复活时 OTB 刷行动条；画面替身不改规则。
  out.operations=operations.map(row=>{
    setup();const BM=w.BattleManager,t=w.$gameTroop.members()[0];
    BM._subject=w.$gameActors.actor(1);BM._targets=[t];BM._allTargets=[t];
    t.setTp(0);if(row.dead)t.addState(1);
    if(row.variable!==undefined)w.$gameVariables.setValue(20,row.variable);
    for(const [name,args] of row.commands)BM.processActionSequence(name,args);
    return {...row,result:{hp:t.hp,mp:t.mp,tp:t.tp,states:t._states.slice(),buffs:t._buffs.slice(),buffTurns:t._buffTurns.slice()}};
  });
  out.parseIntNumbers=[0,1e-7,-1e-7,1e20,-1e20,1e21,-1e21,1e33].map(value=>({value,result:w.parseInt(value)}));
}
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname,'.sandbox'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'.sandbox/sequences.json'),JSON.stringify(out));
process.stdout.write(JSON.stringify({rules:out.rules.length,errors:out.rules.filter(r=>r.error).length,skills:Object.keys(out.skills).length,items:Object.keys(out.items).length,repeatsNotOne:out.repeats.notOne})+'\n');
process.exit(0);
