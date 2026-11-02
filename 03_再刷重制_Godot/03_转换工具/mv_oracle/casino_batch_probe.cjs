'use strict';
// installCasinoBatchRuntime（CodexCasino）：大厅 Map004 EV60「自定义单抽／自定义20连抽」。真走 CodexCasino.open／begin／update／finish，
// 每抽整条跑 CE1432／1431 的副本（跳文字、选项选第 0 项、根解释器跳 212／230、静音 toaster）。Math.random 固定 0.5（host.newGame），用例带 random 的改成那个值。
// 弹窗是 DOM（jsdom），只读它的文字。产物 .sandbox/casino_batch.json，手工复制为 tests/fixtures/casino_batch_oracle.json。
const {start,makeCase,finish}=require('./shared/host.cjs');
const host=start(),{w,newGame}=host;
w.eval(`
ImageManager.isReady = function() { return true; };
Game_CharacterBase.prototype.isAnimationPlaying = function() { return false; };
Game_CharacterBase.prototype.isBalloonPlaying = function() { return false; };
`);
let toasts=[];
if(w.$)w.$.toaster=o=>toasts.push(String(o&&o.message||''));
w.SceneManager.isSceneChanging=()=>false;
const mapScene=Object.create(w.Scene_Map.prototype);
const C=()=>w.CodexCasino;
const specs=[
 {id:'single.five',mode:'single',tickets:7,points:0,count:5},
 {id:'single.max',mode:'single',tickets:3,points:0,count:'max'},
 {id:'single.threshold',mode:'single',tickets:5,points:-29990,count:5},
 {id:'single.below',mode:'single',tickets:5,points:-30001,count:2},
 {id:'single.closed',mode:'single',tickets:5,points:0,count:3,closeAfter:1},
 {id:'single.stop',mode:'single',tickets:5,points:0,count:4,stopAfter:2},
 {id:'single.cancel',mode:'single',tickets:5,points:0,count:0},
 {id:'single.none',mode:'single',tickets:0,points:0,count:1},
 {id:'twenty.two',mode:'twenty',tickets:45,points:0,count:2},
 {id:'twenty.short',mode:'twenty',tickets:19,points:0,count:1},
 {id:'twenty.proof',mode:'twenty',tickets:40,points:0,count:1,proofBefore:true},
 {id:'wrong.map',mode:'single',tickets:5,points:0,count:1,map:5},
 {id:'single.high',mode:'single',tickets:5,points:0,count:5,random:0.99}  // 沙僧二审 S2-1-02：0.99 时每抽都达标，考 CE1431／1432 的 if(actor) 学技能
];
const cases=specs.map(spec=>makeCase(spec.id,spec,()=>{
 newGame();toasts=[];w.$gameMessage.clear();
 if(spec.random!=null)w.eval('Math.random=function(){return '+spec.random+';}');
 if(spec.map){w.DataManager.loadMapData(spec.map);w.$gameMap.setup(spec.map);}
 w.$gameSwitches.setValue(2495,true);w.$gameVariables.setValue(206,spec.points);
 if(spec.tickets)w.$gameParty.gainItem(w.$dataItems[1639],spec.tickets);
 if(spec.proofBefore)w.$gameParty.members()[0].learnSkill(8101);
 w.SceneManager._scene=mapScene;
 const parent=new w.Game_Interpreter();parent.setup([{code:0,indent:0,parameters:[]}],60);
 const before={points:w.$gameVariables.value(206),tickets:w.$gameParty.numItems(w.$dataItems[1639]),max:C().maxCount(spec.mode)};
 const opened=C().open(parent,spec.mode);
 const s=C().session,dialog=s?{label:s.dom.querySelector('label').textContent,status:s.status.textContent,inputMax:s.input.max,title:s.dom.querySelector('h2').textContent,desc:s.dom.querySelector('p').textContent,wait:parent._waitMode}:null;
 let begun=null,frames=0;
 if(s){
  if(spec.count===0)s.cancel.click();
  else{
   if(spec.count==='max'){s.max.click();dialog.afterMax={value:s.input.value,status:s.status.textContent};}
   else{s.input.value=String(spec.count);s.input.dispatchEvent(new w.Event('input'));dialog.preview=s.status.textContent;}
   s.ok.click();begun=s.state;
   while(C().session&&frames<5000){
    frames++;C().update();
    if(spec.closeAfter&&s.used>=spec.closeAfter)w.$gameSwitches.setValue(2495,false);
    if(spec.stopAfter&&s.used>=spec.stopAfter&&!s.stop){s.cancel.click();dialog.stopping=s.cancel.textContent;}
   }
  }
 }
 const result=C().lastResult&&JSON.parse(JSON.stringify(C().lastResult));
 if(C().session){C().finish('探针结束');}
 const actors=w.$gameParty.members().map(a=>({id:a.actorId(),proof:a.isLearnedSkill(8101),loss:a.isLearnedSkill(8102),gift:a.isLearnedSkill(8091)}));
 return {before,opened,dialog,begun,frames,result:opened?result:null,messages:w.$gameMessage._texts.slice(),toasts,
  after:{points:w.$gameVariables.value(206),tickets:w.$gameParty.numItems(w.$dataItems[1639]),wait:parent._waitMode,actors,v1197:w.$gameVariables.value(1197),v1196:w.$gameVariables.value(1196)}};
}));
process.exit(finish(host,'casino_batch.json',{scope:'Native installCasinoBatchRuntime CodexCasino.open/begin/update/finish on Map004 parent interpreter (event 60); native CE1432/1431 copies stepped by C.update; DOM dialog via jsdom; Math.random 0.5.',cases})?0:1);
