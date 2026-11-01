'use strict';
// 【cc·悟空·未经审查】战斗里敌人的掉落概率（Game_Enemy.makeDropItems 整条包装链，冻结 v0.28）：
// 运行时 <Enemy Drops> 的「x%」已并进 dropItems（分母 100/x），和数据库掉落同一式：MV 原式 Math.random()×分母 < dropItemRate()；dropItemRate 被 EliteEnemy（插件表第 138 个，直接覆写：双倍掉落 ? 1 : 0.2，×神话倍率）
// 盖掉 dsPassiveSkill 与 GT_EquipSuitCore 的包装，再由 installNativeRavenRuntime 乘 R.teamDropRateFactor（套装、出战 passiveIRUP 连乘、亡魂汲取 +1）；
// Vitsuno_Difficulty 的按序号掉率整段注释掉了，难度不影响掉落。MOG_TrPopUpBattle 抽一次存 _treasure。
// 量法：Math.random 换成常数 r，二分出 makeDropItems 掉出件数每增加一件的 r 上界——即各掉落的概率（从大到小）。
// 用例：敌人 1（数据库分母 2／20＋额外 0.5%）、16（分母 1／20＋额外），难度 2／5，神话与否，队伍 [1,8,9,10]／[1]／[1,167]（渡鸦 30 级会亡魂汲取）。
// 真实新局，只在内存；产物 .sandbox/battle_drop.json（generated/oracle/battle_drop.json，tests/xiyou_battle_drop.gd 读）。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const SWITCH = 2494;
function setup(difficulty, party, ravenLevel) {
  newGame();
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.$gameSwitches.setValue(SWITCH, true);
  w.$gameSystem.setDifficultyId(difficulty);
  w.eval('$gameParty._actors=[]; $gameParty._battleMembers=[0,0,0,0,0];');
  for (const id of party) w.$gameParty.addActor(id);
  if (party.indexOf(167) >= 0) w.$gameActors.actor(167).changeLevel(ravenLevel, false);
}
function enemy(id, elite) {
  const e = new w.Game_Enemy(id, 0, 0);
  e._elite = !!elite;
  return e;
}
// 常数 r 下掉出几件
function count(e, r) {
  const old = w.Math.random;
  w.Math.random = () => r;
  e._treasure = undefined;  // MOG_TrPopUpBattle：第一次抽完存进 _treasure，之后照返回
  try { return e.makeDropItems().length; } finally { w.Math.random = old; }
}
// 各件的概率：第 k 件在 r < p_k 时掉，p 从大到小
function chances(e) {
  const most = count(e, 0);
  const out = [];
  for (let k = 1; k <= most; k++) {
    let lo = 0, hi = 1;
    for (let n = 0; n < 60; n++) { const mid = (lo + hi) / 2; if (count(e, mid) >= k) lo = mid; else hi = mid; }
    out.push(round(lo));
  }
  return out;
}
const cases = [];
for (const [eid, elite, difficulty, party, tag] of [
  [1, false, 2, [1, 8, 9, 10], 'p4'], [1, true, 2, [1, 8, 9, 10], 'p4'], [1, false, 5, [1, 8, 9, 10], 'p4'],
  [16, false, 2, [1], 'p1'], [16, false, 2, [1, 167], 'raven'], [16, true, 5, [1, 167], 'raven']]) {
  cases.push(makeCase(`drop.e${eid}.${elite ? 'elite' : 'plain'}.d${difficulty}.${tag}`, {enemy: eid, elite, difficulty, party, ravenLevel: 30}, () => {
    setup(difficulty, party, 30);
    const e = enemy(eid, elite);
    return {members: w.$gameParty.battleMembers().map(b => b.actorId()), isElite: e.isElite(), dropItemRate: round(e.dropItemRate()),
      team: round(w.CodexRaven.teamDropRateFactor()), double: !!w.$gameParty.hasDropItemDouble(),
      drops: e.enemy().dropItems.filter(d => d.kind > 0).map(d => [d.kind, d.dataId, d.denominator]), chances: chances(e)};
  }));
}
process.exit(finish(host, 'battle_drop.json', {hostScope: '正式 Game_Enemy.makeDropItems（EliteEnemy／installNativeRavenRuntime 的 dropItemRate、YEP_ExtraEnemyDrops）', cases}) ? 0 : 1);
