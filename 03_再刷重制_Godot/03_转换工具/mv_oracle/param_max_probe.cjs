'use strict';
// 【cc·哪吒·未经审查】角色能力末尾夹值（八戒 toji2 报）：云裳 installNativeYunshangRuntime 的 Game_Actor.param 包装对所有角色
// 最后 round(max(HP?1:0, min(paramMax, v)))。它装在专属模块（米拉、黄泉、甚尔、宿傩、饿狼、导入平衡）之后、异化与种族之前，
// 所以专属倍率乘过 99999999 的会被压回上限；饿狼的 paramMax 是 999999999999。
// 用例：甚尔 171 学 10205 暴君、99 级，各项加值 9e7（G_StateParam 先夹到 99999999，暴君再 ×(1+等级×0.1)）；同一配置不学暴君（对照）；
// 饿狼 173 加值 9e11；角色 1 加值 2e8（没有专属模块）。只在内存，产物 .sandbox/param_max.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const realmArray = values => { const out = w.eval('[]'); for (const v of values) out.push(v); return out; };
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
const VARIANTS = [
  ['toji_tyrant', {actor: 171, level: 99, plus: 9e7, learn: [10205]}],
  ['toji_plain', {actor: 171, level: 99, plus: 9e7, learn: []}],
  ['toji_low', {actor: 171, level: 99, plus: 1e5, learn: [10205]}],
  ['garou_over', {actor: 173, level: 1, plus: 9e11, learn: []}],
  ['actor1_over', {actor: 1, level: 1, plus: 2e8, learn: []}],
];
const cases = [];
for (const [name, cfg] of VARIANTS) {
  cases.push(makeCase(`cap.${name}`, cfg, () => {
    newGame();
    w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
    const a = bare(cfg.actor);
    if (cfg.level > 1) a.changeLevel(cfg.level, false);
    for (const s of cfg.learn) a.learnSkill(s);
    for (let i = 0; i < 8; i++) a._paramPlus[i] = cfg.plus;
    settle(a);
    a._hp = a.mhp;
    return {param: Array.from({length: 8}, (_, i) => a.param(i)), max: Array.from({length: 8}, (_, i) => a.paramMax(i)), level: a.level,
      skills: a._skills.slice()};
  }));
}
process.exitCode = finish(host, 'param_max.json', {scope: 'actor final param clamp (Yunshang wrapper) after native modules', cases}) ? 0 : 1;
process.exit();
