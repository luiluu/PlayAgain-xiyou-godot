'use strict';
// 2026-10-18 核查第二批修复的冻结 v0.28 参照（沙僧复现脚本改成常驻探针）：
// 1) 回春：installDamageElementRuntime.healing 在浮动与取整前乘治疗被动（passiveHEUP）。固定恢复 100、rec=1、无元素、无浮动；
//    HP／MP 回复、三个境界、无道法基线、敌人施法基线。
// 2) 可败战斗全灭：BattleManager.endBattle(2)＋updateBattleEnd；_canLose 时 reviveBattleMembers 把倒下的出战者 setHp(1)。
//    敌群 770（瓶颈之战）、903（神兵试炼）全灭、770 部分阵亡；不可败时不复活。
// 只在内存里跑：新局与 BattleManager.setup；不渲染、不写存档。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const cases = [];
const clean = a => { a._skills.length = 0; a._equips.length = 0; a.clearStates(); a.refresh(); a.recoverAll(); };
const heal = (type) => ({id: 0, name: '核查固定恢复', stypeId: 1, hitType: 0, scope: 7, note: '', meta: {}, effects: [],
  damage: {type, formula: '100', elementId: 0, variance: 0, critical: false}});
const calc = (user, target, item) => { const act = new w.Game_Action(user); act.item = () => item; w.$gameSystem.healRate = () => 1;
  return w.CodexDamage.calculate(act, target, {preview: true}).value; };
const withHuichun = (a, realm) => { a._codexZhenqi = {qi: 0, realm, firsts: {}, pending: [], daofa: {huichun: 1}, spec: {}};
  a.learnSkill(w.CodexZhenqi.skillKey('daofa:huichun')); w.CodexZhenqi.refreshRewards(a); };

for (const [id, realm, type] of [['hp.r0', 0, 3], ['hp.r3', 3, 3], ['hp.r5', 5, 3], ['mp.r3', 3, 4]])
  cases.push(makeCase('heal.' + id, {realm, type}, () => { newGame(); const a = w.$gameActors.actor(1), b = w.$gameActors.actor(8); clean(a); clean(b);
    withHuichun(a, realm); return {passive: a.skills().map(s => s.meta && s.meta.passiveHEUP).filter(Boolean), value: calc(a, b, heal(type))}; }));
// 实战：真实治疗技能 166「治疗术」Game_Action.apply 后的 hpDamage 与预览值（dsPassiveSkill 的 executeDamage 是否再乘一次）
cases.push(makeCase('heal.apply.r3', {realm: 3, skill: 166}, () => { newGame(); const a = w.$gameActors.actor(1), b = w.$gameActors.actor(8); clean(a); clean(b);
  withHuichun(a, 3); w.CodexYunshang._acted = []; w.BattleManager.setup(770, false, true); w.$gameParty._inBattle = true; b.setHp(1);
  const act = new w.Game_Action(a); act.setSkill(166); w.$gameSystem.healRate = () => 1;
  const preview = w.CodexDamage.calculate(act, b, {preview: true}).value; act.apply(b); w.$gameParty._inBattle = false;
  return {preview, hpDamage: b.result().hpDamage, hit: b.result().isHit()}; }));
cases.push(makeCase('heal.none', {type: 3}, () => { newGame(); const a = w.$gameActors.actor(1), b = w.$gameActors.actor(8); clean(a); clean(b);
  return {value: calc(a, b, heal(3))}; }));
cases.push(makeCase('heal.enemy', {troop: 770, type: 3}, () => { newGame(); w.$gameTroop.setup(770); const e = w.$gameTroop.members()[0];
  const b = w.$gameActors.actor(8); clean(b); return {value: calc(e, b, heal(3))}; }));

// 2b) Math.round 取整边界（沙僧 2026-10-21 P2）：真实 healing 入口，公式写成字面量 X（回复型 sign＝-1，取整前即 -X）；
//     覆盖正负半数、已是整数的大奇数、2^52／2^53 邻域。另录原生 Math.round(±x) 表，供 Godot 取整辅助逐例对照（含正值结算方向）。
const ROUND_INPUTS = ['0.5', '1.5', '2.5', '0.49999999999999994', '631187.5', '631186.5', '4503599627370495.5',
  '4503599627370495', '4503599627370496', '4503599627370497', '4503599627370499', '9007199254740991', '9007199254740992', '9007199254740994', '1e21'];
