'use strict';
// 【cc·悟空·未经审查】洪荒二期（installNativeHonghuangRuntime）：判定口径、诅咒加成券、不朽存在权能掉落、CE1445 洪荒压制。
// ① isHonghuang：开关 2483／2463 各种组合，以及只把难度设成 8（牢妲 Map004 EV62 能单独切怪物难度）——原版只看开关；
// ② grantTicketBonus（CE1439 开头）：诅咒持有者（队伍里第一个学了诅咒的，没有取队首）的档位系数连乘 → 加发 round(5×(倍率−1)) 张 1639 与提示；
// ③ rollPower（CE1439 末尾）：真实 BattleManager.setup／startBattle／endBattle 记本场身份（洪荒且不朽存在胜利、每战一次），
//    区段按开战时 bossFloor，概率 min(1, 0.03×倍率×powerFactor(熟练度))，rand 用给定序列；
// ④ CE1445 洪荒补强：开关 2463 开着时全员学 5972／5973 与 <CodexHonghuangSuppress> 被动（10300）。
// 产物 .sandbox/honghuang_reward.json，手工复制为 tests/fixtures/honghuang_reward_oracle.json（tests/xiyou_honghuang_reward 对照，不进同步）。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const H = w.CodexHonghuang;
if (!H || !H.rollPower) throw new Error('洪荒模块未安装');
const toasts = [];
if (!w.$) w.$ = {};
w.$.toaster = o => toasts.push(o && o.message);
const stub = new Proxy({}, {get: () => () => {}});
const PARTY = [1, 8, 9, 10];
const fresh = (o) => {
  newGame(); toasts.length = 0;
  w.eval('$gameParty._actors=[' + PARTY + ']; $gameParty._battleMembers=[' + PARTY + ',0];');
  for (const [id, on] of Object.entries(o.switches || {})) w.$gameSwitches.setValue(Number(id), on);
  for (const [id, list] of Object.entries(o.curses || {})) for (const s of list) w.$gameActors.actor(Number(id)).learnSkill(s);
  if (o.difficulty) w.eval('$gameSystem._difficultyId=' + o.difficulty + ';');
  if (o.mastery) w.$gameSystem._codexBossMastery = o.mastery;
  if (o.v20 != null) w.$gameVariables.setValue(20, o.v20);
};
function battle(troop, map, origin) {
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  if (map) w.$gameMap._mapId = map;
  w.$gameMap._yunUnknownOrigin = origin;
  const bm = w.BattleManager; bm.setup(troop, true, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.SceneManager._scene = {_otbDisplayWindow: stub};
  bm.startBattle();
  return bm;
}
const ticket = () => w.$gameParty.numItems(w.$dataItems[H.TICKET]);
const POWER_ITEMS = [1654, 1655, 1656, 1657, 1658, 1659, 1667, 1674, 1683, 1718];
const powers = () => POWER_ITEMS.filter(id => w.$gameParty.numItems(w.$dataItems[id]) > 0).map(id => [id, w.$gameParty.numItems(w.$dataItems[id])]);
const seqRand = list => { let i = 0; const used = []; const f = () => { const v = i < list.length ? list[i] : 0.99; i++; used.push(v); return v; }; f.used = used; return f; };
const cases = [];

// ① 判定口径
const GATES = [['none', {}], ['s2483', {2483: true}], ['s2463', {2463: true}], ['both', {2483: true, 2463: true}], ['diff8', {}, 8], ['diff8_2483off_2463', {2463: true}, 1]];
for (const [tag, switches, difficulty] of GATES) cases.push(makeCase(`gate.${tag}`, {switches, difficulty}, () => {
  fresh({switches, difficulty, curses: {1: [7201]}});
  const before = ticket(), n = H.grantTicketBonus();
  return {isHonghuang: H.isHonghuang(), difficulty: w.$gameSystem.difficultyId(), granted: n, ticket: ticket() - before, toasts: toasts.slice()};
}));

// ② 发券：持有者、倍率、四舍五入
const TICKETS = [
  ['nocurse', {}],
  ['light', {1: [7211]}],                       // 1.0 → 0
  ['mid', {1: [7210]}],                         // 1.2 → round(1) = 1
  ['heavy', {1: [7201]}],                       // 1.5 → round(2.5) = 3
  ['mid2', {1: [7210, 7205]}],                  // 1.44 → round(2.2) = 2
  ['five_heavy', {1: [7201, 7202, 7212, 7213, 7214]}],
  ['mix', {1: [7203, 7205, 7201, 7215, 7206]}],
  ['holder_second', {9: [7201, 7202]}],         // 队首没有诅咒：取第一个有诅咒的（9）
  ['holder_first_wins', {8: [7210], 9: [7201, 7202]}],
  ['outside_party', {50: [7201, 7202]}]         // 不在队伍：队首（没诅咒）
];
for (const [tag, curses] of TICKETS) cases.push(makeCase(`ticket.${tag}`, {curses}, () => {
  fresh({switches: {2483: true}, curses});
  const before = ticket(), n = H.grantTicketBonus();
  return {bonus: round(H.curseBonus()), granted: n, ticket: ticket() - before, toasts: toasts.slice()};
}));

// ③ 权能掉落
const HEAVY5 = [7201, 7202, 7212, 7213, 7214];
const POWER = [
  // tag, 开关, 诅咒, 敌群, 地图, 来源, 结果, rand 序列, 其他
  ['seg3.hit', {2483: true}, [], 539, 162, 57, 0, [0, 0]],
  ['seg3.edge', {2483: true}, [], 539, 162, 57, 0, [0.0299, 0.03]],          // p＝0.03：前一本中、后一本不中
  ['seg3.miss', {2483: true}, [], 539, 162, 57, 0, [0.5, 0.5]],
  ['seg3.2463', {2463: true}, [], 540, 162, 59, 0, [0, 0]],
  ['not_hh', {}, [], 539, 162, 57, 0, [0, 0]],
  ['diff8_only', {}, [], 539, 162, 57, 0, [0, 0], {difficulty: 8}],
  ['lost', {2483: true}, [], 539, 162, 57, 1, [0, 0]],
  ['escape', {2483: true}, [], 539, 162, 57, 2, [0, 0]],
  ['not_immortal', {2483: true}, [], 539, 162, 56, 0, [0, 0]],             // 来源 56 不是不朽
  ['other_troop', {2483: true}, [], 3, 162, 57, 0, [0, 0]],
  ['legacy', {2483: true}, [], 539, 162, null, 0, [0, 0], {v107: 2}],         // 没有来源：按变量 107 旧难度
  ['seg1', {2483: true}, [], 454, 152, 38, 0, [0, 0]],
  ['seg2', {2483: true}, [], 544, 161, 53, 0, [0, 0]],
  ['seg4', {2483: true}, [], 584, 177, 174, 0, [0, 0]],
  ['seg5', {2483: true}, [], 724, 210, 211, 0, [0, 0]],
  ['heavy.rate', {2483: true}, HEAVY5, 539, 162, 57, 0, [0.2278, 0.2279]],  // p＝0.03×7.59375＝0.2278125
  ['mastery10', {2483: true}, [], 539, 162, 57, 0, [0.0599, 0.06], {mastery: {539: 10}}],
  ['mastery50', {2483: true}, [], 539, 162, 57, 0, [0.0899, 0.09], {mastery: {539: 50}}],
  ['cap', {2483: true}, HEAVY5, 539, 162, 57, 0, [0.68, 0.69], {mastery: {539: 50}}], // 0.683…：0.68 中、0.69 不中
  ['twice', {2483: true}, [], 539, 162, 57, 0, [0, 0, 0, 0], {twice: true}]
];
for (const [tag, switches, curses, troop, map, origin, result, rolls, extra] of POWER) cases.push(makeCase(`power.${tag}`, {switches, curses, troop, map, origin, result, rolls, ...(extra || {})}, () => {
  const x = extra || {};
  fresh({switches, curses: {1: curses}, difficulty: x.difficulty, mastery: x.mastery});
  if (x.v107 != null) w.$gameVariables.setValue(107, x.v107);
  const bm = battle(troop, map, origin);
  bm.endBattle(result);
  const r = seqRand(rolls), got = H.rollPower(r), again = x.twice ? H.rollPower(r) : null;
  return {got, again, used: r.used.length, powers: powers(), toasts: toasts.slice(), floor: H.bossFloor(), segment: H.segment(H.bossFloor()),
    chance: round(H.powerChance()), factor: w.CodexEconomy.powerFactor(troop)};
}));
// 没开战直接调：powerBattle 为空
cases.push(makeCase('power.no_battle', {}, () => { fresh({switches: {2483: true}}); w.BattleManager.setup(539, true, false); return {got: H.rollPower(seqRand([0, 0]))}; }));

// ④ CE1445
const SAMPLE = [1, 8, 9, 10, 2, 50, 166];
for (const [tag, on] of [['on', true], ['off', false]]) cases.push(makeCase(`ce1445.${tag}`, {on}, () => {
  fresh({switches: {2463: on}});
  const it = new w.Game_Interpreter(); it.setup(w.JsonEx.makeDeepCopy(w.$dataCommonEvents[1445].list), 0);
  let frames = 0; for (; frames < 2000 && it.isRunning(); frames++) it.update();
  const named = []; for (let j = 1; j < w.$dataActors.length; j++) if (w.$dataActors[j] && w.$dataActors[j].name !== '') named.push(j);
  const count = s => named.filter(j => w.$gameActors._data[j] && w.$gameActors._data[j].isLearnedSkill(s)).length;
  const actors = {}; SAMPLE.forEach(id => { const a = w.$gameActors.actor(id); actors[id] = [10300, 5972, 5973].filter(s => a.isLearnedSkill(s)); });
  return {finished: !it.isRunning(), named: named.length, learners: {10300: count(10300), 5972: count(5972), 5973: count(5973)}, actors};
}));

process.exit(finish(host, 'honghuang_reward.json', {hostScope: '真实 BattleManager.setup／startBattle／endBattle（不跑回合）、真实公共事件 1445；rollPower 的 rand 用给定序列', cases}) ? 0 : 1);
