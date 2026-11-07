'use strict';
// 【cc·八戒·未经审查】地图事件分发定向参照（Codex 审查第 11、12 项）：真跑 $gameMap.update，记并行事件（触发 4）与自主移动（类型 2 接近玩家、类型 3 自定义路线）。
// event_probe 只单独执行一页的指令，不跑地图帧（不看触发、并行页每帧重启、页面变化终止、自主移动都量不到），这里补上。
// 每例：内存新局（host.newGame，Math.random 固定 0.5）→ 开条件开关 → 载入地图 → 玩家放到给定格 → 逐帧 $gameMap.update(true)，
// 中途按 actions 改开关／强制路线／换图；逐帧记关注事件的格子、朝向、页、图像、速度、频率（变了才记一行）、动画请求、并行解释器是否在跑。
// 动画、气泡不画（无精灵）：requestAnimation 只记一笔、isAnimationPlaying 恒 false（同 event_probe 的占位）；玩家不动。
// 只写 .sandbox/map_dispatch.json，验收后拷成 tests/fixtures/map_dispatch_oracle.json（不接入全量同步）。
// 用法：node map_dispatch_probe.cjs [用例前缀…]
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
let anims = [], frame = 0;
w.Game_CharacterBase.prototype.requestAnimation = function (id) {
  anims.push({f: frame, target: this instanceof w.Game_Event ? this.eventId() : 0, anim: id});
};
w.Game_CharacterBase.prototype.isAnimationPlaying = function () { return false; };
w.Game_CharacterBase.prototype.isBalloonPlaying = function () { return false; };
w.ImageManager.isReady = function () { return true; };

const sceneStub = new Proxy(Object.create(w.Scene_Map.prototype), {
  get(o, k) {
    if (k === 'constructor') return w.Scene_Map;
    if (typeof k === 'symbol' || Object.prototype.hasOwnProperty.call(o, k)) return o[k];
    return function () {};
  },
  set(o, k, v) { o[k] = v; return true; }
});

function look(ev) {
  return [ev.x, ev.y, ev.direction(), ev._pageIndex, ev.characterName(), ev.characterIndex(), ev.moveSpeed(), ev.moveFrequency(),
    ev.isJumping() ? 1 : 0, ev._interpreter && ev._interpreter.isRunning() ? 1 : 0];
}
const FIELDS = ['x', 'y', 'd', 'page', 'img', 'imgIndex', 'speed', 'freq', 'jump', 'parallel'];

// spec: {map, x, y, d, switches, party, frames, watch, actions: [{at, do: 'switch'|'route'|'transfer', ...}]}
function run(spec) {
  newGame();
  for (const id of spec.switches || []) w.$gameSwitches.setValue(id, true);
  if (spec.party) for (const id of spec.party) w.$gameParty.addActor(id);
  w.DataManager.loadMapData(spec.map);
  // pageRoute：把某事件第 1 页的自定义路线换成给定路线（合成用例；只改这次载入的 $dataMap）
  if (spec.pageRoute) w.$dataMap.events[spec.pageRoute.event].pages[0].moveRoute = JSON.parse(JSON.stringify(spec.pageRoute.route));
  w.$gameMap.setup(spec.map);
  w.$gamePlayer.locate(spec.x, spec.y);
  w.$gamePlayer.setDirection(spec.d || 2);
  w.$gamePlayer.refresh();
  w.SceneManager._scene = sceneStub;
  anims = []; frame = 0;
  // idle：这一行之前连续停着（不在走、不在跳）的帧数。原版移动速度与重制不同（rpg_objects 的 distancePerFrame 翻了倍），
  // 所以重制对的是「停多久才走下一步」和走过的格子顺序，不对绝对帧号
  const tracks = {}, last = {}, idle = {};
  for (const id of spec.watch) { tracks[id] = []; last[id] = ''; idle[id] = 0; }
  const record = () => {
    for (const id of spec.watch) {
      const ev = w.$gameMap.mapId() === spec.map ? w.$gameMap.event(id) : null;
      const row = ev ? look(ev) : null;
      const key = JSON.stringify(row);
      if (key !== last[id]) {
        last[id] = key;
        tracks[id].push(row ? Object.assign({f: frame, idle: idle[id]}, ...FIELDS.map((k, i) => ({[k]: row[i]}))) : {f: frame, gone: true});
      }
      idle[id] = ev && !ev.isMoving() && !ev.isJumping() ? idle[id] + 1 : 0;
    }
  };
  record();
  for (frame = 1; frame <= spec.frames; frame++) {
    for (const a of spec.actions || []) {
      if (a.at !== frame) continue;
      if (a.do === 'switch') { w.$gameSwitches.setValue(a.id, a.value); }
      else if (a.do === 'route') { w.$gameMap.event(a.event).forceMoveRoute(JSON.parse(JSON.stringify(a.route))); }
      else if (a.do === 'transfer') {
        w.$gamePlayer.reserveTransfer(a.map, a.x, a.y, 2, 2);
        w.DataManager.loadMapData(a.map);
        w.$gamePlayer.performTransfer();
      }
    }
    w.Graphics.frameCount++;
    w.$gameMap.update(true);
    record();
  }
  const selfA = {};
  for (const id of spec.watch) for (const ch of ['A', 'B']) {
    const v = w.$gameSelfSwitches.value([spec.map, id, ch]);
    if (v) selfA[`${id}${ch}`] = true;
  }
  return {mapNow: w.$gameMap.mapId(), tracks, anims, selfSwitches: selfA};
}

