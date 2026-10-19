'use strict';
// 【Claude·悟空·未经Codex检验】副本系统参照探针（框架维护约定「副本入口与上下文」的最小参照矩阵）。
// 用冻结 v0.28 的正式引擎，从同一内存新游戏起按「剧本」逐步运行副本入口、副本内事件与公共事件，记录每一步的输出与状态变化，
// 供 Godot 的 tests/xiyou_dungeon 用同样的剧本对照（XDungeon、MVInterpreter）。
// - 剧本步骤：event（当前地图上的事件，按正式出现条件取页，暂时消除的为 −1；picks 依次回答选项，用完取最后一项；battle 为 win/lose）、
//   common（公共事件）、item（把物品数量设为 n）、hang（挂机开关 enabled 与运行中 active）、roundtrip（JsonEx 存档往返）、warp（瞬移）、face（玩家朝向 d）。
// - 每例：setupNewGame、setup 里的开关 sw 与变量 vars、队伍 1/8/10/9（setup.actors 再追加，含艾坤 3 时 after 多记坤坤任务 kun）、难度与难度开关（Map001 选难度时开的开关与 DCultyL 标记）、副本初始化 CE822，
//   随机数固定（Math.random＝rand，默认 0.5），宝珠随机流种子固定 12345；场所移动立即执行；战斗胜利走 BattleManager.endBattle(0)。
// - 不加载配置或存档，存档只在内存往返。输出只写 .sandbox/dungeon.json。
// 用法：node dungeon_probe.cjs [剧本 ID 前缀…]
const fs = require('fs'), path = require('path');
const {boot} = require('./hboot.cjs'), {sourceIdentity} = require('./source_identity.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const PARTY = [1, 8, 10, 9], MAX_FRAMES = 6000, ORB_SEED = 12345;
// 难度 → Map001 选难度时打开的开关（CE714 难度修复按它们恢复）
const DIFF_SWITCH = {1: 2496, 2: 2492, 3: 2491, 4: 2500, 5: 2494, 6: 2489};
// 关心的状态（快照 focus）：副本变量与开关、符文与奖励物品
const FOCUS_VARS = [5, 6, 21, 94, 450, 364, 206, 214, 243];
const FOCUS_SW = [229, 230, 882, 1565, 1566, 1567, 1568];   // 二层；其他副本的开关在 delta 里

const identity = sourceIdentity(APP);
const r = boot(APP, {tolerant: true, log: false}), w = r.window;
if (r.errors.length || !w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败');
w.Star.Achievement.Manager.init();

// ---- 剧本 ----
// 副本：楼层地图上入口门前的位置、门事件、第一档开关（CE822 开，每档一页，Boss 胜后换下一档）、
// 逃离事件、通关路线（入口后的事件步骤，最后两步是 Boss 战与宝箱）、副本协会主席（出现开关、事件）
const DUNGEONS = {
  d2: {start: {map: 3, x: 41, y: 17}, door: 7, tierBase: 1565},
  d1: {start: {map: 5, x: 4, y: 18}, door: 8, tierBase: 1561, escape: 8,
    clear: [{do: 'event', event: 3, battle: 'win'}, {do: 'event', event: 1, battle: 'win'}, {do: 'event', event: 1}], boss: {sw: 881, event: 9}},
  d4: {start: {map: 7, x: 16, y: 11}, door: 1, tierBase: 1573, escape: 9,
    clear: [{do: 'event', event: 3, battle: 'win'}, {do: 'event', event: 2, battle: 'win'}, {do: 'event', event: 1}, {do: 'event', event: 2, battle: 'win'},
      {do: 'event', event: 2}], boss: {sw: 884, event: 7}},
  d6: {start: {map: 13, x: 31, y: 1}, door: 1, tierBase: 1581, escape: 20,
    clear: [2, 3, 4, 5].map(e => ({do: 'event', event: e, battle: 'win'})).concat([{do: 'event', event: 1, battle: 'win'}, {do: 'event', event: 19, battle: 'win'},
      {do: 'event', event: 19}]), boss: {sw: 886, event: 9}},
  d7a: {start: {map: 61, x: 1, y: 16}, door: 10, tierBase: 1585, escape: 9,
    clear: [{do: 'event', event: 4, battle: 'win'}, {do: 'event', event: 3, battle: 'win'}, {do: 'event', event: 3}], boss: {sw: 887, event: 1}},
  d7b: {start: {map: 61, x: 24, y: 16}, door: 11, tierBase: 1585, escape: 17,
    clear: [{do: 'event', event: 2, battle: 'win'}, {do: 'event', event: 11, battle: 'win'}, {do: 'event', event: 11}], boss: {sw: 888, event: 1}},
  // 九层女神道场、十层先祖禁地：主席收活力水 912；十层用中级副本挑战符文 64，五只精英（变量 43）开石栏
  d9: {start: {map: 15, x: 30, y: 1}, door: 4, tierBase: 1593, escape: 7,
    clear: [8, 11, 12, 14, 15, 16, 17, 9].map(e => ({do: 'event', event: e, battle: 'win'})).concat([{do: 'event', event: 9}]),
    boss: {sw: 905, event: 20, item: 912}},
  d10: {start: {map: 17, x: 21, y: 36}, door: 2, tierBase: 1597, rune: 64, escape: 14,
    clear: [2, 9, 10, 11, 13, 6, 7, 8].map(e => ({do: 'event', event: e, battle: 'win'})).concat([{do: 'event', event: 8}]),
    boss: {sw: 890, event: 12, item: 912}},
  // 八层哀嚎迷窟（首领坤坤）：六只精英（变量 42）后出两首领开石栏；十一层实验洞窟：精英五只（变量 44），首领连打五场，出口不重置（原版）；
  // 十二层北风高原：精英六只（变量 47）后三首领（变量 48），随机变量 49 决定隐藏首领；逃离要朝下（face）
  d8: {start: {map: 12, x: 8, y: 8}, door: 17, tierBase: 1589, rune: 64, escape: 18,
    clear: [12, 13, 14, 15, 16, 17, 8, 9, 11].map(e => ({do: 'event', event: e, battle: 'win'})).concat([{do: 'event', event: 11}]),
    boss: {sw: 889, event: 19, item: 912}},
  d11: {start: {map: 20, x: 47, y: 5}, door: 5, tierBase: 1601, rune: 110, escape: 6, escapeThen: [{do: 'event', event: 5, picks: [1]}],
    clear: [7, 8, 9, 10, 11, 5].map(e => ({do: 'event', event: e, battle: 'win'})).concat([{do: 'event', event: 5}]),
    boss: {sw: 891, event: 12, item: 913}},
  d12: {start: {map: 65, x: 23, y: 1}, door: 1, tierBase: 1605, rune: 110, escape: 19, escapeFace: 2,
    clear: [3, 4, 5, 6, 7, 9, 10, 11, 12, 15].map(e => ({do: 'event', event: e, battle: 'win'})).concat([{do: 'event', event: 15}]),
    boss: {sw: 892, event: 22, item: 914}},
  // 十三层魔晶洞穴：精英六只后三首领（打掉 4、5 开石栏）；十四层浅析之谷（门是接触触发）：六精英、三首领（变量 51）开石栏；
  // 十五层废墟深处（特级符文 171）：七精英、四首领（变量 111 到 4 才出首领页）；十三、十五层逃离要朝下
  d13: {start: {map: 64, x: 14, y: 26}, door: 2, tierBase: 1609, rune: 110, escape: 2, escapeFace: 2,
    clear: [11, 12, 13, 14, 15, 16, 4, 5, 6, 3].map(e => ({do: 'event', event: e, battle: 'win'})).concat([{do: 'event', event: 3}]),
    boss: {sw: 893, event: 17, item: 914}},
  d14: {start: {map: 30, x: 10, y: 10}, door: 6, tierBase: 1613, rune: 110, escape: 13,
    clear: [14, 15, 16, 17, 18, 19, 22, 23, 24, 21].map(e => ({do: 'event', event: e, battle: 'win'})).concat([{do: 'event', event: 21}]),
    boss: {sw: 894, event: 25, item: 914}},
  d15: {start: {map: 32, x: 29, y: 1}, door: 4, tierBase: 1617, rune: 171, escape: 14, escapeFace: 2,
    clear: [6, 7, 8, 9, 10, 11, 12, 2, 3, 4, 5, 13].map(e => ({do: 'event', event: e, battle: 'win'})).concat([{do: 'event', event: 13}]),
    boss: {sw: 895, event: 17, item: 914}},
  // 十七层风精灵沉眠墓地：八精英、四首领（变量 114 到 4 才出首领页，随机变量 115 决定隐藏首领 14）；
  // 十八层恶魔城：六精英、四首领（变量 116），首领按随机变量 117 是 1 打城主 203，否则打怨念集合体 202；两层逃离要朝下
  // 十六层亚特兰蒂斯秘境（特级符文 171）：十只精英（敌群 166，变量 271≥88 时被吓跑）、四守卫 3～6（敌群 169／170／167／168，变量 113 计数，到 4 才出首领页）、
  // 首领 2 敌群 165「海拉的幻影」（第 4 回合战斗内 101 对话＋334＋336 变身 175）；开关 2303／2307 的两页开守护者 796；逃离要朝下
  d16: {start: {map: 33, x: 20, y: 20}, door: 1, tierBase: 1621, rune: 171, escape: 1, escapeFace: 2,
    clear: [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 3, 4, 5, 6, 2].map(e => ({do: 'event', event: e, battle: 'win'})).concat([{do: 'event', event: 2}]),
    boss: {sw: 896, event: 17, item: 914}},
  d17: {start: {map: 45, x: 24, y: 7}, door: 2, tierBase: 1625, rune: 171, escape: 15, escapeFace: 2,
    clear: [6, 7, 8, 9, 10, 11, 12, 13, 2, 3, 4, 5, 1].map(e => ({do: 'event', event: e, battle: 'win'})).concat([{do: 'event', event: 1}]),
    boss: {sw: 897, event: 16, item: 913}},
  d18: {start: {map: 46, x: 21, y: 25}, door: 2, tierBase: 1629, rune: 171, escape: 12, escapeFace: 2,
    clear: [5, 15, 16, 17, 18, 19, 7, 9, 10, 11, 6].map(e => ({do: 'event', event: e, battle: 'win'})).concat([{do: 'event', event: 6}]),
    boss: {sw: 898, event: 20, item: 913}},
  // 十九层古龙祭坛：六精英（变量 118）后两祭祀首领开火墙，再打护卫、队长，首领「古龙」普拉顿；主席收活力水 912；逃离要朝下
  d19: {start: {map: 47, x: 14, y: 14}, door: 11, tierBase: 1633, rune: 171, escape: 32, escapeFace: 2,
    clear: [23, 24, 25, 26, 27, 28, 18, 19, 29, 30, 15].map(e => ({do: 'event', event: e, battle: 'win'})).concat([{do: 'event', event: 15}]),
    boss: {sw: 899, event: 34, item: 912}},
  // 二十层食人魔的晚宴（终极符文 397）：四首领（变量 175）到 4 后出首领「厄运之王」高尔戈；主席收活力水 912
  d20: {start: {map: 116, x: 17, y: 2}, door: 2, tierBase: 1637, rune: 397, escape: 5,
    clear: [1, 2, 3, 4, 6].map(e => ({do: 'event', event: e, battle: 'win'})).concat([{do: 'event', event: 6}]),
    boss: {sw: 900, event: 7, item: 912}},
  // 二十一层东海湾：五只接触触发的精英后打首领龟丞相（不计数）；主席收精神酒 914
  d21: {start: {map: 117, x: 35, y: 1}, door: 2, tierBase: 1641, rune: 397, escape: 7,
    clear: [1, 2, 3, 4, 5, 6].map(e => ({do: 'event', event: e, battle: 'win'})).concat([{do: 'event', event: 6}]),
    boss: {sw: 901, event: 11, item: 914}},
  // 二十二层剥皮教堂：四只精英（无计数）后首领劳勃；二十三层陈塘关：六只卫兵精英（变量 246 到 4 才出首领李静）；
  // 二十四层熊族桃园：熊一至熊五（变量 249 到 5 才出首领雄霸，宝箱是自动执行页，敌群 526 第 2 页第 1 回合给状态 44 并强制 3813）；三层都收活力水 912
  d22: {start: {map: 119, x: 38, y: 5}, door: 14, tierBase: 1645, rune: 397, escape: 10,
    clear: [6, 7, 8, 9, 5].map(e => ({do: 'event', event: e, battle: 'win'})).concat([{do: 'event', event: 5}]),
    boss: {sw: 902, event: 11, item: 912}},
  d23: {start: {map: 118, x: 43, y: 46}, door: 4, tierBase: 1649, rune: 397, escape: 8,
    clear: [2, 3, 4, 5, 6, 7, 1].map(e => ({do: 'event', event: e, battle: 'win'})).concat([{do: 'event', event: 1}]),
    boss: {sw: 903, event: 9, item: 912}},
  d24: {start: {map: 120, x: 41, y: 1}, door: 2, tierBase: 1653, rune: 397, escape: 7,
    clear: [1, 3, 4, 5, 6, 2].map(e => ({do: 'event', event: e, battle: 'win'})).concat([{do: 'event', event: 2}]),
    boss: {sw: 904, event: 8, item: 912}},
};
const D2 = DUNGEONS.d2.start;
const enter = (picks, rune = 1, door = 7, item = 24) => [{do: 'item', id: item, n: rune}, {do: 'event', event: door, picks}];
// 二层以外的副本按同一模板：缺符文、逃离、普通档通关、王者档通关（CE1439）、行贿主席
function standard(id) {
  const d = DUNGEONS[id], go = (picks, rune) => enter(picks, rune, d.door, d.rune || 24);
  return [
    {id: id + '.no-rune', dungeon: id, setup: {}, steps: go([0], 0)},
    {id: id + '.escape', dungeon: id, setup: {difficulty: 5}, steps: [...go([0]), ...(d.escapeFace ? [{do: 'face', d: d.escapeFace}] : []),
      {do: 'event', event: d.escape, picks: [0]}, ...(d.escapeThen || [])]},
    {id: id + '.clear-normal', dungeon: id, setup: {}, steps: [...go([0]), ...d.clear]},
    {id: id + '.clear-king', dungeon: id, setup: {tier: 4, rand: 0.05}, steps: [...go([0, 3]), ...d.clear]},
    {id: id + '.bribe', dungeon: id, setup: {sw: [d.boss.sw]}, steps: [...go([0]), {do: 'item', id: d.boss.item || 913, n: 1}, {do: 'event', event: d.boss.event, picks: [0]}]},
  ];
}
// ---- 深渊之门 ----
// 宿主副本（宝箱事件末尾：持有物品 179 或随机变量 106 为 1 时出门，选「进入此门」去 A／B 图；设 Difficulty 1）与十二张结构相同的深渊图：
// 封印 seal（先「解开封印」开开关 75，再「继续解开封印」随机变量 108 选一场被封印者战，赢了开开关 76）、
// 深渊商人 shop（开关 76 的自动页随机变量 110 为 1 时按变量 109 定商店，否则开关 78 不开店）、出口 door（按变量 6 回副本所在层并重置）。
// 随机数在一例里是常数 r，所以变量 109 只能取到 N/2 以内的商店、Map058／059 只能从关口之外直接进（r 同时定 136 与 107）；这两处覆盖见交付单。
// n＝封印战斗种数，N＝商店变量 109 的最大值，exits＝出口按变量 6 的取值，cthulu＝Map167／168 的克苏鲁的化身事件（开关 695 的自动页，随机变量 215）
const ABYSS = {
  50: {n: 3, shop: 6, door: 7, N: 15, exits: [10, 11, 19]}, 51: {n: 3, shop: 6, door: 7, N: 15, exits: [10, 11, 19]},
  52: {n: 3, shop: 6, door: 7, N: 15, exits: [12, 13]}, 53: {n: 3, shop: 8, door: 7, N: 15, exits: [12, 13]},
  56: {n: 4, shop: 6, door: 8, N: 51, exits: [14, 18, 45]}, 57: {n: 4, shop: 6, door: 7, N: 51, exits: [14, 18, 45]},
  58: {n: 5, shop: 7, door: 6, N: 51, exits: [14, 18, 45]}, 59: {n: 5, shop: 7, door: 6, N: 51, exits: [14, 18, 45]},
  164: {n: 4, shop: 6, door: 8, N: 34, exits: [28, 29]}, 165: {n: 4, shop: 6, door: 7, N: 34, exits: [28, 29]},
  167: {n: 7, shop: 6, door: 8, N: 47, exits: [32, 33], cthulu: 7}, 168: {n: 7, shop: 6, door: 7, N: 47, exits: [32, 33], cthulu: 8},
};
// 宿主副本 → [低随机数（r＝0.05）进的图, 持物品 179 且 r＝0.5 进的图]
const GATES = {d15: [50, 51], d17: [52, 53], d18: [52, 53], d19: [56, 59], d20: [164, 165], d21: [164, 165], d22: [167, 168], d23: [167, 168]};
const rn = (k, n) => (k - 0.5) / n;
const abyssTail = m => { const a = ABYSS[m]; return [{do: 'event', event: 5, picks: [0]}, {do: 'event', event: 5, picks: [0]}, {do: 'event', event: a.shop},
  {do: 'event', event: a.shop, picks: [0]}, {do: 'event', event: a.door, picks: [0]}]; };
function gateCases(id) {
  const d = DUNGEONS[id], go = () => enter([0], 1, d.door, d.rune || 24), last = d.clear.length - 1;
  const clearTo = picks => [...go(), ...d.clear.map((s, i) => i === last ? {...s, picks} : s)];
  const [lo, hi] = GATES[id];
  return [
    {id: id + '.gate-leave', dungeon: id, setup: {rand: 0.05}, steps: clearTo([1])},
    {id: id + '.gate-low', dungeon: id, setup: {rand: 0.05}, steps: [...clearTo([0]), ...abyssTail(lo)]},
    {id: id + '.gate-item', dungeon: id, setup: {rand: 0.5}, steps: [{do: 'item', id: 179, n: 1}, ...clearTo([0]), ...abyssTail(hi)]},
    ...(id === 'd19' ? [{id: id + '.gate-item-57', dungeon: id, setup: {rand: 0.4}, steps: [{do: 'item', id: 179, n: 1}, ...clearTo([0]), ...abyssTail(57)]}] : []),
  ];
}
function abyssCases(m) {
  const a = ABYSS[m], at = {do: 'warp', map: m, x: 19, y: 23}, id = 'ab' + m, v6 = {6: a.exits[0]};
  const ks = [...new Set([1, Math.round(a.N / 4), Math.floor(a.N / 2)])];
  return [
    ...Array.from({length: a.n}, (_, i) => ({id: `${id}.seal-${i + 1}`, setup: {rand: rn(i + 1, a.n), vars: v6},
      steps: [at, {do: 'event', event: 5, picks: [0]}, {do: 'event', event: 5, picks: [0]}, {do: 'event', event: a.shop}, {do: 'event', event: a.shop, picks: [0]},
        {do: 'event', event: a.door, picks: [0]}]})),
    {id: id + '.seal-leave', setup: {}, steps: [at, {do: 'event', event: 5, picks: [1]}, {do: 'event', event: 5, picks: [0]}, {do: 'event', event: 5, picks: [1]}]},
    {id: id + '.seal-unknown', setup: {rand: 0.05}, steps: [at, {do: 'event', event: 5, picks: [0]}, {do: 'event', event: 5, picks: [0, 0]}]},
    {id: id + '.seal-lose', setup: {rand: 0.05}, steps: [at, {do: 'event', event: 5, picks: [0]}, {do: 'event', event: 5, picks: [0], battle: 'lose'}]},
    ...ks.map(k => ({id: `${id}.shop-${k}`, setup: {sw: [76], rand: rn(k, a.N)}, steps: [at, {do: 'event', event: a.shop}, {do: 'event', event: a.shop, picks: [0]}]})),
    {id: id + '.shop-none', setup: {sw: [76], rand: 0.9}, steps: [at, {do: 'event', event: a.shop}, {do: 'event', event: a.shop, picks: [0]}]},
    ...a.exits.map(v => ({id: `${id}.exit-${v}`, setup: {vars: {6: v}}, steps: [at, {do: 'event', event: a.door, picks: [0]}]})),
    {id: id + '.exit-stay', setup: {vars: v6}, steps: [at, {do: 'event', event: a.door, picks: [1]}]},
    {id: id + '.exit-other', setup: {}, steps: [at, {do: 'event', event: a.door, picks: [0]}]},
    {id: id + '.roundtrip', setup: {rand: 0.05}, steps: [at, {do: 'event', event: 5, picks: [0]}, {do: 'roundtrip'}, {do: 'event', event: 5, picks: [0]}, {do: 'roundtrip'},
      {do: 'event', event: a.shop}, {do: 'event', event: a.shop, picks: [0]}]},
    ...(a.cthulu ? [...[1, 2, 3, 4, 5].map(k => ({id: `${id}.cthulu-${k}`, setup: {sw: [695], rand: rn(k, 11)},
      steps: [at, {do: 'event', event: a.cthulu}, {do: 'event', event: a.cthulu, picks: [0]}]})),
      {id: id + '.cthulu-none', setup: {sw: [695], rand: 0.9}, steps: [at, {do: 'event', event: a.cthulu}, {do: 'event', event: a.cthulu, picks: [0]}]}] : []),
  ];
}
const SCENARIOS = [
  {id: 'd2.no-rune', setup: {}, steps: enter([0], 0)},
  {id: 'd2.leave', setup: {}, steps: enter([2])},
  {id: 'd2.enter', setup: {}, steps: enter([0])},
  {id: 'd2.enter-hang-off', setup: {}, steps: [{do: 'hang', enabled: false, active: false}, ...enter([0])]},
  {id: 'd2.enter-hang-active', setup: {}, steps: [{do: 'hang', enabled: true, active: true}, ...enter([0])]},
  {id: 'd2.tier2-adventure', setup: {tier: 2}, steps: enter([0, 1])},
  {id: 'd2.tier2-cancel', setup: {tier: 2}, steps: enter([0, 2])},
  {id: 'd2.tier3-hero', setup: {tier: 3}, steps: enter([0, 2])},
  {id: 'd2.tier4-king', setup: {tier: 4}, steps: enter([0, 3])},
  {id: 'd2.tier4-cancel-difficulty5', setup: {tier: 4, difficulty: 5}, steps: enter([0, 4])},
  {id: 'd2.reset-outside', setup: {}, steps: [{do: 'event', event: 7, picks: [1]}]},
  {id: 'd2.reenter-needs-reset', setup: {}, steps: [...enter([0]), {do: 'warp', ...D2}, {do: 'item', id: 24, n: 1}, {do: 'event', event: 7, picks: [0]},
    {do: 'event', event: 7, picks: [1]}]},
  {id: 'd2.roundtrip', setup: {}, steps: [...enter([0]), {do: 'roundtrip'}, {do: 'warp', ...D2}, {do: 'event', event: 7, picks: [0]}]},
  {id: 'd2.escape', setup: {difficulty: 5}, steps: [...enter([0]), {do: 'event', event: 6, picks: [0]}, {do: 'common', id: 714}]},
  {id: 'd2.escape-stay', setup: {}, steps: [...enter([0]), {do: 'event', event: 6, picks: [1]}]},
  {id: 'd2.clear-normal', setup: {}, steps: [...enter([0]), {do: 'event', event: 1, battle: 'win'}, {do: 'event', event: 4, picks: [1], battle: 'win'},
    {do: 'event', event: 5}, {do: 'event', event: 1, battle: 'win'}, {do: 'event', event: 1}, {do: 'common', id: 714}]},
  {id: 'd2.clear-adventure', setup: {tier: 2, difficulty: 4}, steps: [...enter([0, 1]), {do: 'event', event: 5}, {do: 'event', event: 1, battle: 'win'},
    {do: 'event', event: 1}, {do: 'common', id: 714}]},
  {id: 'd2.clear-king', setup: {tier: 4, rand: 0.05}, steps: [...enter([0, 3]), {do: 'event', event: 5}, {do: 'event', event: 1, battle: 'win'},
    {do: 'event', event: 1}]},
  {id: 'd2.bribe', setup: {sw: [882]}, steps: [...enter([0]), {do: 'item', id: 913, n: 1}, {do: 'event', event: 4, picks: [0]}, {do: 'event', event: 1, battle: 'win'}]},
  {id: 'd2.bribe-none', setup: {sw: [882]}, steps: [...enter([0]), {do: 'event', event: 4, picks: [0], battle: 'win'}, {do: 'event', event: 4, picks: [1], battle: 'win'},
    {do: 'event', event: 4, picks: [2]}, {do: 'event', event: 2, battle: 'win'}, {do: 'event', event: 2}]},
  {id: 'd2.boss-dead-bribe', setup: {sw: [882]}, steps: [...enter([0]), {do: 'event', event: 5}, {do: 'event', event: 1, battle: 'win'}, {do: 'warp', map: 123, x: 16, y: 23},
    {do: 'item', id: 913, n: 1}, {do: 'event', event: 4, picks: [0]}]},
  {id: 'hall.enable-hang', setup: {vars: {20: 3}}, steps: [...enter([0]), {do: 'event', event: 6, picks: [0]}, {do: 'warp', map: 4, x: 4, y: 18}, {do: 'event', event: 7, picks: [0]}]},
  {id: 'd2.boss-lose', setup: {}, steps: [...enter([0]), {do: 'event', event: 5}, {do: 'event', event: 1, battle: 'lose'}]},
  {id: 'd2.boss-roundtrip', setup: {}, steps: [...enter([0]), {do: 'event', event: 5}, {do: 'event', event: 1, battle: 'win'}, {do: 'roundtrip'},
    {do: 'event', event: 1}]},
  ...['d1', 'd4', 'd6', 'd7a', 'd7b', 'd9', 'd10', 'd8', 'd11', 'd12', 'd13', 'd14', 'd15', 'd16', 'd17', 'd18', 'd19', 'd20', 'd21', 'd22', 'd23', 'd24'].flatMap(standard),
  {id: 'd17.hidden-boss', dungeon: 'd17', setup: {rand: 0.9}, steps: [...enter([0], 1, 2, 171),
    ...[6, 7, 8, 9, 10, 11, 12, 13, 2, 3, 4, 5, 14].map(e => ({do: 'event', event: e, battle: 'win'}))]},
  // 二十层宝箱额外奖励（入口随机变量 155 到 97 以上，157 选三件之一）
  {id: 'd20.rare-drop', dungeon: 'd20', setup: {rand: 0.99}, steps: [...enter([0], 1, 2, 397),
    ...[1, 2, 3, 4, 6].map(e => ({do: 'event', event: e, battle: 'win'})), {do: 'event', event: 6}]},
  {id: 'kun.d17-believer', dungeon: 'd17', setup: {actors: [3]}, steps: [{do: 'warp', map: 193, x: 10, y: 13}, {do: 'event', event: 2}, {do: 'event', event: 1}]},
  // 十二层隐藏首领（随机变量 49 取到 5）；十二层逃离朝上不问
  {id: 'd12.hidden-boss', dungeon: 'd12', setup: {rand: 0.9}, steps: [...enter([0], 1, 1, 110),
    ...[3, 4, 5, 6, 7, 9, 10, 11, 12, 17].map(e => ({do: 'event', event: e, battle: 'win'}))]},
  {id: 'd12.escape-facing-up', dungeon: 'd12', setup: {}, steps: [...enter([0], 1, 1, 110), {do: 'face', d: 8}, {do: 'event', event: 19, picks: [0]}]},
  // 十一层不经副本走入口 10 进实验洞窟，再从出口 14 回
  {id: 'd11.walk-in', dungeon: 'd11', setup: {}, steps: [{do: 'warp', map: 20, x: 10, y: 14}, {do: 'event', event: 10}, {do: 'event', event: 14}]},
  // 坤坤任务：艾坤（角色 3）在队时，副本里的黄昏的信徒（八层 Map190、十一层 Map021、十二层 Map191）各领一次，技能逐级替换；不在队只说话
  {id: 'kun.d8-believer', dungeon: 'd8', setup: {actors: [3]}, steps: [...enter([0], 1, 17, 64), {do: 'event', event: 20},
    {do: 'event', event: 1}, {do: 'event', event: 1}]},
  {id: 'kun.three-believers', dungeon: 'd11', setup: {actors: [3]}, steps: [{do: 'warp', map: 21, x: 4, y: 1}, {do: 'event', event: 13},
    {do: 'warp', map: 190, x: 5, y: 9}, {do: 'event', event: 1}, {do: 'warp', map: 191, x: 3, y: 5}, {do: 'event', event: 1}, {do: 'roundtrip'},
    {do: 'event', event: 1}]},
  // 十五层首领要四只首领都打掉（变量 111≥4）才出现；行贿主席直接加 4
  {id: 'd15.boss-locked', dungeon: 'd15', setup: {}, steps: [...enter([0], 1, 4, 171), {do: 'event', event: 2, battle: 'win'}, {do: 'event', event: 13}]},
  // 十六层首领要四守卫都打掉（变量 113≥4）才出现；开关 2303 且变量 20＝31 时首领页换成守护者海拉（敌群 796，战斗内 101 对话）
  {id: 'd16.boss-locked', dungeon: 'd16', setup: {}, steps: [...enter([0], 1, 1, 171), {do: 'event', event: 3, battle: 'win'}, {do: 'event', event: 2}]},
  {id: 'd16.guardian', dungeon: 'd16', setup: {sw: [2303], vars: {20: 31}}, steps: [...enter([0], 1, 1, 171), {do: 'event', event: 2, battle: 'win'}]},
  {id: 'kun.no-kun', dungeon: 'd11', setup: {}, steps: [{do: 'warp', map: 21, x: 4, y: 1}, {do: 'event', event: 13}]},
  ...Object.keys(GATES).flatMap(gateCases),
  ...Object.keys(ABYSS).flatMap(m => abyssCases(Number(m))),
].map(sc => Object.assign({dungeon: 'd2'}, sc));

// ---- 引擎占位（同 event_probe） ----
w.eval(`
Game_Map.prototype.updateInterpreter = function() {};
ImageManager.isReady = function() { return true; };
Game_CharacterBase.prototype.isAnimationPlaying = function() { return false; };
Game_CharacterBase.prototype.isBalloonPlaying = function() { return false; };
Game_Player.prototype.areFollowersGathering = function() { return false; };
`);
const sceneStub = new Proxy(Object.create(w.Scene_Map.prototype), {
  get(o, k) {
    if (k === 'constructor') return w.Scene_Map;
    if (typeof k === 'symbol' || Object.prototype.hasOwnProperty.call(o, k)) return o[k];
    return function() {};
  },
  set(o, k, v) { o[k] = v; return true; }
});
let trace = null, battleResult = 'win', picks = [], runeItem = 24, trackKun = false;
// 坤坤任务：艾坤的「黄昏的信徒」2765 → +1～+12（4397～4408）
const KUN_SKILLS = [2765].concat(Array.from({length: 12}, (_, i) => 4397 + i));
const rec = e => trace && trace.push(e);
if (w.$) w.$.toaster = o => rec({t: 'toast', text: String(o && (o.message || o.title) || '')});
function sceneCall(cls) {
  if (cls === w.Scene_Battle) {
    rec({t: 'battle', troop: w.$gameTroop._troopId, escape: !!w.BattleManager._canEscape, lose: !!w.BattleManager._canLose});
    const result = battleResult === 'lose' ? 2 : 0;
    if (result === 2 && !w.BattleManager._canLose) { rec({t: 'scene', name: 'Scene_Gameover'}); throw new GameOver(); }
    w.BattleManager.endBattle(result);
  } else if (cls === w.Scene_Shop) rec({t: 'shop', goods: []});     // 商品由随后的 prepareNextScene 填入（command302 先 push 后 prepare）
  else rec({t: 'scene', name: cls && cls.name || String(cls)});
}
class GameOver extends Error {}
w.SceneManager.push = cls => sceneCall(cls);
w.SceneManager.goto = cls => sceneCall(cls);
w.SceneManager.prepareNextScene = function(goods) {
  const last = trace && trace[trace.length - 1];
  if (last && last.t === 'shop' && Array.isArray(goods)) last.goods = goods.map(g => [g[0], g[1]]);
};
w.DataManager.saveGame = id => { rec({t: 'save', slot: Number(id)}); return true; };
// 战斗结束的画面/音乐收尾不需要
w.BattleManager.replayBgmAndBgs = function() {};

// ---- 状态 ----
function baseCount(table, data) {
  const out = {};
  for (const id of Object.keys(table)) {
    const n = table[id]; if (!n) continue;
    const it = data[id], base = it && (it.originalBaseItemId || it.baseItemId) || Number(id);
    out[base] = (out[base] || 0) + n;
  }
  return out;
}
function snap() {
  const g = w, sw = {}, vars = {}, ss = {};
  g.$gameSwitches._data.forEach((v, i) => { if (v) sw[i] = true; });
  g.$gameVariables._data.forEach((v, i) => { if (v !== 0 && v !== undefined && v !== null && v !== '') vars[i] = typeof v === 'number' ? v : String(v); });
  for (const k of Object.keys(g.$gameSelfSwitches._data)) if (g.$gameSelfSwitches._data[k]) ss[k] = true;
  const flags = {};
  for (let i = 1; i <= 8; i++) if (g.$gameParty['DCultyL' + i] !== undefined) flags['DCultyL' + i] = !!g.$gameParty['DCultyL' + i];
  return {switches: sw, variables: vars, selfSwitches: ss, gold: g.$gameParty.gold(), items: Object.assign({}, g.$gameParty._items),
    weapons: baseCount(g.$gameParty._weapons, g.$dataWeapons), armors: baseCount(g.$gameParty._armors, g.$dataArmors),
    difficulty: g.$gameSystem.difficultyId(), flags};
}
function mapDelta(a, b, empty) {
  const out = {};
  for (const k of new Set([...Object.keys(a), ...Object.keys(b)])) {
    const x = a[k] === undefined ? empty : a[k], y = b[k] === undefined ? empty : b[k];
    if (JSON.stringify(x) !== JSON.stringify(y)) out[k] = typeof y === 'number' && typeof x === 'number' && empty === 0 ? y - x : y;
  }
  return out;
}
function delta(a, b) {
  const d = {};
  const put = (k, v) => { if (v !== undefined && (typeof v !== 'object' || Object.keys(v).length)) d[k] = v; };
  put('switches', mapDelta(a.switches, b.switches, false));
  put('variables', mapDelta(a.variables, b.variables, 0));
  put('selfSwitches', mapDelta(a.selfSwitches, b.selfSwitches, false));
  if (a.gold !== b.gold) d.gold = b.gold - a.gold;
  for (const k of ['items', 'weapons', 'armors']) put(k, mapDelta(a[k], b[k], 0));
  if (a.difficulty !== b.difficulty) d.difficulty = b.difficulty;
  put('flags', mapDelta(a.flags, b.flags, null));
  return d;
}
function focus() {
  const p = w.$gamePlayer, hu = w.$gameParty.hangUpData();
  const vars = {}, sw = {};
  for (const v of FOCUS_VARS) vars[v] = w.$gameVariables.value(v);
  for (const s of FOCUS_SW) sw[s] = !!w.$gameSwitches.value(s);
  return {difficulty: w.$gameSystem.difficultyId(), map: w.$gameMap.mapId(), x: p.x, y: p.y, hangEnabled: !!w.$gameParty.hangUpSwitch(),
    hangActive: !!(hu && hu.state), rune: w.$gameParty.numItems(w.$dataItems[runeItem]), vars, switches: sw,
    ...(trackKun ? {kun: {found: w.$gameVariables.value(346), skills: KUN_SKILLS.filter(id => w.$gameActors.actor(3).isLearnedSkill(id))}} : {})};
}

// ---- 运行 ----
function transferNow() {
  const p = w.$gamePlayer;
  if (!p.isTransferring()) return;
  rec({t: 'transfer', map: p._newMapId, x: p._newX, y: p._newY, d: p._newDirection});
  w.DataManager.loadMapData(p._newMapId);
  p.performTransfer();
}
function runList(list, eventId) {
  const it = new w.Game_Interpreter();
  it.setup(w.JsonEx.makeDeepCopy(list), eventId);
  let frames = 0;
  const msg = () => {
    const m = w.$gameMessage;
    if (!m.isBusy()) return;
    const e = {t: 'msg', face: m.faceName(), index: m.faceIndex(), lines: m._texts.slice()};
    if (m.isChoice()) {
      const pick = picks.length ? picks.shift() : m.choices().length - 1;
      Object.assign(e, {choices: m.choices().slice(), pick});
      rec(e);
      m.onChoice(pick);
    } else if (m.hasText()) rec(e);
    m.clear();
  };
  for (; frames < MAX_FRAMES && it.isRunning(); frames++) {
    w.Graphics.frameCount++;
    it.update();
    msg();
    transferNow();
    w.Game_Character.prototype.update.call(w.$gamePlayer);
    for (const ev of w.$gameMap.events()) w.Game_Character.prototype.update.call(ev);
    w.$gameScreen.update();
  }
  return !it.isRunning();
}
function setupCase(sc) {
  const dg = DUNGEONS[sc.dungeon]; runeItem = dg.rune || 24;
  const st = sc.setup, diff = st.difficulty || 3, tier = st.tier || 1, rand = st.rand === undefined ? 0.5 : st.rand;
  w.eval('ConfigManager.applyData({}); DataManager.setupNewGame(); $gamePlayer.clearTransferInfo(); Graphics.frameCount = 0;');
  w.Math.random = () => rand;
  w.$gameSystem._codexOrbRng = {seed: ORB_SEED, n: {}};
  for (const id of PARTY.concat(st.actors || [])) w.$gameParty.addActor(id);
  trackKun = (st.actors || []).includes(3);
  w.$gameSystem._difficultyId = diff;
  w.$gameSwitches.setValue(DIFF_SWITCH[diff], true);
  for (let i = 1; i <= 8; i++) w.$gameParty['DCultyL' + i] = i === diff;
  trace = [];
  runList(w.$dataCommonEvents[822].list, 0);      // 副本初始化（Map002 开局调用）
  for (const id of st.sw || []) w.$gameSwitches.setValue(id, true);
  for (const id of Object.keys(st.vars || {})) w.$gameVariables.setValue(Number(id), st.vars[id]);
  for (let t = 2; t <= tier; t++) { w.$gameSwitches.setValue(dg.tierBase + t - 1, true); w.$gameSwitches.setValue(dg.tierBase + t - 2, false); }
  warp(dg.start);
}
function warp(at) {
  w.DataManager.loadMapData(at.map);
  w.$gameMap.setup(at.map);
  w.$gamePlayer.locate(at.x, at.y);
  w.$gamePlayer.refresh();
  w.SceneManager._scene = sceneStub;
}
function runStep(step) {
  const before = snap();
  trace = [];
  const out = {do: step.do};
  battleResult = step.battle || 'win';
  picks = (step.picks || []).slice();
  try {
    if (step.do === 'event') {
      for (const e of w.$gameMap.events()) e.refresh();    // 事件页随开关变化（正式 $gameMap.refresh）
      const ev = w.$gameMap.event(step.event);
      const page = ev && !ev._erased ? ev.findProperPageIndex() : -1;
      out.page = page;
      if (page >= 0) out.finished = runList(ev.event().pages[page].list, step.event);
    } else if (step.do === 'common') {
      out.finished = runList(w.$dataCommonEvents[step.id].list, 0);
    } else if (step.do === 'item') {
      const it = w.$dataItems[step.id];
      w.$gameParty.gainItem(it, step.n - w.$gameParty.numItems(it));
    } else if (step.do === 'hang') {
      w.$gameParty.setHangUpSwitch(step.enabled);
      w.$gameParty.setHangUpData('state', step.active);
      w.$gameParty.setHangUpData('origin', step.active ? [w.$gamePlayer.x, w.$gamePlayer.y] : null);
    } else if (step.do === 'roundtrip') {
      const json = w.JsonEx.stringify(w.DataManager.makeSaveContents());
      const mapId = w.$gameMap.mapId();
      w.DataManager.createGameObjects();
      w.DataManager.extractSaveContents(w.JsonEx.parse(json));
      w.DataManager.loadMapData(mapId);
      w.$gameMap.setup(mapId);
      w.$gamePlayer.refresh();
    } else if (step.do === 'face') {
      w.$gamePlayer.setDirection(step.d);
    } else if (step.do === 'warp') {
      warp(step);
    }
  } catch (e) {
    if (!(e instanceof GameOver)) out.errors = [String(e && e.stack || e).slice(0, 400)];
    else out.gameOver = true;
  }
  out.trace = trace;
  out.delta = delta(before, snap());
  out.after = focus();
  return out;
}

const only = process.argv.slice(2);
const chosen = only.length ? SCENARIOS.filter(s => only.some(p => s.id.startsWith(p))) : SCENARIOS;
const t0 = Date.now();
const cases = chosen.map(sc => {
  setupCase(sc);
  const start = focus();
  const steps = [];
  for (const step of sc.steps) {
    const res = runStep(step);
    steps.push(res);
    if (res.gameOver || res.errors) break;
  }
  const dg = DUNGEONS[sc.dungeon];
  return {id: sc.id, dungeon: sc.dungeon, at: dg.start, tierBase: dg.tierBase, ...(dg.rune ? {rune: dg.rune} : {}), setup: sc.setup, script: sc.steps, start, steps};
});
if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
const setup = {party: PARTY, orbSeed: ORB_SEED, diffSwitch: DIFF_SWITCH, start: D2, maxFrames: MAX_FRAMES};
fs.mkdirSync(path.join(__dirname, '.sandbox'), {recursive: true});
fs.writeFileSync(path.join(__dirname, '.sandbox/dungeon.json'), JSON.stringify({schemaVersion: 1, sourceIdentity: identity, setup, cases}, null, 1) + '\n');
const bad = cases.filter(c => c.steps.some(s => s.errors));
console.log(JSON.stringify({version: identity.releaseVersion, cases: cases.length, errors: bad.map(c => c.id), ms: Date.now() - t0}));
process.exit(bad.length ? 1 : 0);
