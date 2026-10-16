'use strict';
const {makeCase,round}=require('./host.cjs');
module.exports=function challenge(host){
  const {w,newGame,encode,restore}=host,cases=[];
  const PARTY=[1,8,9,10,11,12],SWITCH={3:null,4:2500,5:2494,6:2489};
  const skills=w.$dataSkills.filter(s=>s&&s.id>=2870&&s.id<=2900&&/挑战/.test(s.name)).map(s=>({id:s.id,name:s.name,note:s.note}));
  const ids=new Set(skills.map(s=>s.id));
  const visual=new Proxy(function(){},{get:(t,k)=>k==='_waitCount'?0:(()=>false),set:()=>true});
  function refresh(a){a.initPassiveCache();a.refreshPassiveCache();a.refresh();}
  function actor(a){return {id:a.actorId(),skills:a._skills.filter(id=>ids.has(id)),params:Array.from({length:8},(_,i)=>a.param(i)),xparams:Array.from({length:10},(_,i)=>round(a.xparam(i))),
    sparams:Array.from({length:10},(_,i)=>round(a.sparam(i))),states:a._states.slice(),mpCost1065:a.skillMpCost(w.$dataSkills[1065]),tpCost1065:a.skillTpCost(w.$dataSkills[1065])};}
  function gate(floor,cancel=false){
    w.$gameVariables.setValue(20,floor);w.$gameSwitches.setValue(686,false);w.$gameSelfSwitches.setValue([4,36,'A'],false);
    const ev=w.$gameMap.event(36);ev.refresh();const it=new w.Game_Interpreter();it.setup(ev.list(),36);const messages=[];
    let steps=0;
    while(it.isRunning()&&steps++<1000){
      it.update();const m=w.$gameMessage;
      if(m.isBusy()){
        const row={lines:m._texts.slice()};
        if(m.isChoice()){const choices=m.choices().slice(),pick=cancel?choices.length-1:Math.max(0,choices.findIndex(x=>x.includes('进入该层')));Object.assign(row,{choices,pick});m.onChoice(pick);}
        messages.push(row);m.clear();
      }
      // 本参照只测门的能力变化，场所移动登记后解除等待，不推进新地图自动事件。
      if(w.$gamePlayer.isTransferring())w.$gamePlayer.clearTransferInfo();
    }
    if(it.isRunning())throw new Error('门事件未结束');
    return {messages,skillCap:w.$gameVariables.value(8),actors:PARTY.map(id=>actor(w.$gameActors.actor(id)))};
  }
  for(const difficulty of [3,4,5,6])for(const floor of [6,11,16,21,26]){
    cases.push(makeCase(`challenge.f${floor}.d${difficulty}`,{floor,difficulty,switch:SWITCH[difficulty],party:PARTY,actor1Level:10,skillCapBefore:10},()=>{
      newGame();w.$gameSystem.setDifficultyId(difficulty);
      for(const sid of [2500,2494,2489,2487])w.$gameSwitches.setValue(sid,sid===SWITCH[difficulty]);
      w.eval('$gameParty._actors=[];'+JSON.stringify(PARTY)+'.forEach(function(id){$gameParty.addActor(id);});');
      w.$gameVariables.setValue(8,10);w.$gameActors.actor(1).changeLevel(10,false);
      PARTY.forEach(id=>refresh(w.$gameActors.actor(id)));
      const before=PARTY.map(id=>actor(w.$gameActors.actor(id))),first=gate(floor);PARTY.forEach(id=>refresh(w.$gameActors.actor(id)));
      const after=PARTY.map(id=>actor(w.$gameActors.actor(id))),second=gate(floor);PARTY.forEach(id=>refresh(w.$gameActors.actor(id)));
      const repeated=PARTY.map(id=>actor(w.$gameActors.actor(id)));
      // JsonEx只在内存往返，不调用StorageManager或任何真实存档。
      const json=encode();restore(json);PARTY.forEach(id=>refresh(w.$gameActors.actor(id)));
      const restored=PARTY.map(id=>actor(w.$gameActors.actor(id)));
      // 真正调用Scene_Battle.start链，让dsPassiveSkill的StartAEPushState生效；仅图形/音频等待给占位。
      w.Math.random=()=>0.99;w.BattleManager.setup(4,false,false);w.Math.random=()=>0.5;
      w.BattleManager._logWindow=visual;w.BattleManager._spriteset=visual;w.BattleManager._statusWindow=visual;
      const sc=Object.create(w.Scene_Battle.prototype);sc.startFadeIn=()=>{};sc._statusWindow=visual;sc._partyCommandWindow=visual;sc._logWindow=visual;sc._spriteset=visual;
      sc.start();
      const a=w.$gameActors.actor(1),enemy=w.$gameTroop.members()[0];
      const damage=[1,1065].map(sid=>{const action=new w.Game_Action(a);action.setSkill(sid);const rec=w.$dataSkills[sid],old=rec.damage.variance;rec.damage.variance=0;
        try{return {skill:sid,normal:round(action.makeDamageValue(enemy,false)),critical:round(action.makeDamageValue(enemy,true)),mpCost:a.skillMpCost(rec),tpCost:a.skillTpCost(rec)};}finally{rec.damage.variance=old;}});
      return {before,skillCap:first.skillCap,messages:first.messages,after,repeated,restored,
        repeatSkillCap:second.skillCap,battleMembers:w.$gameParty.battleMembers().map(a=>a.actorId()),
        battleActors:PARTY.map(id=>actor(w.$gameActors.actor(id))),enemy:{id:enemy.enemyId(),states:enemy._states.slice(),params:Array.from({length:8},(_,i)=>enemy.param(i)),hit:round(enemy.hit),cri:round(enemy.cri),cev:round(enemy.cev)},damage};
    }));
  }
  cases.push(makeCase('challenge.cancel',{floor:21,difficulty:4,skillCapBefore:10},()=>{
    newGame();w.$gameSwitches.setValue(2500,true);w.$gameVariables.setValue(8,10);const result=gate(21,true);return {skillCap:result.skillCap,actors:result.actors};
  }));
  for(const difficulty of [4,5,6])cases.push(makeCase('challenge.progression.d'+difficulty,{difficulty,floors:[6,11,16,21,26]},()=>{
    newGame();w.$gameSwitches.setValue(SWITCH[difficulty],true);w.$gameSystem.setDifficultyId(difficulty);w.$gameVariables.setValue(8,10);
    const trace=[];for(const floor of [6,11,16,21,26]){const result=gate(floor);const a=w.$gameActors.actor(1);refresh(a);trace.push({floor,skillCap:result.skillCap,actor:actor(a)});}
    return {trace};
  }));
  return {hostScope:'真实Map004 EV36有效页与完整指令；开局难度开关作为已知输入，不冒充重跑全部开局；全部角色学技由原脚本执行，记录6人含后备。JsonEx仅内存，战斗开始调用正式Scene_Battle.start链',skills,cases};
};
