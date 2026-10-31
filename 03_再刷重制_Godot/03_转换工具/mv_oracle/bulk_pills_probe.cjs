'use strict';
// 【cc·哪吒·未经审查】批量服用丹药（js/codex/runtime/installBulkPillsRuntime.js）：不开场景，照 processBatch 的顺序逐颗
// useItem → 对目标 apply（numRepeats 次）→ applyGlobal，期间拦下 reserveCommonEvent、把审过的事件当场用解释器跑完。
// ① supports：43 个支持的物品、几个不支持的、把 CE1226 改掉一条后 1685 不再支持；
// ② batch：凝血丹 1685 过 240 给奖励、九转长生丹 1710（多一层条件的那条事件）、养神丹 1726（没有事件）、法宝经验丹 1901／1987、
//    要的比库存多（停在库存不足）。记服用前后的能力、变量 968～971、开关 2466～2469、物品、插件指令与提示。
// 只在内存，产物 .sandbox/bulk_pills.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const B = w.CodexBulkPills;
if (!B || typeof B.supports !== 'function') throw new Error('批量服用模块未安装');
const toasts = [], commands = [];
w.$.toaster = o => toasts.push(String(o && o.message));
const oldPlugin = w.Game_Interpreter.prototype.pluginCommand;
w.Game_Interpreter.prototype.pluginCommand = function(command, args) { commands.push([command].concat(Array.from(args || [])).join(' ')); };
// MOG_TreasurePopup 在 126 里按事件角色画「获得物品」弹窗；不开场景时没有角色会报错。只是画面，换成空操作，物品照常进背包
w.Game_Interpreter.prototype.checkTreasurePopup = function() {};
const P = id => Array.from({length: 8}, (_, i) => w.$gameActors.actor(id).param(i));
const VARS = [968, 969, 970, 971], SWS = [2466, 2467, 2468, 2469], REWARDS = [1497, 1498, 1499, 1500];
function snap(item, actor) {
  return {stock: w.$gameParty.numItems(item), vars: VARS.map(v => w.$gameVariables.value(v)), switches: SWS.map(s => w.$gameSwitches.value(s)),
    rewards: REWARDS.map(r => w.$gameParty.numItems(w.$dataItems[r])), param: P(actor.actorId())};
}
function runEvent(id) {
  const it = new w.Game_Interpreter(); it.setup(w.$dataCommonEvents[id].list, 0);
  for (let guard = 0; guard < 10000 && it.isRunning(); guard++) it.update();
}
function batch(itemId, requested, stock, preVar) {
  newGame();
  const item = w.$dataItems[itemId], user = w.$gameParty.members()[0];
  w.$gameParty.gainItem(item, stock);
  if (preVar) w.$gameVariables.setValue(preVar[0], preVar[1]);
  toasts.length = 0; commands.length = 0;
  const before = snap(item, user);
  const action0 = new w.Game_Action(user); action0.setItemObject(item);
  const forFriend = action0.isForFriend(), targets = forFriend ? [user] : [];
  let used = 0, reason = 'complete', events = [];
  while (used < requested) {
    if (!B.supports(item) || w.$gameParty.numItems(item) < 1) { reason = '库存不足或道具已改变'; break; }
    const action = new w.Game_Action(user); action.setItemObject(item);
    if (!user.canUse(item) || (forFriend && !targets.some(t => action.testApply(t)))) { reason = '当前目标无法继续服用'; break; }
    const temp = w.$gameTemp, mine = [];
    temp.reserveCommonEvent = id => { if (id > 0) mine.push(id); };
    try { user.useItem(item); targets.forEach(t => { for (let r = 0; r < action.numRepeats(); r++) action.apply(t); }); action.applyGlobal(); used++; }
    finally { delete temp.reserveCommonEvent; }
    events = events.concat(mine);
    mine.forEach(runEvent);
  }
  return {before, after: snap(item, user), used, reason, events: [...new Set(events)], eventCount: events.length, toasts: toasts.slice(0, 6), toastCount: toasts.length,
    commands: [...new Set(commands)], commandCount: commands.length, forFriend};
}
newGame();
const cases = [];
cases.push(makeCase('supports', {}, () => {
  const ids = B.supportedItemIds.slice();
  const out = {supported: ids, yes: ids.filter(id => B.supports(w.$dataItems[id])), no: [1684, 1701, 1718, 1497, 1].filter(id => B.supports(w.$dataItems[id]))};
  const list = w.$dataCommonEvents[1226].list, saved = list[2].parameters.slice();
  list[2].parameters[3] = 239;
  out.tampered1685 = B.supports(w.$dataItems[1685]);
  list[2].parameters = saved;
  out.restored1685 = B.supports(w.$dataItems[1685]);
  return out;
}));
const BATCHES = [
  ['1685_cross', 1685, 5, 10, [968, 237]],
  ['1685_from0', 1685, 3, 3, null],
  ['1710_cross', 1710, 4, 4, [971, 78]],
  ['1726', 1726, 5, 5, null],
  ['1901', 1901, 3, 3, null],
  ['1987', 1987, 2, 2, null],
  ['short', 1685, 5, 3, null],
];
for (const [name, id, req, stock, pre] of BATCHES) cases.push(makeCase('batch.' + name, {item: id, requested: req, stock, preVar: pre}, () => batch(id, req, stock, pre)));
w.Game_Interpreter.prototype.pluginCommand = oldPlugin;
process.exitCode = finish(host, 'bulk_pills.json', {scope: 'CodexBulkPills supports() and processBatch order without scene', cases}) ? 0 : 1;
process.exit();