const healFormula = (type, formula) => Object.assign(heal(type), {damage: Object.assign(heal(type).damage, {formula})});
for (const x of ROUND_INPUTS)
  cases.push(makeCase('heal.round.' + x, {type: 3, input: Number(x), formula: x}, () => { newGame(); const a = w.$gameActors.actor(1), b = w.$gameActors.actor(8);
    clean(a); clean(b); return {value: calc(a, b, healFormula(3, x))}; }));
cases.push(makeCase('round.native', {inputs: ROUND_INPUTS}, () => ({rows: ROUND_INPUTS.map(Number).flatMap(x => [x, -x])
  .map(x => [x, Math.round(x)])})));
// 同一张表按 IEEE-754 双精度位（小端十六进制）记录：Godot 的数字解析不是正确舍入（4503599627370495.5 读成 …495.0），按位才能逐例对照
const bits = x => { const b = Buffer.alloc(8); b.writeDoubleLE(x); return b.toString('hex'); };
cases.push(makeCase('round.native.bits', {inputs: ROUND_INPUTS, encoding: 'float64-le-hex'}, () => ({rows: ROUND_INPUTS.map(Number).flatMap(x => [x, -x])
  .map(x => [bits(x), bits(Math.round(x))])})));

// 3) 指令 283 更改战斗背景的存档行为（悟空_24 低级项）：$gameMap 整个进存档（makeSaveContents.map），同版本读档不重设地图；
//    同图移动不 setup、换图 setupBattleback 重设为地图指定；版本号不同时 reloadMapIfUpdated 重载本图也会重设。
//    放在可败战斗之前：updateBattleEnd 留下的换场景状态会让之后的解释器停在原地。
//    Map055 指定 Translucent／Temple，公共事件 1387 改成 DemonicWorld／DemonCastle2；Map004 不指定。JsonEx 只在内存往返。
const names = () => [w.$gameMap.battleback1Name(), w.$gameMap.battleback2Name()];
const battleNames = () => [w.Spriteset_Battle.prototype.battleback1Name.call({}), w.Spriteset_Battle.prototype.battleback2Name.call({})];
const goMap = (id, x, y) => { w.$gamePlayer.reserveTransfer(id, x, y, 2, 0); w.DataManager.loadMapData(id); w.$gamePlayer.performTransfer(); };
const changed = () => { newGame(); goMap(55, 1, 1); const before = names(); const it = new w.Game_Interpreter();
  it.setup(w.JsonEx.makeDeepCopy(w.$dataCommonEvents[1387].list), 0); let n = 0; while (it.isRunning() && n++ < 100) it.update();
  return {before, after: names()}; };
const roundtrip = () => { const json = host.encode(); const saved = w.JsonEx.parse(json).map;
  host.restore(json); return [saved._battleback1Name, saved._battleback2Name]; };
cases.push(makeCase('battleback.save', {map: 55, common: 1387}, () => { const c = changed(); const saved = roundtrip();
  return {...c, saved, loaded: names(), battle: battleNames(), map: w.$gameMap.mapId()}; }));
cases.push(makeCase('battleback.sameMap', {map: 55, common: 1387, transfer: 55}, () => { const c = changed(); roundtrip(); goMap(55, 2, 2);
  return {...c, after: names(), battle: battleNames()}; }));
cases.push(makeCase('battleback.otherMap', {map: 55, common: 1387, transfer: 4}, () => { changed(); roundtrip(); goMap(4, 14, 23); const left = names();
  goMap(55, 1, 1); return {left, back: names()}; }));
cases.push(makeCase('battleback.versionReload', {map: 55, common: 1387, versionId: 'changed'}, () => { changed(); roundtrip();
  w.$gameSystem._versionId = -1; w.Scene_File.prototype.reloadMapIfUpdated.call(null);
  const reserved = w.$gamePlayer.isTransferring(); w.DataManager.loadMapData(w.$gamePlayer._newMapId); w.$gamePlayer.performTransfer();
  return {reserved, after: names()}; }));

