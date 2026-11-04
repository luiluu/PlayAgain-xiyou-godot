'use strict';
// 【cc·悟空·未经审查】被控回合（审查 35b 后续）：真实 BattleManager.processTurn 下，不能行动的角色走 OTB startOTBInput→makeActions→startAction（没有行动）→endAction，
// 敌人走 YEP processTurn（不 startAction）。各专属角色先正常打一下，再上睡眠 10 和行动结束减回合的伏虎 303，记这一回合前后的变化：
// 生命、魔法、TP、状态与回合数、增益、敌人生命，以及角色自身字段（own，只作证据，重制字段不同不比）。
// 产物 .sandbox/stunned_turn.json，拷成 tests/fixtures/stunned_turn_oracle.json（不进同步），专项 xiyou_stunned_turn。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');
const stub = new Proxy(function () {}, {get: (_, k) => k === '_waitCount' ? 0 : (() => false), set: () => true});
const sprites = new Map();
w.Game_Battler.prototype.battler = function () {
  if (!sprites.has(this)) sprites.set(this, new Proxy({x: 0, y: 0, _homeX: 0, _homeY: 0, width: 64, height: 64, scale: {x: 1, y: 1}, anchor: {x: 0.5, y: 1}, opacity: 255},
    {get: (t, k) => k in t ? t[k] : (() => false), set: (t, k, v) => {t[k] = v; return true;}}));
  return sprites.get(this);
};
w.BattleManager.actionBattleHud = () => true;
w.BattleManager.otbDisplayWindow = () => stub;
if (!w.$) w.$ = {};
w.$.toaster = () => {};
w.Math.random = () => 0.5;
const SLEEP = 10, TICK = 303, TROOP = 3;
function battle(id) {
  newGame();
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.$gameSwitches.setValue(2494, true);
  const party = id === 1 ? [1, 8, 9, 10] : [id, 1, 8, 9];
  w.eval(`$gameParty._actors=[${party}]; $gameParty._battleMembers=[${party},0];`);
  const u = w.$gameActors.actor(id);
  u.changeLevel(60, false);
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.SceneManager._scene = {_otbDisplayWindow: stub};
  for (const t of w.$gameTroop.members()) t._paramPlus[0] = 1e9;
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  bm.startBattle(); bm.startTurn(); bm._phase = 'turn';
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) b.recoverAll();
  return {bm, u};
}
function run(bm) {
  for (let i = 0; i < 20000; i++) {
    const ph = bm._phase;
    if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
    else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
  }
  bm._phase = 'turn';
}
function attack(bm, u) {
  const a = new w.Game_Action(u); a.setAttack(); a.setTarget(0);
  u._actions = [a]; bm._subject = u; bm._action = null; bm.startAction(); run(bm);
}
const read = b => ({hp: b.hp, mp: b.mp, tp: b.tp, states: b._states.slice().sort((x, y) => x - y).map(s => [s, b._stateTurns[s] == null ? null : b._stateTurns[s]]), buffs: b._buffs.slice()});
const own = b => { const o = {}; for (const k of Object.keys(b)) if (/^_(garou|sukuna|codex|toji|yun|raven|jingliu|yomi|tusu|guyu|mira|alien)/i.test(k)) { try { o[k] = JSON.stringify(b[k]); } catch (e) { o[k] = '?'; } } return o; };
const foes = () => w.$gameTroop.members().map(e => e.hp);
const diffOwn = (x, y) => Object.keys({...x, ...y}).filter(k => x[k] !== y[k]).map(k => [k, x[k] === undefined ? null : x[k].slice(0, 200), y[k] === undefined ? null : y[k].slice(0, 200)]);
const cases = [];
const ACTORS = {garou: 173, sukuna: 172, jingliu: 170, yomi: 169, toji: 171, raven: 167, yunshang: 174, xuan: 177, tusu: 176, guyu: 175, mira: 168, nanoha: 108, plain: 1};
for (const [name, id] of Object.entries(ACTORS)) cases.push(makeCase('actor.' + name, {id}, () => {
  const {bm, u} = battle(id);
  attack(bm, u);
  u.addNewState(SLEEP); u._stateTurns[SLEEP] = 3; u.addNewState(TICK); u._stateTurns[TICK] = 3; u.refresh();  // addNewState：甚尔免疫睡眠，这里只要它不能行动
  const a0 = read(u), f0 = foes(), o0 = own(u);
  u._actions = []; bm._subject = u; bm._action = null; bm._phase = 'turn';
  bm.processTurn();
  run(bm);
  return {canMove: u.canMove(), before: a0, after: read(u), foes0: f0, foes1: foes(), own: diffOwn(o0, own(u))};
}));
// 敌人对照：不能行动不减行动结束的回合（YEP _processTurn）
cases.push(makeCase('enemy.sleep', {}, () => {
  const {bm} = battle(1), e = w.$gameTroop.members()[0];
  e.addState(SLEEP); e._stateTurns[SLEEP] = 3; e.addState(TICK); e._stateTurns[TICK] = 3;
  const a0 = read(e);
  e._actions = []; bm._subject = e; bm._action = null; bm._phase = 'turn';
  bm.processTurn();
  run(bm);
  return {canMove: e.canMove(), before: a0, after: read(e)};
}));
// 敌人跳过的回合不走 endAction：连命的 syncRelations 不跑。这里绕过 gainHp 直接写队友生命制造不同步，看这一回合会不会被拉回来
cases.push(makeCase('gate.lifelink', {}, () => {
  const {bm, u} = battle(1), AL = w.CodexAlienation, mate = w.$gameActors.actor(8), e = w.$gameTroop.members()[0];
  const item = AL.create('w', 1044, 'boss', 'lifelink');
  AL.mark(item).config = {actorId: 1, partnerId: 8};
  u._equips[0].setObject(item);
  AL.lockParty();
  mate._hp = 1;
  const a0 = [u.hp, mate.hp];
  e._actions = []; bm._subject = e; bm._action = null; bm._phase = 'turn';
  bm.processTurn();
  run(bm);
  return {has: AL.has(u, 'lifelink'), before: a0, after: [u.hp, mate.hp]};
}));
process.exit(finish(host, 'stunned_turn.json', {hostScope: '真实 processTurn 下被控角色与敌人的这一回合', cases}) ? 0 : 1);
