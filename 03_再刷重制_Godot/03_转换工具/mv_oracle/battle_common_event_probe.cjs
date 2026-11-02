'use strict';
// 战斗中技能／物品的公共事件（效果 44）严格级参照（八戒_71 期四）：真实 BattleManager（YEP 行动序列收尾 ACTION COMMON EVENT
// 预约 → updateEventMain → setupBattleEvent 先跑预约）逐帧推进，记每次行动（行动者、技能、目标、是否强制）、公共事件开跑时刻
// 与宠物数。例：84 魔雷（会 5083 时对上次目标强制 533；不会时不触发）、173 捕获网（行动结束后才 PetGet）、打倒最后一只敌人时不跑。
// 不加载玩家存档；渲染占位；唯一产物 .sandbox/battle_common_events.json，抄进 tests/fixtures/battle_common_event_oracle.json。
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
const toasts = [];
if (!w.$) w.$ = {};
w.$.toaster = m => toasts.push(m.message);
const key = b => !b ? null : b.isActor() ? 'a' + b.actorId() : 'e' + b.index();

function setup(party, troop) {
  w.eval('ConfigManager.applyData({});DataManager.setupNewGame();$gameSystem.setDifficultyId(3);for(var i=1;i<5000;i++)if($gameVariables._data[i]===undefined)$gameVariables._data[i]=0;');
  w.eval('$gameParty._actors=[];' + JSON.stringify(party) + '.forEach(function(id){$gameParty.addActor(id);});');
  party.forEach(id => { const a = w.$gameActors.actor(id); a._paramPlus[0] = 999999999; a._paramPlus[1] = 999999; a.recoverAll(); });
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  w.Math.random = () => 0.99;   // 精英、开战随机：不中
  const bm = w.BattleManager; bm.setup(troop, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.Math.random = () => 0.5;
  w.$gameTroop.members().forEach(e => { e._paramPlus[0] = 999999999; e.recoverAll(); });  // 敌人打不死（除非用例另设）
  return bm;
}

// 推进到第 maxActions 次行动结束后的事件检查；user 的第一次输入用 plan（[技能或物品, 是否物品, 目标序号]），其余人防御
function run(o, user, plan, maxActions) {
  const bm = w.BattleManager;
  bm.processVictory = function () { o.victory = o.actions.length; this._phase = 'battleEnd'; };  // 只记打赢的时刻，不跑结算画面
  o.actions = []; o.events = []; toasts.length = 0;
  const startAction = bm.startAction;
  bm.startAction = function () {
    const a = this._subject && this._subject.currentAction();
    o.actions.push({subject: key(this._subject), item: a && a.item() ? [a.isItem() ? 'item' : 'skill', a.item().id] : null,
      target: a ? a._targetIndex : null, forcing: !!(a && a._forcing), enemyHp: w.$gameTroop.members().map(e => e.hp)});
    return startAction.call(this);
  };
  const setupCE = w.Game_Interpreter.prototype.setupReservedCommonEvent;
  w.Game_Interpreter.prototype.setupReservedCommonEvent = function () {
    const id = w.$gameTemp._commonEventId;
    const ok = setupCE.apply(this, arguments);
    if (ok) o.events.push({commonEvent: id, afterActions: o.actions.length, marked: w.$gameParty.members().filter(m => m._states.includes(345)).map(m => m.actorId())});
    return ok;
  };
  let used = false;
  try {
    bm.startBattle();
    for (let tick = 0; tick < 20000; tick++) {
      if (bm._phase === 'battleEnd' || (o.actions.length >= maxActions && bm._phase !== 'action' && !w.$gameTroop.isEventRunning() && bm._phase !== 'actionList')) {
        // 再推几帧让行动后的事件检查跑完
        if (o.actions.length >= maxActions) for (let k = 0; k < 200 && bm._phase !== 'input'; k++) bm.update();
        break;
      }
      if (w.$gameMessage.isBusy()) { w.$gameMessage.clear(); continue; }
      if (bm._phase === 'input') {
        const actor = bm.actor(), a = bm.inputtingAction();
        if (a && actor && actor.actorId() === user && !used) {
          if (plan[1]) a.setItem(plan[0]); else a.setSkill(plan[0]);
          a.setTarget(plan[2]); used = true;
        } else if (a) a.setGuard();
        bm.selectNextCommand();
      } else bm.update();
    }
  } finally {
    bm.startAction = startAction;
    w.Game_Interpreter.prototype.setupReservedCommonEvent = setupCE;
  }
  o.toasts = toasts.slice();
  o.phase = bm._phase;
  o.enemies = w.$gameTroop.members().map(e => ({index: e.index(), alive: e.isAlive(), hidden: e.isHidden()}));
}

const cases = [];
function caseRun(id, setupFn, fn) {
  const c = {id, setup: setupFn, errors: [], observed: {}};
  try { fn(c.observed); } catch (e) { c.errors.push(String(e.stack || e).slice(0, 1500)); }
  cases.push(c);
}
// 173 捕获网：行动结束后才 PetGet（成功率 80%，Math.random 0.5）
caseRun('net_after_action', {party: [1, 8, 9, 10], troop: 2, item: 317, user: 8, use: [317, true, 0], capture: true}, o => {
  setup([1, 8, 9, 10], 2); w.$gameParty.gainItem(w.$dataItems[317], 1); w.$gameParty.Pets = [];
  w.$gameTroop.members().forEach(e => { e.Capture = true; });
  const getPet = w.Star.PetSystem.PetGet;
  w.Star.PetSystem.PetGet = function () { o.petGetAfterActions = o.actions.length; return getPet.apply(this, arguments); };
  try { run(o, 8, [317, true, 0], 3); } finally { w.Star.PetSystem.PetGet = getPet; }
  o.pets = w.$gameParty.Pets.length; o.items317 = w.$gameParty.numItems(w.$dataItems[317]);
});
// 84 魔雷：魔雷老人（23）会 5083 时，魔雷术 217 之后对上次目标强制 533
caseRun('thunder_learned', {party: [23, 8, 9, 10], troop: 2, learn: [217, 5083], use: [217, false, 1]}, o => {
  setup([23, 8, 9, 10], 2); const a = w.$gameActors.actor(23); a.learnSkill(217); a.learnSkill(5083); a._mp = a.mmp;
  run(o, 23, [217, false, 1], 3);
});
caseRun('thunder_not_learned', {party: [23, 8, 9, 10], troop: 2, learn: [217], use: [217, false, 1]}, o => {
  setup([23, 8, 9, 10], 2); const a = w.$gameActors.actor(23); a.learnSkill(217); a.forgetSkill(5083); a._mp = a.mmp;
  run(o, 23, [217, false, 1], 3);
});
// 「套装再放一次」一族（CE17 水流、18 锋芒、107 影杀等 37 个，events3c）：技能动作序列给使用者加 345，公共事件找带 345 且穿着套装
// （或会某技能、拿某武器）的人：new Game_Action → setSkill → decideRandomTarget → _actions.splice(1,0,…) → BattleManager.forceAction；
// 107／18 最后 313 解除 345，17 不解除。记强制行动、事件后 345 还在不在。
function wear(a, kind, id) {
  const item = kind === 'armor' ? w.$dataArmors[id] : w.$dataWeapons[id];
  const slot = a.equipSlots().indexOf(kind === 'armor' ? item.etypeId : 1);
  a._equips[slot].setObject(item);
}
function recast(id, setupInfo, prep) {
  caseRun(id, setupInfo, o => {
    setup(setupInfo.party, 2); const a = w.$gameActors.actor(setupInfo.user);
    a.learnSkill(setupInfo.use[0]); a._mp = a.mmp; a._tp = 100; a.releaseUnequippableItems = function () {}; prep(a); o.worn = a.equips().filter(Boolean).map(e => [e.etypeId, e.baseItemId || e.id]);
    run(o, setupInfo.user, setupInfo.use, 3);
    o.state345 = a._states.includes(345);
  });
}
recast('recast_armor_worn', {party: [23, 8, 9, 10], user: 8, use: [785, false, 0], wear: [['armor', 932], ['armor', 933]]}, a => { wear(a, 'armor', 932); wear(a, 'armor', 933); });
recast('recast_armor_half', {party: [23, 8, 9, 10], user: 8, use: [785, false, 0], wear: [['armor', 932]]}, a => { wear(a, 'armor', 932); });
recast('recast_weapon', {party: [23, 8, 9, 10], user: 8, use: [2260, false, 0], wear: [['weapon', 472]]}, a => { wear(a, 'weapon', 472); });
recast('recast_skill_learned', {party: [23, 8, 9, 10], user: 8, use: [3669, false, 0], learn: [3671]}, a => { a.learnSkill(3671); });
recast('recast_skill_not', {party: [23, 8, 9, 10], user: 8, use: [3669, false, 0], learn: []}, a => { a.forgetSkill(3671); });
// 打倒最后一只敌人：checkBattleEnd 先成立，预约的 84 不跑
caseRun('thunder_battle_end', {party: [23, 8, 9, 10], troop: 2, learn: [217, 5083], use: [217, false, 0], enemiesHp: 1, othersHidden: true}, o => {
  setup([23, 8, 9, 10], 2); const a = w.$gameActors.actor(23); a.learnSkill(217); a.learnSkill(5083); a._mp = a.mmp;
  const es = w.$gameTroop.members(); es.forEach((e, i) => { if (i > 0) { e.hide(); } }); es[0]._paramPlus[0] = 0; es[0].setHp(1);
  run(o, 23, [217, false, 0], 2);
});
const src = f => crypto.createHash('sha256').update(fs.readFileSync(path.join(APP, f))).digest('hex');
const out = {source: 'js/plugins/YEP_BattleEngineCore.js', sha256: src('js/plugins/YEP_BattleEngineCore.js'), cases};
fs.mkdirSync(path.join(__dirname, '.sandbox'), {recursive: true});
fs.writeFileSync(path.join(__dirname, '.sandbox', 'battle_common_events.json'), JSON.stringify(out, null, 1));
console.log(JSON.stringify(cases.map(c => ({id: c.id, errors: c.errors.length, actions: c.observed.actions, events: c.observed.events, toasts: c.observed.toasts, pets: c.observed.pets, state345: c.observed.state345}))));
process.exit(cases.some(c => c.errors.length) ? 1 : 0);
