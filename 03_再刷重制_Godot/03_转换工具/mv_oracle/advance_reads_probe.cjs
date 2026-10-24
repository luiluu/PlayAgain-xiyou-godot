'use strict';
// 读进阶次数（Game_Actor._AdvancedNum）的三处，冻结 v0.28：
// ① 小猫剑圣 CodexCat.advanced（35 级起、_AdvancedNum≥1、学会 10444）与进阶后成长曲线 growth、说明文字 helpText；
// ② 甚尔／宿傩 rollAdvanceStone（甚尔进阶过或已有一枚不掷；宿傩 need=3−次数，背包够数不掷；否则 Math.randomInt(50)==0 得一枚）；
// ③ 角色图鉴「最大进阶次数」（Star_ActorsBook：本角色、当前次数那一行的 AdvancedActNumMaX，没有行显示当前次数）。
// 真实新游戏、Math.random 0.5（掷石头的「中」用例临时改 0），只在内存；产物 .sandbox/advance_reads.json，
// 复制进 01_Godot工程/tests/fixtures/advance_reads_oracle.json（tests/xiyou_advance_reads.gd 读）。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const C = w.CodexCat;
const cases = [];
const LEVELS = [30, 34, 35, 42, 50, 55, 65, 75, 81, 90];
const TEXTS = [[10442, '条件：进阶后额外获得1次行动'], [10443, '条件：进阶后专属剑技结算伤害+100%'],
  [10443, '条件：进阶后终技消费剑心，追加同层数神圣剑段；满层冷却减1']];
cases.push(makeCase('cat', {actor: 178, levels: LEVELS, ranks: [0, 1, 2], learned10444: [false, true]}, () => {
  newGame();
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.$gameActors._data[178] = null;
  const a = w.$gameActors.actor(178), rows = [];
  for (const lv of LEVELS) for (const rank of [0, 1, 2]) for (const learned of [false, true]) {
    a.changeLevel(lv, false);
    a._AdvancedNum = rank;
    if (learned) a.learnSkill(10444); else a.forgetSkill(10444);
    rows.push({level: a.level, rank, learned, advanced: C.advanced(a), growth: round(C.growth(a)),
      help: TEXTS.map(([id, t]) => C.helpText(t, w.$dataSkills[id], a))});
  }
  return {rows};
}));
function stone(who, rank, have, rnd) {
  newGame();
  const id = who === 'toji' ? 171 : 172, item = who === 'toji' ? 2935 : 2937;
  w.$gameActors.actor(id)._AdvancedNum = rank;
  w.$gameParty.gainItem(w.$dataItems[item], have);
  w.eval('Math.random=function(){return ' + rnd + ';};');
  const got = who === 'toji' ? w.CodexToji.rollAdvanceStone() : w.CodexSukuna.rollAdvanceStone();
  w.eval('Math.random=function(){return 0.5;};');
  return {who, rank, have, random: rnd, got, count: w.$gameParty.numItems(w.$dataItems[item])};
}
cases.push(makeCase('stones', {random: [0, 0.5]}, () => {
  const rows = [];
  for (const rnd of [0, 0.5]) {
    for (const rank of [0, 1, 2]) for (const have of [0, 1]) rows.push(stone('toji', rank, have, rnd));
    for (const rank of [0, 1, 2, 3, 4]) for (const have of [0, 1, 2, 3]) rows.push(stone('sukuna', rank, have, rnd));
  }
  return {rows};
}));
// 图鉴的 GetUpData（照 Star_ActorsBook 的 filter）：表里出现的每个角色，次数 0～最大＋1，另加渡鸦 167 与一个不在表里的角色 1
cases.push(makeCase('book', {}, () => {
  const opt = w.$dataStarAdvancedOpt.filter(Boolean), ids = [...new Set(opt.map(o => Number(o.AdvancedActId)).concat([167, 1]))];
  const rows = [];
  for (const id of ids) {
    const top = Math.max(0, ...opt.filter(o => o.AdvancedActId == id).map(o => Number(o.AdvancedActNum) + 1));
    for (let n = 0; n <= top + 1; n++) {
      const g = opt.filter(o => id == o.AdvancedActId && n == o.AdvancedActNum)[0];
      rows.push({actor: id, rank: n, text: String(g ? g.AdvancedActNumMaX : n)});
    }
  }
  return {rows};
}));
process.exit(finish(host, 'advance_reads.json', {hostScope: '新游戏（Math.random 0.5）；读进阶次数：小猫 advanced／成长／说明、甚尔宿傩进阶石、图鉴最大进阶次数', cases}) ? 0 : 1);
