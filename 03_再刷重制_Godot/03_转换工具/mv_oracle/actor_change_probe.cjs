'use strict';
// 事件指令「更改名字／职业／角色图像／称号」（320／321／322／324），冻结 v0.28：
// ① recruit：新游戏里跑招募公共事件（29 玛莎 职业 16→21、125 签弟 改名改称号、153 波加尼 改脸图与称号、1209 钟离 改名改图称号清空、
//    1575 甘雨 改图），每次后记该角色的名字、称号、职业、等级、经验、五项图像与 mhp、玩家行走图。
// ② hat：绿司机 2 跑 689 戴帽子、690 脱帽子（技能与图像）。
// ③ reset：先把 1～4 号的图像改乱，再跑大厅「更改形象」460～463，记 1～93 号的图像。
// ④ changeClass：狗逍遥 1 升到 30 级，321 换职业 2 不保留经验 → 换回 1 不保留 → 换 3 保留 → 换 3 不保留，每步记职业、等级、经验与 _exp。
// ⑤ resources：「增减 HP／MP／TP」311／312／326：不允许死亡最多扣到 1、允许时倒下、倒下后不再加；变量操作数（317）、全队（角色 0）；
//    公共事件 46 一掷千金（钱不够扣 3000 HP、允许死亡）、624 快捷回血（持有物品 793 时 HP、MP 各加变量 317＝99999）。
// 真实新游戏、Math.random 0.5，只在内存；产物 .sandbox/actor_change.json，
// 复制进 01_Godot工程/tests/fixtures/actor_change_oracle.json（tests/xiyou_actor_change.gd 读）。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const J = o => w.JSON.parse(w.JSON.stringify(o));
function run(list) {
  const it = new w.Game_Interpreter(); it.setup(list.concat([{code: 0, indent: 0, parameters: []}]), 0);
  for (let n = 0; n < 2000 && it.isRunning(); n++) {
    if (w.$gameMessage.isBusy()) w.$gameMessage.clear();
    it.update();
  }
  if (it.isRunning()) throw new Error('解释器未结束');
}
const ce = id => run([{code: 117, indent: 0, parameters: [id]}]);
function look(id) {
  const a = w.$gameActors.actor(id);
  return {actor: id, name: a.name(), nickname: a.nickname(), classId: a._classId, level: a.level, exp: round(a.currentExp()),
    characterName: a.characterName(), characterIndex: a.characterIndex(), faceName: a.faceName(), faceIndex: a.faceIndex(),
    battlerName: a.battlerName(), mhp: round(a.mhp)};
}
const player = () => ({characterName: w.$gamePlayer.characterName(), characterIndex: w.$gamePlayer.characterIndex()});
const cases = [];

cases.push(makeCase('recruit', {events: [[29, 21], [125, 34], [153, 41], [1209, 107], [1575, 106]]}, () => {
  newGame();
  const rows = [];
  for (const [id, actor] of [[29, 21], [125, 34], [153, 41], [1209, 107], [1575, 106]]) {
    const before = look(actor);
    ce(id);
    rows.push({event: id, before, after: look(actor), party: w.$gameParty.allMembers().map(a => a.actorId())});
  }
  return {rows, player: player()};
}));

cases.push(makeCase('hat', {actor: 2}, () => {
  newGame();
  const skills = () => w.$gameActors.actor(2)._skills.filter(s => s >= 3790 && s <= 3793);
  const rows = [{step: 'init', look: look(2), skills: skills()}];
  ce(689); rows.push({step: 689, look: look(2), skills: skills()});
  ce(690); rows.push({step: 690, look: look(2), skills: skills()});
  return {rows};
}));

cases.push(makeCase('reset', {events: [460, 461, 462, 463]}, () => {
  newGame();
  run([1, 2, 3, 4].map(id => ({code: 322, indent: 0, parameters: [id, 'Actor1', 3, 'Actor1', 3, 'Actor1_4']})));
  const mixed = [1, 2, 3, 4].map(look);
  for (const id of [460, 461, 462, 463]) ce(id);
  const rows = [];
  for (let id = 1; id <= 93; id++) if (w.$dataActors[id]) rows.push(look(id));
  return {mixed, rows, player: player()};
}));

cases.push(makeCase('changeClass', {actor: 1, level: 30}, () => {
  newGame();
  const a = w.$gameActors.actor(1);
  a.changeLevel(30, false);
  const snap = step => Object.assign({step, expByClass: J(a._exp), skills: a._skills.length}, look(1));
  const rows = [snap('init')];
  for (const [cls, keep] of [[2, false], [1, false], [3, true], [3, false], [1, true]]) {
    run([{code: 321, indent: 0, parameters: [1, cls, keep]}]);
    rows.push(snap(cls + (keep ? '_keep' : '_reset')));
  }
  return {rows};
}));

cases.push(makeCase('resources', {}, () => {
  newGame();
  const party = w.$gameParty.members();
  const snap = step => ({step, gold: w.$gameParty.gold(), actors: party.map(a => ({actor: a.actorId(), hp: round(a.hp), mp: round(a.mp), tp: round(a.tp),
    mhp: round(a.mhp), mmp: round(a.mmp), dead: a.isDead()}))});
  const a1 = w.$gameActors.actor(1), a8 = w.$gameActors.actor(8);
  a1.setHp(100); a8.setMp(5); a8.setTp(10);
  const rows = [snap('init')];
  const steps = [
    ['hp_minus_nodeath', [{code: 311, indent: 0, parameters: [0, 1, 1, 0, 3000, false]}]],
    ['mp_minus_floor', [{code: 312, indent: 0, parameters: [0, 8, 1, 0, 50]}]],
    ['tp_plus', [{code: 326, indent: 0, parameters: [0, 0, 0, 0, 20]}]],
    ['tp_over_cap', [{code: 326, indent: 0, parameters: [0, 8, 0, 0, 500]}]],
    ['hp_minus_death', [{code: 311, indent: 0, parameters: [0, 1, 1, 0, 3000, true]}]],
    ['hp_plus_dead', [{code: 311, indent: 0, parameters: [0, 1, 0, 0, 500, false]}]],
    ['hp_var_all', [{code: 122, indent: 0, parameters: [317, 317, 0, 0, 77]}, {code: 311, indent: 0, parameters: [0, 0, 1, 1, 317, false]}]],
    ['mp_var_actor_var', [{code: 122, indent: 0, parameters: [318, 318, 0, 0, 9]}, {code: 312, indent: 0, parameters: [1, 318, 0, 1, 317]}]],
  ];
  for (const [label, list] of steps) { run(list); rows.push(snap(label)); }
  w.$gameParty.loseGold(w.$gameParty.gold()); w.$gameParty.gainGold(100);
  ce(46); rows.push(snap('ce46_poor'));
  w.$gameParty.gainItem(w.$dataItems[793], 1);
  ce(624); rows.push(snap('ce624'));
  return {rows};
}));

process.exit(finish(host, 'actor_change.json', {hostScope: '新游戏（Math.random 0.5）；事件更改名字、职业、角色图像、称号', cases}) ? 0 : 1);
