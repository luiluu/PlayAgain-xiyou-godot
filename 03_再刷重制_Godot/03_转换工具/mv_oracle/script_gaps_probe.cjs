'use strict';
// 事件脚本普查第一批（悟空 events1）：重制认不出的两种写法在正式引擎里的结果。
// - 大厅小盖盖调速（Map004 EV044）：脚本 $gamePlayer._moveSpeed = 3／4／5，读 _moveSpeed、realMoveSpeed（走／冲刺），存读档往返后再读；
//   另：下载具 getOffVehicle 里 setMoveSpeed(4)（rpg_objects），这里直接调原函数的那一句等价路径不好搭，只量调速与存档。
// - 牛头人认证（Map017 EV004）：条件分支脚本 $gameSystem.defeatNumber(66) >= 999／9999，击败数 0／998／999／9998／9999 各一例，
//   在 Game_Interpreter 里真跑条件分支（真支设变量 1＝1、否则支设 2），读变量 1。
// 新游戏（Math.random 0.5），只在内存；产物 .sandbox/script_gaps.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame, restore, encode} = host;
const cmd = (code, parameters, indent) => ({code, indent: indent || 0, parameters});
const runList = list => { const it = new w.Game_Interpreter(); it.setup(list, 0); let n = 0; while (it.isRunning() && n++ < 100) it.update(); return n; };
const cases = [];
for (const speed of [3, 4, 5]) {
  cases.push(makeCase('moveSpeed.' + speed, {map: 4, event: 44, script: '$gamePlayer._moveSpeed = ' + speed}, () => {
    newGame();
    runList([cmd(355, ['$gamePlayer._moveSpeed = ' + speed]), cmd(0, [])]);
    const p = w.$gamePlayer, walk = p.realMoveSpeed();
    p._dashing = true; const dash = p.realMoveSpeed(); p._dashing = false;
    const saved = encode(); restore(saved);
    return {moveSpeed: p._moveSpeed, walk, dash, afterLoad: w.$gamePlayer._moveSpeed};
  }));
}
for (const need of [999, 9999]) {
  for (const kills of [0, 998, 999, 9998, 9999]) {
    if (need === 999 && kills > 999) continue;
    if (need === 9999 && kills < 998) continue;
    const expr = '$gameSystem.defeatNumber(66) >= ' + need;
    cases.push(makeCase('defeat.' + need + '.' + kills, {map: 17, event: 4, enemy: 66, kills, condition: expr}, () => {
      newGame();
      w.$gameSystem.clearDefeatNumber();
      for (let i = 0; i < kills; i++) w.$gameSystem.incrementDefeatNumber(66);
      runList([cmd(111, [12, expr]), cmd(122, [1, 1, 0, 0, 1], 1), cmd(0, [], 1), cmd(411, []), cmd(122, [1, 1, 0, 0, 2], 1), cmd(0, [], 1), cmd(412, []), cmd(0, [])]);
      return {defeatNumber: w.$gameSystem.defeatNumber(66), branch: w.$gameVariables.value(1)};
    }));
  }
}
// 第二批（悟空 events2）：
// - 失去剩余的伙伴号角（CE1391，鼬号角 CE1511 调）：给 2701～2805 里几件（一件、三件），跑 CE1391，读剩多少；范围外 2700、2806 不动。
// - 按变量取人学技能＋提示（CE1313 第一支：var actor = $gameActors.actor($gameVariables.value(348)); learnSkill(6128); $.toaster 角色名）：
//   变量 348＝1（在队）／0（没人：读 null 抛错、YEP 吞掉，不学不提示）；鲲拳 CE1160 那种只有一句声明的段跑完什么都不变。
const toasts = [];
if (w.$) w.$.toaster = o => toasts.push(String(o && (o.message || o.title) || ''));
const scriptCmds = lines => lines.map((s, i) => cmd(i ? 655 : 355, [s]));
cases.push(makeCase('loseHorns', {ce: 1391, give: {2700: 1, 2701: 1, 2750: 3, 2805: 1, 2806: 1}}, () => {
  newGame();
  for (const [id, n] of [[2700, 1], [2701, 1], [2750, 3], [2805, 1], [2806, 1]]) w.$gameParty.gainItem(w.$dataItems[id], n);
  runList(w.JsonEx.makeDeepCopy(w.$dataCommonEvents[1391].list));
  const out = {}; for (const id of [2700, 2701, 2750, 2805, 2806]) out[id] = w.$gameParty.numItems(w.$dataItems[id]);
  return out;
}));
const learn = w.$dataCommonEvents[1313].list.filter((c, i, l) => i >= 30 && i <= 32).map(c => c.parameters[0]);
for (const who of [1, 0]) {
  cases.push(makeCase('actorVar.learn.' + who, {ce: 1313, lines: learn, variable348: who}, () => {
    newGame(); toasts.length = 0;
    w.$gameVariables.setValue(348, who);
    const before = w.$gameActors.actor(1).hasSkill(6128);
    runList(scriptCmds(learn).concat([cmd(0, [])]));
    return {before, learned: w.$gameActors.actor(1).hasSkill(6128), toasts: toasts.slice()};
  }));
}
cases.push(makeCase('actorVar.declareOnly', {ce: 1160, line: 'var actor = $gameActors.actor($gameVariables.value(348));'}, () => {
  newGame(); toasts.length = 0; w.$gameVariables.setValue(348, 1);
  const skills = w.$gameActors.actor(1)._skills.slice();
  runList([cmd(355, ['var actor = $gameActors.actor($gameVariables.value(348));']), cmd(0, [])]);
  return {sameSkills: JSON.stringify(skills) === JSON.stringify(w.$gameActors.actor(1)._skills), toasts: toasts.slice()};
}));
// - 战斗里按角色号加状态（CE43「PUA」，技能 73 调）：var actorN = $gameActors.actor(K); … actorN.addState(708);
//   战斗中（敌群 2），13～15 在队（队伍 13／14／15／1）与不在队（1／8／9／10）各一例，读三人是否有 708。
for (const [tag, party] of [['inParty', [13, 14, 15, 1]], ['notInParty', [1, 8, 9, 10]]]) {
  cases.push(makeCase('actorStates.' + tag, {ce: 43, troop: 2, party}, () => {
    newGame();
    w.eval('$gameParty._actors=[];[' + party.join(',') + '].forEach(function(id){$gameParty.addActor(id);});');
    w.$gameTroop.setup(2); w.$gameParty._inBattle = true;
    runList(w.JsonEx.makeDeepCopy(w.$dataCommonEvents[43].list.slice(8)));   // 只跑脚本那段（前面是角色 13 在队时的强制行动）
    const out = {}; for (const id of [13, 14, 15]) out[id] = w.$gameActors.actor(id).isStateAffected(708);
    w.$gameParty._inBattle = false;
    return out;
  }));
}
// 第三批（悟空 events3）：
// - 投石问路（CE2486，技能 7188）：战斗中（敌群 2）每个敌人一条 (i+1)+'号敌人暴闪为'+cev.toFixed(2)*100+'%!'；
// - 猛击（CE78，技能 459）：for i<30 找带状态 345 且身上有防具 506 的角色，有就给全体敌人加状态 43。
//   一例给 1 号角色穿上 506 并加 345，一例只加 345 不穿；读敌人是否有 43。
cases.push(makeCase('troopCev', {ce: 2486, troop: 2}, () => {
  newGame(); toasts.length = 0;
  w.$gameTroop.setup(2); w.$gameParty._inBattle = true;
  runList(w.JsonEx.makeDeepCopy(w.$dataCommonEvents[2486].list.filter(c => c.code === 355 || c.code === 655 || c.code === 0).slice(-4)));
  const cev = w.$gameTroop.members().map(e => e.cev);
  w.$gameParty._inBattle = false;
  return {toasts: toasts.slice(), cev};
}));
for (const wear of [true, false]) {
  cases.push(makeCase('setArmorState.' + (wear ? 'wear' : 'bare'), {ce: 78, troop: 2, actor: 1, armor: 506, state: 345}, () => {
    newGame();
    w.$gameTroop.setup(2); w.$gameParty._inBattle = true;
    const a = w.$gameActors.actor(1);
    if (wear) { const slot = a.equipSlots().indexOf(w.$dataArmors[506].etypeId); w.$gameParty.gainItem(w.$dataArmors[506], 1); a.changeEquip(slot, w.$dataArmors[506]); }
    a.addState(345);
    runList(w.JsonEx.makeDeepCopy(w.$dataCommonEvents[78].list));
    const out = {hasArmor: a.hasArmor(w.$dataArmors[506]), enemies: w.$gameTroop.members().map(e => e.isStateAffected(43))};
    w.$gameParty._inBattle = false;
    return out;
  }));
}
process.exit(finish(host, 'script_gaps.json', {hostScope: '新游戏（Math.random 0.5）；事件脚本普查：调速脚本、击败数条件（悟空 events1）；伙伴号角清理、按变量取人学技能、战斗里按角色号加状态（events2）；敌人暴闪提示、套装加敌人状态（events3）', cases}) ? 0 : 1);
