'use strict';
// 冻结源敌群 101/334/335/336：全库静态索引＋正式插件引擎实测。
// 不加载玩家存档；hboot 文件系统守卫保留，唯一产物 .sandbox/battle_events.json。
// 渲染/音频用占位，消息关闭由测试驱动；消息忙时仍运行真实 BattleManager.update。
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const {boot} = require('./hboot.cjs'), {sourceIdentity} = require('./source_identity.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity = sourceIdentity(APP), r = boot(APP, {tolerant: true, log: false}), w = r.window;
w.eval('CodexZones.ENABLED=false;');  // 五乘区（CodexZones）重制不移植（O-044），探针宿主默认开着；关掉让参照不含成长修正（tools51 确认关与不关产物一致或已更新夹具）
if (r.errors.length || !w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败：' + JSON.stringify(r.errors));
const CODES = [101, 334, 335, 336], PARTY = [1, 8, 9, 10];
const json = x => JSON.parse(JSON.stringify(x));
const read = f => JSON.parse(fs.readFileSync(path.join(APP, 'data', f), 'utf8'));
function scanSource() {
  const troops = read('Troops.json').filter(Boolean).map(t => ({id: t.id, name: t.name, members: t.members,
    pages: t.pages.map((p, i) => ({page: i + 1, span: p.span, conditions: p.conditions,
      commands: p.list.map((c, j) => ({index: j, ...c}))})).filter(p => p.commands.some(c => CODES.includes(c.code)))})).filter(t => t.pages.length);
  const ids = new Set(troops.map(t => t.id)), infos = read('MapInfos.json'), maps = [], commonEvents = [], unresolvedBattles = [];
  const calls = (list, context) => list.flatMap((c, index) => {
    if (c.code !== 301) return [];
    if (c.parameters[0] !== 0) { unresolvedBattles.push({...context, index, parameters: c.parameters}); return []; }
    return ids.has(c.parameters[1]) ? [{index, troop: c.parameters[1]}] : [];
  });
  for (const file of fs.readdirSync(path.join(APP, 'data')).filter(f => /^Map\d{3}\.json$/.test(f)).sort()) {
    const id = Number(file.slice(3, 6)), d = read(file), events = [];
    for (const e of (d.events || []).filter(Boolean)) e.pages.forEach((p, i) => {
      const found = calls(p.list, {map: id, event: e.id, page: i + 1});
      if (found.length) events.push({event: e.id, name: e.name, page: i + 1, calls: found});
    });
    const encounters = (d.encounterList || []).filter(e => ids.has(e.troopId));
    if (events.length || encounters.length) maps.push({map: id, name: infos[id] ? infos[id].name : null,
      displayName: d.displayName, events, encounters});
  }
  for (const ce of read('CommonEvents.json').filter(Boolean)) {
    const found = calls(ce.list, {commonEvent: ce.id});
    if (found.length) commonEvents.push({id: ce.id, name: ce.name, calls: found});
  }
  // 公共事件调用链与技能/物品 effects 的 CE 入口也保留；只表示静态可达，不推定所有分支都在正常流程开放。
  const wanted = new Set(commonEvents.map(c => c.id)), commonEventCallers = [];
  const ceData = read('CommonEvents.json').filter(Boolean);
  for (let changed = true; changed;) {
    changed = false;
    for (const ce of ceData) if (!wanted.has(ce.id) && ce.list.some(c => c.code === 117 && wanted.has(c.parameters[0]))) {
      wanted.add(ce.id); changed = true;
    }
  }
  for (const ce of ceData) for (const [index, c] of ce.list.entries())
    if (c.code === 117 && wanted.has(c.parameters[0])) commonEventCallers.push({kind: 'commonEvent', id: ce.id, name: ce.name, index, target: c.parameters[0]});
  for (const file of fs.readdirSync(path.join(APP, 'data')).filter(f => /^Map\d{3}\.json$/.test(f)).sort()) {
    const id = Number(file.slice(3, 6));
    for (const e of (read(file).events || []).filter(Boolean)) e.pages.forEach((p, page) => p.list.forEach((c, index) => {
      if (c.code === 117 && wanted.has(c.parameters[0])) commonEventCallers.push({kind: 'map', id, event: e.id, page: page + 1, index, target: c.parameters[0]});
    }));
  }
  for (const [file, kind] of [['Skills.json', 'skill'], ['Items.json', 'item']])
    for (const x of read(file).filter(Boolean)) for (const e of x.effects || [])
      if (e.code === 44 && wanted.has(e.dataId)) commonEventCallers.push({kind, id: x.id, name: x.name, target: e.dataId});
  return {troops, maps, commonEvents, commonEventCallers, unresolvedBattles};
}
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
const key = b => !b ? null : b.isActor() ? 'a' + b.actorId() : 'e' + b.index();
const actions = b => b._actions.map(a => ({skill: a.item() ? a.item().id : null, target: a._targetIndex, forcing: !!a._forcing}));
const enemy = b => ({index: b.index(), enemyId: b.enemyId(), name: b.name(), hidden: b.isHidden(), alive: b.isAlive(),
  hp: b.hp, mhp: b.mhp, mp: b.mp, mmp: b.mmp, tp: b.tp, level: b.level,
  params: Array.from({length: 8}, (_, i) => b.param(i)), states: json(b._states), stateTurns: json(b._stateTurns),
  buffs: json(b._buffs), buffTurns: json(b._buffTurns), actions: actions(b), actionState: b._actionState});
const snap = () => ({turn: w.$gameTroop.turnCount(), phase: w.BattleManager._phase,
  subject: key(w.BattleManager._subject), currentOrder: (w.BattleManager._actionBattlers || []).map(key),
  nextOrder: (w.BattleManager._nextTurnActionBattlers || []).map(key),
  messageBusy: w.$gameMessage.isBusy(), texts: json(w.$gameMessage._texts),
  message: {faceName: w.$gameMessage.faceName(), faceIndex: w.$gameMessage.faceIndex(),
    background: w.$gameMessage.background(), positionType: w.$gameMessage.positionType()},
  waitMode: w.$gameTroop._interpreter._waitMode, index: w.$gameTroop._interpreter._index, eventFlags: json(w.$gameTroop._eventFlags),
  variable112: w.$gameVariables.value(112), enemies: w.$gameTroop.members().map(enemy)});
function setup(troop) {
  w.eval('ConfigManager.applyData({});DataManager.setupNewGame();$gameSystem.setDifficultyId(3);for(var i=1;i<5000;i++)if($gameVariables._data[i]===undefined)$gameVariables._data[i]=0;');
  w.eval('$gameParty._actors=[];' + JSON.stringify(PARTY) + '.forEach(function(id){$gameParty.addActor(id);});');
  PARTY.forEach(id => { const a = w.$gameActors.actor(id);
    // 只提高测试队伍 HP 以撑到第4回合；敌人规则、血量、状态与招式均由源引擎执行。
    a._paramPlus[0] = 999999999; a.recoverAll(); });
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  w.Math.random = () => 0.99;
  const bm = w.BattleManager; bm.setup(troop, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.Math.random = () => 0.5;
  return bm;
}
function command(code, p) { const it = new w.Game_Interpreter(); it._params = p; return it['command' + code](); }
function caseRun(id, fn) {
  const c = {id, errors: [], observed: {}};
  try { fn(c.observed); } catch (e) { c.errors.push(String(e.stack || e)); }
  return c;
}
function realFourTurns(o) {
  const bm = setup(165); o.commands = []; o.messages = []; o.actions = []; o.turns = []; const restore = [];
  for (const code of CODES) {
    const name = 'command' + code, original = w.Game_Interpreter.prototype[name];
    w.Game_Interpreter.prototype[name] = function () {
      const item = {code, parameters: json(this._params), before: snap()};
      const ret = original.apply(this, arguments); item.after = snap(); o.commands.push(item); return ret;
    };
    restore.push(() => {w.Game_Interpreter.prototype[name] = original;});
  }
  const original = bm.startAction;
  bm.startAction = function () { o.actions.push({turn: w.$gameTroop.turnCount(), subject: key(this._subject), actions: this._subject ? actions(this._subject) : []}); return original.call(this); };
  restore.push(() => {bm.startAction = original;});
  try {
    bm.startBattle(); let lastTurn = -1, finished = false;
    for (let tick = 0; tick < 60000; tick++) {
      const turn = w.$gameTroop.turnCount();
      if (turn !== lastTurn) {o.turns.push(snap()); lastTurn = turn;}
      if (turn > 4) {finished = true; break;}
      if (bm._phase === 'battleEnd') throw new Error('未到第4回合就结束');
      if (w.$gameMessage.isBusy()) {
        const start = snap(), actionCount = o.actions.length, commandCount = o.commands.length;
        for (let hold = 0; hold < 3; hold++) bm.update();
        const held = snap();
        assert.deepEqual(held, start, '消息忙期间必须停在同一规则状态');
        assert.equal(o.actions.length, actionCount); assert.equal(o.commands.length, commandCount);
        o.messages.push({opened: start, heldTicks: 3, held});
        w.$gameMessage.clear(); // 模拟玩家读完消息，未调用游戏场景或玩家配置。
        o.messages[o.messages.length - 1].closed = snap();
      } else if (bm._phase === 'input') {
        const a = bm.inputtingAction(); if (a) a.setGuard(); bm.selectNextCommand();
      } else bm.update();
    }
    o.final = snap(); assert.ok(finished, '调度超时');
    const msg = o.commands.find(c => c.code === 101); assert.ok(msg, '未触发第4回合101');
    assert.equal(msg.before.turn, 4); assert.equal(msg.after.messageBusy, true);
    const transform = o.commands.find(c => c.code === 336); assert.ok(transform); assert.equal(transform.before.turn, 4);
    assert.equal(transform.before.messageBusy, false); assert.equal(transform.after.enemies[0].enemyId, 175);
    assert.equal(o.messages.length, 1); assert.equal(o.commands.filter(c => c.code === 334).length, 4);
    assert.deepEqual(o.commands.map(c => c.code), [334, 334, 334, 101, 334, 336]);
    assert.ok(o.actions.some(a => a.turn === 4 && a.subject === 'e0'), '变身后第4回合敌人仍有行动');
  } finally {restore.reverse().forEach(f => f());}
}
function recoverCase(o) {
  setup(165); const e = w.$gameTroop.members()[0];
  e.setHp(0); e.setMp(0); e.setTp(37); e.addState(4); e.addBuff(2, 3);
  o.before = snap(); command(334, [-1]); o.after = snap();
  assert.equal(e.hp, e.mhp); assert.equal(e.mp, e.mmp); assert.equal(e.tp, 37);
  assert.deepEqual(json(e._states), []); assert.equal(e.isAlive(), true);
  assert.deepEqual(json(e._buffs), o.before.enemies[0].buffs, '完全恢复不清除buff');
}
function livingHiddenRecoverCase(o) {
  setup(824); const members = w.$gameTroop.members();
  for (const e of members.slice(0, 2)) {
    const hidden = e.isHidden(); if (hidden) e.appear();
    e.addState(77); e.setHp(Math.floor(e.mhp / 3)); e.setMp(0); e.setTp(29); e.addBuff(2, 3);
    if (hidden) e.hide();
  }
  o.before = snap(); command(334, [-1]); o.after = snap();
  for (const e of members.slice(0, 2)) {
    assert.equal(e.hp, o.before.enemies[e.index()].mhp, '冻结源缓存令334先按旧上限写HP'); assert.equal(e.mp, e.mmp); assert.equal(e.tp, 29);
    assert.deepEqual(json(e._states), []); assert.ok(e.mhp > o.before.enemies[e.index()].mhp, '77清除后真实上限回升，但HP仍为旧上限');
    assert.equal(e.isHidden(), o.before.enemies[e.index()].hidden, '334不令隐藏成员出现');
    assert.deepEqual(json(e._buffs), o.before.enemies[e.index()].buffs);
  }
}
function transformCase(o, hasAction) {
  const bm = setup(165); bm.startBattle(); w.$gameTroop._turnCount = 4; const e = w.$gameTroop.members()[0];
  e.setHp(Math.floor(e.mhp / 3)); e.setMp(Math.floor(e.mmp / 3)); e.setTp(37); e.addState(4); e.addBuff(2, 3);
  if (hasAction) {const a = new w.Game_Action(e); a.setSkill(1); a.setTarget(2); e.clearActions(); e._actions.push(a);} else e.clearActions();
  o.before = snap(); command(336, [0, 175]); o.after = snap();
  assert.equal(e.enemyId(), 175); assert.equal(e.hp, Math.min(o.before.enemies[0].hp, e.mhp));
  assert.equal(e.mp, Math.min(o.before.enemies[0].mp, e.mmp)); assert.equal(e.tp, 37);
  assert.ok(o.before.enemies[0].states.every(id => e._states.includes(id)), '变身保留原有状态');
  assert.ok(e._states.includes(2651), '偶数回合变身同步源Boss霸体2651');
  assert.deepEqual(json(e._buffs), o.before.enemies[0].buffs);
  assert.equal(e._actions.length > 0, hasAction, '变身只在原来有行动时重选');
  if (hasAction) assert.equal(e._actions[0].item().id, 4023, '按175第4回合AI重选');
}
function appearCase(o, variable1178) {
  const bm = setup(824); w.$gameVariables.setValue(1178, variable1178); o.commands = []; o.actions = []; o.turns = []; o.before = snap();
  const restore = [];
  for (const code of [333, 335]) {
    const name = 'command' + code, original = w.Game_Interpreter.prototype[name];
    w.Game_Interpreter.prototype[name] = function () {
      const item = {code, parameters: json(this._params), before: snap()};
      const ret = original.apply(this, arguments); item.after = snap(); o.commands.push(item); return ret;
    };
    restore.push(() => {w.Game_Interpreter.prototype[name] = original;});
  }
  const startAction = bm.startAction;
  bm.startAction = function () {o.actions.push({turn: w.$gameTroop.turnCount(), subject: key(this._subject)}); return startAction.call(this);};
  restore.push(() => {bm.startAction = startAction;});
  try {
    bm.startBattle(); let finished = false, lastTurn = -1;
    for (let tick = 0; tick < 30000; tick++) {
      const turn = w.$gameTroop.turnCount();
      if (turn !== lastTurn) {o.turns.push(snap()); lastTurn = turn;}
      if (turn > 3) {finished = true; break;}
      if (w.$gameMessage.isBusy()) w.$gameMessage.clear();
      else if (bm._phase === 'input') {const a = bm.inputtingAction(); if (a) a.setGuard(); bm.selectNextCommand();}
      else bm.update();
    }
    assert.ok(finished, '824调度超时'); o.after = snap();
    assert.equal(o.before.enemies.filter(e => !e.hidden).length, 1);
    assert.equal(o.after.enemies.filter(e => !e.hidden).length, variable1178 >= 6 ? 6 : 1);
    const state = o.commands.find(c => c.code === 333 && c.parameters[2] === 3); assert.ok(state);
    assert.ok(state.after.enemies.filter(e => !e.hidden).every(e => e.states.includes(3)));
    assert.ok(state.after.enemies.filter(e => e.hidden).every(e => !e.states.includes(3)), '隐藏成员isAlive=false，333附加状态被原引擎拒绝');
    assert.equal(o.commands.filter(c => c.code === 335).length, variable1178 >= 6 ? 5 : 0);
    const newNames = o.after.enemies.filter(e => !e.hidden).map(e => e.name);
    assert.equal(new Set(newNames).size, newNames.length, '出现后名称唯一');
    if (variable1178 >= 6) {
      for (const i of [1, 2, 3, 4, 5]) {
        const first = o.actions.find(a => a.subject === 'e' + i);
        assert.ok(first); assert.equal(first.turn, 3, '冻结源隐藏成员首次行动在第3回合');
      }
      for (const c of o.commands.filter(c => c.code === 335)) {
        assert.deepEqual(c.after.currentOrder, c.before.currentOrder, '冻结源335未插入当前队列');
        assert.deepEqual(c.after.nextOrder, c.before.nextOrder, '冻结源335未插入下一回合队列');
      }
      const e = w.$gameTroop.members()[1]; e.setHp(Math.floor(e.mhp / 2)); e.setMp(0); e.setTp(31); e.addState(4); e.hide();
      o.reappearBefore = snap(); command(335, [1]); o.reappearAfter = snap();
      assert.equal(e.hp, o.reappearBefore.enemies[1].hp); assert.equal(e.mp, 0); assert.equal(e.tp, 31);
      assert.deepEqual(json(e._states), o.reappearBefore.enemies[1].states);
      assert.equal(e.index(), 1); assert.equal(e.isHidden(), false);
      e.setHp(0); e.hide(); o.deadAppearBefore = snap(); command(335, [1]); o.deadAppearAfter = snap();
      assert.equal(e.isHidden(), false); assert.equal(e.hp, 0); assert.ok(e.isDeathStateAffected(), '335显现死亡成员，不执行复活');
    }
  } finally {restore.reverse().forEach(f => f());}
}
// 336 变身能力值缓存（krz_state_re Game_Enemy.param 的 _ParamCache2／need_refresh_param）：敌群 466 的敌人 534→538，
// 开战后（inBattle）才走缓存。只读原始缓存字段与 dirty，规定的预热／终点才读 2～7 号参数，不用 snap()／enemy()（会读全八项）。
const PARAM_IDS = [2, 3, 4, 5, 6, 7];
function cacheBattle() {
  const bm = setup(466); const e = w.$gameTroop.members()[0];
  assert.equal(e.enemyId(), 534); bm.startBattle(); assert.equal(w.$gameParty.inBattle(), true); e.clearActions();
  return e;
}
const cacheRaw = e => ({enemyId: e.enemyId(), needRefresh: !!e.need_refresh, dirtyParams: json((e.need_refresh_param || []).slice(0, 8)),
  cache: json((e._ParamCache2 || []).slice(0, 8)), states: json(e._states), buffs: json(e._buffs), hp: e._hp, mp: e._mp, tp: e._tp});
const cacheRead = e => ({before: cacheRaw(e), params: PARAM_IDS.map(i => e.param(i))});
function interpret(list) {
  const it = new w.Game_Interpreter();
  it.setup(list.map(([code, parameters]) => ({code, indent: 0, parameters})).concat([{code: 0, indent: 0, parameters: []}]), 0);
  it.update(); assert.equal(it.isRunning(), false);
}
const transform538 = (e, id = 538) => { assert.equal(command(336, [e.index(), id]), true); assert.equal(e.enemyId(), id); };
function paramCacheCase(o) {
  o.fixture = {troop: 466, slot: 0, from: 534, to: 538, paramIds: PARAM_IDS, inBattle: true,
    ops: 'refresh/setHp/setMp/addState/removeState/clearStates/recoverAll/addBuff/addDebuff/removeBuff/onTurnStart/onTurnEnd/gain*/command333/334/336'};
  o.initialized = cacheRaw(cacheBattle());
  o.warm = [];
  for (const warm of [[], ...PARAM_IDS.map(i => [i]), [2, 4, 6], PARAM_IDS]) {
    const e = cacheBattle(), warmed = warm.map(i => e.param(i)), before = cacheRaw(e);
    transform538(e); o.warm.push({warm, warmed, before, after: cacheRead(e)});
  }
  { const e = cacheBattle(), old = PARAM_IDS.map(i => e.param(i)); transform538(e); const first = cacheRead(e);
    transform538(e, 534); o.twice = {old, first, second: cacheRead(e)}; }
  const boundaries = [
    ['refresh', null, e => e.refresh()], ['setHp', null, e => e.setHp(e._hp - 1)], ['setMp', null, e => e.setMp(e._mp - 1)],
    ['addState4', null, e => e.addState(4)], ['removeState4', e => e.addState(4), e => e.removeState(4)],
    ['clearStates', null, e => e.clearStates()], ['clearStates.state77', e => e.addState(77), e => e.clearStates()],
    ['recoverAll', null, e => e.recoverAll()], ['recoverAll.state77', e => e.addState(77), e => e.recoverAll()],
    ['addBuff2', null, e => e.addBuff(2, 3)], ['addDebuff2', null, e => e.addDebuff(2, 3)],
    ['removeBuff2', e => e.addBuff(2, 3), e => e.removeBuff(2)], ['onTurnStart', null, e => e.onTurnStart()],
    ['onTurnEnd', null, e => e.onTurnEnd()], ['dirtyRefresh', null, e => {e.need_refresh = true; e.refresh();}],
    ['gainHp-1', null, e => e.gainHp(-1)], ['gainMp-1', null, e => e.gainMp(-1)], ['gainTp1', null, e => e.gainTp(1)],
    ['gainSilentTp1', null, e => e.gainSilentTp(1)], ['gainHp0', null, e => e.gainHp(0)], ['gainMp0', null, e => e.gainMp(0)],
    ['gainTp0', null, e => e.gainTp(0)]];
  o.boundaries = [];
  for (const [id, prepare, fn] of boundaries) {
    const e = cacheBattle(); if (prepare) prepare(e); e.refresh(); assert.equal(!!e.need_refresh, false);
    const old = PARAM_IDS.map(i => e.param(i)); transform538(e); const transformed = cacheRead(e);
    fn(e); const after = cacheRead(e); e.refresh();
    o.boundaries.push({id, old, transformed, after, followingRefresh: cacheRead(e)});
  }
  o.interpreter = [];
  for (const [id, list, state] of [
    ['336-334', [[336, [0, 538]], [334, [-1]]], 0], ['336-334-334', [[336, [0, 538]], [334, [-1]], [334, [-1]]], 0],
    ['336-333add4-334', [[336, [0, 538]], [333, [0, 0, 4]], [334, [-1]]], 0],
    ['336-333add77-334', [[336, [0, 538]], [333, [0, 0, 77]], [334, [-1]]], 0],
    ['336-333remove4-334', [[336, [0, 538]], [333, [0, 1, 4]], [334, [-1]]], 4]]) {
    const e = cacheBattle(); if (state) e.addState(state); e.refresh();
    e.setHp(Math.floor(e._hp / 3)); e.setMp(0);
    const old = PARAM_IDS.map(i => e.param(i)), before = cacheRaw(e); interpret(list);
    o.interpreter.push({id, state, old, before, after: cacheRead(e)});
    assert.equal(e._hp, before.cache[0], '334 先按旧缓存上限写回');
  }
}
// 难度 3 的被动 5980「难度适应」：开战附加 Permanent 状态 1691（特性 54 封印装备类型 15／16／18／19），addState 内部 Game_Actor.refresh
// 的 releaseUnequippableItems(false) 把已装的件退回队伍背包。开战状态照 dsPassiveSkill 开战标签顺序直接附加（同 slice_probe）。
function sealReleaseCase(o) {
  const SEALED = [15, 16, 18, 19], ACTOR = 104;
  w.eval('ConfigManager.applyData({});DataManager.setupNewGame();$gameSystem.setDifficultyId(3);for(var i=1;i<5000;i++)if($gameVariables._data[i]===undefined)$gameVariables._data[i]=0;');
  w.eval('$gameParty._actors=[];$gameParty.addActor(' + ACTOR + ');');
  const a = w.$gameActors.actor(ACTOR);
  for (const s of [6168, 5980, 5548]) a.learnSkill(s);
  a.refresh(); a.recoverAll();
  const read = () => ({states: json(a._states), mhp: a.mhp, mmp: a.mmp, hp: a.hp, inBattle: w.$gameParty.inBattle(),
    sealedEquips: a.equips().map((e, i) => e && SEALED.includes(a.equipSlots()[i]) ? {slot: i, etype: a.equipSlots()[i], name: e.name} : null).filter(Boolean),
    sealedBag: w.$gameParty.armors().filter(x => SEALED.includes(x.etypeId)).map(x => ({etype: x.etypeId, name: x.name, n: w.$gameParty.numItems(x)}))});
  o.fixture = {actor: ACTOR, difficulty: 3, skills: [6168, 5980, 5548], troop: 2, startStates: [995, 1691, 1631]};
  o.before = read();
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  w.Math.random = () => 0.99;
  const bm = w.BattleManager; bm.setup(2, true, false); bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  bm.startBattle(); w.Math.random = () => 0.5;
  o.steps = [];
  for (const s of o.fixture.startStates) { a.addState(s); o.steps.push(Object.assign({added: s}, read())); }
  w.$gameParty.onBattleEnd(); w.$gameTroop.onBattleEnd(); a.refresh(); o.afterBattle = read();
  o.canEquipAfter = w.$gameParty.armors().filter(x => SEALED.includes(x.etypeId)).map(x => ({name: x.name, canEquip: a.canEquip(x)}));
  assert.ok(o.before.sealedEquips.length > 0, '104 开局装着被封印类型的装备');
  assert.equal(o.afterBattle.sealedEquips.length, 0); assert.ok(o.afterBattle.states.includes(1691), '1691 战后不解除');
}
const result = {schemaVersion: 1, hostScope: 'headless-rule-timing', sourceIdentity: identity, scan: scanSource(),
  fixture: {party: PARTY, difficulty: 3, randomSetup: 0.99, randomBattle: 0.5, partyHpParamPlus: 999999999,
    actorInput: 'guard', messageClose: 'after 3 real BattleManager.update calls; UI frames are not measured'},
  cases: [caseRun('scan.inventory', o => {
    const scan = scanSource(); o.troops = scan.troops.length; o.pages = scan.troops.reduce((n,t) => n+t.pages.length, 0);
    assert.equal(o.troops, 35); assert.equal(o.pages, 47);
  }), caseRun('troop165.real-turns1-4', realFourTurns), caseRun('command334.revive-and-recover', recoverCase), caseRun('command334.living-and-hidden', livingHiddenRecoverCase),
    caseRun('command336.no-queued-action', o => transformCase(o, false)), caseRun('command336.rebuild-queued-action', o => transformCase(o, true)),
    caseRun('troop824.variable1178-5-hidden', o => appearCase(o, 5)), caseRun('troop824.variable1178-6-appear', o => appearCase(o, 6)),
    caseRun('command336.param-cache-466', paramCacheCase), caseRun('actor104.seal-release-1691', sealReleaseCase)]};
if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
fs.writeFileSync(path.join(__dirname, '.sandbox/battle_events.json'), JSON.stringify(result, null, 1));
process.stdout.write(JSON.stringify({troops: result.scan.troops.length, pages: result.scan.troops.reduce((n,t) => n+t.pages.length, 0),
  cases: result.cases.map(c => ({id: c.id, errors: c.errors}))}) + '\n');
process.exit(result.cases.some(c => c.errors.length) ? 1 : 0);
