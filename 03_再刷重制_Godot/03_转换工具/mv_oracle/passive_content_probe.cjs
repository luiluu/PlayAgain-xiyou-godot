'use strict';
// 书籍与科技静态能力链；冻结插件，全内存。条件低血/低蓝与learn/relearn/forget，写入仅.sandbox。
const {start,makeCase,finish}=require('./shared/host.cjs');
const host=start(),{w,newGame}=host;newGame();w.$gameParty._targetActorId=1;w.$gameVariables.setValue(9,999);
const a=w.$gameActors.actor(1);a._level=37;a._equips.forEach((_,i)=>a.changeEquip(i,null));a._states=new w.Array();a._paramPlus=w.Array.from([0,0,0,0,0,0,0,0]);
const damageSkills=[1,125,275];
function refresh(){a.refreshPassiveSkillCache();a.initPassiveCache();a.refreshPassiveCache();a.refresh();}
function reset(){Array.from(a._skills).forEach(id=>a.forgetSkill(id));a._states=new w.Array();a._hp=1e9;a._mp=1e9;refresh();a.recoverAll();a.clearResult();}
function snap(){
  const damage=[];const e=new w.Game_Enemy(1,0,0);e.refresh();
  for(const sid of damageSkills)for(const critical of [false,true]){
    const item=w.JsonEx.makeDeepCopy(w.$dataSkills[sid]);item.damage.variance=0;
    const action=new w.Game_Action(a);action.setSkill(sid);action.item=()=>item;
    damage.push(action.makeDamageValue(e,critical));
  }
  return {base:Array.from({length:8},(_,i)=>a.paramBase(i)),param:Array.from({length:8},(_,i)=>a.param(i)),
    xparam:Array.from({length:10},(_,i)=>a.xparam(i)),sparam:Array.from({length:10},(_,i)=>a.sparam(i)),
    elements:Array.from({length:15},(_,i)=>w.CodexElements.bonus(a,i+1)),maxTp:a.maxTp(),preserveTp:a.isPreserveTp(),
    actionPlus:Array.from(a.actionPlusSet()),weapons:Array.from({length:12},(_,i)=>a.isEquipWtypeOk(i+1)),
    armors:Array.from({length:3},(_,i)=>a.isEquipAtypeOk(i+1)),damage};
}
const books=[];
for(const item of w.$dataItems)if(item)for(const effect of item.effects||[]){
  const skill=effect.code===43&&w.$dataSkills[effect.dataId];
  if(skill&&/<(?:passive|SkEType)/i.test(skill.note||''))books.push({item:item.id,skill:skill.id});
}
const tech=w.$dataSkills.slice(4555,4653).filter(s=>s&&/科技:/.test(s.name)).map(s=>({skill:s.id}));
const cases=[];reset();const baseline=snap();
for(const setup of books.concat(tech))cases.push(makeCase((setup.item?'book.':'tech.')+(setup.item||setup.skill),setup,()=>{
  reset();
  if(setup.item){const action=new w.Game_Action(a);action.setItem(setup.item);action.apply(a);}
  else a.learnSkill(setup.skill);
  refresh();a.recoverAll();const learned=a.isLearnedSkill(setup.skill),full=snap();
  a.learnSkill(setup.skill);refresh();const repeat=snap();
  a._hp=Math.floor(a.mhp*.25);a._mp=Math.floor(a.mmp*.25);refresh();const low=snap();
  a.forgetSkill(setup.skill);refresh();a.recoverAll();const forgot=snap();
  return {learned,full,repeat,low,forgot};
}));
const target=new w.Game_Enemy(1,0,0);
process.exit(finish(host,'passive_content.json',{scope:'actor1 level37,empty equips,253 passive book effect43 plus90 technologies; static facade and3 damage skills; no dynamic boss armor',difficulty:w.$gameSystem.difficultyId(),target:{enemy:1,level:target.level,param:Array.from({length:8},(_,i)=>target.param(i))},damageSkills,baseline,cases})?0:1);
