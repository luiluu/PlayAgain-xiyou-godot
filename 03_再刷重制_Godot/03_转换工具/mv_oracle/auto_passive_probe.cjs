'use strict';
// YEP_AutoPassiveStates（自动被动状态）与套装状态排序参照（rules-autopassive1）。
// 原版 plugins.js 里 YEP_AutoPassiveStates 是停用的（v0.28、v0.62.12 都是 status:false），所以 <Passive State: n> 标签不生效：
// ①插件是否载入、备注里谁带这个标签 ②带标签的装备／技能拿到手后 states() 里有没有对应状态
// ③GT_EquipSuitCore 的 states() 接上套装状态后按优先级降序稳定再排（sortEquipSuitBonusStates）：套装状态与低／同优先级普通状态的先后。
// 只在内存里跑；产物 .sandbox/auto_passive.json（复制到 tests/fixtures/auto_passive_oracle.json）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const fs = require('fs'), path = require('path');
const ids = a => a.states().map(s => s.id);
function fresh(actorId) {
  newGame();
  const a = w.$gameActors.actor(actorId);
  a.clearStates();
  return a;
}
function settle(a) {
  a.need_refresh = true; a.need_refresh_states = true; a._statescache2 = undefined; a._basestatecache = undefined;
  a._passiveStatesRaw = undefined;
  a.refreshEquipSuit();
  a.refresh();
}
// 找一个能装备这件东西的角色（refresh 会卸掉装不了的）
function equipper(item) {
  for (let id = 1; id < w.$dataActors.length; id++) {
    if (!w.$dataActors[id] || !w.$dataActors[id].name) continue;
    const a = w.$gameActors.actor(id);
    if (a && a.canEquip(item)) return id;
  }
  return 0;
}
function wearing(kind, itemId) {
  const item = (kind === 'weapon' ? w.$dataWeapons : w.$dataArmors)[itemId];
  newGame();
  const actorId = equipper(item);
  const a = fresh(actorId);
  const slot = a.equipSlots().indexOf(item.etypeId);
  a._equips[slot].setObject(item);
  settle(a);
  return {a, actorId, slot};
}
const cases = [];
cases.push(makeCase('plugin', {}, () => {
  newGame();
  const list = JSON.parse(fs.readFileSync(path.join(require('./shared/host.cjs').APP, 'js/plugins.js'), 'utf8').replace(/^[^\[]*/, '').replace(/;\s*$/, ''));
  const row = list.find(p => p.name === 'YEP_AutoPassiveStates');
  return {status: row ? row.status : null, imported: !!w.Imported.YEP_AutoPassiveStates,
    passiveStatesFn: typeof w.Game_BattlerBase.prototype.passiveStates, passiveStatesRawFn: typeof w.Game_Actor.prototype.passiveStatesRaw,
    meetConditionFn: typeof w.Game_BattlerBase.prototype.meetPassiveStateCondition};
}));
cases.push(makeCase('census', {}, () => {
  newGame();
  const out = [];
  for (const [t, table] of [['actors', w.$dataActors], ['classes', w.$dataClasses], ['weapons', w.$dataWeapons], ['armors', w.$dataArmors],
    ['skills', w.$dataSkills], ['items', w.$dataItems], ['enemies', w.$dataEnemies], ['states', w.$dataStates]]) {
    for (const o of table) {
      if (!o || !o.note) continue;
      const m = o.note.match(/<passive states?:[^>]*>/ig);
      if (m) out.push({table: t, id: o.id, name: o.name, tags: m, parsed: o.passiveStates === undefined ? null : o.passiveStates});
    }
  }
  return out;
}));
for (const [id, kind, itemId, state] of [['weapon79', 'weapon', 79, 1640], ['armor49', 'armor', 49, 2498], ['armor3834', 'armor', 3834, 2498]]) {
  cases.push(makeCase(id, {kind, itemId, state}, () => {
    const {a, actorId, slot} = wearing(kind, itemId);
    const eq = a.equips()[slot];
    return {actorId, slot, equipped: eq ? eq.id : null, states: ids(a), affected: a.isStateAffected(state)};
  }));
}
cases.push(makeCase('skill7769', {skillId: 7769, state: 1347}, () => {
  const a = fresh(1);
  a.learnSkill(7769); settle(a);
  const inBattle = w.$gameParty._inBattle; w.$gameParty._inBattle = true;
  settle(a);
  const battle = {states: ids(a), affected: a.isStateAffected(1347)};
  w.$gameParty._inBattle = inBattle;
  return {hasSkill: a.hasSkill(7769), states: ids(a), affected: a.isStateAffected(1347), battle};
}));
// 套装 8 缝合小刀：防具 487 一件即给状态 38（优先级 50）
for (const [id, normal] of [['suit.lower', [170]], ['suit.same', [11]], ['suit.none', []], ['suit.mixed', [170, 27]]]) {
  cases.push(makeCase(id, {armorId: 487, normal}, () => {
    const {a, actorId} = wearing('armor', 487);
    if (normal.length) { normal.forEach(n => a.addState(n)); settle(a); }
    return {actorId, suitStates: a._equipSuitsStateIDs.slice(), states: a.states().map(s => [s.id, s.priority])};
  }));
}
process.exitCode = finish(host, 'auto_passive.json', {scope: 'YEP_AutoPassiveStates disabled in plugins.js; GT_EquipSuitCore states() resorts by priority after suit states', cases}) ? 0 : 1;
process.exit();
