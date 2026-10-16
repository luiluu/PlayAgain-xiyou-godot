'use strict';
const {makeCase}=require('./host.cjs');
module.exports=function messages(host){
  const {w,newGame}=host,cases=[],definitions=[];
  const snapshot=()=>({face:w.$gameMessage.faceName(),faceIndex:w.$gameMessage.faceIndex(),background:w.$gameMessage.background(),position:w.$gameMessage.positionType(),lines:Array.from(w.$gameMessage._texts)});
  for(const tid of [456,457,458]){
    const page=w.$dataTroops[tid].pages[2];definitions.push({troop:tid,page:2,conditions:page.conditions,span:page.span,list:page.list});
    for(const variant of ['above-threshold','exact-threshold','below-threshold','variable-off','late-variable']){
      cases.push(makeCase(`message.${tid}.${variant}`,{troop:tid,page:2,variable853:variant.includes('variable')?0:1,hpRate:variant==='above-threshold'?0.21:variant==='exact-threshold'?0.2:0.19},()=>{
        newGame();w.$gameParty._inBattle=true;w.Math.random=()=>0.99;w.BattleManager.setup(tid,false,false);w.Math.random=()=>0.5;
        w.BattleManager._action=null;
        const tr=w.$gameTroop,enemy=tr.members()[0];enemy.setHp(Math.floor(enemy.mhp*(variant==='above-threshold'?0.21:variant==='exact-threshold'?0.2:0.19)));
        w.$gameVariables.setValue(853,variant.includes('variable')?0:1);
        // 本夹具只验第三页；此前开场/回合页已有独立troop_events参照，不在这里重放。
        tr._eventFlags[0]=tr._eventFlags[1]=true;
        const forced=[],original=w.BattleManager.forceAction;
        w.BattleManager._actionForcedBattler=null;
        w.BattleManager.forceAction=function(b){const a=b.currentAction();forced.push({subject:b.isActor()?'a'+b.actorId():'e'+b.index(),skill:a.item().id,target:a._targetIndex});return original.call(this,b);};
        try{
          const conditionBefore=tr.meetsConditions(page);
          tr.setupBattleEvent();const it=tr._interpreter;it.update();
          const displayed=w.$gameMessage.isBusy()?snapshot():null,index=it._index,flagsBefore=Object.assign({},tr._eventFlags),hpBefore=enemy.hp;
          for(let i=0;i<5;i++)it.update();
          const waiting={busy:w.$gameMessage.isBusy(),running:it.isRunning(),indexStable:it._index===index,forcedCount:forced.length,hpStable:enemy.hp===hpBefore,hasChild:!!it._childInterpreter};
          w.$gameMessage.clear();
          let steps=0;
          while(it.isRunning()&&steps++<300){
            // 渲染/行动完成宿主：记录真实339排队后解除action等待；本参照不执行伤害或声称覆盖专属技能效果。
            if(w.BattleManager._actionForcedBattler){w.BattleManager._actionForcedBattler.clearActions();w.BattleManager._actionForcedBattler=null;}
            it.update();if(w.$gameMessage.isBusy())throw new Error('出现未预期的额外消息');
          }
          const after={finished:!it.isRunning(),forced:forced.slice(),states:enemy._states.slice(),eventFlags:Object.assign({},tr._eventFlags)};
          if(variant==='late-variable')w.$gameVariables.setValue(853,1);
          for(let i=0;i<5;i++){tr.setupBattleEvent();it.update();}
          return {conditionBefore,conditionAfter:tr.meetsConditions(page),displayed,flagsBefore,waiting,after,repeated:{messageBusy:w.$gameMessage.isBusy(),forcedCount:forced.length,finished:!it.isRunning()}};
        }finally{w.BattleManager.forceAction=original;w.BattleManager._actionForcedBattler=null;w.$gameMessage.clear();}
      }));
    }
  }
  // 明确标成解释器契约夹具，CE内容仅存内存，不假称是游戏数据里的真实剧情。
  cases.push(makeCase('message.contract-nested-common',{kind:'engine-contract',syntheticCommon:9001,variable:4900},()=>{
    newGame();const saved=w.$dataCommonEvents[9001];
    const c=(code,parameters,indent=0)=>({code,parameters,indent});
    w.$dataCommonEvents[9001]={id:9001,name:'oracle-memory-only',list:[c(122,[4900,4900,1,0,1]),c(101,['',0,0,2]),c(401,['nested A']),c(401,['nested B']),c(122,[4900,4900,1,0,10]),c(0,[])]};
    try{
      const it=new w.Game_Interpreter();it.setup([c(117,[9001]),c(122,[4900,4900,1,0,100]),c(0,[])]);it.update();
      const before={message:snapshot(),variable:w.$gameVariables.value(4900),parentIndex:it._index,childIndex:it._childInterpreter._index};
      for(let i=0;i<5;i++)it.update();const held=w.$gameVariables.value(4900);w.$gameMessage.clear();
      for(let i=0;i<5;i++)it.update();return {before,held,after:w.$gameVariables.value(4900),finished:!it.isRunning()};
    }finally{if(saved===undefined)delete w.$dataCommonEvents[9001];else w.$dataCommonEvents[9001]=saved;}
  }));
  return {hostScope:'正式Game_Troop页条件与Game_Interpreter 101/401/117/339；第三页隔离；339只记录真实排队，宿主解除action等待，未执行专属技能伤害',definitions,cases};
};
