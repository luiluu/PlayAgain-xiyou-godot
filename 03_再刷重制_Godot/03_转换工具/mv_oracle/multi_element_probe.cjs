'use strict';
// 多属性技能（16 个带 <Multi-Element Rule> 的技能）的结算与属性反弹（防具 4998 <Element Reflect 8: +100%>）。
// multi.*：把 Game_Enemy 的 elementRate 换成固定表、公式固定 1000，去浮动不暴击；让技能的每个属性轮流当最优（2.0，其余 0.5），
//   再加吸收、部分免疫、全免疫、全低抗；amp.*：穿带单属性增幅的防具，全抗性 1，看增幅高的属性是否胜出；
//   rule.*：把 elementMultiRule 改成 0～4 五种，确认标签本身无效（installDamageElementRuntime 接管元素结算）。
//   native.*：技能原公式对真实敌人（去浮动不暴击）。
// reflect.*：Game_Action.itemMrf 的属性反弹率与 invokeAction 走的分支。只在内存跑，产物 .sandbox/multi_element.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');
const SKILLS = [7006, 7007, 7057, 7063, 7319, 7327, 7471, 7472, 7473, 9956, 9959, 9962, 9963, 10007, 10008, 10070];
const DIFFICULTY = 2;
const realm = v => { const o = w.eval('[]'); for (const x of v) o.push(x); return o; };
newGame(); w.$gameSystem.setDifficultyId(DIFFICULTY);  // 只开一局：makeDamageValue 不改全局，每例只重置角色，整份约半分钟
function reset(actorId = 1) {
  const a = w.$gameActors.actor(actorId);
  a._skills = realm([]); a._states = realm([]); a._equips.forEach(x => x.setObject(null));
  a.need_refresh = true; a.refresh(); if (a.initPassiveCache) a.initPassiveCache(); a.refreshPassiveCache(); a.recoverAll();
  return a;
}
const TROOP_MEMBERS = w.$dataTroops[1].members;  // 敌群 1 原成员：native 用例换掉后要还原，否则后面的用例打到别的敌人
function foe(enemyId) {
  w.Math.random = () => 0.99;
  w.$dataTroops[1].members = enemyId ? realm([{enemyId, x: 0, y: 0, hidden: false}]) : TROOP_MEMBERS;
  w.$gameTroop.setup(1);
  w.Math.random = () => 0.5;
  const b = w.$gameTroop.members()[0]; b.clearStates(); b.refresh(); b.refreshPassiveCache();
  return b;
}
const P = w.Game_Enemy.prototype, nativeRate = P.elementRate;
// 公式固定：damage 整份复制回填，防止污染后面的用例
function value(a, b, id, fixed) {
  const s = w.$dataSkills[id], old = s.damage;
  s.damage = Object.assign({}, old, {variance: 0, critical: false}, fixed ? {formula: '1000'} : {});
  try { const act = new w.Game_Action(a); act.setSkill(id); return act.makeDamageValue(b, false); }
  finally { s.damage = old; }
}
function withRates(table, fn) {
  P.elementRate = function (e) { return table[e] === undefined ? 1 : table[e]; };
  try { return fn(); } finally { P.elementRate = nativeRate; }
}
const stats = a => ({level: a.level, atk: a.atk, mat: a.mat});
const elementsOf = (a, id) => { const act = new w.Game_Action(a); act.setSkill(id); return act.getItemElements().slice(); };
const TABLES = {
  absorb: {2: -1, 3: 0.5, 5: 1, 9: 1.5, 1: 0.5},   // 吸收属性不会胜过正伤害
  immune: {2: 0, 3: 1.2},                           // 部分免疫
  allImmune: Object.fromEntries(Array.from({length: 15}, (_, i) => [i + 1, 0])),
  allLow: Object.fromEntries(Array.from({length: 15}, (_, i) => [i + 1, 0.1])),
  allAbsorb: Object.fromEntries(Array.from({length: 15}, (_, i) => [i + 1, -0.5]))
};
const cases = [];
for (const id of SKILLS) {
  const es = elementsOf(reset(), id);
  cases.push(makeCase(`elements.${id}`, {skill: id}, () => ({elements: elementsOf(reset(), id)})));
  for (const best of es) {
    const table = Object.fromEntries(es.map(e => [e, e === best ? 2 : 0.5]));
    cases.push(makeCase(`multi.${id}.best${best}`, {skill: id, table}, () => {
      const a = reset(), b = foe();
      return {value: withRates(table, () => value(a, b, id, true)), enemyLevel: b.level, actor: stats(a)};
    }));
  }
  for (const [name, table] of Object.entries(TABLES)) {
    cases.push(makeCase(`multi.${id}.${name}`, {skill: id, table}, () => {
      const a = reset(), b = foe();
      return {value: withRates(table, () => value(a, b, id, true)), enemyLevel: b.level, actor: stats(a)};
    }));
  }
  // 全抗性 1，增幅只有一项：带状态 122 炽魂（<Element Amplify 2: +15%>），含属性 2 的技能应高出 15%
  cases.push(makeCase(`amp.${id}.state122`, {skill: id, state: 122}, () => {
    const a = reset(), b = foe();
    a._states = realm([122]); a.need_refresh = true; a.refresh(); a.refreshPassiveCache();
    return {value: withRates({}, () => value(a, b, id, true)), amp2: a.elementAmplifyRate(2), enemyLevel: b.level, actor: stats(a)};
  }));
  for (const enemyId of [465, 947]) {
    cases.push(makeCase(`native.${id}.e${enemyId}`, {skill: id, enemy: enemyId}, () => {
      const a = reset(), b = foe(enemyId);
      return {value: value(a, b, id, false), rates: es.map(e => b.elementRate(e)), enemyLevel: b.level, actor: stats(a)};
    }));
  }
}
for (const id of [7006, 9956, 10007]) {
  cases.push(makeCase(`rule.${id}`, {skill: id}, () => {
    const s = w.$dataSkills[id], old = s.elementMultiRule, a = reset(), b = foe(), out = {};
    const table = {2: 2, 3: 0.5, 5: 1, 9: 1.5, 1: 1};
    for (const r of [0, 1, 2, 3, 4]) { s.elementMultiRule = r; out[r] = withRates(table, () => value(a, b, id, true)); }
    s.elementMultiRule = old;
    return {values: out, original: old === undefined ? null : old};
  }));
}
// 反弹：目标是角色 99 小明（4998 的 <req_actors: 099>，别人穿了 refresh 会被脱下）
const REFLECT = {
  magic8: 109, cert8: 743, phys8: 51, cert2multi8: 10007, cert2multi8b: 10008, fire: 7472, multiNo8: 7006
};
const WEARER = 99;
function wearer() {
  const a = reset(WEARER);
  const armor = w.$dataArmors[4998], slot = a.equipSlots().findIndex(t => t === armor.etypeId);
  a._equips[slot].setObject(armor);
  a.need_refresh = true; a.refresh(); a.refreshPassiveCache();
  return a;
}
function branch(act, subject, target) {
  // BattleManager.invokeAction 的分支：只记走哪条，不真结算
  const BM = w.BattleManager, saved = {};
  const hit = [];
  for (const k of ['invokeMagicReflection', 'invokeCounterAttack', 'invokeNormalAction']) {
    saved[k] = BM[k]; BM[k] = function () { hit.push(k); };
  }
  const log = BM._logWindow, oldAction = BM._action;
  BM._logWindow = {push() {}}; BM._action = act;
  w.Math.random = () => 0.5;
  try { BM.invokeAction(subject, target); }
  catch (e) { hit.push('error:' + e.message); }
  finally { Object.assign(BM, saved); BM._logWindow = log; BM._action = oldAction; }
  return hit[0];
}
for (const [name, id] of Object.entries(REFLECT)) {
  cases.push(makeCase(`reflect.${name}`, {skill: id}, () => {
    const a = wearer(), b = foe(), act = new w.Game_Action(b); act.setSkill(id);
    return {worn: a.equips().some(o => o && o.id === 4998), elements: act.getItemElements().slice(), hitType: w.$dataSkills[id].hitType, reflect8: a.elementReflectRate(8), mrf: a.mrf,
      itemMrf: act.itemMrf(a), branch: branch(act, b, a)};
  }));
}
cases.push(makeCase('reflect.unworn', {skill: 109}, () => {
  const a = reset(WEARER), b = foe(), act = new w.Game_Action(b); act.setSkill(109);
  return {reflect8: a.elementReflectRate(8), itemMrf: act.itemMrf(a), branch: branch(act, b, a)};
}));
cases.push(makeCase('reflect.item_data', {armor: 4998}, () => ({elementReflect: JSON.parse(JSON.stringify(w.$dataArmors[4998].elementReflect || {}))})));
process.exit(finish(host, 'multi_element.json', {difficulty: DIFFICULTY, skills: SKILLS, reflectSkills: REFLECT, wearer: WEARER, tables: TABLES, cases}) ? 0 : 1);
