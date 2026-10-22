'use strict';
// Frozen CodexDamageHooks: preserve every installed native handler. All fixtures
// are in memory; cache restoration is tested by identity, never by editing source.
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
newGame();
const J = x => JSON.parse(JSON.stringify(x));
const fields = ['mode','kind','skillMultiplier','flatSkill','normalAdd','criticalAdd','elementAdd','elementMultiplier',
  'finalAdd','finalMultiplier','growthMultiplier','settlementMultiplier','physicalDefenseRate','magicalDefenseRate',
  'physicalDamageMultiplier','magicalDamageMultiplier','flatMitigationRate','healingMultiplier','physicalIncomingPierce',
  'magicalIncomingPierce','resistancePierce','incomingMultiplier','elements','noElement','categoryMax'];
const frameSnap = f => Object.fromEntries(fields.filter(k => f[k] !== undefined).map(k => [k,J(f[k])]));
let trace = [], frame = null, draws = 0;
const hooks = w.CodexDamageHooks.map((h,i) => ({id:h.id||h.name, order:i, handlers:['split','enter','build'].filter(k=>h[k])}));
w.CodexDamageHooks = w.CodexDamageHooks.map((h,i) => {
  const out = Object.assign({},h), id = hooks[i].id;
  for(const phase of ['enter','build']) if(h[phase]) out[phase] = function(action,target,f) {
    trace.push([id,phase]); const result = h[phase].call(this,action,target,f); frame = frameSnap(f);
    if(phase==='enter' && result) return function(){trace.push([id,'cleanup']); return result();};
    return result;
  };
  return out;
});
function battler(actorId, target, setup) {
  const b = actorId ? new w.Game_Actor(actorId) : new w.Game_Enemy(setup.dragon?1999:1,0,0);
  const params = [1000000,1000,321,456,210,789,Number(setup.agi||100),100];
  b.param = i => params[i]; b.paramBase = i => params[i];
  b.traitObjects = () => []; b.criticalMultiplierBonus = () => 0; b.attackElements = () => [1];
  b.elementRate = e => setup.absorb && e===8 ? -.5 : setup.immune ? 0 : 1;
  b.elementAmplifyRate = () => 0; b.elementAmplifyNRate = () => 0; b.elementMagnifyRate = () => 1;
  b.iteratePassiveSkill = () => {}; b.skillMasteryLevel = () => 0;
  b._states = []; b._hp = 999999; b._mp = 1000; b._tp = 33; b._level=35; b._AdvancedNum=setup.advanced?1:0;
  b._skills = actorId===178 ? [10441].concat(setup.heart?[10443]:[],setup.advanced?[10444]:[]) : [];
  b.skills = () => b._skills.map(id=>w.$dataSkills[id]);
  b._passiveCache = {harmRe:{1:11,8:22}};
  if(actorId) {
    b._equips.forEach(e=>e.setObject(null));
    if(setup.sword) b._equips[0].setObject(w.$dataWeapons.find(e=>e && e.wtypeId===2));
  }
  b.xparam = () => 0; b.sparam = () => 1; b.isGuard = () => !!setup.guard;
  return b;
}
const cases = [makeCase('registry.native', {}, () => ({hooks}))];
for(const setup of [
  {id:'plain',actor:1,skill:1},
  {id:'cat.unarmed',actor:178,skill:10437},
  {id:'cat.sword',actor:178,skill:10437,sword:true},
  {id:'cat.heart',actor:178,skill:10438,sword:true,heart:true,critical:true},
  {id:'cat.advanced',actor:178,skill:10439,sword:true,heart:true,advanced:true},
  {id:'cat.echo',actor:178,skill:10445,sword:true,heart:true},
  {id:'cat.other',actor:178,skill:1,sword:true,heart:true},
  {id:'cat.absorb',actor:178,skill:10440,sword:true,heart:true,advanced:true,absorb:true},
  {id:'cat.immune',actor:178,skill:10437,sword:true,heart:true,immune:true},
  {id:'target.sword',actor:1,skill:1,target:178,sword:true,agi:537},
  {id:'target.sword.cap',actor:1,skill:1,target:178,sword:true,agi:100000},
  {id:'target.dragon',actor:1,skill:1,dragon:true},
  {id:'healing',actor:178,skill:10437,sword:true,heart:true,healing:true},
  {id:'live.variance',actor:178,skill:10437,sword:true,preview:false},
]) cases.push(makeCase(setup.id, setup, () => {
  const a = battler(setup.actor,false, setup.target ? {} : setup);
  const b = battler(setup.target||0,true,setup);
  const item = J(w.$dataSkills[setup.skill]);
  // Only neutralize formula/mastery/variance and fixtures' unrelated traits;
  // retain native skill identity so the actual cat-sword handler selects it.
  item.damage = {type:setup.healing?3:1,formula:'123457',elementId:setup.skill===10440?8:1,variance:0,critical:!!setup.critical};
  item.masteryDamage = null; item.meta={}; item.multipleElements=[];
  const action = new w.Game_Action(a); action.subject=()=>a; action.item=()=>item;
  const priorA=a._passiveCache, priorB=b._passiveCache, before=J([priorA,priorB]);
  const resources=[a.hp,a.mp,a.tp,b.hp,b.mp,b.tp]; trace=[];frame=null;draws=0;
  const oldRandom=w.Math.random;w.Math.random=()=>{draws++;return .5;};
  let res;
  try {res=w.CodexDamage.calculate(action,b,{reference:true,raw:setup.healing?-123457:123457,
    critical:!!setup.critical,preview:setup.preview!==false,isolated:true});}
  finally {w.Math.random=oldRandom;}
  return {frame,trace:J(trace),draws,resourcesBefore:resources,resourcesAfter:[a.hp,a.mp,a.tp,b.hp,b.mp,b.tp],
    cachesUnchanged:a._passiveCache===priorA&&b._passiveCache===priorB&&JSON.stringify(before)===JSON.stringify([a._passiveCache,b._passiveCache]),
    frameRestored:action._codexDamageFrame===undefined,value:res.value,kind:res.kind,breakdown:J(res.breakdown),
    item:{id:item.id,stypeId:item.stypeId,hitType:item.hitType,damage:item.damage},params:[321,456,210,789]};
}));
process.exit(finish(host,'module_hooks.json',{hostScope:'Frozen native registry; real Game_Action / fixed battler stats; native cat enter/build with finally cleanup',cases})?0:1);
