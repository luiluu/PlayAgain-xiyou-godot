'use strict';
// 【Claude·悟空·未经审查】战斗核心缺口定向参照：① 百分比 MP 消耗（YEP_SkillCore <MP Cost: x%>，经 dsPassive 减耗、
// installSkillCostRuntime 的 −100% 下限）进实扣 skillMpCost；② 角色能力上限（YEP_CoreEngine Actor MaxHP/MaxMP/Parameter＝99999999，
// G_StateParam 在 paramMax 处夹；饿狼 173 的 paramMax 包装放到 999999999999）；③ 技能 HP 费用（<HP Cost: n>／<HP Cost: n%>）；
// ④ 战斗经验与金钱（makeRewards 的 ×8／×5、难度倍率是否生效、passiveGRUP 连乘、金钱双倍、神话）。
// 真实冻结插件、全内存新局；只写 .sandbox/battle_gaps.json，拷成 tests/fixtures/battle_gaps_oracle.json（不接入全量同步）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const realmArray = values => { const out = w.eval('[]'); for (const v of values) out.push(v); return out; };
function state(note, traits) {
  const st = w.JsonEx.makeDeepCopy(w.$dataStates[4]);
  Object.assign(st, {id: w.$dataStates.length, name: '战斗缺口参照', traits: realmArray(traits || []), note, meta: {}, restriction: 0});
  for (const key in st.customEffectEval) st.customEffectEval[key] = '';
  w.DataManager.extractMetadata(st); w.$dataStates.push(st); return st.id;
}
function bare(id) {
  const a = w.$gameActors.actor(id);
  a._skills = realmArray([]); a._states = realmArray([]); a._equips.forEach(x => x.setObject(null));
  a._paramPlus = realmArray([0, 0, 0, 0, 0, 0, 0, 0]);
  return a;
}
function settle(a) {
  a.need_refresh = true;
  a.need_refresh_param = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
  a.refresh(); if (a.initPassiveCache) a.initPassiveCache(); a.refreshPassiveCache();
}
newGame();
const cases = [];
// ---- ① 百分比 MP 消耗 ----
const percentSkills = w.$dataSkills.filter(s => s && Number(s.mpCostPer) > 0).map(s => s.id);
const COST_VARIANTS = [
  ['base', {mmpPlus: 0, notes: []}],
  ['bigMp', {mmpPlus: 87654, notes: []}],
  ['mcr', {mmpPlus: 87654, mcr: 0.63, notes: []}],
  ['reduce', {mmpPlus: 87654, notes: ['<ConsumeReduceAll:30>']}],
  ['penalty', {mmpPlus: 87654, notes: ['<ConsumeReduceAll:-600>']}],   // 挑战加耗：百分比部分下限 −100%
];
// 备注写法边界：7225「<MP Cost: 7.5%>」原版认不出（比例 0）；9944「<TP Cost: 200>」改基础 TP
const NOTE_SKILLS = [7225, 9944];
for (const [name, cfg] of COST_VARIANTS) for (const id of percentSkills.concat(name === 'bigMp' ? NOTE_SKILLS : [])) {
  cases.push(makeCase(`cost.${name}.${id}`, {actor: 1, skill: id, ...cfg}, () => {
    newGame(); const a = bare(1);
    a._paramPlus[1] = cfg.mmpPlus;
    a._states = realmArray(cfg.notes.map(n => state(n)));
    if (cfg.mcr !== undefined) Object.defineProperty(a, 'mcr', {get: () => cfg.mcr, configurable: true});
    settle(a);
    const sk = w.$dataSkills[id];
    return {mp: a.skillMpCost(sk), tp: a.skillTpCost(sk), mmp: a.mmp, maxTp: a.maxTp(), mpCost: sk.mpCost, mpCostPer: sk.mpCostPer, tpCost: sk.tpCost, tpCostPer: sk.tpCostPer, stypeId: sk.stypeId};
  }));
}
// ---- ② 能力上限 ----
const CAP_VARIANTS = [
  ['under', {actor: 1, plus: 5e7, rate: 1}],
  ['plusOver', {actor: 1, plus: 2e8, rate: 1}],
  ['rateOver', {actor: 1, plus: 3e7, rate: 10}],     // 加值未过上限，比率叠满后过
  ['garou', {actor: 173, plus: 2e8, rate: 10}],      // 饿狼上限 999999999999
  ['garouOver', {actor: 173, plus: 9e11, rate: 10}],
];
for (const [name, cfg] of CAP_VARIANTS) {
  cases.push(makeCase(`cap.${name}`, cfg, () => {
    newGame(); const a = bare(cfg.actor);
    for (let i = 0; i < 8; i++) a._paramPlus[i] = cfg.plus;
    if (cfg.rate !== 1) a._states = realmArray([state('', Array.from({length: 8}, (_, i) => ({code: 21, dataId: i, value: cfg.rate})))]);
    settle(a);   // 不 recoverAll：它清状态，而 krz 的状态缓存不跟着清，比率会残留
    return {param: Array.from({length: 8}, (_, i) => a.param(i)), max: Array.from({length: 8}, (_, i) => a.paramMax(i)), mhp: a.mhp, mmp: a.mmp};
  }));
}
// ---- ③ HP 费用（YEP_SkillCore skillHpCost／canPaySkillHpCost／paySkillHpCost）----
// 角色 1 生命上限加 5000；生命取 满／等于费用／费用＋1 时能否付（canPaySkillCost，MP／TP 都满），满血时付费后的生命（paySkillCost）
const hpSkills = w.$dataSkills.filter(s => s && (Number(s.hpCost) > 0 || Number(s.hpCostPer) > 0)).map(s => s.id);
for (const id of hpSkills) {
  cases.push(makeCase(`hp.${id}`, {actor: 1, skill: id, mhpPlus: 5000}, () => {
    newGame(); const a = bare(1); a._paramPlus[0] = 5000; settle(a); a.recoverAll(); a.setTp(100);
    const sk = w.$dataSkills[id], cost = a.skillHpCost(sk), out = {cost, mhp: a.mhp, canPay: {}};
    for (const [k, hp] of [['full', a.mhp], ['equal', cost], ['plus1', cost + 1]]) { a._hp = hp; out.canPay[k] = a.canPaySkillCost(sk); }
    a._hp = a.mhp; a.paySkillCost(sk); out.afterPay = a.hp;
    return out;
  }));
}
// ---- ④ 战斗奖励（BattleManager.makeRewards：rpg_managers 的 gold×5、exp×8；Game_Troop.expTotal／goldTotal 走 deadMembers，
// dsPassiveSkill 的 goldTotal 按出战成员 passiveGRUP 依次连乘、×金钱双倍，GT_EquipSuitCore 再套套装；EliteEnemy 后装的 exp／gold 盖掉 Vitsuno 难度倍率）----
// 全队清技能、装备、状态后按用例学被动；敌人全部倒下（addState 1）再 makeRewards
const REWARD_VARIANTS = [];
for (const d of [1, 2, 3, 5, 10, 13]) for (const t of [1, 173, 300]) REWARD_VARIANTS.push([`d${d}.t${t}`, {difficulty: d, troop: t}]);
REWARD_VARIANTS.push(['grup', {difficulty: 2, troop: 173, skills: {1: [2157, 2235], 8: [351]}}]);
REWARD_VARIANTS.push(['elite', {difficulty: 5, troop: 1, elite: [0]}]);
REWARD_VARIANTS.push(['goldDouble', {difficulty: 3, troop: 300, goldDouble: true, skills: {9: [2575]}}]);
for (const [name, cfg] of REWARD_VARIANTS) {
  cases.push(makeCase(`reward.${name}`, cfg, () => {
    newGame(); w.$gameSystem.setDifficultyId(cfg.difficulty);
    for (const id of [1, 8, 9, 10]) {
      const a = bare(id);
      for (const sid of (cfg.skills || {})[id] || []) a.learnSkill(sid);
      if (cfg.goldDouble && id === 1) a._states = realmArray([state('', [{code: 64, dataId: 4, value: 1}])]);
      settle(a); if (a.refreshPassiveSkillCache) a.refreshPassiveSkillCache();
    }
    w.$gameTroop.setup(cfg.troop);
    const ms = w.$gameTroop.members();
    for (const i of cfg.elite || []) ms[i]._elite = true;
    ms.forEach(e => e.addState(1));
    w.BattleManager.makeRewards(); const rw = w.BattleManager._rewards;
    const grup = w.$gameParty.battleMembers().map(a => { const v = []; a.iteratePassiveSkill('passiveGRUP', m => v.push(Number(m))); return [a.actorId(), v]; });
    return {exp: rw.exp, gold: rw.gold, grup, suitGold: w.$gameParty.equipSuitBonusBResultCal(1000, 1), enemies: ms.map(e => ({id: e.enemyId(), exp: e.exp(), gold: e.gold(), elite: !!e.isElite()}))};
  }));
}
process.exitCode = finish(host, 'battle_gaps.json', {scope: 'percent MP cost in skillMpCost; actor param cap; skill HP cost; battle rewards exp/gold', percentSkills, hpSkills, cases}) ? 0 : 1;
process.exit();
