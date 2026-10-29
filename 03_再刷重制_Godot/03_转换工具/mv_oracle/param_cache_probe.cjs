'use strict';
// krz_state_re 能力值缓存（_ParamCache2／need_refresh_param／_paramratecache）与减益的时序参照：冻结原版、全内存新局，只写 .sandbox。
// 每个读数同时记缓存值（a.param）与绕过缓存的现算值（krz.restate.Game_Actor_param），stale＝两者不等。
const {start, makeCase, finish} = require('./shared/host.cjs');
const {battleHost} = require('./shared/battle_host.cjs');
const host=start(), {w,newGame}=host, K=w.krz.restate;
const PIDS=[0,2,3,6];
// 伤害公式读数：临时把技能 1 的公式换成 a.atk／b.def，量完还原（evalDamageFormula 读的就是 param 缓存）
function formula(sub, tgt, f) {
  const d=w.$dataSkills[1].damage, old=d.formula; d.formula=f;
  try { const act=new w.Game_Action(sub); act.setSkill(1); return act.evalDamageFormula(tgt); } finally { d.formula=old; }
}
function fresh(b, i) { return (b.isActor()?K.Game_Actor_param:K.Game_Enemy_param).call(b, i); }
function rd(b, tag, foe) {
  const r={tag, buffs:Array.from(b._buffs), states:Array.from(b._states), need:!!b.need_refresh};
  for(const i of PIDS) { const c=b.param(i), f=fresh(b,i); r['p'+i]=c; if(c!==f) r['p'+i+'_fresh']=f; }
  if(foe) { r.formula_b_def=formula(foe,b,'b.def'); r.formula_a_atk=formula(b,foe,'a.atk'); }
  if(b.isActor() && w.CodexCombatPower) { try { r.power=w.CodexCombatPower.actor(b).total; } catch(e) { r.power='err:'+String(e).slice(0,80); } }
  return r;
}
// 无参数特性、无备注的状态（「已有状态」用），与带 21 号特性（能力值倍率）的状态
const plainState=w.$dataStates.find(s=>s&&s.id>10&&s.traits.length===0&&!s.note&&s.autoRemovalTiming===0&&!s.restriction);
const rateState=w.$dataStates.find(s=>s&&s.id>10&&!s.note&&s.traits.length===1&&s.traits[0].code===21&&s.traits[0].dataId===2&&s.traits[0].value!==1);
const plainState2=w.$dataStates.find(s=>s&&s!==plainState&&s.id>10&&s.traits.length===0&&!s.note&&s.autoRemovalTiming===0&&!s.restriction);
function battle(opt={}) {
  newGame(); const a=w.$gameActors.actor(1), e=new w.Game_Enemy(1,0,0); w.$gameTroop._enemies=[e];  // Game_Action.subject() 按敌群序号取敌人
  if(opt.inBattle!==false) w.$gameParty._inBattle=true;
  for(const b of [a,e]) { b.onBattleStart(); b.refresh(); b.recoverAll(); }
  return {a,e};
}
const cases=[];
// 1. 减益前后各读一次（缓存已热）：无状态／已有状态
for(const st of ['none','plain']) cases.push(makeCase('debuff_warm.'+st, {state:st==='plain'?plainState.id:null}, ()=>{
  const {a,e}=battle(); if(st==='plain') { a.addState(plainState.id); a.refresh(); }
  const rows=[rd(a,'before',e)]; a.addDebuff(2,5); a.addDebuff(3,5); rows.push(rd(a,'after_debuff',e));
  a.refresh(); rows.push(rd(a,'after_refresh',e)); return {rows};
}));
// 2. 冷格：上次 refresh 后没读过，减益后第一次读
cases.push(makeCase('debuff_cold', {}, ()=>{
  const {a,e}=battle(); a.addState(plainState.id); a.refresh();
  a.addDebuff(2,5); a.addDebuff(3,5); return {rows:[rd(a,'first_read_after_debuff',e)]};
}));
// 3. 失效时机：减益读到旧值之后，各做一件事再读
const after={
  refresh_only:a=>a.refresh(),
  gainHp_minus1:a=>a.gainHp(-1),
  gainHp_0:a=>{a.gainHp(0);},
  onTurnEnd:a=>a.onTurnEnd(),
  onTurnStart:a=>a.onTurnStart(),
  onTurnStart_refresh:a=>{a.onTurnStart(); a.refresh();},
  addState_new:a=>a.addState(plainState2.id),
  addBuff_other:a=>a.addBuff(6,3),
  addDebuff_again:a=>a.addDebuff(2,5),
  removeBuff:a=>a.removeBuff(2),
  eraseBuff:a=>{a.eraseBuff(2); a.refresh();},
  removeState:a=>a.removeState(plainState.id),
};
for(const [k,f] of Object.entries(after)) cases.push(makeCase('invalidate.'+k, {}, ()=>{
  const {a,e}=battle(); a.addState(plainState.id); a.refresh(); rd(a,'warm');
  a.addDebuff(2,5); a.addDebuff(3,5); const rows=[rd(a,'stale',e)]; f(a); rows.push(rd(a,k,e)); return {rows};
}));
// 4. 实战顺序：Game_Action.apply 先 executeDamage（gainHp 标 dirty）再逐个 applyItemEffect（效果 32 → addDebuff，内部 refresh）。
// 这两例按 apply 的顺序直接调这两步（上期的模拟）；下面 4a 用 battleHost 走真 apply 核对。pure＝不带伤害的减益效果。
for(const k of ['damage','pure']) cases.push(makeCase('apply_debuff.'+k, {}, ()=>{
  const {a,e}=battle(); a.addState(plainState.id); a.refresh(); const rows=[rd(a,'before',e)];
  const act=new w.Game_Action(e); act.setSkill(1);
  if(k==='damage') act.executeDamage(a, 10);
  act.applyItemEffect(a, {code:32, dataId:2, value1:5, value2:0}); act.applyItemEffect(a, {code:32, dataId:3, value1:5, value2:0});
  rows.push(Object.assign(rd(a,'after_apply',e),{hp:a.hp,debuffs:Array.from(a.result().addedDebuffs)}));
  return {rows};
}));
// 4a. 真 apply（battleHost：敌群 2、BattleManager.setup＋startBattle）：敌人对角色用带伤害、附加减益（效果 32）的技能；
// 它原本减敏捷（角色 1 敏捷为 0 看不出），量时把效果临时换成减攻、减防各一层；pure＝再临时把伤害类型改成 0（只走效果）。缓存先读热，看 apply 后当场读到的值。
const realDebuff=w.$dataSkills.find(s=>s&&s.damage.type===1&&s.effects.some(x=>x.code===32));
for(const k of ['damage','pure']) cases.push(makeCase('apply_real.'+k, {skill:realDebuff.id, effects:realDebuff.effects.filter(x=>x.code===32)}, ()=>{
  const bh=battleHost(host), a=bh.actor(0), e=bh.enemy(0); const rows=[rd(a,'before',e)];
  const d=realDebuff.damage, old=d.type, oldFx=realDebuff.effects; if(k==='pure') d.type=0;
  realDebuff.effects=[{code:32,dataId:2,value1:5,value2:0},{code:32,dataId:3,value1:5,value2:0}];
  let r; try { r=bh.apply(e, realDebuff.id, a); } finally { d.type=old; realDebuff.effects=oldFx; }
  rows.push(Object.assign(rd(a,'after_apply',e),{hp:a.hp,hpDamage:r.hpDamage,debuffs:Array.from(r.addedDebuffs)}));
  a.refresh(); rows.push(rd(a,'after_refresh',e)); return {rows};
}));
// 4b. 加带 xparam 特性（22）的新状态：addState 内部 refresh 在 krz 标 dirty 之前，命中／回避等读到哪一刻才变
const xState=w.$dataStates.find(s=>s&&s.id>10&&!s.note&&s.traits.length>0&&s.traits.every(t=>t.code===22)&&!s.restriction);
cases.push(makeCase('xparam_state', {state:xState&&xState.id, traits:xState&&xState.traits}, ()=>{
  const {a,e}=battle(); const xs=t=>Array.from({length:10},(_,i)=>a.xparam(i));
  const rows=[{tag:'before',x:xs()}]; a.addState(xState.id); rows.push({tag:'after_addState',x:xs(),need:!!a.need_refresh});
  a.refresh(); rows.push({tag:'after_refresh',x:xs()}); return {rows};
}));
// 5. 敌人侧（重制已缓存敌人）：同 1
cases.push(makeCase('enemy_debuff_warm', {}, ()=>{
  const {a,e}=battle(); e.addState(plainState.id); e.refresh();
  const rows=[rd(e,'before',a)]; e.addDebuff(2,5); e.addDebuff(3,5); rows.push(rd(e,'after_debuff',a)); e.refresh(); rows.push(rd(e,'after_refresh',a)); return {rows};
}));
// 6. 战斗外：param 不缓存，但 paramRate 缓存不看 inBattle
cases.push(makeCase('outside_battle', {rateState:rateState&&rateState.id}, ()=>{
  const {a,e}=battle({inBattle:false}); const rows=[rd(a,'before')];
  a.addDebuff(2,5); rows.push(rd(a,'after_debuff'));
  if(rateState) { a.addState(rateState.id); rows.push(Object.assign(rd(a,'after_rate_state'),{paramRate2:a.paramRate(2),paramRate2_fresh:K.Game_Actor_paramRate.call(a,2)})); a.refresh(); rows.push(rd(a,'after_refresh')); }
  return {rows};
}));
process.exit(finish(host,'param_cache.json',{scope:'krz_state_re param cache vs addDebuff timing; actor 1 and enemy 1, in-memory',
  plainState:plainState&&plainState.id, rateState:rateState&&rateState.id, plainState2:plainState2&&plainState2.id, cases})?0:1);
