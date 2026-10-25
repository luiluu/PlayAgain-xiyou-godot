'use strict';
// 四零散项：原版真实消耗查询、死亡入口、敌人元素 ownBonus；全程内存，输出仅 .sandbox。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const sprites = new Map();
w.Game_Battler.prototype.battler = function () {
  if (!sprites.has(this)) sprites.set(this, new Proxy({}, {get: (t, k) => k in t ? t[k] : (() => false), set: (t, k, v) => {t[k] = v; return true;}}));
  return sprites.get(this);
};
newGame();
const cases = [];
function realmArray(values) { const out = w.eval('[]'); for (const value of values) out.push(value); return out; }
function state(note) {
  const st = w.JsonEx.makeDeepCopy(w.$dataStates[4]);
  Object.assign(st, {id: w.$dataStates.length, name: '四零散参照', traits: [], note, meta: {}, restriction: 0});
  for (const key in st.customEffectEval) st.customEffectEval[key] = '';
  w.DataManager.extractMetadata(st); w.$dataStates.push(st); return st.id;
}
const a = w.$gameActors.actor(1);
a._skills = realmArray([]); a._states = realmArray([]); a._equips.forEach(x => x.setObject(null));
Object.defineProperty(a, 'mcr', {get: () => 0.63, configurable: true});
const variants = [
  ['base', []], ['all', ['<ConsumeReduceAll:10>']],
  ['type', ['<ConsumeReduceZj:20>\n<ConsumeReduceMf:35>']],
  ['skill', ['<ConsumeReduce12:17>']],
  ['sum', ['<ConsumeReduceAll:10>\n<ConsumeReduceZj:20>\n<ConsumeReduce12:17>', '<ConsumeReduceAll:7>']],
  ['cap', ['<ConsumeReduceAll:130>']], ['negative', ['<ConsumeReduceAll:-25>']],
  ['parseInt', ['<ConsumeReduceAll:12.8%>']],
  ['duplicate', ['<ConsumeReduceAll:10>\n<ConsumeReduceAll:30>']]
];
for (const [name, notes] of variants) for (const stypeId of [1, 2, 3]) {
  cases.push(makeCase('cost.' + name + '.' + stypeId, {notes, mcr: 0.63, skill: {id: 12, stypeId, mpCost: 37, tpCost: 19}}, () => {
    a._states = realmArray(notes.map(state)); a.need_refresh = true; a.refresh(); a.refreshPassiveCache();
    const skill = Object.assign({}, w.$dataSkills[12], {id: 12, stypeId, mpCost: 37, tpCost: 19});
    return {mp: a.skillMpCost(skill), tp: a.skillTpCost(skill), cache: w.JsonEx.makeDeepCopy(a._passiveCache.consumeReduce), states: a.states().map(st => ({id: st.id, meta: st.meta}))};
  }));
}
w.$gameParty._inBattle = true;
function enemy() {
  w.$gameSystem.clearDefeatNumber(); w.BattleManager.setup(2, true, true); return w.$gameTroop.members()[0];
}
const count = e => w.$gameSystem.defeatNumber(e.enemyId());
cases.push(makeCase('death.hpAndQueries', {}, () => {
  const e = enemy(); e.gainHp(-e.hp); const first = count(e);
  for (let i = 0; i < 8; i++) { e.isDead(); e.isAlive(); }
  const afterQueries = count(e); e.removeState(1); e.setHp(1); e.clearResult(); e.gainHp(-1);
  return {enemyId: e.enemyId(), first, afterQueries, second: count(e)};
}));
cases.push(makeCase('death.explicitState', {}, () => {
  const e = enemy(); e.addState(1); const first = count(e); e.addState(1);
  return {enemyId: e.enemyId(), first, afterReapply: count(e)};
}));
cases.push(makeCase('death.refreshAndTransform', {}, () => {
  const e = enemy(); const id = e.enemyId(); e.setHp(0); const first = count(e);
  e.refresh(); const afterRefresh = count(e); e.transform(w.$dataTroops[3].members[0].enemyId);
  return {enemyId: id, otherId: e.enemyId(), first, afterRefresh, original: w.$gameSystem.defeatNumber(id), transformed: count(e)};
}));
for (const [name, notes] of [['actual932', []], ['duplicates', ['<passiveELUP02:10%>\n<passiveELUP02:20%>']], ['caseAndPadding', ['<PASSIVEELUP2:13%>\n<passiveELUP02:7%>']]]) {
  cases.push(makeCase('bonus.' + name, {enemyId: 932, notes}, () => {
    const e = new w.Game_Enemy(932, 0, 0); e._states = realmArray(notes.map(state)); e.need_refresh = true; e.refresh();
    return {values: Array.from({length: 15}, (_, i) => w.CodexElements.bonus(e, i + 1))};
  }));
}
cases.push(makeCase('cost.enemyNotReduced', {}, () => {
  const e = enemy(); e._states = realmArray([state('<ConsumeReduceAll:100>')]); e.refreshPassiveCache();
  const skill = Object.assign({}, w.$dataSkills[12], {mpCost: 37, tpCost: 19});
  return {mp: e.skillMpCost(skill), tp: e.skillTpCost(skill), mcr: e.mcr};
}));
process.exit(finish(host, 'loose_fixes.json', {hostScope: '一局内存宿主；合成状态仅覆盖消耗与ownBonus解析边界，真实敌群2死亡与真实敌人932；不认证全部玩法', cases}) ? 0 : 1);
