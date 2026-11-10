'use strict';
// 【cc·悟空·未经审查】角色说明卡动态行探针（chars-gaps2）：installDisplayPreferencesRuntime 的 characterHelpView。
// ① listCosts（技能界面／战斗里为真）：消耗行不显示；② dyn2 里云裳 174（目标、段数、成长倍率、爆伤终伤）、镜流 170（已解锁星魂、寒川映月上限）、
// 宿傩 172 的 10242 斩击强化（读 actor._codexSukuna 的 emp／domain 与觉醒 2639、领域 2636）。
// 只记卡上以「成长／目标／段数／消耗」开头（去色后，含「；」并排的）的行，和实际的技能表、进阶次数，Godot 照这些摆角色。
// 只写 .sandbox/character_help_dyn.json，拷成 01_Godot工程/tests/fixtures/character_help_dyn_oracle.json（不进同步），专项 xiyou_character_help_dyn。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const plain = t => String(t).replace(/\\c\[\d+\]/gi, '');
const pick = v => v.descParams.map(r => plain(r[0])).filter(t => /^(?:成长|目标|段数|消耗|基础(?:MP|TP)?消耗|MP消耗|TP消耗)/.test(t));
const own = a => a ? a._skills.filter(s => s >= 10122 && s <= 10299).sort((x, y) => x - y) : null;
const lvOf = a => a ? a.level : null;
// 新局的等级上限是 10（$gameParty.ActorMaxLevel），同 yunshang_probe 放到 99
const maxLevel = () => w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
function setup(id, lv, rank, learn, forget) {
  maxLevel();
  const a = w.$gameActors.actor(id);
  a.changeLevel(lv, false);
  a._AdvancedNum = rank;
  (learn || []).forEach(s => a.learnSkill(s));
  (forget || []).forEach(s => a.forgetSkill(s));
  a.refresh();
  return a;
}
function view(skills, options) {
  const out = {};
  skills.forEach(s => { out[s] = pick(w.CodexDisplay.characterHelpView(w.$dataSkills[s], options || {})); });
  return out;
}
const cases = [];
for (const [actor, lv, skill] of [[167, 10, 10122], [168, 10, 10140], [174, 30, 10270], [172, 30, 10230]]) for (const listCosts of [false, true]) {
  cases.push(makeCase('cost.' + actor + '.' + listCosts, {actor, level: lv, skills_view: [skill], listCosts}, () => {
    newGame();
    const a = setup(actor, lv, 0);
    return {level: lvOf(a), skills: own(a), rank: 0, rows: view([skill], {actor: a, listCosts})};
  }));
}
const YUN = [10270, 10271, 10274, 10276, 10277, 10278, 10279, 10281];
// 预览（characterHelpActor 的初始状态替身）：新局里别的模块已经建过 174（$gameActors._data 有），先记下再删掉，才走得到替身
cases.push(makeCase('yun.preview', {actor: 174, skills_view: YUN, preview: true}, () => {
  newGame();
  const existed = !!w.$gameActors._data[174];
  delete w.$gameActors._data[174];
  return {existedAfterNewGame: existed, skills: null, rows: view(YUN)};
}));
for (const [lv, rank] of [[25, 0], [30, 0], [36, 1], [45, 1], [60, 2]]) {
  cases.push(makeCase('yun.' + lv + '.' + rank, {actor: 174, level: lv, rank, skills_view: YUN}, () => {
    newGame();
    const a = setup(174, lv, rank, [10276, 10277]);
    return {level: lvOf(a), skills: own(a), rank, rows: view(YUN)};
  }));
}
// 学了展幅但等级不到门槛（25 级以下）：yh 为假
cases.push(makeCase('yun.24.gate', {actor: 174, level: 24, rank: 0, skills_view: YUN}, () => { newGame(); const a = setup(174, 24, 0, [10276, 10277]); return {level: lvOf(a), skills: own(a), rank: 0, rows: view(YUN)}; }));
for (const [lv, extra] of [[1, []], [30, []], [45, [10202]]]) {
  cases.push(makeCase('jl.' + lv, {actor: 170, level: lv, skills_view: [10194, 10196]}, () => {
    newGame();
    const a = setup(170, lv, 0, [10194].concat(extra), extra.length ? [] : [10202]);
    return {level: lvOf(a), skills: own(a), rank: 0, rows: view([10194, 10196])};
  }));
}
for (const [tag, emp, awake, domain] of [['none', 0, false, false], ['emp2', 2, true, false], ['emp3dom', 3, true, true], ['sleep', 2, false, false]]) {
  cases.push(makeCase('sk.' + tag, {actor: 172, level: 30, skills_view: [10242], emp, awake, domain}, () => {
    newGame();
    const a = setup(172, 30, 0);
    a._codexSukuna = Object.assign({}, a._codexSukuna || {}, {emp, domain: domain ? 1 : 0});
    if (awake) a._states.push(2639);
    if (domain) a._states.push(2636);
    return {level: lvOf(a), skills: own(a), rank: 0, rows: view([10242])};
  }));
}
process.exit(finish(host, 'character_help_dyn.json', {scope: 'characterHelpView listCosts and dyn2 rows for Yunshang/Jingliu/Sukuna 10242; filtered to 成长/目标/段数/消耗 rows', cases}) ? 0 : 1);