// 4) 云端审查（dev.049～081）转来的解释器三项（八戒_47）：
//    a) 指令 214 只在 isOnCurrentMap（解释器起跑时的地图＝当前地图）时 eraseEvent：先 201 换图再 214 不消除新图同号事件；
//    b) Game_Event._erased 随 $gameMap 进存档，同版本读档不重设地图，消除的事件读档后仍不出现；同图移动不 setup 也仍消除；
//       换图再回来 setupEvents 重建，恢复出现。Map008 事件 3／5 是只靠 214 消除的副本怪（冻结数据共 131 页这样的事件）。
//    c) 225 勾等待时 wait(时间)：之前由指令直接加进 $gameMessage 的文字（316 升级提示）在等待期间显示，等待结束后才执行下一条；
//       不勾等待时同一帧接着执行下一条。记下一条（122 设变量 1）执行时的帧号与消息是否还在。
const erasedIds = () => w.$gameMap.events().filter(e => e._erased).map(e => e.eventId());
const runList = (list, eventId, max) => { const it = new w.Game_Interpreter(); it.setup(list, eventId); let n = 0;
  while (it.isRunning() && n++ < (max || 100)) { it.update(); if (w.$gamePlayer.isTransferring()) { w.DataManager.loadMapData(w.$gamePlayer._newMapId); w.$gamePlayer.performTransfer(); } }
  return n; };
const cmd = (code, parameters, indent) => ({code, indent: indent || 0, parameters});
const erase8 = () => { newGame(); goMap(8, 29, 26); runList([cmd(214, []), cmd(0, [])], 3); return erasedIds(); };
cases.push(makeCase('erase.save', {map: 8, event: 3}, () => { const after = erase8(); roundtrip();
  return {after, loaded: erasedIds(), map: w.$gameMap.mapId()}; }));
cases.push(makeCase('erase.sameMap', {map: 8, event: 3, transfer: 8}, () => { erase8(); roundtrip(); goMap(8, 28, 26);
  return {after: erasedIds()}; }));
cases.push(makeCase('erase.otherMap', {map: 8, event: 3, transfer: 4}, () => { erase8(); roundtrip(); goMap(4, 14, 23); goMap(8, 29, 26);
  return {back: erasedIds()}; }));
cases.push(makeCase('erase.afterTransfer', {map: 4, event: 3, transfer: 8}, () => { newGame(); goMap(4, 14, 23);
  runList([cmd(201, [0, 8, 29, 26, 2, 0]), cmd(214, []), cmd(0, [])], 3); return {map: w.$gameMap.mapId(), after: erasedIds()}; }));

// 5) 同图场所移动（八戒_48）：performTransfer 只在新地图 ID 与当前不同（或 _needsMapReload）时 $gameMap.setup，
//    同图只 locate 玩家（含跟随者 synchronize、makeEncounterCount）；事件对象、位置、朝向、强制移动路线及其索引、
//    当前页、事件自己的（并行）解释器与地图解释器都原样保留。换到别图再回来 setupEvents 重建，全部回到初始。
//    Map008 事件 3（17,8）／6（26,13）都是固定不动的副本怪：先改位置朝向、挂一条强制路线并推进到第 2 步、
//    给事件 3 挂一个停在等待里的解释器（模拟并行事件），再由事件 7 的解释器执行同图 201。
const evState = id => { const e = w.$gameMap.event(id); return {x: e.x, y: e.y, d: e.direction(), page: e._pageIndex,
  forcing: !!e._moveRouteForcing, routeIndex: e._moveRouteIndex, route: e._moveRoute ? e._moveRoute.list.length : 0,
  interp: e._interpreter ? {index: e._interpreter._index, wait: e._interpreter._waitCount} : null}; };
