'use strict';
// 【Claude·悟空·未经Codex检验】副本系统参照探针（框架维护约定「副本入口与上下文」的最小参照矩阵）。
// 用冻结 v0.28 的正式引擎，从同一内存新游戏起按「剧本」逐步运行副本入口、副本内事件与公共事件，记录每一步的输出与状态变化，
// 供 Godot 的 tests/xiyou_dungeon 用同样的剧本对照（XDungeon、MVInterpreter）。
// - 剧本步骤：event（当前地图上的事件，按正式出现条件取页，暂时消除的为 −1；picks 依次回答选项，用完取最后一项；battle 为 win/lose）、
//   common（公共事件）、item（把物品数量设为 n）、hang（挂机开关 enabled 与运行中 active）、roundtrip（JsonEx 存档往返）。
// - 每例：setupNewGame、setup 里的开关 sw 与变量 vars、队伍 1/8/10/9、难度与难度开关（Map001 选难度时开的开关与 DCultyL 标记）、副本初始化 CE822，
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
const FOCUS_SW = [229, 230, 882, 1565, 1566, 1567, 1568];

const identity = sourceIdentity(APP);
const r = boot(APP, {tolerant: true, log: false}), w = r.window;
if (r.errors.length || !w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败');
w.Star.Achievement.Manager.init();

// ---- 剧本 ----
const D2 = {map: 3, x: 41, y: 17};          // 二层溪流森林，土地庙门（EV7 在 (41,16)）前
const enter = (picks, rune = 1) => [{do: 'item', id: 24, n: rune}, {do: 'event', event: 7, picks}];
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
];

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
let trace = null, battleResult = 'win', picks = [];
const rec = e => trace && trace.push(e);
if (w.$) w.$.toaster = o => rec({t: 'toast', text: String(o && (o.message || o.title) || '')});
function sceneCall(cls) {
  if (cls === w.Scene_Battle) {
    rec({t: 'battle', troop: w.$gameTroop._troopId, escape: !!w.BattleManager._canEscape, lose: !!w.BattleManager._canLose});
    const result = battleResult === 'lose' ? 2 : 0;
    if (result === 2 && !w.BattleManager._canLose) { rec({t: 'scene', name: 'Scene_Gameover'}); throw new GameOver(); }
    w.BattleManager.endBattle(result);
  } else rec({t: 'scene', name: cls && cls.name || String(cls)});
}
class GameOver extends Error {}
w.SceneManager.push = cls => sceneCall(cls);
w.SceneManager.goto = cls => sceneCall(cls);
w.SceneManager.prepareNextScene = function() {};
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
    hangActive: !!(hu && hu.state), rune: w.$gameParty.numItems(w.$dataItems[24]), vars, switches: sw};
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
  const st = sc.setup, diff = st.difficulty || 3, tier = st.tier || 1, rand = st.rand === undefined ? 0.5 : st.rand;
  w.eval('ConfigManager.applyData({}); DataManager.setupNewGame(); $gamePlayer.clearTransferInfo(); Graphics.frameCount = 0;');
  w.Math.random = () => rand;
  w.$gameSystem._codexOrbRng = {seed: ORB_SEED, n: {}};
  for (const id of PARTY) w.$gameParty.addActor(id);
  w.$gameSystem._difficultyId = diff;
  w.$gameSwitches.setValue(DIFF_SWITCH[diff], true);
  for (let i = 1; i <= 8; i++) w.$gameParty['DCultyL' + i] = i === diff;
  trace = [];
  runList(w.$dataCommonEvents[822].list, 0);      // 副本初始化（Map002 开局调用）
  for (const id of st.sw || []) w.$gameSwitches.setValue(id, true);
  for (const id of Object.keys(st.vars || {})) w.$gameVariables.setValue(Number(id), st.vars[id]);
  for (let t = 2; t <= tier; t++) { w.$gameSwitches.setValue(1564 + t, true); w.$gameSwitches.setValue(1563 + t, false); }
  warp(D2);
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
  return {id: sc.id, setup: sc.setup, script: sc.steps, start, steps};
});
if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
const setup = {party: PARTY, orbSeed: ORB_SEED, diffSwitch: DIFF_SWITCH, start: D2, maxFrames: MAX_FRAMES};
fs.mkdirSync(path.join(__dirname, '.sandbox'), {recursive: true});
fs.writeFileSync(path.join(__dirname, '.sandbox/dungeon.json'), JSON.stringify({schemaVersion: 1, sourceIdentity: identity, setup, cases}, null, 1) + '\n');
const bad = cases.filter(c => c.steps.some(s => s.errors));
console.log(JSON.stringify({version: identity.releaseVersion, cases: cases.length, errors: bad.map(c => c.id), ms: Date.now() - t0}));
process.exit(bad.length ? 1 : 0);