const ROUTE_TURN_WAIT = {list: [{code: 16}, {code: 15, parameters: [40]}, {code: 19}, {code: 0}], repeat: false, skippable: false, wait: false};
const ROUTE_LR = {list: [{code: 2}, {code: 15, parameters: [30]}, {code: 3}, {code: 15, parameters: [30]}, {code: 0}], repeat: true, skippable: false, wait: false};
const ROUTE_DOWN3 = {list: [{code: 1}, {code: 1}, {code: 1}, {code: 0}], repeat: false, skippable: true, wait: false};
const PX142 = Number(process.env.PX || 9), PY142 = Number(process.env.PY || 16);
const PX149 = Number(process.env.QX || 4), PY149 = Number(process.env.QY || 20);
const SPECS = {
  // ── 第 11 项：并行事件 ──
  // Map152 EV8：开关 2307＋79 时第 1 页并行：自身动画 60（等）→ 强制路线（上移、朝下、换图，等）→ 自开关 A → 换到第 3 页（确定键）
  'par.m152e8': {map: 152, x: 9, y: 17, d: 8, switches: [2307, 79], frames: 120, watch: [8]},
  // Map032 EV10：开关 2285 时并行：给 EV9 放动画 76（不等）→ 等 300 帧，循环；第 400 帧关开关（页面消失，等待中的解释器终止），
  // 第 500 帧再开（新解释器从头跑，当帧就放动画），共 700 帧
  'par.m32e10.toggle': {map: 32, x: 28, y: 21, d: 6, switches: [2285], frames: 700, watch: [9, 10],
    actions: [{at: 400, do: 'switch', id: 2285, value: false}, {at: 500, do: 'switch', id: 2285, value: true}]},
  // 同上，第 100 帧换到大厅 Map004：旧图的并行解释器随地图丢弃，之后不再放动画
  'par.m32e10.transfer': {map: 32, x: 28, y: 21, d: 6, switches: [2285], frames: 400, watch: [10],
    actions: [{at: 100, do: 'transfer', map: 4, x: 12, y: 18}]},
  // ── 第 12 项：自主移动 ──
  // 类型 2 接近玩家（Map142 EV4 火焰，速度 3 频率 3）：玩家在 6 格外
  'auto2.m142e4': {map: 142, x: PX142, y: PY142, d: 4, frames: 600, watch: [4, 5, 6, 7]},
  // 类型 2，频率 2（Map093 EV3）
  'auto2.m93e3': {map: 93, x: 12, y: 9, d: 4, frames: 600, watch: [3]},
  // 类型 2 中途强制路线（下移三格，可跳过）：强制期间不自主走、不看频率；走完恢复接近玩家
  'auto2.m142e4.forced': {map: 142, x: PX142, y: PY142, d: 4, frames: 600, watch: [4, 5, 6, 7],
    actions: [{at: 100, do: 'route', event: 4, route: ROUTE_DOWN3}]},
  // 类型 3 自定义路线（Map149 EV33，角色 111 在队）：随机移动／远离玩家／跳跃／改速度频率／等待
  'auto3.m149e33': {map: 149, x: PX149, y: PY149, d: 4, party: [111], frames: 400, watch: [33]},
  // 类型 3 中途强制路线（朝下、等 40 帧、朝上）：强制期间自定义路线暂停，结束后从原来的位置接着走
  'auto3.m149e33.forced': {map: 149, x: PX149, y: PY149, d: 4, party: [111], frames: 400, watch: [33],
    actions: [{at: 20, do: 'route', event: 33, route: ROUTE_TURN_WAIT}]},
  // 合成：Map149 EV33 的自定义路线换成「左、等 30、右、等 30」循环；第 100 帧（走完左步、正等着）强制路线。
  // 原版强制路线结束时 restoreMoveRoute 还原了序号又被 advanceMoveRouteIndex 加一，跳过一条（这里跳过「右」，之后一路往左偏）
  'auto3.m149e33.skip': {map: 149, x: PX149, y: PY149, d: 4, party: [111], frames: 500, watch: [33],
    pageRoute: {event: 33, route: ROUTE_LR},
    actions: [{at: 100, do: 'route', event: 33, route: ROUTE_TURN_WAIT}]},
  // 类型 3 的脚本路线「this._fleeRange = 5」（YEP_EventChasePlayer 逃离玩家；Map088 EV3），玩家在 3 格内
  'auto3.m88e3.flee': {map: 88, x: 29, y: 8, d: 8, frames: 600, watch: [3]},
};
const only = process.argv.slice(2);
const cases = Object.entries(SPECS).filter(([id]) => !only.length || only.some(p => id.startsWith(p)))
  .map(([id, spec]) => makeCase(id, spec, () => run(spec)));
process.exit(finish(host, 'map_dispatch.json', {cases}) ? 0 : 1);
