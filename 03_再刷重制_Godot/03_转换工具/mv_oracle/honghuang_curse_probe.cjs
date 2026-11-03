'use strict';
// 洪荒诅咒自选（公共事件 1442「洪荒技能抽奖·诅咒」，大厅 Map004 EV41 第 3／5 页开洪荒难度时调）：
// 原版没有随机数——15 种全列，连问 5 次（每次去掉已选的，不可取消），选完写变量 1468～1472，再按变量给所有有名字的角色 learnSkill(7200+N)。
// 用例按 picks 依次应答每个选项窗（序号），记文字、选项、取消类型、变量、开关、各角色学到的诅咒技能与 CodexHonghuang.curseBonus。
// 产物 .sandbox/honghuang_curse.json，手工复制为 tests/fixtures/honghuang_curse_oracle.json（tests/xiyou_honghuang_curse 对照）。
const {start,makeCase,finish,round}=require('./shared/host.cjs');
const host=start(),{w,newGame}=host;
w.eval(`
ImageManager.isReady = function() { return true; };
Game_CharacterBase.prototype.isAnimationPlaying = function() { return false; };
Game_CharacterBase.prototype.isBalloonPlaying = function() { return false; };
`);
if(w.$)w.$.toaster=()=>{};
w.SceneManager.isSceneChanging=()=>false;
w.SceneManager._scene=Object.create(w.Scene_Map.prototype);
const CURSES=[];for(let i=7201;i<=7215;i++)CURSES.push(i);
const SAMPLE=[1,8,9,10,2,50];   // 队伍四人＋两个不在队的
const VARS=[9,20,1468,1469,1470,1471,1472,1482],SWITCHES=[2461,2462,2463,2483];

function run(list,picks,eventId){
 const it=new w.Game_Interpreter();it.setup(w.JsonEx.makeDeepCopy(list),eventId||0);
 const messages=[];let at=0,frames=0;
 for(;frames<20000&&it.isRunning();frames++){
  w.Graphics.frameCount++;it.update();
  const m=w.$gameMessage;if(!m.isBusy())continue;
  const e={face:m.faceName(),index:m.faceIndex(),lines:m._texts.slice()};
  if(m.isChoice()){
   const pick=at<picks.length?picks[at++]:0;
   Object.assign(e,{choices:m.choices().slice(),cancel:m.choiceCancelType(),default:m.choiceDefaultType(),pick});
   messages.push(e);m.onChoice(pick);
  }else if(m.hasText())messages.push(e);
  m.clear();
 }
 return {messages,frames,finished:!it.isRunning(),usedPicks:at};
}
function learned(id){const a=w.$gameActors.actor(id);return CURSES.filter(s=>a.isLearnedSkill(s));}
function observe(r){
 const named=[];for(let j=1;j<w.$dataActors.length;j++)if(w.$dataActors[j]&&w.$dataActors[j].name!=='')named.push(j);
 const learners={};CURSES.forEach(s=>{const n=named.filter(j=>w.$gameActors._data[j]&&w.$gameActors._data[j].isLearnedSkill(s)).length;if(n)learners[s]=n;});
 const vars={},sw={};VARS.forEach(v=>vars[v]=w.$gameVariables.value(v));SWITCHES.forEach(s=>sw[s]=w.$gameSwitches.value(s));
 const actors={};SAMPLE.forEach(id=>actors[id]=learned(id));
 return {...r,vars,switches:sw,actors,learners,namedActors:named.length,
  tempLeft:w.$gameTemp._hhCurseOffer!==undefined||w.$gameTemp._hhCursePicked!==undefined,
  curseBonus:round(w.CodexHonghuang.curseBonus(w.$gameParty.members()[0]))};
}
const CE=()=>w.$dataCommonEvents[1442].list;
const EV41=page=>w.$dataMap.events[41].pages[page].list;
const specs=[
 {id:'ce.first',v1482:1,runs:[[0,0,0,0,0]]},
 {id:'ce.last',v1482:1,runs:[[14,13,12,11,10]]},
 {id:'ce.mix',v1482:1,runs:[[6,2,0,9,3]]},
 {id:'ce.heavy',v1482:1,runs:[[0,0,9,9,9]]},          // 1、2、12、13、14：五个重
 {id:'ce.gate0',v1482:0,runs:[[0,0,0,0,0]]},           // 变量 1482 不是 1：整段不跑
 {id:'ce.gate2',v1482:2,runs:[[0,0,0,0,0]]},
 {id:'ce.repeat',v1482:1,runs:[[0,0,0,0,0],[14,13,12,11,10]]},  // 再进一次：已学的不忘，变量换成第二次的
 {id:'ce.preset',v1482:1,pre:{8:[7203]},runs:[[2,0,0,0,0]]},     // 已会 7203 的角色再学不重复
 {id:'ev41.p3.yes',map:{page:3,v20:13},runs:[[1,0,4,4,4,4,4]]},  // 离开→是→五次第 5 项
 {id:'ev41.p3.no',map:{page:3,v20:13},runs:[[1,1]]},
 {id:'ev41.p5.yes',map:{page:5,v20:13},runs:[[1,0,1,1,1,1,1]]},
 {id:'ev41.p3.done',map:{page:3,v20:13,on2483:true},runs:[[1]]}  // 已开洪荒（开关 2483）：不再问
];
const cases=specs.map(spec=>makeCase(spec.id,spec,()=>{
 newGame();w.$gameMessage.clear();
 if(spec.pre)Object.keys(spec.pre).forEach(id=>spec.pre[id].forEach(s=>w.$gameActors.actor(+id).learnSkill(s)));
 const runs=[];
 if(spec.map){
  w.$gameVariables.setValue(20,spec.map.v20);w.$gameSwitches.setValue(2489,true);
  if(spec.map.on2483)w.$gameSwitches.setValue(2483,true);
  spec.runs.forEach(p=>runs.push(run(EV41(spec.map.page),p,41)));
 }else{
  spec.runs.forEach(p=>{w.$gameVariables.setValue(1482,spec.v1482);runs.push(run(CE(),p,0));});
 }
 return observe({runs});
}));
process.exit(finish(host,'honghuang_curse.json',{scope:'Native CE1442 (and Map004 EV41 pages 3/5) run in a root Game_Interpreter; choices answered by picks in order; no RNG in CE1442.',cases})?0:1);
