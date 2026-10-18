'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {start,makeCase,finish}=require('./shared/host.cjs');
const host=start(),w=host.w,cases=[];host.newGame();
const generated=process.env.XIYOU_GENERATED||path.resolve(__dirname,'../../01_Godot工程/modes/xiyou/generated');
const skills=JSON.parse(fs.readFileSync(path.join(generated,'db/Skills.json'),'utf8'));
const modes=['none','wrong_kind','zero','high','first','different_base','nonmagic'];
for(const sk of skills){
 if(!sk||!sk.damage.formulaProgram.capabilities.includes('read.equipment_instance_level'))continue;
 const source=w.$dataSkills[sk.id];
 const base=Number(source.damage.formula.match(/var\s+\w+\s*=\s*(\d+)/)[1]);
 for(const mode of modes)for(const edge of [false,true]){
  const armor=(baseItemId,level,magic=true)=>({kind:'armor',baseItemId,level,meta:magic?{'Magic Weapon':true}:{}});
  const equipment=mode==='none'?[]:mode==='wrong_kind'?[{...armor(base,40),kind:'weapon'}]:mode==='zero'?[armor(base,0)]:mode==='high'?[armor(base,40)]:mode==='first'?[armor(base,3),armor(base,99)]:mode==='different_base'?[armor(base+1,99),armor(base,5)]:[armor(base,22,false)];
  const variables={};for(const m of source.damage.formula.matchAll(/v\s*\[\s*(\d+)\s*\]/g))variables[m[1]]=edge?1000:0;
  const setup={skill:sk.id,mode,edge,equipment,variables,mastery:edge?7:0,params:[10000,1000,100,100,100,100,100,100]};
  cases.push(makeCase(`s${sk.id}.${mode}.${edge}`,setup,()=>{
   const a=w.$gameActors.actor(1),b=w.$gameActors.actor(8);
   const oldEquips=a.equips,oldMastery=a.skillMasteryLevel,oldA=a.param,oldB=b.param;
   const rows=new w.Array();
   for(let i=0;i<equipment.length;i++){
    const row=equipment[i],table=row.kind==='armor'?w.$dataArmors:w.$dataWeapons,id=60000+i;
    const template=row.kind==='armor'?w.$dataArmors[base]:w.$dataWeapons[1];
    const item={...template,id,baseItemId:row.baseItemId,meta:row.meta,level:row.level};
    delete item._isMagicWeaponCache;table[id]=item;rows.push(item);
   }
   a._hp=b._hp=10000;a._mp=b._mp=1000;a._tp=b._tp=55;
   a.equips=()=>rows;a.skillMasteryLevel=()=>setup.mastery;a.param=b.param=i=>setup.params[i];
   for(const [key,value]of Object.entries(variables))w.$gameVariables._data[Number(key)]=value;
   let draws=0;w.Math.random=()=>{draws++;return 0.5;};
   try{
    for(const item of rows)a.getEquipItemObject(item).level(); // prime native readonly caches
    const before=JSON.stringify([rows,a.hp,a.mp,a.tp,b.hp,b.mp,b.tp,variables]);
    const action=new w.Game_Action(a);action.setSkill(sk.id);const value=action.evalDamageFormula(b);
    if(before!==JSON.stringify([rows,a.hp,a.mp,a.tp,b.hp,b.mp,b.tp,variables]))throw Error('readonly fixture mutated');
    const levels=rows.filter(x=>w.DataManager.isArmor(x)&&x.baseItemId===base).map(x=>a.getEquipItemObject(x).level());
    return {value:Number.isFinite(value)?value:0,valueKind:Number.isNaN(value)?'nan':Number.isFinite(value)?'finite':'infinity',firstLevel:levels.length?levels[0]:0,randomDraws:draws,formulaSHA256:crypto.createHash('sha256').update(source.damage.formula).digest('hex')};
   }finally{a.equips=oldEquips;a.skillMasteryLevel=oldMastery;a.param=oldA;b.param=oldB;w.Math.random=()=>0.5;}
  }));
 }
}
process.exit(finish(host,'formula_equipment.json',{hostScope:'readonly-equipment-query',cases})?0:1);
