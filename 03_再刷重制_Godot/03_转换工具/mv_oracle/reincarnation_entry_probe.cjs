'use strict';
// installReincarnationRandomRuntime 的轮回入口（CodexReincarnationRandom.open／entryAccepted／entryHard／finishEntry）：
// Map221 引路人事件（事件 3 第 0 页）「轮回归来！」那段（指令 66～135）真实跑一遍。open 会 push Scene_ReincarnationDraft 并让事件等待（waitMode codexRandomDraft），
// 这里真创建那个场景（给它一层 WindowLayer），按用例调它菜单的处理函数（normal／hard／classic／back），再让事件接着跑：
// 111 的两个条件分支各走哪边、打投影（command301 在这里只记敌群、当作胜利）、开关与技能、finishEntry 之后的状态。
// 只读正式引擎；文字全部清掉并记下；Math.random 固定 0.5（host.newGame）。产物 .sandbox/reincarnation_entry.json，手工复制为 tests/fixtures/reincarnation_entry_oracle.json。
const {start,makeCase,finish}=require('./shared/host.cjs');
const host=start(),{w,newGame}=host;
w.eval(`
ImageManager.isReady = function() { return true; };
Game_CharacterBase.prototype.isAnimationPlaying = function() { return false; };
Game_CharacterBase.prototype.isBalloonPlaying = function() { return false; };
`);
const R=()=>w.CodexReincarnationRandom;
let toasts=[],texts=[],pushed=[],battles=[];
if(w.$)w.$.toaster=o=>toasts.push(String(o&&o.message||''));
w.SceneManager.push=function(c){pushed.push(c.name||'?');};
w.Game_Interpreter.prototype.command301=function(){
  battles.push({troop:this._params[0]===0?this._params[1]:'var',canEscape:this._params[2],canLose:this._params[3]});
  this._branch[this._indent]=0;  // 当作胜利：601（胜利）分支执行
  return true;
};
const SWITCHES=[2282,2303,2307,2494,2496,2500,2489];
const SKILLS=[8105,2872,2878,5561,2891];
function snap(){
  const d=w.$gameSystem._codexReincarnationRandom;
  return {
    switches:SWITCHES.map(i=>[i,w.$gameSwitches.value(i)]),
    party:w.$gameParty._actors.slice(),gold:w.$gameParty.gold(),
    item4:w.$gameParty.numItems(w.$dataItems[4]),item2896:w.$gameParty.numItems(w.$dataItems[2896]),
    knowers:SKILLS.map(id=>[id,w.$gameActors._data.filter(a=>a&&a.isLearnedSkill(id)).length]),
    entry:R().entry?JSON.parse(JSON.stringify(R().entry)):null,
    entryAccepted:R().entryAccepted(),entryHard:R().entryHard(),
    store:d?{status:d.status,entryPending:!!d.entryPending,hard:!!d.hard}:null,
    transfer:w.$gamePlayer.isTransferring()?[w.$gamePlayer._newMapId,w.$gamePlayer._newX,w.$gamePlayer._newY]:null
  };
}
const list0=(()=>{w.DataManager.loadMapData(221);return null;})();
const specs=[
 {id:'normal.classic',steps:['normal','classic']},
 {id:'hard.classic',steps:['hard','classic']},
 {id:'top.back',steps:['back']},
 {id:'normal.back.then.classic',steps:['normal','back','normal','classic']},
 {id:'hard.back.then.hard.classic',steps:['hard','back','hard','classic']},
 {id:'already.2307',steps:[],pre:{switches:{2307:true}}},
 {id:'already.2303',steps:[],pre:{switches:{2303:true}}},
 {id:'pending.active',steps:[],pre:{store:{status:'active',entryPending:true,hard:true}}}
];
const cases=specs.map(spec=>makeCase(spec.id,spec,()=>{
 newGame();toasts=[];texts=[];pushed=[];battles=[];w.$gameMessage.clear();
 w.DataManager.loadMapData(221);w.$gameMap.setup(221);w.$gamePlayer.clearTransferInfo();
 for(const [k,v] of Object.entries((spec.pre&&spec.pre.switches)||{}))w.$gameSwitches.setValue(Number(k),v);
 if(spec.pre&&spec.pre.store)w.$gameSystem._codexReincarnationRandom=Object.assign({version:1,seed:1,used:0,branches:{},selected:[]},spec.pre.store);
 delete R().entry;
 const page=w.$dataMap.events[3].pages[0].list;
 // 指令 66 起到 135（分支结束）：open、111 entryAccepted…finishEntry、412
 const list=page.slice(66,137);
 const it=new w.Game_Interpreter();it.setup(list,3);
 const trace=[],states={};
 const origExec=w.Game_Interpreter.prototype.executeCommand;
 w.Game_Interpreter.prototype.executeCommand=function(){
  if(this===it){const c=this.currentCommand();if(c)trace.push(this._index+66);}
  return origExec.apply(this,arguments);
 };
 states.before=snap();
 let scene=null,sceneLog=[],frames=0,stage=0;
 const stepsLeft=spec.steps.slice();
 const origCmd301=null;
 try{
  while(it.isRunning()&&frames<3000){
   frames++;
   if(w.$gameMessage.hasText()||w.$gameMessage.isChoice&&w.$gameMessage.isChoice()){texts.push((w.$gameMessage._texts||[]).join('\n'));w.$gameMessage.clear();}
   if(it._waitMode==='transfer'){states.transfer=snap().transfer;w.$gamePlayer.clearTransferInfo();it._waitMode='';}
   if(it._waitMode==='codexRandomDraft'&&!scene&&pushed.length){
     scene=new w.Scene_ReincarnationDraft();scene.popScene=function(){sceneLog.push('pop');if(R().entry&&R().entry.phase!=='closed')sceneLog.push('pop-with-phase-'+R().entry.phase);};
     w.SceneManager._scene=scene;scene.createWindowLayer();scene.create();
     sceneLog.push({phase:scene.phase,menu:scene.menu._list.map(x=>x.symbol),help:scene.help._text});
     states.afterOpen=snap();
   }
   if(scene&&stepsLeft.length&&it._waitMode==='codexRandomDraft'){
     const k=stepsLeft.shift();
     scene.menu.callHandler(k);
     sceneLog.push({step:k,phase:scene.phase,hard:scene.hard,menu:scene.menu._list.map(x=>x.symbol),help:scene.help._text,entry:R().entry&&JSON.parse(JSON.stringify(R().entry))});
     if(!stepsLeft.length)states.afterScene=snap();
     continue;
   }
   if(scene&&!stepsLeft.length&&R().entry&&R().entry.phase!=='closed'&&it._waitMode==='codexRandomDraft'){
     // 用例没关掉界面（不应发生）
     sceneLog.push('stuck');break;
   }
   if(it._waitMode==='codexRandomDraft'&&!scene&&!pushed.length){sceneLog.push('wait-without-scene');break;}
   it.update();
   if(battles.length===1&&!states.atBattle){states.atBattle=snap();}
  }
 }finally{w.Game_Interpreter.prototype.executeCommand=origExec;}
 if(w.$gameMessage.hasText()){texts.push((w.$gameMessage._texts||[]).join('\n'));w.$gameMessage.clear();}
 return {pushed,sceneLog,trace,battles,texts,toasts,frames,running:it.isRunning(),states,after:snap()};
}));
process.exit(finish(host,'reincarnation_entry.json',{scope:'Native CodexReincarnationRandom.open/entryAccepted/entryHard/finishEntry via Map221 EV3 page0 commands 66..136, Scene_ReincarnationDraft menu handlers driven headless; command301 stubbed as victory; Math.random 0.5.',cases})?0:1);
