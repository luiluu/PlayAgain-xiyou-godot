'use strict';
// 【Claude·未经Codex检验】地图事件对照探针（效率改造第二步）：用正式引擎的 Game_Interpreter 逐个运行切片里的事件页与公共事件，
// 记录可观察的输出（文字/选项/数值输入/场所移动/战斗/商店/场景/存档/输入名字/提示/预约公共事件）与运行前后的状态变化，
// 供 Godot 的 MVInterpreter 以同样的初始状态和同样的应答逐项对照（tests/xiyou_event_compare）。
// - 每个用例从同一内存新游戏开始：setupNewGame、难度 3、队伍 1/8/10/9、所在地图为事件所在地图（公共事件用大厅 4），玩家在事件的位置。
// - 随机数固定 0.5（Math.random）；每例游戏时间从 0 起（Graphics.frameCount），Godot 侧用 MVInterpreter.fixed_random 对应。
// - 应答：选项取默认项（无默认取 0；同一组选项第 4 次出现起取最后一项，避免「更早的更新」之类的循环），数值输入 0，prompt 输入「测试」，战斗记为胜利（不进战斗），商店/菜单/名字等场景只记录不打开。
// - 只跑该页指令：不看出现条件；地图自己的自动/并行事件、并行公共事件都不运行；动画/气泡/集合等等待直接结束。
// - 不加载配置或任何存档；存档调用只记录（不写文件）。输出只写 .sandbox/events.json；验收后复制到 generated/oracle/。
// 用法：node event_probe.cjs [用例 ID 前缀…]
const fs = require('fs'), path = require('path');
const {boot} = require('./hboot.cjs'), {sourceIdentity} = require('./source_identity.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const GEN = process.env.XIYOU_GENERATED || path.resolve(__dirname, '../../01_Godot工程/modes/xiyou/generated');
const SLICE = JSON.parse(fs.readFileSync(path.join(__dirname, '../xiyou_slice.json'), 'utf8'));
const MANIFEST = JSON.parse(fs.readFileSync(path.join(GEN, 'manifest.json'), 'utf8'));
const MAX_FRAMES = 6000, PROMPT_TEXT = '测试', COMMON_MAP = 4, PARTY = [1, 8, 10, 9], DIFFICULTY = 3;

const identity = sourceIdentity(APP);
const r = boot(APP, {tolerant: true, log: false}), w = r.window;
if (r.errors.length || !w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败');

// ---- 用例：Godot 实际导出的事件（generated/maps）的每一页 ＋ 切片公共事件 ----
const cases = [];
for (const id of SLICE.maps) {
  const map = JSON.parse(fs.readFileSync(path.join(GEN, 'maps', 'Map' + String(id).padStart(3, '0') + '.json'), 'utf8'));
  (map.events || []).forEach(ev => {
    if (!ev) return;
    ev.pages.forEach((pg, p) => {
      if ((pg.list || []).some(c => c.code !== 0)) cases.push({id: `m${id}e${ev.id}p${p}`, kind: 'map', map: id, event: ev.id, page: p, x: ev.x, y: ev.y});
    });
  });
}
for (const ce of MANIFEST.slice.commonEvents) {
  const rec = w.$dataCommonEvents[ce];
  if (rec && (rec.list || []).some(c => c.code !== 0)) cases.push({id: `ce${ce}`, kind: 'common', map: COMMON_MAP, event: 0, common: ce, x: 0, y: 0});
}
const only = process.argv.slice(2);
const chosen = only.length ? cases.filter(c => only.some(p => c.id.startsWith(p))) : cases;

// ---- 引擎占位：只跑指定解释器，等待类直接结束 ----
w.eval(`
Game_Map.prototype.updateInterpreter = function() {};
ImageManager.isReady = function() { return true; };
Game_CharacterBase.prototype.isAnimationPlaying = function() { return false; };
Game_CharacterBase.prototype.isBalloonPlaying = function() { return false; };
Game_Player.prototype.areFollowersGathering = function() { return false; };
`);
// 脚本常读 SceneManager._scene（是否在地图、虚拟按键等）：给一个地图场景替身，未知方法一律空操作
const sceneStub = new Proxy(Object.create(w.Scene_Map.prototype), {
  get(o, k) {
    if (k === 'constructor') return w.Scene_Map;
    if (typeof k === 'symbol' || Object.prototype.hasOwnProperty.call(o, k)) return o[k];
    return function() {};
  },
  set(o, k, v) { o[k] = v; return true; }
});
let trace = null, choiceSeen = {};
const rec = e => trace && trace.push(e);
w.prompt = (msg, def) => { rec({t: 'prompt', text: String(msg || '')}); return PROMPT_TEXT; };
if (w.$) w.$.toaster = o => rec({t: 'toast', text: String(o && (o.message || o.title) || '')});
const realPush = w.SceneManager.push, realGoto = w.SceneManager.goto;
function sceneCall(cls) {
  const name = cls && cls.name || String(cls);
  if (cls === w.Scene_Battle) {
    rec({t: 'battle', troop: w.$gameTroop._troopId, escape: !!w.BattleManager._canEscape, lose: !!w.BattleManager._canLose});
    if (w.BattleManager._eventCallback) w.BattleManager._eventCallback(0);
  } else if (cls === w.Scene_Shop) {
    rec({t: 'shop', goods: []});      // 商品由随后的 prepareNextScene 填入（command302 先 push 后 prepare）
  } else {
    rec({t: 'scene', name});
  }
}
w.SceneManager.push = cls => sceneCall(cls);
w.SceneManager.goto = cls => sceneCall(cls);
w.SceneManager.prepareNextScene = function(goods) {
  const last = trace && trace[trace.length - 1];
  if (last && last.t === 'shop' && Array.isArray(goods)) last.goods = goods.map(g => [g[0], g[1]]);
};
w.DataManager.saveGame = id => { rec({t: 'save', slot: Number(id)}); return true; };

// ---- 状态快照与变化 ----
function baseCount(table, data) {
  const out = {};
  for (const id of Object.keys(table)) {
    const n = table[id]; if (!n) continue;
    const it = data[id], base = it && (it.originalBaseItemId || it.baseItemId) || Number(id);   // DreamX 随机词缀实例记原始装备 ID
    out[base] = (out[base] || 0) + n;
  }
  return out;
}
function snap() {
  const g = w, sw = {}, vars = {}, ss = {};
  g.$gameSwitches._data.forEach((v, i) => { if (v) sw[i] = true; });
  g.$gameVariables._data.forEach((v, i) => { if (v !== 0 && v !== undefined && v !== null && v !== '') vars[i] = typeof v === 'number' ? v : String(v); });
  for (const k of Object.keys(g.$gameSelfSwitches._data)) if (g.$gameSelfSwitches._data[k]) ss[k] = true;
  const actors = {};
  for (const id of g.$gameParty._actors) {
    const a = g.$gameActors.actor(id);
    actors[id] = {name: a.name(), level: a.level, classId: a._classId, skills: a._skills.slice().sort((x, y) => x - y)};
  }
  const flags = {};
  for (let i = 1; i <= 8; i++) if (g.$gameParty['DCultyL' + i] !== undefined) flags['DCultyL' + i] = !!g.$gameParty['DCultyL' + i];
  if (g.$gamePlayer.SaveGameId !== undefined) flags.SaveGameId = Number(g.$gamePlayer.SaveGameId);
  return {switches: sw, variables: vars, selfSwitches: ss, gold: g.$gameParty.gold(), items: Object.assign({}, g.$gameParty._items),
    weapons: baseCount(g.$gameParty._weapons, g.$dataWeapons), armors: baseCount(g.$gameParty._armors, g.$dataArmors),
    party: g.$gameParty._actors.slice(), actors, difficulty: g.$gameSystem.difficultyId(), encounter: g.$gameSystem.isEncounterEnabled(),
    followers: g.$gamePlayer.followers().isVisible(), actorName: g.$gamePlayer.SaveActorName === undefined ? '' : String(g.$gamePlayer.SaveActorName),
    actorMaxLevel: Number(g.$gameParty.ActorMaxLevel || 0), flags};
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
  if (JSON.stringify(a.party) !== JSON.stringify(b.party)) d.party = b.party;
  const actors = {};
  for (const id of Object.keys(b.actors)) {
    const x = a.actors[id] || {}, y = b.actors[id], ch = {};
    for (const f of Object.keys(y)) if (JSON.stringify(x[f]) !== JSON.stringify(y[f])) ch[f] = y[f];
    if (Object.keys(ch).length) actors[id] = ch;
  }
  put('actors', actors);
  for (const k of ['difficulty', 'encounter', 'followers', 'actorName', 'actorMaxLevel']) if (a[k] !== b[k]) d[k] = b[k];
  put('flags', mapDelta(a.flags, b.flags, null));
  return d;
}

// ---- 运行一个用例 ----
function runCase(c) {
  // 随机数先固定再开新局：宝珠随机流的种子（setupNewGame 时取 Math.random）每例都是 0.5×2³²
  w.eval('Math.random = function() { return 0.5; }; ConfigManager.applyData({}); DataManager.setupNewGame(); $gamePlayer.clearTransferInfo(); Graphics.frameCount = 0;');
  w.$gameSystem._difficultyId = DIFFICULTY;
  for (const id of PARTY) w.$gameParty.addActor(id);
  w.DataManager.loadMapData(c.map);
  w.$gameMap.setup(c.map);
  w.$gamePlayer.locate(c.x, c.y);
  w.$gamePlayer.refresh();
  w.SceneManager._scene = sceneStub;
  trace = []; choiceSeen = {};
  const before = snap();
  const list = c.kind === 'common' ? w.$dataCommonEvents[c.common].list : w.$dataMap.events[c.event].pages[c.page].list;
  const it = new w.Game_Interpreter();
  it.setup(w.JsonEx.makeDeepCopy(list), c.event);
  const errors = [];
  let frames = 0;
  const msg = () => {
    const m = w.$gameMessage;
    if (!m.isBusy()) return;
    const e = {t: 'msg', face: m.faceName(), index: m.faceIndex(), lines: m._texts.slice()};
    if (m.isChoice()) {
      const sig = JSON.stringify(m.choices());
      choiceSeen[sig] = (choiceSeen[sig] || 0) + 1;
      const pick = choiceSeen[sig] > 3 ? m.choices().length - 1 : m.choiceDefaultType() >= 0 ? m.choiceDefaultType() : 0;
      Object.assign(e, {choices: m.choices().slice(), pick});
      rec(e);
      m.onChoice(pick);
    } else if (m.isNumberInput()) {
      Object.assign(e, {number: m.numInputVariableId(), pick: 0});
      rec(e);
      w.$gameVariables.setValue(m.numInputVariableId(), 0);
    } else if (m.isItemChoice()) {
      Object.assign(e, {itemChoice: m.itemChoiceVariableId(), pick: 0});
      rec(e);
      w.$gameVariables.setValue(m.itemChoiceVariableId(), 0);
    } else if (m.hasText()) {
      rec(e);
    }
    m.clear();
  };
  try {
    for (; frames < MAX_FRAMES && it.isRunning(); frames++) {
      w.Graphics.frameCount++;
      it.update();
      msg();
      if (w.$gamePlayer.isTransferring()) {
        const p = w.$gamePlayer;
        rec({t: 'transfer', map: p._newMapId, x: p._newX, y: p._newY, d: p._newDirection});
        w.DataManager.loadMapData(p._newMapId);
        p.performTransfer();
      }
      if (w.$gameTemp.isCommonEventReserved()) {
        rec({t: 'reserve', common: w.$gameTemp._commonEventId});
        w.$gameTemp.clearCommonEvent();
      }
      w.Game_Character.prototype.update.call(w.$gamePlayer);
      for (const ev of w.$gameMap.events()) w.Game_Character.prototype.update.call(ev);
      w.$gameScreen.update();
    }
  } catch (e) { errors.push(String(e && e.message || e).slice(0, 200)); }
  const out = {id: c.id, kind: c.kind, map: c.map, event: c.event, page: c.page, common: c.common, finished: !it.isRunning(), frames,
    trace, delta: delta(before, snap())};
  if (errors.length) out.errors = errors;
  trace = null;
  return out;
}

const t0 = Date.now();
const results = chosen.map(runCase);
if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
const setup = {party: PARTY, difficulty: DIFFICULTY, commonMap: COMMON_MAP, prompt: PROMPT_TEXT, maxFrames: MAX_FRAMES};
fs.mkdirSync(path.join(__dirname, '.sandbox'), {recursive: true});
fs.writeFileSync(path.join(__dirname, '.sandbox/events.json'), JSON.stringify({sourceIdentity: identity, setup, cases: results}));
console.log(JSON.stringify({version: identity.releaseVersion, cases: results.length, unfinished: results.filter(x => !x.finished).map(x => x.id),
  errors: results.filter(x => x.errors).map(x => x.id), ms: Date.now() - t0}));
process.exit(0);
