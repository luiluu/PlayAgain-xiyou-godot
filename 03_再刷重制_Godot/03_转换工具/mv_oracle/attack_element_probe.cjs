'use strict';
// 普通攻击（技能 1，elementId −1）的攻击属性：Game_Actor.attackElements 在没装武器时另加空手属性 1（rpg_οbjects.js:3970），
// 敌人只取特性 31（Game_BattlerBase.attackElements，可为空）；installDamageElementRuntime 的 actionElements 据此取属性、
// 多属性时 elementalBonus 取平均（v2 起取最有利的一个）。154 夏娜（角色特性 31 火 2）、158 炮姐（雷 5）、1（无攻击属性特性）
// × 裸装与能装备的物理／无特性 31／火／雷武器；另记 4 个无特性 31 的敌人。普攻公式在内存固定为 1000000、去浮动，
// 对敌群 173 首个敌人与几个属性抗性不同的敌人量 makeDamageValue。只在内存跑，产物 .sandbox/attack_elements.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
newGame();
w.eval('CodexZones.ENABLED=false;');
w.$gameSystem.setDifficultyId(3);
const item = w.$dataSkills[1];
item.damage.formula = '1000000'; item.damage.variance = 0;
// 敌群 173 首个敌人（同 settlement_probe），再加火／雷抗性各不为 1 的第一个敌人
const rate = (e, id) => (e.traits || []).filter(t => t.code === 11 && t.dataId === id).reduce((s, t) => s * t.value, 1);
const pick = id => w.$dataEnemies.findIndex(e => e && e.name && e.traits.some(t => t.code === 31) && rate(e, id) !== 1);
const TARGETS = [...new Set([0, pick(2), pick(5)])];
// 每人按能装备（canEquip，50 级）且不替换普攻（<Replace Attack>）挑武器：只带物理／无特性 31／火／雷 各取编号最小的一件
const elementsOf = o => o.traits.filter(t => t.code === 31).map(t => t.dataId);
const CATEGORY = {physical: es => es.length === 1 && es[0] === 1, noElement: es => !es.length, fire: es => es.length === 1 && es[0] === 2,
  thunder: es => es.length === 1 && es[0] === 5};
function weaponsFor(a) {
  const out = {naked: 0};
  for (const [name, ok] of Object.entries(CATEGORY)) {
    const o = w.$dataWeapons.find(o => o && o.name && !o.meta['Replace Attack'] && ok(elementsOf(o)) && a.canEquip(o));
    if (o) out[name] = o.id;
  }
  return out;
}
function target(enemyId) {
  w.Math.random = () => 0.99;
  if (enemyId) { w.$dataTroops[1].members = [{enemyId, x: 0, y: 0, hidden: false}]; w.$gameTroop.setup(1); }
  else w.$gameTroop.setup(173);
  w.Math.random = () => 0.5;
  const b = w.$gameTroop.members()[0]; b.clearStates(); b.refresh(); b.refreshPassiveCache();
  return b;
}
const cases = [];
const WEAPONS = {};
for (const actorId of [154, 158, 1]) {
  const probe = new w.Game_Actor(actorId); probe.changeLevel(50, false);
  WEAPONS[actorId] = weaponsFor(probe);
}
for (const actorId of [154, 158, 1]) for (const [variant, weaponId] of Object.entries(WEAPONS[actorId])) {
  cases.push(makeCase(`a${actorId}-${variant}`, {actor: actorId, weapon: weaponId, level: 50}, () => {
    const a = new w.Game_Actor(actorId); w.$gameActors._data[actorId] = a;  // Game_Action.subject() 按角色 ID 取人
    a.changeLevel(50, false);
    a._equips.forEach((e, i) => e.setObject(i === 0 && weaponId ? w.$dataWeapons[weaponId] : null));
    a._skills = []; a.clearStates(); a.initPassiveCache(); a.refreshPassiveCache();
    a.need_refresh = true; a.refresh();
    const act = new w.Game_Action(a); act.setAttack();
    const out = {attackElements: a.attackElements().slice(), itemElements: act.getItemElements().slice(), hasNoWeapons: a.hasNoWeapons(), level: a.level, damage: []};
    for (const t of TARGETS) {
      const b = target(t);
      out.damage.push({enemy: b.enemyId(), level: b.level, value: act.makeDamageValue(b, false)});
    }
    return out;
  }));
}
for (const enemyId of [465, 926, 947, 1999]) {
  cases.push(makeCase(`e${enemyId}`, {enemy: enemyId}, () => {
    const b = target(enemyId), act = new w.Game_Action(b); act.setAttack();
    return {attackElements: b.attackElements().slice(), itemElements: act.getItemElements().slice()};
  }));
}
process.exit(finish(host, 'attack_elements.json', {targets: TARGETS, weapons: WEAPONS, cases}) ? 0 : 1);
