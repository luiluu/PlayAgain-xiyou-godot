'use strict';
// 【Claude·未经Codex检验】大厅人族首领与特殊物品商店参照（悟空_39）：用正式引擎的 Game_Interpreter 跑 Map004 EV054（人族首领，
// 变量 20 ≥1／13／21／28 四页）、EV063（特殊物品购买，≥12／21 两页）与 EV065（洪荒女皇，变量 1476 有无限购组）的每一条选项路径，
// 记录每次打开商店时的商品（种类、ID、价格方式、价格）与当时待用的限购组（KMS_ShopInventory 的 $gameTemp.nextInventoryId）。
// event_probe 只走默认项（每页第一条路径），这里补全其余分支：丹药按开关 2466／2467 三档、变量 1476 决定是否套限购组。
// - 每例新游戏、难度 3、队伍 1/8/10/9、随机数固定 0.5；商店只记录不打开；记录后清掉待用组（同打开商店时消耗）。
// - 只写 .sandbox/lobby_shops.json；验收后复制到 generated/oracle/。
// 用法：node lobby_shop_probe.cjs
const fs = require('fs'), path = require('path');
const {boot} = require('./hboot.cjs'), {sourceIdentity} = require('./source_identity.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const MAP = 4, EVENTS = [54, 63, 65], PARTY = [1, 8, 10, 9], DIFFICULTY = 3, MAX_FRAMES = 2000;
const STATES = [   // 预设：变量 1476（≥1 时商店前套限购组）、开关 2466／2467（21 层起丹药档次）
  {id: 'base', variables: {}, switches: []},
  {id: 'v1476', variables: {1476: 1}, switches: []},
  {id: 'v1476_s2466', variables: {1476: 1}, switches: [2466]},
  {id: 'v1476_s2467', variables: {1476: 1}, switches: [2466, 2467]},
];

const identity = sourceIdentity(APP);
const r = boot(APP, {tolerant: true, log: false}), w = r.window;
if (r.errors.length || !w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败');
w.eval(`
Game_Map.prototype.updateInterpreter = function() {};
ImageManager.isReady = function() { return true; };
`);
const sceneStub = new Proxy(Object.create(w.Scene_Map.prototype), {
  get(o, k) {
    if (k === 'constructor') return w.Scene_Map;
    if (typeof k === 'symbol' || Object.prototype.hasOwnProperty.call(o, k)) return o[k];
    return function() {};
  },
  set(o, k, v) { o[k] = v; return true; }
});
let trace = null;
const sceneCall = cls => {
  if (!trace) return;
  if (cls === w.Scene_Shop) {
    trace.push({t: 'shop', goods: [], inventory: w.$gameTemp.nextInventoryId || ''});
    w.$gameTemp.nextInventoryId = null;
  } else {
    trace.push({t: 'scene', name: cls && cls.name || String(cls)});
  }
};
w.SceneManager.push = sceneCall;
w.SceneManager.goto = sceneCall;
w.SceneManager.prepareNextScene = function(goods, purchaseOnly) {
  const last = trace && trace[trace.length - 1];
  if (last && last.t === 'shop' && Array.isArray(goods)) {
    last.goods = goods.map(g => [g[0], g[1], g[2], g[3]]);
    last.purchaseOnly = !!purchaseOnly;
  }
};

function snapVars() {
  const sw = {}, vars = {};
  w.$gameSwitches._data.forEach((v, i) => { if (v) sw[i] = true; });
  w.$gameVariables._data.forEach((v, i) => { if (v) vars[i] = v; });
  return JSON.stringify({sw, vars, items: w.$gameParty._items, gold: w.$gameParty.gold()});
}

// picks：依次回答的选项下标；用完后取最后一项（离开／返回）
function run(eventId, page, st, picks) {
  w.eval('Math.random = function() { return 0.5; }; ConfigManager.applyData({}); DataManager.setupNewGame(); $gamePlayer.clearTransferInfo(); Graphics.frameCount = 0;');
  w.$gameSystem._difficultyId = DIFFICULTY;
  for (const id of PARTY) w.$gameParty.addActor(id);
  w.DataManager.loadMapData(MAP);
  w.$gameMap.setup(MAP);
  w.SceneManager._scene = sceneStub;
  for (const [k, v] of Object.entries(st.variables)) w.$gameVariables.setValue(Number(k), v);
  for (const s of st.switches) w.$gameSwitches.setValue(s, true);
  const before = snapVars();
  trace = [];
  const queue = picks.slice();
  const it = new w.Game_Interpreter();
  it.setup(w.JsonEx.makeDeepCopy(w.$dataMap.events[eventId].pages[page].list), eventId);
  const m = w.$gameMessage;
  let frames = 0;
  for (; frames < MAX_FRAMES && it.isRunning(); frames++) {
    w.Graphics.frameCount++;
    it.update();
    if (m.isBusy()) {
      if (m.isChoice()) {
        const n = m.choices().length, pick = queue.length ? Math.min(queue.shift(), n - 1) : n - 1;
        trace.push({t: 'choice', choices: m.choices().slice(), pick});
        m.onChoice(pick);
      }
      m.clear();
    }
  }
  const out = {trace, finished: !it.isRunning(), stateUnchanged: before === snapVars()};
  trace = null;
  return out;
}

// 选项树：先走一遍取第一层选项数，再对每个非最后项递归（最后一项为离开／返回）
function paths(eventId, page, st, prefix, depth) {
  const res = run(eventId, page, st, prefix);
  const choices = res.trace.filter(e => e.t === 'choice');
  if (depth > 3 || choices.length <= prefix.length) return [prefix];
  const n = choices[prefix.length].choices.length, out = [];
  for (let i = 0; i < n - 1; i++) out.push(...paths(eventId, page, st, prefix.concat([i]), depth + 1));
  return out;
}

const cases = [];
for (const ev of EVENTS) {
  const pages = w.DataManager.loadMapData && JSON.parse(fs.readFileSync(path.join(APP, 'data/Map004.json'), 'utf8')).events[ev].pages;
  pages.forEach((pg, p) => {
    if (!pg.list.some(c => c.code === 302)) return;
    for (const st of STATES) {
      for (const picks of paths(ev, p, st, [], 0)) {
        const res = run(ev, p, st, picks);
        cases.push(Object.assign({id: `e${ev}p${p}_${st.id}_${picks.join('-') || 'x'}`, event: ev, page: p, state: st.id, picks}, res));
      }
    }
  });
}
if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname, '.sandbox'), {recursive: true});
fs.writeFileSync(path.join(__dirname, '.sandbox/lobby_shops.json'),
  JSON.stringify({sourceIdentity: identity, setup: {map: MAP, party: PARTY, difficulty: DIFFICULTY, states: STATES}, cases}));
console.log(JSON.stringify({version: identity.releaseVersion, cases: cases.length,
  shops: cases.reduce((n, c) => n + c.trace.filter(e => e.t === 'shop').length, 0),
  unfinished: cases.filter(c => !c.finished).map(c => c.id), changed: cases.filter(c => !c.stateUnchanged).map(c => c.id)}));
process.exit(0);
