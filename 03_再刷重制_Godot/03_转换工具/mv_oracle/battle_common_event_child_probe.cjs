'use strict';
// 事件运行中行动序列 COMMON EVENT 的时序参照（八戒_77，F5）：ActSeqPack1 actionCommonEvent 在 $gameTroop 事件运行中
// 直接 $gameTroop._interpreter.setupChild(list)（顶层解释器，换掉已有子解释器），不运行时才 reserveCommonEvent。
// 用合成公共事件（追加在 $dataCommonEvents 末尾，只在内存）强制角色 8 用 292 踏地（目标动作里 Common event: 375），
// 公共事件 375 荒芜剑诀：荒天弟 83 在队且会 5997 时强制 83 用 5989。变量 V 当时间戳：父事件在 339 之后写 V=V*10+k。
// 例：top_level（父事件顶层 339）、inside_call（339 在父事件 117 叫起的公共事件里）、no_event（不在事件里，照常预约）。
// 不加载玩家存档；渲染占位；唯一产物 .sandbox/battle_common_event_child.json，抄进 tests/fixtures/battle_common_event_child_oracle.json。
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
const key = b => !b ? null : b.isActor() ? 'a' + b.actorId() : 'e' + b.index();

const V = 1600, PARTY = [8, 83, 9, 10];
const cmd = (code, parameters, indent = 0) => ({code, indent, parameters});
const mark = k => [cmd(122, [V, V, 3, 0, 10]), cmd(122, [V, V, 1, 0, k])];   // V = V*10 + k
const force = cmd(339, [1, 8, 292, 0]);                                       // 角色 8 用 292 打敌人 0
const base = w.$dataCommonEvents.length;
const CALLED = base, TOP = base + 1, CALL = base + 2;
w.$dataCommonEvents[CALLED] = {id: CALLED, name: '探针:被叫', trigger: 0, switchId: 1, list: [force, ...mark(5), cmd(0, [])]};
w.$dataCommonEvents[TOP] = {id: TOP, name: '探针:顶层', trigger: 0, switchId: 1, list: [cmd(122, [V, V, 0, 0, 1]), force, ...mark(2), cmd(0, [])]};
w.$dataCommonEvents[CALL] = {id: CALL, name: '探针:叫起', trigger: 0, switchId: 1, list: [cmd(122, [V, V, 0, 0, 1]), cmd(117, [CALLED]), ...mark(9), cmd(0, [])]};

function setup() {
  w.eval('ConfigManager.applyData({});DataManager.setupNewGame();$gameSystem.setDifficultyId(3);for(var i=1;i<5000;i++)if($gameVariables._data[i]===undefined)$gameVariables._data[i]=0;');
  w.eval('$gameParty._actors=[];' + JSON.stringify(PARTY) + '.forEach(function(id){$gameParty.addActor(id);});');
  PARTY.forEach(id => { const a = w.$gameActors.actor(id); a._paramPlus[0] = 999999999; a._paramPlus[1] = 999999; a.recoverAll(); });
  w.$gameActors.actor(83).learnSkill(5997);
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  w.Math.random = () => 0.99;
  const bm = w.BattleManager; bm.setup(2, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.Math.random = () => 0.5;
  w.$gameTroop.members().forEach(e => { e._paramPlus[0] = 999999999; e.recoverAll(); });
  return bm;
}

// reserveId：第一次输入时预约的合成公共事件（0 不预约）；use：角色 8 第一次输入用的技能（0 防御）
function run(o, reserveId, use) {
  const bm = w.BattleManager, I = w.Game_Interpreter.prototype;
  bm.processVictory = function () { this._phase = 'battleEnd'; };
  o.actions = []; o.children = []; o.reserved = []; o.ran = [];
  const startAction = bm.startAction, setupChild = I.setupChild, reserve = w.Game_Temp.prototype.reserveCommonEvent,
    setupCE = I.setupReservedCommonEvent;
  bm.startAction = function () {
    const a = this._subject && this._subject.currentAction();
    if (a && a.item() && !a.isGuard()) o.actions.push({subject: key(this._subject), skill: a.item().id, forcing: !!a._forcing, v: w.$gameVariables.value(V)});
    return startAction.call(this);
  };
  I.setupChild = function (list, eventId) {
    o.children.push({depth: this._depth, top: this === w.$gameTroop._interpreter, length: list.length, v: w.$gameVariables.value(V),
      replaced: !!this._childInterpreter});
    return setupChild.apply(this, arguments);
  };
  w.Game_Temp.prototype.reserveCommonEvent = function (id) {
    if (id !== 1320) o.reserved.push({id, v: w.$gameVariables.value(V), running: w.$gameTroop.isEventRunning()});
    return reserve.apply(this, arguments);
  };
  I.setupReservedCommonEvent = function () {
    const id = w.$gameTemp._commonEventId, ok = setupCE.apply(this, arguments);
    if (ok && id !== 1320) o.ran.push({id, v: w.$gameVariables.value(V)});
    return ok;
  };
  let inputs = 0, reserved = false;
  try {
    bm.startBattle();
    for (let tick = 0; tick < 20000 && bm._phase !== 'battleEnd'; tick++) {
      if (w.$gameMessage.isBusy()) { w.$gameMessage.clear(); continue; }
      if (bm._phase === 'input') {
        if (!reserved && reserveId) { w.$gameTemp.reserveCommonEvent(reserveId); reserved = true; }
        const actor = bm.actor(), a = bm.inputtingAction();
        if (a && actor && actor.actorId() === 8 && use && inputs === 0) { a.setSkill(use); a.setTarget(0); } else if (a) a.setGuard();
        if (actor && actor.actorId() === 8) inputs++;
        if (inputs > 1) break;   // 第二回合输入：第一回合的事件、行动都已结束
        bm.selectNextCommand();
      } else bm.update();
    }
  } finally {
    bm.startAction = startAction; I.setupChild = setupChild; w.Game_Temp.prototype.reserveCommonEvent = reserve;
    I.setupReservedCommonEvent = setupCE;
  }
  o.finalV = w.$gameVariables.value(V);
  o.phase = bm._phase;
}

const cases = [];
function caseRun(id, setupInfo, fn) {
  const c = {id, setup: setupInfo, errors: [], observed: {}};
  try { setup(); fn(c.observed); } catch (e) { c.errors.push(String(e.stack || e).slice(0, 1500)); }
  cases.push(c);
}
caseRun('top_level', {event: 'top', list: w.$dataCommonEvents[TOP].list}, o => run(o, TOP, 0));
caseRun('inside_call', {event: 'call', list: w.$dataCommonEvents[CALL].list, called: w.$dataCommonEvents[CALLED].list}, o => run(o, CALL, 0));
caseRun('no_event', {use: 292}, o => run(o, 0, 292));
const src = f => crypto.createHash('sha256').update(fs.readFileSync(path.join(APP, f))).digest('hex');
const out = {source: 'js/plugins/YEP_X_ActSeqPack1.js', sha256: src('js/plugins/YEP_X_ActSeqPack1.js'), variable: V, party: PARTY, cases};
fs.mkdirSync(path.join(__dirname, '.sandbox'), {recursive: true});
fs.writeFileSync(path.join(__dirname, '.sandbox', 'battle_common_event_child.json'), JSON.stringify(out, null, 1));
console.log(JSON.stringify(cases.map(c => ({id: c.id, errors: c.errors, o: c.observed}))));
process.exit(cases.some(c => c.errors.length) ? 1 : 0);
