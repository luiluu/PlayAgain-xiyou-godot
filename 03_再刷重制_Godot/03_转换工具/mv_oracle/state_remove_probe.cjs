'use strict';
// 【cc·规则·未经审查】受伤解除与受限解除（审查报告第 8、9 项）：
// - 受伤解除：Game_Action.executeHpDamage 正伤害 → onDamage → removeStatesByDamage（StateChangeIfRemove「受伤解除」包装），
//   带 removeByDamage 的状态按 states() 顺序各掷一次 Math.randomInt(100) < chanceByDamage 就解除；伤害 0 不掷。
// - 受限解除：addNewState 从「未受限」变「受限」（restriction > 0）的那一次 onRestrict：clearActions、去掉 removeByRestriction 的状态；
//   已受限时 isStateRestrict 让 removeByRestriction 的状态加不上。
// 产物 .sandbox/state_remove.json，拷成 tests/fixtures/state_remove_oracle.json（不进同步），专项 xiyou_state_remove。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');
let seq = [0.5], pos = 0, draws = 0;
const rnd = () => { draws++; const v = seq[pos % seq.length]; pos++; return v; };
const setSeq = s => { seq = s; pos = 0; draws = 0; };
const TROOP = 3;
function battle() {
  newGame(); w.Math.random = rnd;
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.$gameSwitches.setValue(2494, true);
  w.eval('$gameParty._actors=[1,8,9,10]; $gameParty._battleMembers=[1,8,9,10,0];');
  for (const id of [1, 8, 9, 10]) w.$gameActors.actor(id).changeLevel(60, false);
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  w.BattleManager.setup(TROOP, false, false);
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) { b._paramPlus[0] = 1e9; b.need_refresh = true; b.refresh(); b.recoverAll(); }
}
const addS = (b, id, turns) => { b.addNewState(id); b._stateTurns[id] = turns; b.need_refresh_states = true; b.need_refresh_stateResistSet = true; b.need_refresh = true; b.refresh(); };
const st = b => b._states.slice().sort((x, y) => x - y);
const unit = side => side === 'actor' ? w.$gameParty.members()[0] : w.$gameTroop.members()[0];
const foe = side => side === 'actor' ? w.$gameTroop.members()[0] : w.$gameParty.members()[0];
// 一次 HP 伤害：真实 executeHpDamage（含各插件包装）
function hit(side, value, s) {
  const t = unit(side), act = new w.Game_Action(foe(side));
  act.setAttack();
  t.clearResult();
  setSeq(s);
  act.executeHpDamage(t, value);
  return {draws, states: st(t), removed: t.result().removedStates.slice().sort((x, y) => x - y)};
}
const DMG = w.$dataStates.filter(s => s && s.removeByDamage).map(s => s.id);
const RES = w.$dataStates.filter(s => s && s.removeByRestriction).map(s => s.id);
const cases = [];
cases.push(makeCase('census', {}, () => ({damage: DMG.map(i => [i, w.$dataStates[i].chanceByDamage, w.$dataStates[i].restriction]), restriction: RES.map(i => [i, w.$dataStates[i].restriction])})));
for (const side of ['actor', 'enemy']) for (const id of DMG) {
  const ch = w.$dataStates[id].chanceByDamage;
  // 恰在阈值下（randomInt＝ch−1，解除）与恰在阈值（randomInt＝ch，保留；ch=100 时没有）
  const vals = [['under', (ch - 1) / 100 + 0.001]];
  if (ch < 100) vals.push(['at', ch / 100 + 0.001]);
  for (const [name, v] of vals) cases.push(makeCase(`damage.${side}.${id}.${name}`, {side, id, v}, () => {
    battle(); addS(unit(side), id, 3);
    return hit(side, 100, [v]);
  }));
}
// 伤害 0／负（回复）不掷
for (const value of [0, -50]) cases.push(makeCase(`damage.enemy.10.value${value}`, {value}, () => {
  battle(); addS(unit('enemy'), 10, 3);
  return hit('enemy', value, [0.0]);
}));
// 两个受伤解除状态：按 states() 顺序各掷一次
for (const s of [[0.0, 0.99], [0.99, 0.0], [0.5, 0.5]]) cases.push(makeCase(`damage.enemy.10+742.${s.join('_')}`, {seq: s}, () => {
  battle(); addS(unit('enemy'), 10, 3); addS(unit('enemy'), 742, 3);
  return {order: unit('enemy')._states.slice(), ...hit('enemy', 100, s)};
}));
// 受限解除：带着 removeByRestriction 的状态，新加一个受限状态
const restrictCase = (name, side, pre, add, extra) => cases.push(makeCase(`restrict.${side}.${name}`, {side, pre, add}, () => {
  battle(); const b = unit(side);
  for (const p of pre) addS(b, p, 3);
  b.makeActions();
  const before = {states: st(b), restricted: b.isRestricted(), actions: b._actions.length, guard: b.isGuard()};
  b.clearResult(); setSeq([0.5]);
  b.addState(add);
  const out = {before, states: st(b), restricted: b.isRestricted(), actions: b._actions.length, guard: b.isGuard(), removed: b.result().removedStates.slice().sort((x, y) => x - y), draws};
  if (extra) Object.assign(out, extra(b));
  return out;
}));
for (const side of ['actor', 'enemy']) {
  for (const r of RES) for (const add of [10, 8, 7]) restrictCase(`${r}+${add}`, side, [r], add);
  // 防御后被晕，再解除晕：不再是防御
  restrictCase('2+10.thenRemove10', side, [2], 10, b => { b.removeState(10); return {afterRemove: {states: st(b), guard: b.isGuard()}}; });
  // 已受限（混乱 8）再加晕：不是第一次受限，不触发；凌波舞 525 留着
  restrictCase('8,525+10', side, [8, 525], 10);
  // 已受限时 removeByRestriction 的状态加不上
  restrictCase('8+2', side, [8], 2);
  restrictCase('8+525', side, [8], 525);
  // 没受限状态的普通状态不触发
  restrictCase('2+3', side, [2], 3);
}
process.exit(finish(host, 'state_remove.json', {hostScope: '受伤解除（removeStatesByDamage）与受限解除（onRestrict、isStateRestrict）', cases}) ? 0 : 1);
