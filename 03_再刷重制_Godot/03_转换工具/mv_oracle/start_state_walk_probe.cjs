'use strict';
// 冻结原版：连打两场→走一步→第三场，开战标签状态（removeAtBattleEnd）与结果槽。真实接口，全内存新局，仅写.sandbox。
// Scene_Battle.start 需要窗口，无界面宿主跑不了；这里照 dsPassiveSkill 的 processStateTags 逐键解析，
// 只取本例用到的 StartPushState（自己）与 StartWTPushState（全体出战），addState 走真实包装链。
const {start,makeCase,finish}=require('./shared/host.cjs');
const host=start(),{w,newGame}=host;
const TAGS=['StartPushState','StartWTPushState'];
function battleStart(){
  const members=w.$gameParty.battleMembers();
  members.forEach(actor=>{
    actor.initPassiveCache();
    for(const prefix of TAGS)actor.equips().concat(actor.skills()).filter(Boolean).forEach(obj=>{
      for(const key in obj.meta||{}){
        if(!key.startsWith(prefix))continue;
        const stateId=Number(key.replace(prefix,'')),probability=parseFloat(String(obj.meta[key]).trim().replace('%',''));
        if(isNaN(probability)||!(Math.random()*100<probability))continue;
        (prefix==='StartWTPushState'?members:[actor]).forEach(a=>a.addState(stateId));
      }
    });
    actor._passiveCache.okadd=true;
  });
  members.forEach(a=>a.refreshPassiveCache());
}
function snap(tag,ids){return {tag,members:w.$gameParty.members().map(a=>({id:a.actorId(),has:ids.filter(i=>a.isStateAffected(i)),
  removed:Array.from(a._result.removedStates).filter(i=>ids.includes(i)).sort((x,y)=>x-y)}))};}
const GROUPS=[{id:'longwang',skills:{1:[1818]},ids:[113,114]},{id:'mixed',skills:{1:[2037],8:[5996,5451]},ids:[193,246,294]}];
// victory：processVictory 先 removeBattleStates，Scene_Battle.terminate 再 onBattleEnd（开头 clearResult）。
const ENDS={escape:()=>w.$gameParty.onBattleEnd(),victory:()=>{w.$gameParty.removeBattleStates();w.$gameParty.onBattleEnd();}};
const cases=[];
for(const end of ['escape','victory'])for(const plan of ['walk','chain'])for(const g of GROUPS)cases.push(makeCase(`${end}.${plan}.${g.id}`,{end,plan,group:g},()=>{
  newGame();w.$gameParty._actors=w.Array.from([1,8]);w.$gameParty._battleMembers=w.Array.from([1,8,0,0,0]);
  for(const id of [1,8]){const a=w.$gameActors.actor(id);a._level=37;(g.skills[id]||[]).forEach(s=>a.learnSkill(s));}
  const rows=[],ids=g.ids;
  const battle=n=>{w.$gameParty._inBattle=true;battleStart();rows.push(snap('battle'+n+'_start',ids));
    ENDS[end]();rows.push(snap('battle'+n+'_end',ids));};
  battle(1);battle(2);if(plan==='walk'){w.$gameParty.onPlayerWalk();rows.push(snap('walk',ids));}battle(3);
  return {rows,removeAtBattleEnd:ids.map(i=>w.$dataStates[i].removeAtBattleEnd)};
}));
process.exit(finish(host,'start_state_walk.json',{scope:'battle-start state tags across two battles, one map step, third battle',cases})?0:1);
