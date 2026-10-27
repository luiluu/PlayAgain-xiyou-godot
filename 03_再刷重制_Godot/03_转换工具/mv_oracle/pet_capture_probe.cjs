'use strict';
// 宠物来源（Star_PetSystem）严格级参照：战斗开始掷「可捕捉」（Scene_Battle.start 包装）、敌群 1 强制可捕捉、名字「宝宝」后缀、
// 第 5 回合结束可捕捉的敌人逃跑（BattleManager.endTurn 包装）、捕捉道具的公共事件 173 PetGet（成功／失败／不可捕捉退还）、
// 神秘生物刷新 isrefreshGTEveWar（固定时钟与随机数，记事件独立开关与敌群 1 的敌人）。新建内存队伍，只写 .sandbox/，不读写存档。
// 输出抄进 tests/fixtures/pet_capture_oracle.json，xiyou_pet_capture 对照（夹具记插件 SHA，正式版改了要重跑）。
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const {boot} = require('./hboot.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const r = boot(APP, {tolerant:true, log:false}), w = r.window;
if (!w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败');
w.eval(`ConfigManager.applyData({}); DataManager.setupNewGame();
$gameParty._actors = [1,8,9,10]; $gameParty._battleMembers = [1,8,9,10]; $gameParty._inBattle = true;`);
const toasts = [];
if (!w.$) w.$ = {};
w.$.toaster = m => toasts.push(m.message);
let queue = [];
const draws = [];
w.Math.random = () => { const v = queue.length ? queue.shift() : 0.5; draws.push(v); return v; };
const take = () => toasts.splice(0);
// AB_EnemyBook 击败数合计（O-105：die＋refresh 每只记 2 次）
const defeats = () => (w.$gameSystem._defeatNumbers || []).reduce((a, n) => a + (n || 0), 0);

// 1. 全部敌人的 <Capture> 门槛（/(\d+)/ 取第一个整数）与 RareCapture
const capture = [];
w.$dataEnemies.forEach(e => { if (e && e.meta.Capture) { const m = /(\d+)/.exec(e.meta.Capture); capture.push([e.id, m ? Number(m[0]) : null, !!e.meta.RareCapture]); } });

// 2. Scene_Battle.start 的掷骰：只跑插件包装，原 start 换成空函数
w.Star.PetSystem.Scene_Battle_prototype_start = function () {};
function battleStart(troopId, rolls) {
  queue = [0.99, 0.99, 0.99, 0.99, 0.99, 0.99, 0.99, 0.99]; // 精英与 setup 的随机：都不中
  w.$gameTroop.setup(troopId);
  queue = rolls.slice(); draws.length = 0;
  w.Scene_Battle.prototype.start.call({});
  return {troop: troopId, rolls: draws.slice(), enemies: w.$gameTroop.members().map(e => ({id: e.enemyId(), capture: !!e.Capture, name: e.name(), letter: e._letter}))};
}
const starts = [];
// 敌群 2～6 与带同名字母的敌群：每个有 <Capture> 的敌人掷一次，随机×100 ≤ 门槛
for (const [t, rolls] of [[2, [0.39, 0.41, 0.4]], [3, [0.0, 0.999, 0.3]], [4, [0.2, 0.2, 0.2, 0.2]], [5, [0.1, 0.5, 0.9]], [6, [0.05, 0.31, 0.29]]]) starts.push(battleStart(t, rolls));
// 敌群 1：setup 时强制可捕捉，再按门槛掷（掷不中也保持可捕捉）
starts.push(battleStart(1, [0.999]));

// 3. endTurn：第 4／5／6 回合时可捕捉且活着的敌人逃跑（die＋hide）
w.Star.PetSystem.BattleManager_endTurn = function () {};
function endTurn(turn) {
  queue = [0.99, 0.99, 0.99, 0.99, 0.99, 0.99];
  w.$gameTroop.setup(2);
  const es = w.$gameTroop.members();
  es.forEach((e, i) => { e.Capture = i !== 1; });
  if (es[2]) { es[2].die(); es[2].refresh(); } // 已倒下的可捕捉敌人不逃跑
  w.$gameTroop._turnCount = turn;
  w.BattleManager._actionBattlers = []; w.BattleManager._nextTurnActionBattlers = [];
  w.$gameSystem.clearDefeatNumber();
  w.BattleManager.endTurn();
  return {turn, defeats: defeats(), enemies: es.map(e => ({capture: !!e.Capture, dead: e.isDead(), hidden: e.isHidden(), hp: e.hp, states: e._states.slice()})), toasts: take()};
}
const turns = [4, 5, 6].map(endTurn);

// 3b. 先后：Star 的包装在原版 endTurn 之前（外层只有 Raven／Mira 等角色专属的前置代码），逃跑先于各成员 onTurnEnd（毒伤、状态回合）。
// 内层换成「全体 onTurnEnd」：中毒的可捕捉敌人先逃跑、不吃毒伤；中毒的不可捕捉敌人照常扣 10%。
w.Star.PetSystem.BattleManager_endTurn = function () { w.$gameTroop.members().forEach(m => m.onTurnEnd()); };
const order = (() => {
  queue = [0.99, 0.99, 0.99, 0.99, 0.99, 0.99];
  w.$gameTroop.setup(2);
  const es = w.$gameTroop.members();
  es.forEach((e, i) => { e.Capture = i !== 1; if (i < 2) e.addState(4); });
  w.$gameTroop._turnCount = 5;
  w.BattleManager._actionBattlers = []; w.BattleManager._nextTurnActionBattlers = [];
  queue = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5];
  w.BattleManager.endTurn();
  return {turn: 5, enemies: es.map(e => ({capture: !!e.Capture, hidden: e.isHidden(), hpRate: e.hp / e.mhp, states: e._states.slice()})), toasts: take()};
})();
w.Star.PetSystem.BattleManager_endTurn = function () {};

// 4. PetGet：成功、失败（掷不中）、不可捕捉（退还道具）；Game_Action.setItem 记下的是最后一个
function petGet(name, itemId, roll, capturable, extra) {
  queue = [0.99, 0.99, 0.99, 0.99, 0.99, 0.99];
  w.$gameTroop.setup(2);
  w.$gameParty.Pets = [];
  w.$gameParty._items = {};
  w.$gameParty.gainItem(w.$dataItems[itemId], 3);
  const es = w.$gameTroop.members();
  es.forEach(e => { e.Capture = capturable; });
  const act = new w.Game_Action(w.$gameParty.members()[0]);
  act.setItem(itemId); act.setTarget(1);
  w.$gameParty.loseItem(w.$dataItems[itemId], 1); // 使用时已扣
  if (extra) extra();
  w.$gameSystem.clearDefeatNumber();
  queue = [roll, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]; draws.length = 0;
  w.Star.PetSystem.PetGet();
  const p = w.$gameParty.Pets[0];
  return {name, item: itemId, successRate: w.$dataItems[itemId].successRate, roll, capturable,
    toasts: take(), defeats: defeats(), count: w.$gameParty.numItems(w.$dataItems[itemId]), pets: w.$gameParty.Pets.length,
    targets: es.map(e => ({id: e.enemyId(), dead: e.isDead(), hidden: e.isHidden(), hp: e.hp})),
    pet: p ? {enemy: p.enemyId(), push: p._paramPush.map(Number), skills: p._skills.map(s => s && s.id), lv: p._Levelskills, ls: [p.extraLS, p.extraLSMax]} : null,
    draws: draws.length};
}
const gets = [
  petGet('success', 200, 0.4, true),
  petGet('success_80', 317, 0.79, true),
  petGet('fail', 200, 0.41, true),
  petGet('not_capturable', 316, 0.0, false),
  // 原版缺陷：第二个角色这回合又选了道具 1（成功率 100），PetGet 读的是这一次的行动（目标序号 0）
  petGet('last_action_wins', 200, 0.9, true, () => { const b = new w.Game_Action(w.$gameParty.members()[1]); b.setItem(1); b.setTarget(0); }),
];

// 5. 神秘生物刷新：固定 Date 与随机数
const RealDate = w.Date;
const ALL = [];
function refresh(name, hm, refCapture, last, preset) {
  w.Date = function () { return {getDate: () => 15, getHours: () => hm[0], getMinutes: () => hm[1]}; };
  w.$gameSelfSwitches.clear();
  w.$gameParty.PetRef_Capture = refCapture;
  w.$gameParty.PetShowTextT = true;
  w.$gameParty.PetRefDay = last ? last[0] : undefined; w.$gameParty.PetRefHour = last ? last[1] : undefined; w.$gameParty.PetRefMinute = last ? last[2] : undefined;
  w.$dataTroops[1].members[0].enemyId = 1;
  // preset：先把所有刷新图的开关打开，看 StopGTEveWar 是否全关、刷新是否只多开一处
  if (preset) w.Star.PetSystem.PetMap.forEach(m => { if (m) { if (m.PetMapIDA) w.$gameSelfSwitches.setValue([m.PetMapIDA, m.PetMapEveIDA, m.PetMapEveSwA], true); if (m.PetMapIDB) w.$gameSelfSwitches.setValue([m.PetMapIDB, m.PetMapEveIDB, m.PetMapEveSwB], true); } });
  queue = [0.3, 0.6]; draws.length = 0;
  w.Star.PetSystem.isrefreshGTEveWar();
  w.Date = RealDate;
  const on = Object.keys(w.$gameSelfSwitches._data).filter(k => w.$gameSelfSwitches._data[k]);
  return {name, hm, refCapture: !!refCapture, last: last || null, on, troop1: w.$dataTroops[1].members[0].enemyId, toasts: take(), draws: draws.slice()};
}
const refreshes = [
  refresh('window_00', [10, 2], false),
  refresh('window_30', [10, 34], false),
  refresh('outside', [10, 5], false),
  refresh('outside_29', [10, 29], false),
  refresh('done_same_window', [10, 3], false, [15, 10, 1]),
  refresh('done_other_half', [10, 31], false, [15, 10, 1]),
  refresh('done_other_hour', [11, 1], false, [15, 10, 1]),
  refresh('ref_capture', [10, 2], true),
  refresh('ref_capture_31', [10, 31], true),
  refresh('outside_preset', [10, 5], false, null, true),
  refresh('done_preset', [10, 3], false, [15, 10, 1], true),
  refresh('window_preset', [10, 2], false, null, true),
];
// 敌群 1 setup：强制可捕捉并记下当时的日／时／分
w.Date = function () { return {getDate: () => 16, getHours: () => 9, getMinutes: () => 31}; };
queue = [0.99, 0.99]; w.$dataTroops[1].members[0].enemyId = 290;
w.$gameTroop.setup(1);
const troop1 = {enemy: w.$gameTroop.members()[0].enemyId(), capture: !!w.$gameTroop.members()[0].Capture, ref: [w.$gameParty.PetRefDay, w.$gameParty.PetRefHour, w.$gameParty.PetRefMinute]};
w.Date = RealDate;

// 6. 魔兽要诀 ComEveLearnSkill：无出战宠物、学会、已会、次数满（失败都退还 $gameParty._lastItem）
function book(name, skill, war, ls) {
  w.$gameParty._items = {};
  w.$gameParty.setLastItem(w.$dataItems[343]);
  const pet = new w.Game_Enemy(1, 0, 0);
  pet._paramPush = [0,0,0,0,0,0,0,0,0,0,0,0,0,0]; pet._skills = [w.$dataSkills[1365], w.$dataSkills[1374]]; pet._Levelskills = [];
  pet.extraLS = ls[0]; pet.extraLSMax = ls[1];
  w.$gameParty.Pets = [pet]; w.$gameParty.GTWar = war ? pet : null;
  w.Star.PetSystem.ComEveLearnSkill(skill);
  const out = {name, skill, war, lsBefore: ls, toasts: take(), skills: pet._skills.map(s => s.id), ls: [pet.extraLS, pet.extraLSMax], refund: w.$gameParty.numItems(w.$dataItems[343])};
  w.$gameParty.GTWar = null; w.$gameParty.Pets = [];
  return out;
}
const books = [book('no_war', 1493, false, [0, 2]), book('learn', 1493, true, [0, 2]), book('exists', 1374, true, [0, 2]), book('full', 1493, true, [2, 2]),
  book('over', 1493, true, [3, 2])];

const petMap = w.Star.PetSystem.PetMap.map((m, i) => m ? Object.assign({index: i}, m) : null).filter(Boolean);
const src = f => crypto.createHash('sha256').update(fs.readFileSync(path.join(APP, f))).digest('hex');
const out = {source: 'js/plugins/Star_PetSystem.js', sha256: src('js/plugins/Star_PetSystem.js'), petRefNum: w.Star.PetSystem.PetRefNum,
  petMap, capture, starts, turns, gets, refreshes, troop1, books, order};
fs.mkdirSync(path.join(__dirname, '.sandbox'), {recursive: true});
fs.writeFileSync(path.join(__dirname, '.sandbox', 'pet_capture.json'), JSON.stringify(out, null, 1));
console.log(JSON.stringify({capture: capture.length, starts: starts.map(s => s.enemies.map(e => e.capture)), turns: turns.map(t => t.enemies.map(e => e.dead)), gets: gets.map(g => [g.name, g.toasts, g.count, g.pets]), refreshes: refreshes.map(x => [x.name, x.on.length, x.troop1])}));
process.exit(0);
