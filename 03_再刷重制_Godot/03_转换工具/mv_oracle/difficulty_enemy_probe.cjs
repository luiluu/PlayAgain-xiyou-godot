'use strict';
// 难度验收（nezha accept2）：难度 1～9（宝宝～混沌）× 一批敌人，原版 Game_Enemy 的最终能力值（param／xparam／sparam）、等级、
// exp()／gold()（O-130 前：难度经验金钱倍率被后装 EliteEnemy 盖掉）、dropItemRate、掉出件数分段概率。
// slice_probe 只覆盖难度 1～6 的切片敌群；这里补 7 灭世、8 洪荒、9 混沌，并抽样比六难度之外的敌人与奖励。
// 敌人：非神话（Math.random=0.99 建对象）与神话（0）各一份；队伍 [1,8,9,10] 1 级，等级随机取 0.99。
// 产物 .sandbox/difficulty_enemy.json（generated/oracle/difficulty_enemy.json，tests/xiyou_difficulty_enemy 读）。
const {start, makeCase, finish, round} = host0();
function host0() { return require('./shared/host.cjs'); }
const host = start(), {w, newGame} = host;
const P = ['mhp', 'mmp', 'atk', 'def', 'mat', 'mdf', 'agi', 'luk'];
const X = ['hit', 'eva', 'cri', 'cev', 'mev', 'mrf', 'cnt', 'hrg', 'mrg', 'trg'];
const S = ['tgr', 'grd', 'rec', 'pha', 'mcr', 'tcr', 'pdr', 'mdr', 'fdr', 'exr'];
const snap = b => ({param: P.map(k => b[k]), xparam: X.map(k => round(b[k])), sparam: S.map(k => round(b[k]))});
// 抽样：前几个常用 + 全库等距 + 带 boss 备注的几只
const all = w.$dataEnemies.filter(e => e && e.name);
const ids = new Set([1, 3, 6, 16, 193, 214]);
for (let i = 0; i < all.length; i += Math.max(1, Math.floor(all.length / 14))) ids.add(all[i].id);
all.filter(e => /boss/i.test(e.note || '')).slice(0, 6).forEach(e => ids.add(e.id));
const enemyIds = [...ids].filter(i => w.$dataEnemies[i] && w.$dataEnemies[i].name).sort((a, b) => a - b);
function count(e, r) {
  const old = w.Math.random;
  w.Math.random = () => r;
  e._treasure = undefined;
  try { return e.makeDropItems().length; } finally { w.Math.random = old; }
}
function chances(e) {
  const most = count(e, 0), out = [];
  for (let k = 1; k <= most; k++) {
    let lo = 0, hi = 1;
    for (let n = 0; n < 36; n++) { const mid = (lo + hi) / 2; if (count(e, mid) >= k) lo = mid; else hi = mid; }
    out.push(round(lo));
  }
  return out;
}
const cases = [];
for (let d = 1; d <= 9; d++) {
  // 每个难度只开一次新局（newGame 约 0.7 秒，原来每例一次占了探针九成多的时间；diff2 提速）：
  // 各例只建敌人、不改全局状态，难度、开关、出战成员每例照旧重设。
  newGame();
  for (const id of enemyIds) {
    for (const elite of [false, true]) {
      cases.push(makeCase(`diffenemy.d${d}.e${id}.${elite ? 'elite' : 'plain'}`, {difficulty: d, enemy: id, elite}, () => {
        w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
        w.$gameSwitches.setValue(2494, true);  // 同 battle_drop_probe：掉率链的开关
        w.$gameSystem.setDifficultyId(d);
        w.eval('$gameParty._actors=[]; $gameParty._battleMembers=[0,0,0,0,0];');
        [1, 8, 9, 10].forEach(a => w.$gameParty.addActor(a));  // 同 battle_drop_probe：出战成员要重建，掉率链读出战成员的被动
        w.Math.random = () => (elite ? 0 : 0.99);
        const e = new w.Game_Enemy(id, 0, 0);
        w.Math.random = () => 0.99;
        if (e.setupEnemyLevel) e.setupEnemyLevel();
        w.Math.random = () => 0.5;
        if (e.refreshPassiveCache) e.refreshPassiveCache();
        return {isElite: !!e.isElite(), level: e.level, exp: e.exp(), gold: e.gold(), dropItemRate: round(e.dropItemRate()), ...snap(e), chances: chances(e)};
      }));
    }
  }
}
process.exit(finish(host, 'difficulty_enemy.json', {hostScope: '正式 Game_Enemy 难度 1～9 的最终能力值、等级、经验金钱、掉率', enemyIds, cases}) ? 0 : 1);