const dressEvents = () => { const route = {list: [cmd(12, []), cmd(12, []), cmd(12, []), cmd(0, [])], repeat: false, skippable: true, wait: false};
  const marks = {};
  for (const id of [3, 6]) { const e = w.$gameMap.event(id); e.setPosition(e.x + 1, e.y); e.setDirection(8);
    e.forceMoveRoute(w.JsonEx.makeDeepCopy(route)); e._moveRouteIndex = 2; marks[id] = e; }
  const it = new w.Game_Interpreter(); it.setup([cmd(230, [600]), cmd(0, [])], 3); it.update(); w.$gameMap.event(3)._interpreter = it;
  return marks; };
const playerState = () => ({x: w.$gamePlayer.x, y: w.$gamePlayer.y, d: w.$gamePlayer.direction(),
  followers: w.$gamePlayer.followers()._data.map(f => [f.x, f.y, f.direction()])});
cases.push(makeCase('transfer.sameMap.events', {map: 8, events: [3, 6], runner: 7, transfer: [8, 28, 26, 4]}, () => {
  newGame(); goMap(8, 29, 26); const marks = dressEvents(), mapInterp = w.$gameMap._interpreter;
  const before = {3: evState(3), 6: evState(6)};
  runList([cmd(201, [0, 8, 28, 26, 4, 0]), cmd(0, [])], 7);
  return {map: w.$gameMap.mapId(), before, after: {3: evState(3), 6: evState(6)},
    sameObjects: [3, 6].map(id => w.$gameMap.event(id) === marks[id]), sameMapInterpreter: w.$gameMap._interpreter === mapInterp,
    player: playerState()}; }));
cases.push(makeCase('transfer.otherMap.events', {map: 8, events: [3, 6], transfer: [4, 14, 23, 2], back: [8, 29, 26, 2]}, () => {
  newGame(); goMap(8, 29, 26); const marks = dressEvents();
  goMap(4, 14, 23); goMap(8, 29, 26);
  return {map: w.$gameMap.mapId(), back: {3: evState(3), 6: evState(6)}, sameObjects: [3, 6].map(id => w.$gameMap.event(id) === marks[id]),
    player: playerState()}; }));
for (const wait of [true, false])
  cases.push(makeCase('flush.225.' + (wait ? 'wait' : 'nowait'), {actor: 1, shake: [5, 5, 10, wait]}, () => { newGame(); w.$gameMessage.clear();
    const it = new w.Game_Interpreter(); it.setup([cmd(316, [0, 1, 0, 0, 1, true]), cmd(225, [5, 5, 10, wait]), cmd(122, [1, 1, 0, 0, 1]), cmd(0, [])], 0);
    let frame = 0, at = null;
    while (it.isRunning() && frame < 100) { frame++; it.update(); if (at === null && w.$gameVariables.value(1) === 1) at = {frame, busy: w.$gameMessage.isBusy()}; }
    return {lines: w.$gameMessage._texts.slice(), varSet: at, level: w.$gameActors.actor(1).level}; }));

const lose = (troop, canLose, dead) => { newGame(); w.BattleManager.setup(troop, false, canLose); w.$gameParty._inBattle = true;
  const members = w.$gameParty.battleMembers();
  members.forEach((a, i) => { if (dead.includes(i)) a.addState(1); else a.setHp(Math.floor(a.mhp / 2)); });
  const scene = w.SceneManager.goto; w.SceneManager.goto = () => {};
  try { w.BattleManager.endBattle(2); w.BattleManager.updateBattleEnd(); } finally { w.SceneManager.goto = scene; }
  return {canLose: !!w.BattleManager._canLose, hp: members.map(a => a.hp), mhp: members.map(a => a.mhp), dead: members.map(a => a.isDead())}; };
for (const [id, troop, canLose, dead] of [['770.all', 770, true, [0, 1, 2, 3]], ['903.all', 903, true, [0, 1, 2, 3]],
  ['770.partial', 770, true, [0, 2]], ['770.cannot', 770, false, [0, 1, 2, 3]]])
  cases.push(makeCase('lose.' + id, {troop, canLose, dead}, () => lose(troop, canLose, dead)));

process.exit(finish(host, 'review_fix.json', {hostScope: '真实 CodexDamage.calculate（preview）与 BattleManager.endBattle／updateBattleEnd；SceneManager.goto 置空', cases}) ? 0 : 1);
