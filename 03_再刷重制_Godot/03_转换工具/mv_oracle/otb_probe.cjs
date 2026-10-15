'use strict';
// 正式版 OTB 顺序探针（夹具记录插件 SHA，xiyou_otb 对照当前来源）；新建内存队伍，写入只限 .sandbox/，不创建或读取存档。
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const {boot} = require('./hboot.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const w = boot(APP, {tolerant:true, log:false}).window;
w.eval(`ConfigManager.applyData({}); DataManager.setupNewGame();
$gameParty._actors = [1,8,9,10]; $gameParty._battleMembers = [1,8,9,10]; $gameParty._inBattle = true;
Math.random = function(){return 0.99;}; $gameTroop.setup(2); Math.random = function(){return 0.5;};
BattleManager._actionBattlers=[]; BattleManager._nextTurnActionBattlers=[];
BattleManager.otbDisplayWindow=function(){return {createReturnedBattlerSprite:function(){}};};`);
const bm = w.BattleManager, actors = w.$gameParty.members(), enemies = w.$gameTroop.members();
const members = actors.concat(enemies);
const key = b => b.isActor() ? 'a'+b.actorId() : 'e'+b.index();
const orders = () => ({current:Array.from(bm._actionBattlers,key), next:Array.from(bm._nextTurnActionBattlers,key)});
const rows = {};
for (let i=0;i<members.length;i++) {
  members[i].makeActions();
  members[i].makeSpeed = function(){this._speed=100-i*10;};
  members[i].makeActionTimes = () => 1;
}
bm.makeActionOrdersOTB(); rows.first=orders();
bm.otbNextTurnChange(actors[3],2,false); rows.shift_plus=orders();
bm.otbNextTurnChange(actors[0],-2,false); rows.shift_minus=orders();
bm._actionBattlers=[]; bm.makeActionOrdersOTB(); rows.carry=orders();
actors[0].makeActionTimes=()=>8;
bm._createdFirstTurnActionOrders=false; bm.makeActionOrdersOTB(); rows.cap=orders();
bm.otbNextTurnChange(actors[0],-2,false); rows.shift_repeats=orders();
actors[0].makeActionTimes=()=>1;
const stateId=w.$dataStates.length;
w.$dataStates.push(Object.assign({},w.$dataStates[4],{id:stateId,name:'OTB probe stun',restriction:4,autoRemovalTiming:2,minTurns:1,maxTurns:1,traits:[],note:'',meta:{}}));
actors[1].clearStates(); actors[1].addState(stateId); actors[1]._stateTurns[stateId]=1; actors[1]._freeStateTurn=new w.Array(); actors[1].refresh();
bm._createdFirstTurnActionOrders=false; bm.makeActionOrdersOTB(); rows.stun_one=orders();
actors[1]._stateTurns[stateId]=2; bm.otbClearActionOrdersOfUnableBattlers(); rows.stun_two=orders();
actors[1].removeState(stateId); actors[1].refresh(); actors[1]._otbTimesActedThisTurn=0; bm.otbInsertRevivalActionOrders(actors[1]); rows.wakeup=orders();
// 技能速度与标签效果单独对照（只调用顺序效果，不结算伤害）。
bm._createdFirstTurnActionOrders=false; bm.makeActionOrdersOTB();
const action = new w.Game_Action(actors[0]); action.setSkill(2); actors[0]._actions=w.Array.of(action); actors[0].otbTurnShift(); rows.guard=orders();
bm._createdFirstTurnActionOrders=false; bm.makeActionOrdersOTB();
const custom=Object.assign({},w.$dataSkills[1],{note:'<OTB Target Current Turn: +2>\n<OTB Target Next Turn: -1>'});
action.item=()=>custom; action.applyOTBEffect(actors[3]); rows.target=orders();
const source='js/plugins/Olivia_BattleSysOTB.js';
const out={source,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(APP,source))).digest('hex'),rows};
fs.writeFileSync(path.join(__dirname,'.sandbox','otb.json'),JSON.stringify(out,null,2));
console.log(JSON.stringify(out)); process.exit(0);
