'use strict';
// 跨存档变量（Drill_VariablesAcrossArchive＋Drill_CoreOfGlobalSave）：同一进程里改变量／开关、新开局、读档、公共事件 1322／1328，
// 记 $gameVariables／$gameSwitches 与全局存储的内存值。全局文件（游戏根目录 save/drill_global.rpgsave）由 SceneManager 帧刷新延迟写，
// 无画面引擎不跑帧刷新，所以不写盘（参照只量内存，重启后读回由 Godot 测试自证）。只写 .sandbox/global_vars.json。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded())throw new Error('参照引擎启动失败');
w.eval('ConfigManager.applyData({});Math.random=function(){return 0.5;};');
w.$dataMap={displayName:'',encounterList:[],events:[],data:[],width:1,height:1,note:'',meta:{}};  // makeSaveContents（YEP_SaveCore）要读地图名
const VARS=[899,900,901,1000,1476],SWS=[2280,2281];
const tank=()=>JSON.parse(JSON.stringify({s:w.DrillUp.global_GVa_switchTank,v:w.DrillUp.global_GVa_variableTank,
  file:(w.DrillUp.g_COGS_fileDataTank[w.DrillUp.g_GVa_saveFileId]||{}).GVa||null}));
// 稀疏数组 JSON 化后空位为 null；按 id 摘出有值的格
const defined=a=>{const o={};(a||[]).forEach((v,i)=>{if(v!==null&&v!==undefined)o[i]=v;});return o;};
const snap=label=>{const t=tank();return {label,variables:Object.fromEntries(VARS.map(id=>[id,w.$gameVariables._data[id]===undefined?null:w.$gameVariables._data[id]])),
  switches:Object.fromEntries(SWS.map(id=>[id,w.$gameSwitches._data[id]===undefined?null:w.$gameSwitches._data[id]])),
  tankVariables:defined(t.v),tankSwitches:defined(t.s),fileVariables:t.file?defined(t.file.global_variableTank):null,fileSwitches:t.file?defined(t.file.global_switchTank):null};};
const steps=[];
const params={fileId:w.DrillUp.g_GVa_saveFileId,switchIds:w.DrillUp.g_GVa_switch_id.map(Number),variableIds:w.DrillUp.g_GVa_variable_id.map(Number)};
w.DataManager.setupNewGame();
steps.push(snap('boot_new_game'));
// 1. 改值：900＝1、899＝2.7（_data 取整为 2，全局存原值）、901（不跨存档）、开关 2281 开、2280（不跨存档）开
w.$gameVariables.setValue(900,1);w.$gameVariables.setValue(899,2.7);w.$gameVariables.setValue(901,5);
w.$gameSwitches.setValue(2281,true);w.$gameSwitches.setValue(2280,true);
steps.push(snap('after_set'));
// 2. 新开局：900／899／2281 带过来，901／2280 不带
w.DataManager.setupNewGame();
steps.push(snap('new_game'));
// 3. 读旧档：档里 900＝5、899＝0、2281 关（直接写 _data，不经 setValue，相当于插件生效前的档），读档后被全局值盖掉
w.$gameVariables._data[900]=5;w.$gameVariables._data[899]=0;w.$gameSwitches._data[2281]=false;w.$gameVariables._data[1476]=3;
const contents=w.JsonEx.parse(w.JsonEx.stringify(w.DataManager.makeSaveContents()));
w.DataManager.createGameObjects();w.DataManager.extractSaveContents(contents);
steps.push(snap('load_save'));
// 4. 公共事件 1322（变量 900＝1 才学 6176）、1328（变量 899＝1 才学 6205；这里是 2.7，取不到）
function runCommon(id){const it=new w.Game_Interpreter();it.setup(w.$dataCommonEvents[id].list,0);let n=0;while(it.isRunning()&&n++<1000)it.update();}
const learned=()=>({6176:[1,2,3].map(a=>w.$gameActors.actor(a).isLearnedSkill(6176)),6205:[1,2,3].map(a=>w.$gameActors.actor(a).isLearnedSkill(6205))});
w.DataManager.setupNewGame();
runCommon(1322);runCommon(1328);
steps.push(Object.assign(snap('ce_after_new_game'),{learned:learned()}));
// 5. 899＝1 后新开局再跑 1328
w.$gameVariables.setValue(899,1);
w.DataManager.setupNewGame();runCommon(1328);
steps.push(Object.assign(snap('ce1328_after_set_1'),{learned:learned()}));
// 6. 设回 0：全局存 0（不是删掉），之后新开局也带 0
w.$gameVariables.setValue(900,0);w.$gameSwitches.setValue(2281,false);
w.DataManager.setupNewGame();
steps.push(snap('reset_zero_new_game'));
// 7. 运算指令（122 加法）也经 setValue
const it=new w.Game_Interpreter();it.setup([{code:122,indent:0,parameters:[1476,1476,1,0,4]},{code:0,indent:0,parameters:[]}],0);while(it.isRunning())it.update();
w.DataManager.setupNewGame();
steps.push(snap('operate_add_new_game'));
if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname,'.sandbox'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'.sandbox/global_vars.json'),JSON.stringify({sourceIdentity:identity,params,steps},null,1));
console.log(JSON.stringify({params,steps:steps.length,last:steps[steps.length-1]}));
process.exit(0);
