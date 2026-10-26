'use strict';
// 开战公共事件 1320「战斗开始时调整变量」严格级参照（八戒_71 期五）：本版改过的 BattleManager.startBattle 先 reserveCommonEvent(1320)，
// 开战第一次 updateEventMain 由敌群解释器跑完（调 1315 特殊物品数量、1372 见钱眼开、1373 血脉数量统计、1375 半人马上阵统计，
// 变量 13＝1 时把一串变量截到上限）。真实 BattleManager，逐帧推进到第一次输入；记相关变量与角色 79 的状态。
// 不加载玩家存档；渲染占位；唯一产物 .sandbox/battle_start_event.json，抄进 tests/fixtures/battle_start_event_oracle.json。
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const {boot} = require('./hboot.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const r = boot(APP, {tolerant: true, log: false}), w = r.window;
if (!w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败');
const stub = new Proxy(function () {}, {get: (_, k) => k === '_waitCount' ? 0 : (() => false), set: () => true});
const sprites = new Map();
w.BattleManager.actionBattleHud = () => true;
w.BattleManager.otbDisplayWindow = () => stub;
w.Game_Battler.prototype.battler = function () {
  if (!sprites.has(this)) sprites.set(this, new Proxy({x: 0, y: 0, _homeX: 0, _homeY: 0, width: 64, height: 64,
    scale: {x: 1, y: 1}, anchor: {x: 0.5, y: 1}, opacity: 255},
  {get: (t, k) => k in t ? t[k] : (() => false), set: (t, k, v) => {t[k] = v; return true;}}));
  return sprites.get(this);
};
if (!w.$) w.$ = {};
w.$.toaster = () => {};
// 1320 及子事件读写的变量
const VARS = [13, 206, 361, 362, 364, 370, 371, 374, 375, 376, 378, 379, 380, 399, 522, 523, 524, 525, 526, 541, 542, 543, 544, 545, 546,
  547, 548, 885, 1474, 1552, 1553, 1554, 1555, 1556];

function run(party, prep) {
  w.eval('ConfigManager.applyData({});DataManager.setupNewGame();$gameSystem.setDifficultyId(3);for(var i=1;i<5000;i++)if($gameVariables._data[i]===undefined)$gameVariables._data[i]=0;');
  w.eval('$gameParty._actors=[];' + JSON.stringify(party) + '.forEach(function(id){$gameParty.addActor(id);});');
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  if (prep) prep();
  w.Math.random = () => 0.99;
  const bm = w.BattleManager; bm.setup(2, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.Math.random = () => 0.5;
  const ran = [];
  const setupCE = w.Game_Interpreter.prototype.setupReservedCommonEvent;
  w.Game_Interpreter.prototype.setupReservedCommonEvent = function () {
    const id = w.$gameTemp._commonEventId, ok = setupCE.apply(this, arguments);
    if (ok) ran.push(id);
    return ok;
  };
  try {
    bm.startBattle();
    for (let tick = 0; tick < 5000 && bm._phase !== 'input'; tick++) {
      if (w.$gameMessage.isBusy()) { w.$gameMessage.clear(); continue; }
      bm.update();
    }
  } finally { w.Game_Interpreter.prototype.setupReservedCommonEvent = setupCE; }
  const vars = {};
  VARS.forEach(v => { vars[v] = w.$gameVariables.value(v); });
  const a79 = w.$gameActors.actor(79);
  return {ran, phase: bm._phase, vars, actor79States: a79 ? a79._states.slice().sort((x, y) => x - y) : null,
    battleMembers: w.$gameParty.battleMembers().map(a => a.actorId())};
}

const cases = [];
function caseRun(id, setup, party, prep) {
  const c = {id, setup, errors: [], observed: null};
  try { c.observed = run(party, prep); } catch (e) { c.errors.push(String(e.stack || e).slice(0, 1500)); }
  cases.push(c);
}
caseRun('plain', {party: [1, 8, 9, 10]}, [1, 8, 9, 10]);
// 变量 13＝1：一串变量截到上限（364≤120、361≤20000…、1552～1556≤500）
caseRun('caps', {party: [1, 8, 9, 10], vars: {13: 1, 361: 50000, 364: 999, 370: 20000, 374: 30, 1552: 501, 1556: 7}}, [1, 8, 9, 10], () => {
  const v = w.$gameVariables; v.setValue(13, 1); v.setValue(361, 50000); v.setValue(364, 999); v.setValue(370, 20000); v.setValue(374, 30);
  v.setValue(1552, 501); v.setValue(1556, 7);
});
// 1315：持有特殊物品的数量写进变量
caseRun('items', {party: [1, 8, 9, 10], items: {1920: 2, 1953: 1, 2456: 3, 1639: 5}}, [1, 8, 9, 10], () => {
  [[1920, 2], [1953, 1], [2456, 3], [1639, 5]].forEach(([id, n]) => w.$gameParty.gainItem(w.$dataItems[id], n));
});
// 1373：角色 12 学会的血脉技能数（2807～2813、3224～3236、4701～4707）
caseRun('bloodline', {party: [12, 8, 9, 10], learn12: [2807, 2810, 3224, 3236, 4701, 4708]}, [12, 8, 9, 10], () => {
  const a = w.$gameActors.actor(12); [2807, 2810, 3224, 3236, 4701, 4708].forEach(id => a.learnSkill(id));
});
// 1375：出战成员里半人马（41～44）数减一；开关 2303 时设 3
caseRun('centaur', {party: [41, 42, 8, 9]}, [41, 42, 8, 9]);
caseRun('centaur_switch', {party: [41, 42, 8, 9], switches: [2303]}, [41, 42, 8, 9], () => { w.$gameSwitches.setValue(2303, true); });
// 1372：变量 206≥30 时 547／548 = 206 ÷60 再 ÷3（取整）；547＜变量 20 且角色 79 在队、会 2838 时给它加状态 1044
caseRun('greed', {party: [79, 8, 9, 10], vars: {206: 3600, 20: 10}, learn79: [2838]}, [79, 8, 9, 10], () => {
  w.$gameVariables.setValue(206, 3600); w.$gameVariables.setValue(20, 10); w.$gameActors.actor(79).learnSkill(2838);
});
caseRun('greed_low', {party: [79, 8, 9, 10], vars: {206: 29, 20: 21}, learn79: [2838]}, [79, 8, 9, 10], () => {
  w.$gameVariables.setValue(206, 29); w.$gameVariables.setValue(20, 21); w.$gameActors.actor(79).learnSkill(2838);
});
const src = f => crypto.createHash('sha256').update(fs.readFileSync(path.join(APP, f))).digest('hex');
const out = {source: 'data/CommonEvents.json', sha256: src('data/CommonEvents.json'), managers: src('js/rpg_managеrs.js'), cases};
fs.mkdirSync(path.join(__dirname, '.sandbox'), {recursive: true});
fs.writeFileSync(path.join(__dirname, '.sandbox', 'battle_start_event.json'), JSON.stringify(out, null, 1));
console.log(JSON.stringify(cases.map(c => ({id: c.id, errors: c.errors.length, ran: c.observed && c.observed.ran, v: c.observed && c.observed.vars, s79: c.observed && c.observed.actor79States}))));
process.exit(cases.some(c => c.errors.length) ? 1 : 0);
