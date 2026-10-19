'use strict';
// Pure VM shadow migration: real frozen YEP evalDamageFormula, no game code replaced.
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const {start, makeCase, finish} = require('./shared/host.cjs');
const language = require('./shared/formula_language_cases.json');
const generated = process.env.XIYOU_GENERATED || path.resolve(__dirname, '../../01_Godot工程/modes/xiyou/generated');
const host = start(), w = host.w, cases = [], contexts = {};
host.newGame();
const props = 'hp mp tp mhp mmp atk def mat mdf agi luk level hit eva cri cev mev mrf cnt hrg mrg trg tgr grd rec pha mcr tcr pdr mdr fdr exr'.split(' ');
const measuredValue = value => ({value:Number.isFinite(value)?value:null,normalizedValue:Number.isFinite(value)?value:0,
  valueKind:Number.isNaN(value)?'nan':value===Infinity?'positive-infinity':value===-Infinity?'negative-infinity':'finite'});
function snapshot(b) {
  return {properties:Object.fromEntries(props.map(k=>[k,b[k]])),
    elements:Object.fromEntries(w.$dataSystem.elements.map((_,i)=>[String(i),b.elementRate(i)])),
    mastery:{}, stateIds:Array.from(b._states), states:b.states().map(s=>s.id),
    maxTp:b.maxTp(), actorId:b.isActor()?b.actorId():null,
    param:Array.from({length:8},(_,i)=>b.param(i)), xparam:Array.from({length:10},(_,i)=>b.xparam(i)),
    sparam:Array.from({length:10},(_,i)=>b.sparam(i))};
}
let a=w.$gameActors.actor(1), b=w.$gameActors.actor(8);
const tables = {};
for(const table of ['Skills','Items']) tables[table] = JSON.parse(fs.readFileSync(path.join(generated,'db',table+'.json'),'utf8'));
for(const pair of ['actors','enemy_actor','actor_enemy']) {
  if(pair!=='actors') {
    w.$gameTroop.setup(157);
    const enemy=w.$gameTroop.members()[0];
    a=pair==='enemy_actor'?enemy:w.$gameActors.actor(1);
    b=pair==='actor_enemy'?enemy:w.$gameActors.actor(8);
  }
for(const [suffix,resources] of [['full',[1,1,200]],['edge',[0.2,0,1]]]) {
  const label=pair==='actors'?suffix:pair+'.'+suffix;
  a._hp=a.mhp; a._mp=a.mmp; a._tp=55;
  b._hp=Math.floor(b.mhp*resources[0]); b._mp=Math.floor(b.mmp*resources[1]); b._tp=resources[2];
  w.Math.random=()=>0.5;
  const sparse = data => Object.fromEntries(Object.keys(data).filter(k=>data[k]!==undefined).map(k=>[k,data[k]]));
  contexts[label]={a:snapshot(a),b:snapshot(b),v:sparse(w.$gameVariables._data),s:sparse(w.$gameSwitches._data)};
  const seen = new Set();
  for(const [table,rows] of Object.entries(tables)) for(const row of rows) {
    if(!row || !row.damage.type || row.damage.formulaProgram.status!=='pure' || row.damage.formulaProgram.capabilities.includes('read.equipment_instance_level')) continue;
    const p=row.damage.formulaProgram, source=(table==='Skills'?w.$dataSkills:w.$dataItems)[row.id];
    const key=JSON.stringify([source.damage.formula,source.damage.custom,source.damage.type,/item\s*\.\s*id/.test(source.damage.formula)?row.id:0]);
    if(seen.has(key)) continue; seen.add(key);
    const setup={table,id:row.id,context:label};
    cases.push(makeCase(`${table}.${row.id}.${label}`,setup,()=>{
      if(crypto.createHash('sha256').update(source.damage.formula).digest('hex')!==p.source.sha256) throw Error('effective source mismatch');
      if(a.skillMasteryLevel(row.id)!==0 || b.skillMasteryLevel(row.id)!==0) throw Error('nonzero mastery requires explicit snapshot');
      const action=new w.Game_Action(a); if(table==='Skills')action.setSkill(row.id);else action.setItem(row.id);
      const before=[a.hp,a.mp,a.tp,b.hp,b.mp,b.tp];
      const value=action.evalDamageFormula(b);
      if(JSON.stringify(before)!==JSON.stringify([a.hp,a.mp,a.tp,b.hp,b.mp,b.tp])) throw Error('claimed pure formula wrote resources');
      return {...measuredValue(value),formulaSHA256:p.source.sha256};
    }));
  }
}
}
a=w.$gameActors.actor(1);b=w.$gameActors.actor(8);
for(const fixture of language) {
  const setup={context:'edge',program:fixture.program,formula:fixture.formula,type:fixture.type};
  cases.push(makeCase('language.'+fixture.id,setup,()=>{
    const source={...w.$dataSkills[1],damage:{...w.$dataSkills[1].damage,formula:fixture.formula,custom:fixture.custom,type:fixture.type}};
    const action=new w.Game_Action(a);action.setSkill(1);action.item=()=>source;
    let draws=0;w.Math.random=()=>{draws++;return 0.5;};
    const value=action.evalDamageFormula(b);w.Math.random=()=>0.5;
    return {...measuredValue(value),randomDraws:draws};
  }));
}
process.exit(finish(host,'formula_programs.json',{hostScope:'pure-formula-shadow',contexts,cases})?0:1);
