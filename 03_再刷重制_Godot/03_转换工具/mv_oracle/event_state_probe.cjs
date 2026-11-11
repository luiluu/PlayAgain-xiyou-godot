'use strict';
// 【cc·八戒 events2·未经审查】事件对照「有状态」探针：event_probe.cjs 的变体——同一批事件页／公共事件，但在运行前按
// event_presets.json 的预设改好初始状态（开关、变量、物品、金钱、队伍、角色技能／等级、难度），
// 让 event_probe 在新游戏里走不到的分支能被量到（事件空绿，见 03_转换工具/事件空绿扫描.py）。
// 运行方式、应答、随机数、状态快照与变化都与 event_probe.cjs 相同（改那边的运行逻辑时这里要同步改）；
// 变体用例号 = 基础用例号 + '#' + tag；快照 before 在预设之后取，delta 只含事件自己造成的变化；
// 额外记 reached：[实际执行到的效果指令数, 该页效果指令总数]，证明变体比基础用例走得更深。
// 用法：node event_state_probe.cjs [变体号前缀…]；XIYOU_EVENT_OUT 改输出路径，默认 .sandbox/event_states.json；
// 增量见文末（XIYOU_STATE_PREV／XIYOU_STATE_PREV_KEYS 指定上次的结果与摘要，XIYOU_STATE_KEYS_OUT 指定本次摘要写到哪）
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const {boot} = require('./hboot.cjs'), {sourceIdentity} = require('./source_identity.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const GEN = process.env.XIYOU_GENERATED || path.resolve(__dirname, '../../01_Godot工程/modes/xiyou/generated');
const SLICE = JSON.parse(fs.readFileSync(path.join(__dirname, '../xiyou_slice.json'), 'utf8'));
const MANIFEST = JSON.parse(fs.readFileSync(path.join(GEN, 'manifest.json'), 'utf8'));
const MAX_FRAMES = 6000, PROMPT_TEXT = '测试', COMMON_MAP = 4, PARTY = [1, 8, 10, 9], DIFFICULTY = 3;

const identity = sourceIdentity(APP);
// 按地图增量（哪吒 tools81）：记下每例读了冻结源的哪些 data/MapNNN.json（所在地图、场所移动去的地图、插件自己读的），
// 摘要只含这几张地图＋冻结源其余部分；换源只改了几张地图时，别的地图上的变体照旧取回。在 sourceIdentity 之后装（它读全部地图）。
const APP_DATA = path.resolve(APP, 'data') + path.sep;
const bootMaps = new Set(), snapshotMaps = new Set();
let readSink = bootMaps;
{
  const realRead = fs.readFileSync;
  fs.readFileSync = function (file) {
    if (readSink && typeof file === 'string') {
      const f = path.resolve(file), m = f.startsWith(APP_DATA) && path.basename(f).match(/^Map(\d{3})\.json$/);
      if (m) readSink.add(Number(m[1]));
    }
    return realRead.apply(this, arguments);
  };
}
const r = boot(APP, {tolerant: true, log: false}), w = r.window;
if (r.errors.length || !w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败');
w.Input.clear();   // 参照启动不走 Scene_Boot 的 Input.initialize；玩家移动路线（门事件）的 isDebugThrough 要读 Input._currentState
// 选择称号公共事件：正式版在标题画面 Scene_Title.initialize 里接到 $dataCommonEvents 末尾（Star.Designation.ComLen），参照不进标题画面，
// 照 designation_probe 原样调一次（父类 initialize 换成空函数）；否则 ChooseTitle 预约落空（m4e1p2／p3 更换称号，悟空 dmg2）
{
  const parent = w.Star.Designation.STitle_initialize; w.Star.Designation.STitle_initialize = function () {};
  try { w.Scene_Title.prototype.initialize.call(Object.create(w.Scene_Title.prototype)); } finally { w.Star.Designation.STitle_initialize = parent; }
}
const TITLE_CE = w.Star.Designation.ComLen;

const sha = v => crypto.createHash('sha256').update(JSON.stringify(v)).digest('hex');
// ---- 用例：Godot 实际导出的事件（generated/maps）的每一页 ＋ 切片公共事件 ----
const cases = [];
for (const id of SLICE.maps) {
  const map = JSON.parse(fs.readFileSync(path.join(GEN, 'maps', 'Map' + String(id).padStart(3, '0') + '.json'), 'utf8'));
  (map.events || []).forEach(ev => {
    if (!ev) return;
    ev.pages.forEach((pg, p) => {
      if ((pg.list || []).some(c => c.code !== 0)) cases.push({id: `m${id}e${ev.id}p${p}`, kind: 'map', map: id, event: ev.id, page: p, x: ev.x, y: ev.y, listHash: sha(pg.list)});
    });
  });
}
for (const ce of MANIFEST.slice.commonEvents) {
  const rec = w.$dataCommonEvents[ce];
  if (rec && (rec.list || []).some(c => c.code !== 0)) cases.push({id: `ce${ce}`, kind: 'common', map: COMMON_MAP, event: 0, common: ce, x: 0, y: 0, listHash: sha(rec.list)});
}
const PRESETS = JSON.parse(fs.readFileSync(path.join(__dirname, '../event_presets.json'), 'utf8')).cases;
const baseById = Object.fromEntries(cases.map(c => [c.id, c]));
// goneIn：在这些冻结源版本里基础用例已经没了的预设（如 v0.30 深渊商人改成脚本 CodexAbyssMerchant.openCurrent，原第 3 页删掉），这一版跳过并记进 skippedPresets；
// 没标却找不到、或标了却还在，都报错（预设要跟着核对）
const skippedPresets = [];
const variants = PRESETS.map(p => {
  const base = baseById[p.base], gone = (p.goneIn || []).includes(identity.releaseVersion);
  if (gone) {
    if (base) throw new Error('预设标了 goneIn ' + identity.releaseVersion + '，基础用例却还在：' + p.base + '#' + p.tag);
    skippedPresets.push(p.base + '#' + p.tag); return null;
  }
  if (!base) throw new Error('预设的基础用例不存在：' + p.base);
  return Object.assign({}, base, {id: p.base + '#' + p.tag, base: p.base, preset: p.preset});
}).filter(Boolean);
const only = process.argv.slice(2);
const chosen = only.length ? variants.filter(c => only.some(p => c.id.startsWith(p))) : variants;
// 分段并行（BO）：XIYOU_PROBE_SHARD=i/n 只跑第 i 段（按变体序号轮转：序号 % n == i，各段难易搭配均衡），
// 每个变体都从新局快照起跑、互不依赖，补跑事件状态探针.py 起 n 个进程各写自己的文件再按序号交错拼回，与单进程逐字相同
const shardSpec = (process.env.XIYOU_PROBE_SHARD || '').match(/^(\d+)\/(\d+)$/);
const shardOf = shardSpec ? chosen.filter((c, i) => i % Number(shardSpec[2]) === Number(shardSpec[1])) : chosen;

// ---- 引擎占位：只跑指定解释器，等待类直接结束 ----
w.eval(`
Game_Map.prototype.updateInterpreter = function() {};
ImageManager.isReady = function() { return true; };
Game_CharacterBase.prototype.isAnimationPlaying = function() { return false; };
Game_CharacterBase.prototype.isBalloonPlaying = function() { return false; };
Game_Player.prototype.areFollowersGathering = function() { return false; };
`);
// 成就弹窗管理器正常在 Scene_Boot.start 里 init（建成就清单）；探针不走 Scene_Boot，获得物品触发成就奖励时 ShowPopUp 会读未建的 _items 而抛错，这里照原版补一次 init（无回调、不改状态）
w.eval(`if (Star.Achievement && Star.Achievement.Manager && !Star.Achievement.Manager._items) Star.Achievement.Manager.init();`);
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
const EFFECT = new Set([121, 122, 123, 125, 126, 127, 128, 129, 134, 135, 136, 137, 201, 223, 236, 301, 302, 303, 311, 312, 313, 314, 315, 316, 317,
  318, 319, 320, 321, 324, 325, 355, 356, 117, 352, 353, 354]);
// 初始状态预设：开关、变量、独立开关、金钱、物品／武器／防具、队伍、角色技能和等级、难度
const PRESET_KEYS = ['difficulty', 'party', 'actors', 'answers', 'armors', 'battleResult', 'dead', 'defeats', 'gold', 'items', 'maxLevel', 'playerDirection', 'playtime', 'random_seq', 'selfSwitches', 'switches', 'variables', 'weapons'];
// cc 分段甲 a6：actors.N 下认的子键（角色状态门：paramPlus／hp／mp／states）；不认识的同样报错
const ACTOR_PRESET_KEYS = ['level', 'skills', 'forget', 'armors', 'weapons', 'paramPlus', 'hp', 'mp', 'states'];
function applyPreset(p) {
  if (!p) return;
  // 不认识的预设键直接报错（审查 49：g3 用了 random 而不是 random_seq，悄悄没生效）
  for (const k of Object.keys(p)) if (!PRESET_KEYS.includes(k)) throw new Error('event_presets 不认识的预设键: ' + k);
  for (const [id, a] of Object.entries(p.actors || {}))
    for (const k of Object.keys(a)) if (!ACTOR_PRESET_KEYS.includes(k)) throw new Error('event_presets 不认识的角色预设键: actors.' + id + '.' + k);
  if (p.difficulty !== undefined) w.$gameSystem._difficultyId = p.difficulty;
  for (const id of p.party || []) w.$gameParty.addActor(id);
  // cc 分段甲 a3：等级上限＝插件指令「maxlevel equal N」（YEP_CoreEngine：$gameParty.ActorMaxLevel 与全部 $dataActors[i].maxLevel），
  // 在角色等级之前摆，开「变量＝角色等级 ≥ 开局上限 10」的门（m4e49 45 级以上、m4e74）；$dataActors 的上限每例由开局快照换回
  if (p.maxLevel !== undefined) {
    w.$gameParty.ActorMaxLevel = Number(p.maxLevel);
    for (let i = 1; i < w.$dataActors.length; i++) if (w.$dataActors[i]) w.$dataActors[i].maxLevel = Number(p.maxLevel);
  }
  for (const [id, a] of Object.entries(p.actors || {})) {
    const ac = w.$gameActors.actor(Number(id));
    if (a.level !== undefined) ac.changeLevel(a.level, false);
    for (const sk of a.skills || []) ac.learnSkill(sk);
    // cc 分段甲 a3：actors.N.forget＝忘掉的技能（开局就会的），开「否则（角色没学会技能）」门（ce2495 等锻炼链）
    for (const sk of a.forget || []) ac.forgetSkill(sk);
    // 八戒 DR：actors.N.armors＝给这名角色直接穿上的防具底材（forceChangeEquip 到 etype 对应的第一个槽），开「角色 N 装备防具」门（ce1213）
    for (const ar of a.armors || []) {
      const item = w.$dataArmors[ar], slot = ac.equipSlots().indexOf(item.etypeId);
      if (slot >= 0) ac.forceChangeEquip(slot, item);
    }
    for (const wp of a.weapons || []) {   // actors.N.weapons：同上，武器（etype 1）
      const item = w.$dataWeapons[wp], slot = ac.equipSlots().indexOf(item.etypeId);
      if (slot >= 0) ac.forceChangeEquip(slot, item);
    }
    // cc 分段甲 a6：角色状态门。paramPlus＝{能力编号: 值}（addParam，同指令 317）；states＝附加的状态（addState，死者不加）；
    // hp／mp＝当前值（setHp／setMp，refresh 夹到上限）。顺序：能力 → 状态 → HP → MP（先抬上限、状态改上限后再设当前值）
    for (const [i, v] of Object.entries(a.paramPlus || {})) ac.addParam(Number(i), Number(v));
    for (const st of a.states || []) ac.addState(Number(st));
    if (a.hp !== undefined) ac.setHp(Number(a.hp));
    if (a.mp !== undefined) ac.setMp(Number(a.mp));
  }
  if (p.gold !== undefined) w.$gameParty.gainGold(p.gold - w.$gameParty.gold());
  for (const [id, n] of Object.entries(p.items || {})) w.$gameParty.gainItem(w.$dataItems[Number(id)], n);
  for (const [id, n] of Object.entries(p.weapons || {})) w.$gameParty.gainItem(w.$dataWeapons[Number(id)], n);
  for (const [id, n] of Object.entries(p.armors || {})) w.$gameParty.gainItem(w.$dataArmors[Number(id)], n);
  for (const [k, v] of Object.entries(p.switches || {})) w.$gameSwitches.setValue(Number(k), !!v);
  for (const [k, v] of Object.entries(p.variables || {})) w.$gameVariables.setValue(Number(k), v);
  // events5：怪物图鉴击败数（AB_EnemyBook，$gameSystem.defeatNumber(敌人号)）；按 incrementDefeatNumber 逐次加
  for (const [id, n] of Object.entries(p.defeats || {})) for (let i = 0; i < n; i++) w.$gameSystem.incrementDefeatNumber(Number(id));
  // 审查 42：先倒下的角色（setHp(0) 带死亡状态 1），看事件脚本 addState 对死者的处理
  for (const id of p.dead || []) w.$gameActors.actor(Number(id)).setHp(0);
  // accept5：玩家朝向（条件分歧 6 [-1, 方向]：传送门、机关多要玩家面朝某方向）
  if (p.playerDirection) w.$gamePlayer.setDirection(p.playerDirection);
  for (const [k, v] of Object.entries(p.selfSwitches || {})) { const [m, e, ch] = k.split(','); w.$gameSelfSwitches.setValue([Number(m), Number(e), ch], !!v); }
  // tools75：游玩秒数（$gameSystem.playtime() = floor(Graphics.frameCount / 60)）。此时 frameCount 刚清 0，之后每帧照常 +1，
  // 所以第一条指令看到 playtime 秒＋1 帧；Godot 侧 _apply_preset 设 play_seconds，start_frames 以它为起点，同
  if (p.playtime !== undefined) {
    // 只收非负整数秒：小数秒两边浮点取整可能差一帧
    if (!Number.isInteger(p.playtime) || p.playtime < 0) throw new Error('event_presets playtime 要非负整数秒: ' + p.playtime);
    w.Graphics.frameCount = p.playtime * 60;
  }
}
w.prompt = (msg, def) => { rec({t: 'prompt', text: String(msg || '')}); return PROMPT_TEXT; };
if (w.$) w.$.toaster = o => rec({t: 'toast', text: String(o && (o.message || o.title) || '')});
const realPush = w.SceneManager.push, realGoto = w.SceneManager.goto;
// accept5：预设 battleResult（0 胜、1 逃、2 败）＝战斗回调给的结果；不写默认胜利（旧例逐字节不变）。看「输了」分支（301 can_lose 的 602／603）
let battleResult = 0;
function sceneCall(cls) {
  const name = cls && cls.name || String(cls);
  if (cls === w.Scene_Battle) {
    rec({t: 'battle', troop: w.$gameTroop._troopId, escape: !!w.BattleManager._canEscape, lose: !!w.BattleManager._canLose});
    if (w.BattleManager._eventCallback) w.BattleManager._eventCallback(battleResult);
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

// 观察面扩充（events3）：除队伍成员外，再看指令点名的角色（改 HP／经验／等级／技能／装备／名字／职业等指令，及脚本里 $gameActors.actor(N)；
// 公共事件调用递归 4 层）。队伍外角色的技能、等级此前完全看不见（如 CE 里 318 学习技能的 79 号角色），重制做没做都绿。Godot 侧 tests/xiyou_event_compare.gd 的 _watch_actors 同规则。
const WATCH_FIXED = new Set([311, 312, 313, 314, 315, 316, 317, 318]), WATCH_DIRECT = new Set([129, 319, 320, 321, 324, 325]);
function watchActors(list, depth = 0, out = new Set()) {
  for (const cmd of list || []) {
    const p = cmd.parameters || [];
    if (WATCH_FIXED.has(cmd.code) && p[0] === 0) out.add(Number(p[1]));
    else if (WATCH_DIRECT.has(cmd.code)) out.add(Number(p[0]));
    else if (cmd.code === 355 || cmd.code === 655) { if (/\$dataActors\.length|\$gameActors\.length/.test(String(p[0]))) w.$dataActors.forEach((x, i) => { if (x && x.name) out.add(i); }); for (const m of String(p[0]).matchAll(/\$gameActors\.actor\((\d+)\)/g)) out.add(Number(m[1])); }
    else if (cmd.code === 117 && depth < 4 && w.$dataCommonEvents[p[0]]) watchActors(w.$dataCommonEvents[p[0]].list, depth + 1, out);
  }
  return [...out].filter(id => w.$dataActors[id]);
}
function snap(watch = []) {
  const g = w, sw = {}, vars = {}, ss = {};
  g.$gameSwitches._data.forEach((v, i) => { if (v) sw[i] = true; });
  g.$gameVariables._data.forEach((v, i) => { if (v !== 0 && v !== undefined && v !== null && v !== '') vars[i] = typeof v === 'number' ? v : String(v); });
  for (const k of Object.keys(g.$gameSelfSwitches._data)) if (g.$gameSelfSwitches._data[k]) ss[k] = true;
  const actors = {};
  for (const id of new Set([...g.$gameParty._actors, ...watch])) {
    const a = g.$gameActors.actor(id);
    actors[id] = {name: a.name(), level: a.level, classId: a._classId, skills: a._skills.slice().sort((x, y) => x - y), states: a._states.slice().sort((x, y) => x - y),
      // events5：生命／魔法当前值与指令 317 的能力加成（_paramPlus 八项）
      hp: a._hp, mp: a._mp, paramPlus: (a._paramPlus || []).slice(0, 8).map(Number)};
  }
  const flags = {};
  for (let i = 1; i <= 8; i++) if (g.$gameParty['DCultyL' + i] !== undefined) flags['DCultyL' + i] = !!g.$gameParty['DCultyL' + i];
  if (g.$gamePlayer.SaveGameId !== undefined) flags.SaveGameId = Number(g.$gamePlayer.SaveGameId);
  return {switches: sw, variables: vars, selfSwitches: ss, gold: g.$gameParty.gold(), items: Object.assign({}, g.$gameParty._items),
    weapons: baseCount(g.$gameParty._weapons, g.$dataWeapons), armors: baseCount(g.$gameParty._armors, g.$dataArmors),
    party: g.$gameParty._actors.slice(), actors, difficulty: g.$gameSystem.difficultyId(), encounter: g.$gameSystem.isEncounterEnabled(),
    followers: g.$gamePlayer.followers().isVisible(), actorName: g.$gamePlayer.SaveActorName === undefined ? '' : String(g.$gamePlayer.SaveActorName),
    actorMaxLevel: Number(g.$gameParty.ActorMaxLevel || 0), flags,
    // events4：称号解锁（ConfigManager.DesignationN，全局）与本局成就（$gameParty.SAchievementS，不含「<ID>Time」）
    designations: Object.keys(g.ConfigManager.DesignationN || {}).filter(k => g.ConfigManager.DesignationN[k]).sort(),
    achievements: Object.keys(g.$gameParty.SAchievementS || {}).filter(k => !/Time$/.test(k)).sort(),
    // 画面色调与天气只取指令设下的目标（223／236）：色调目标、天气强度目标，天气类型仅在目标强度不为 0 时记（渐弱中的旧类型不算）
    // events5：指令 283 设的战斗背景（$gameMap._battleback1Name／2Name）
    battleback: [String(g.$gameMap._battleback1Name || ''), String(g.$gameMap._battleback2Name || '')],
    screen: {tone: g.$gameScreen._toneTarget.map(Number), weather: g.$gameScreen._weatherPowerTarget ? String(g.$gameScreen._weatherType) : 'none', power: Number(g.$gameScreen._weatherPowerTarget)}};
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
  for (const k of ['designations', 'achievements', 'battleback']) if (JSON.stringify(a[k]) !== JSON.stringify(b[k])) d[k] = b[k];
  if (JSON.stringify(a.screen) !== JSON.stringify(b.screen)) d.screen = b.screen;
  return d;
}

// 随机数改成固定序列（循环取）的用例：随机伙伴（CE1344，地图 221 引路人赢了以后也调它）抽 2701～2819 里的伙伴号角，
// 和已抽到的相同就跳回标签重抽；随机数固定 0.5 时每次都抽到同一个，死循环到帧数上限（悟空 dmg2）。Godot 侧 MVEventCore.random_sequence 同表。
const RANDOM_SEQUENCES = {ce1344: [0.5, 0.1, 0.9, 0.3, 0.7, 0.2, 0.8, 0.4, 0.6, 0.05], m221e3p0: [0.5, 0.1, 0.9, 0.3, 0.7, 0.2, 0.8, 0.4, 0.6, 0.05]};

// ---- 运行一个用例 ----
const NEW_GAME_SNAPSHOT = true;
let newGameSave = null;
const SNAPSHOT_GLOBALS = ['$gameSystem', '$gameScreen', '$gameTimer', '$gameSwitches', '$gameVariables', '$gameSelfSwitches', '$gameActors', '$gameParty', '$gameMap', '$gamePlayer'];
const mapsOf = {};
function runCase(c) {
  const caseMaps = new Set();
  readSink = caseMaps;
  // 随机数先固定再开新局：宝珠随机流的种子（setupNewGame 时取 Math.random）每例都是 0.5×2³²
  // 提速（唐僧 2026-10-25）：新开局每次约 0.6 秒（全部角色的独立装备、头顶／云裳成长记录落盘），占整轮九成以上；
  // 只在第一例真开一局，把开局后的各游戏对象序列化存下，之后每例重建游戏对象、再把这些对象换回开局时的副本。
  // 不走读档（extractSaveContents 的插件钩子与开局一样慢）。回退：把 NEW_GAME_SNAPSHOT 改为 false。
  w.eval('Math.random = function() { return 0.5; }; ConfigManager.applyData({});');
  if (NEW_GAME_SNAPSHOT && newGameSave) {
    w.eval('DataManager.createGameObjects();');
    const saved = w.JsonEx.parse(newGameSave);
    for (const k of SNAPSHOT_GLOBALS) w[k] = saved[k];
    // 独立装备实例（YEP_ItemCore）：createGameObjects 清空了实例表并截回基础长度，照它读档的做法放回开局时的实例再接上
    [w.DataManager._independentItems, w.DataManager._independentWeapons, w.DataManager._independentArmors] = saved.independent;
    w.DataManager.loadIndependentItems();
    // 数据库里被事件改过的字段也换回开局值：YEP_CoreEngine「maxlevel equal N」直接改 $dataActors[i].maxLevel，
    // 不随游戏对象复位，前一例的等级上限会带到下一例（CE231 升级药单跑 10、整轮跟在 Map011 后得 25，哪吒 2026-10-27）
    saved.dataActorMaxLevel.forEach((v, i) => { if (w.$dataActors[i]) w.$dataActors[i].maxLevel = v; });
  } else {
    readSink = snapshotMaps;   // 开局快照每例都用：它读的地图记进每例的摘要
    w.eval('DataManager.setupNewGame();');
    readSink = caseMaps;
    if (NEW_GAME_SNAPSHOT) {
      const o = {independent: [w.DataManager._independentItems, w.DataManager._independentWeapons, w.DataManager._independentArmors],
        dataActorMaxLevel: w.$dataActors.map(a => a ? a.maxLevel : null)};
      for (const k of SNAPSHOT_GLOBALS) o[k] = w[k];
      newGameSave = w.JsonEx.stringify(o);
    }
  }
  w.eval('$gamePlayer.clearTransferInfo(); Graphics.frameCount = 0;');
  w.$gameSystem._difficultyId = DIFFICULTY;
  for (const id of PARTY) w.$gameParty.addActor(id);
  w.DataManager.loadMapData(c.map);
  w.$gameMap.setup(c.map);
  w.$gamePlayer.locate(c.x, c.y);
  w.$gamePlayer.refresh();
  w.SceneManager._scene = sceneStub;
  trace = []; choiceSeen = {};
  battleResult = (c.preset && c.preset.battleResult) || 0;
  // 预设 answers（eventsreg2）：依次应答选项（选第几项，从 0 数）与数值输入（填的数）；用完回到默认应答。Godot 侧 EventHost.answers 同
  const answers = ((c.preset && c.preset.answers) || []).slice();
  applyPreset(c.preset);
  const list = c.kind === 'common' ? w.$dataCommonEvents[c.common].list : w.$dataMap.events[c.event].pages[c.page].list;
  const watch = watchActors(list);
  const before = snap(watch);
  // 第一条仓库指令就是「PHWarehouse show」（前面没有 create）的页（如青霞的第 2 页，正常流程里仓库已由第 1 页建好）：照原流程先建好默认仓库，
  // 否则 PH_Warehouse.openWarehouse 取不到仓库、抛 lootBonus 错
  const firstWarehouse = list.find(cmd => cmd.code === 356 && /^PHWarehouse /.test(String(cmd.parameters[0])));
  if (firstWarehouse && /^PHWarehouse show /.test(String(firstWarehouse.parameters[0]))) {
    const named = String(firstWarehouse.parameters[0]).match(/<([^>:]*)/);
    if (named) w.PHPlugins.PHWarehouse.createWarehouse('<' + named[1] + '>');
  }
  // 预设 random_seq（eventsreg2；键名同 accept5 解锁链用例的 random_seq）／RANDOM_SEQUENCES：这一例的 Math.random 全部按这串循环取。
  // 口径（八戒 DR，总装二十九）：原来只包 command122、脚本里的 Math.random 仍是 0.5；MV 里 122 与脚本（秘境抽奖、随机伙伴、
  // 掉落等）共用同一条 Math.random，重制 MVEventCore.random_float／random_int 也是 122 与脚本共用 random_sequence。
  // 改成事件指令执行期间（含 355 脚本、356 插件指令、子公共事件）的 Math.random 都吃序列；逐帧更新（地图、角色移动等）照旧 0.5——
  // 整例全换时这些逐帧调用也吃掉序列、首个 122 就错位（试过：66 例不一致），而重制那边逐帧随机不走 random_sequence。
  // 两边按同一事件调用顺序取数；多值序列不再因脚本随机错位（w7／w11／w13 删掉的 124 例）。
  const seq = (c.preset && c.preset.random_seq) || RANDOM_SEQUENCES[c.id], command122 = w.Game_Interpreter.prototype.command122;
  let at = 0;
  const seqRandom = seq ? () => seq[at++ % seq.length] : null;
  const it = new w.Game_Interpreter();
  const ran = new Set(), execute = w.Game_Interpreter.prototype.executeCommand;
  w.Game_Interpreter.prototype.executeCommand = function () {
    if (this === it) { const cmd = this.currentCommand(); if (cmd) ran.add(cmd); }
    if (!seqRandom) return execute.apply(this, arguments);
    // 301 战斗处理（敌群、战斗模拟）里的随机数不吃序列：重制战斗走自己的随机流，不走 random_sequence（试过：m138e6p0 等 69 例 301 后首个 122 错位）
    const cmd = this.currentCommand(), inBattle = cmd && cmd.code === 301;
    const old = w.Math.random; w.Math.random = inBattle ? () => 0.5 : seqRandom;
    try { return execute.apply(this, arguments); } finally { w.Math.random = old; }
  };
  // 生成装备（DreamX 词缀与预掷池 RandomPrefixSuffix.makeItem、YEP 独立物品的插槽浮动 addNewIndependentItem）里的随机数也不吃序列：
  // 重制 XGear.roll 走自己的装备随机流，不走 random_sequence（八戒 dropseq：m160e4p0#w13_302 等 10 例，1439 掉天顶剑·封印时
  // 这里吃掉 42 个，后面甚尔／宿傩进阶石的 randomInt(50) 错位，原版掉石头、重制没掉——对照口径不同，不是游戏不一致）
  const gearHooks = [[w.DreamX.RandomPrefixSuffix, 'makeItem'], [w.DataManager, 'addNewIndependentItem']].map(([o, k]) => [o, k, o[k]]);
  if (seqRandom) for (const [o, k, f] of gearHooks) o[k] = function () {
    const old = w.Math.random; w.Math.random = () => 0.5;
    try { return f.apply(this, arguments); } finally { w.Math.random = old; }
  };
  const runList = w.JsonEx.makeDeepCopy(list);
  it.setup(runList, c.event);
  const errors = [];
  let frames = 0;
  const msg = () => {
    const m = w.$gameMessage;
    if (!m.isBusy()) return;
    const e = {t: 'msg', face: m.faceName(), index: m.faceIndex(), lines: m._texts.slice()};
    if (m.isChoice()) {
      const sig = JSON.stringify(m.choices());
      choiceSeen[sig] = (choiceSeen[sig] || 0) + 1;
      const pick = answers.length ? Math.max(0, Math.min(m.choices().length - 1, Number(answers.shift())))
        : choiceSeen[sig] > 3 ? m.choices().length - 1 : m.choiceDefaultType() >= 0 ? m.choiceDefaultType() : 0;
      Object.assign(e, {choices: m.choices().slice(), pick});
      rec(e);
      m.onChoice(pick);
    } else if (m.isNumberInput()) {
      const num = answers.length ? Number(answers.shift()) : 0;
      Object.assign(e, {number: m.numInputVariableId(), pick: num});
      rec(e);
      w.$gameVariables.setValue(m.numInputVariableId(), num);
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
      if (w.$gameTemp.isCommonEventReserved() && w.$gameTemp._commonEventId === TITLE_CE) {
        // 称号选择：实机是本事件结束后由 setupStartingEvent 跑；它不读本事件之后改的开关，这里当场在子解释器里跑完，
        // 选项进 trace（同 Godot XDesignation.choose 当场弹）
        w.$gameTemp.clearCommonEvent();
        const child = new w.Game_Interpreter();
        child.setup(w.JsonEx.makeDeepCopy(w.$dataCommonEvents[TITLE_CE].list), 0);
        for (; frames < MAX_FRAMES && child.isRunning(); frames++) { w.Graphics.frameCount++; child.update(); msg(); }
      } else if (w.$gameTemp.isCommonEventReserved()) {
        rec({t: 'reserve', common: w.$gameTemp._commonEventId});
        w.$gameTemp.clearCommonEvent();
      }
      w.Game_Character.prototype.update.call(w.$gamePlayer);
      for (const ev of w.$gameMap.events()) w.Game_Character.prototype.update.call(ev);
      w.$gameScreen.update();
    }
  } catch (e) { errors.push(String(e && e.message || e).slice(0, 200)); }
  const out = {id: c.id, kind: c.kind, map: c.map, event: c.event, page: c.page, common: c.common, finished: !it.isRunning(), frames,
    trace, delta: delta(before, snap(watch))};
  if (errors.length) out.errors = errors;
  w.Game_Interpreter.prototype.executeCommand = execute; for (const [o, k, f] of gearHooks) o[k] = f;
  out.base = c.base; out.preset = c.preset;
  // 按指令对象记执行到的（不按下标）：帮助页更新日志段（CodexGuide.injectChangelog）把解释器指令表换成插了行的新表，
  // 下标对不上原表（map-m4 发现，原先 list[i] 越界 TypeError 整段崩）；新表里原有指令仍是 runList 里的同一对象，runList 与 list 下标对齐
  out.reached = [list.filter((x, i) => EFFECT.has(x.code) && ran.has(runList[i])).length, list.filter(x => EFFECT.has(x.code)).length];
  w.Game_Interpreter.prototype.command122 = command122;
  w.Math.random = () => 0.5;
  trace = null;
  readSink = null;
  mapsOf[c.id] = [...caseMaps];
  return out;
}

const t0 = Date.now();
// ---- 增量（BV）：变体的结果只由「用例号＋预设＋基础事件页指令＋来源＋探针代码」决定（每例从同一新局快照起跑、互不依赖），
// 摘要没变的变体从上次的 event_states.json 原样取回；上次的文件由旁边的 .keys.json 认领（含文件摘要，改过就不认）。
// 取回的变体抽 1% 重跑比对，有不同就整份重跑。XIYOU_STATE_INCREMENTAL=0 关闭；XIYOU_STATE_PREV 指定上次的文件（默认就是输出路径）。
const SETUP = {party: PARTY, difficulty: DIFFICULTY, commonMap: COMMON_MAP, prompt: PROMPT_TEXT, maxFrames: MAX_FRAMES};
const OUT = process.env.XIYOU_EVENT_OUT || path.join(__dirname, '.sandbox/event_states.json');
const KEYS_OUT = process.env.XIYOU_STATE_KEYS_OUT || OUT.replace(/\.json$/, '.keys.json');
const PREV = process.env.XIYOU_STATE_PREV || OUT, PREV_KEYS = process.env.XIYOU_STATE_PREV_KEYS || PREV.replace(/\.json$/, '.keys.json');
const fileSha = f => crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex');
// 摘要（tools81 起第 2 版）：冻结源除 data/MapNNN.json 以外的全部＋开局设定＋探针代码＋引擎外壳为公共部分；每例再加
// 用例号、预设、基础页指令与坐标、本例读到的那几张地图（含开局快照与启动时读的）。不再含整份切片与切片地图表：
// 那只决定有哪些用例，不改变单个用例的结果（原来切片改任何字段、换源改任何文件都让 1 万个变体全部重跑）。
const MAP_INPUT = /^data\/Map\d{3}\.json$/;
const restInputs = Object.fromEntries(Object.entries(identity.inputs).filter(([k]) => !MAP_INPUT.test(k)));
const mapDigest = m => identity.inputs['data/Map' + String(m).padStart(3, '0') + '.json'] || null;
// 探针代码本身的指纹按「影响面声明」折算（tools-probe-deps2，probe_change_scope.json）：本文件从 from 改到 to，若声明只影响预设里带某些键
// （如 maxLevel、actors.*.forget）的变体，别的变体算键时把本文件当作还是 from，不因这次改动整份重跑。没有声明时与以前逐字相同。
// 声明要交叉核查（甲档）；写错会让产物过期，所以取回的变体照旧抽 1% 重跑比对，同步每日一次整份审计（XIYOU_STATE_AUDIT=1）。
const SELF_SHA = fileSha(path.join(__dirname, 'event_state_probe.cjs')), SELF_REL = 'mv_oracle/event_state_probe.cjs';
const HELPER_SHAS = ['hboot.cjs', 'fs_guard.cjs', 'manual_sandbox.cjs', 'source_identity.cjs'].map(f => fileSha(path.join(__dirname, f)));
const JSDOM_VERSION = (() => { try { return require('jsdom/package.json').version; } catch (e) { return ''; } })();
const coreMemo = new Map();
const coreFor = selfSha => {
  if (!coreMemo.has(selfSha)) coreMemo.set(selfSha, sha([2, identity.releaseVersion, restInputs, identity.runtimeInputs, SETUP,
    [selfSha, ...HELPER_SHAS], JSDOM_VERSION, [...bootMaps].sort((a, b) => a - b).map(m => [m, mapDigest(m)])]));
  return coreMemo.get(selfSha);
};
const coreFingerprint = coreFor(SELF_SHA);
const SCOPE_ROWS = (() => {
  let rows;
  try { rows = JSON.parse(fs.readFileSync(path.join(__dirname, '../probe_change_scope.json'), 'utf8')).changes || []; } catch (e) { if (e.code === 'ENOENT') return []; throw e; }
  for (const r of rows) {
    if (!(r && r.file === SELF_REL && /^[0-9a-f]{64}$/.test(r.from) && /^[0-9a-f]{64}$/.test(r.to) && r.from !== r.to
        && Array.isArray(r.presetKeys) && r.presetKeys.every(k => typeof k === 'string' && k) && typeof r.why === 'string' && r.why))
      throw new Error('probe_change_scope.json 的条目要有 file（mv_oracle/event_state_probe.cjs）、from／to（不同的整份 SHA-256）、presetKeys（字符串数组，空＝不影响任何变体）、why：' + JSON.stringify(r));
  }
  // 审查 95 P2-3：同一个 to 写两条时 scopedSelf 的 find 会按「带不带本变体的键」挑其中一条，带键那条被跳过、空数组那条命中，
  // 该重跑的变体被取回；链上有环时追链结果取决于从哪进环。两种都在用例执行前报错（同 incremental_sync.py 对 (file,to) 的去重）。
  const tos = new Set();
  for (const r of rows) {
    if (tos.has(r.to)) throw new Error('probe_change_scope.json 里同一个 to 写了两条，折算不唯一：' + r.to);
    tos.add(r.to);
  }
  const back = new Map(rows.map(r => [r.to, r.from]));
  for (const start of back.keys()) {
    const seen = new Set();
    for (let cur = start; back.has(cur); cur = back.get(cur)) {
      if (seen.has(cur)) throw new Error('probe_change_scope.json 的声明连成了环（from／to 绕回自己）：' + start);
      seen.add(cur);
    }
  }
  return rows;
})();
// 预设里出现过的键路径（数字键记成 *，含各级前缀）：{actors:{79:{forget:[1]}}} → actors、actors.*、actors.*.forget
const presetPaths = (v, pre = '', out = new Set()) => {
  if (v && typeof v === 'object' && !Array.isArray(v)) for (const [k, x] of Object.entries(v)) {
    const p = pre ? pre + '.' + (/^\d+$/.test(k) ? '*' : k) : k;
    out.add(p); presetPaths(x, p, out);
  }
  return out;
};
// 最新那条声明（to＝当前文件 SHA）的每个键都要在至少一个变体（全部预设，不只本次选中的）的键路径里出现：
// 键写错或拼错会让它「不影响任何变体」，该重跑的变体被取回（审查 76 P3-2）。只查最新那条：旧条目对应的预设可能已删改。
if (SCOPE_ROWS.length) {
  const allPaths = new Set();
  for (const c of variants) for (const p of presetPaths(c.preset)) allPaths.add(p);
  for (const r of SCOPE_ROWS.filter(r => r.to === SELF_SHA)) {
    const missing = r.presetKeys.filter(k => !allPaths.has(k));
    if (missing.length)
      throw new Error('probe_change_scope.json 最新声明的 presetKeys 在任何变体的预设键路径里都没出现（拼错？数字键要写 *）：' + JSON.stringify(missing));
  }
}
const scopedSelf = preset => {
  if (!SCOPE_ROWS.length) return SELF_SHA;
  const paths = presetPaths(preset), seen = new Set();
  let cur = SELF_SHA;
  while (!seen.has(cur)) {
    seen.add(cur);
    const row = SCOPE_ROWS.find(r => r.to === cur && !r.presetKeys.some(k => paths.has(k)));
    if (!row) break;
    cur = row.from;
  }
  return cur;
};
const keyOf = (c, maps) => sha([coreFor(scopedSelf(c.preset)), c.id, c.preset, c.listHash, c.x, c.y, maps.map(m => [m, mapDigest(m)])]);
const byId = Object.fromEntries(variants.map(c => [c.id, c]));
let reuse = new Map(), reuseMaps = {};
if (process.env.XIYOU_STATE_INCREMENTAL !== '0' && fs.existsSync(PREV) && fs.existsSync(PREV_KEYS)) {
  try {
    const pk = JSON.parse(fs.readFileSync(PREV_KEYS, 'utf8')), prev = JSON.parse(fs.readFileSync(PREV, 'utf8'));
    if (pk.version === 2 && pk.fileSha === fileSha(PREV) && JSON.stringify(prev.setup) === JSON.stringify(SETUP)) {
      for (const c of prev.cases) {
        const v = byId[c.id], maps = pk.maps && pk.maps[c.id];
        if (v && Array.isArray(maps) && pk.keys[c.id] && pk.keys[c.id] === keyOf(v, maps)) { reuse.set(c.id, c); reuseMaps[c.id] = maps; }
      }
    }
  } catch (e) { reuse = new Map(); }
}
// 审计（XIYOU_STATE_AUDIT=1，同步每日一次）：整份重跑，同时拿每个「本可取回」的变体（结果与读到的地图）与上次逐个比对，有不同就失败（退出码 3），
// 说明指纹漏了依赖（或影响面声明写错）。
const AUDIT = process.env.XIYOU_STATE_AUDIT === '1';
let auditCandidates = null;
if (AUDIT && reuse.size) { auditCandidates = reuse; reuse = new Map(); }
let reused = 0, sampled = 0, mismatched = 0;
const todo = shardOf.filter(c => reuse.has(c.id));
if (todo.length) {
  const picks = todo.filter((c, i) => i % 100 === 0);   // 1% 自检
  for (const c of picks) {
    sampled++;
    const again = runCase(c), got = [...new Set([...mapsOf[c.id], ...snapshotMaps])].sort((a, b) => a - b);
    // 结果相同、读到的地图也要相同（摘要漏了某张地图的依赖就会在这里露出来）
    if (JSON.stringify(again) !== JSON.stringify(reuse.get(c.id)) || JSON.stringify(got) !== JSON.stringify(reuseMaps[c.id])) mismatched++;
  }
  if (mismatched) { console.error('增量自检：' + mismatched + '/' + sampled + ' 个取回的变体与重跑不同，整份重跑'); reuse = new Map(); }
}
const results = shardOf.map(c => reuse.has(c.id) ? (reused++, reuse.get(c.id)) : runCase(c));
if (auditCandidates) {
  const wrong = [];
  shardOf.forEach((c, i) => {
    if (!auditCandidates.has(c.id)) return;
    const got = [...new Set([...mapsOf[c.id], ...snapshotMaps])].sort((a, b) => a - b);
    if (JSON.stringify(results[i]) !== JSON.stringify(auditCandidates.get(c.id)) || JSON.stringify(got) !== JSON.stringify(reuseMaps[c.id])) wrong.push(c.id);
  });
  if (wrong.length) {
    console.error('STATE_AUDIT_FAIL ' + JSON.stringify({audited: auditCandidates.size, different: wrong.length, sample: wrong.slice(0, 5),
      note: '指纹相同的变体这次重跑与上次结果不同：指纹漏了依赖，或探针代码改动的影响面声明写错；先查清再同步'}));
    process.exit(3);
  }
  console.error('STATE_AUDIT_OK ' + JSON.stringify({audited: auditCandidates.size}));
}
readSink = null;
if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
const setup = SETUP;
// 同步按地图分几个进程并行时，各进程由 XIYOU_EVENT_OUT 写到自己的存档目录下，再按原顺序拼回 .sandbox/events.json
fs.mkdirSync(path.dirname(OUT), {recursive: true});
fs.writeFileSync(OUT, JSON.stringify(Object.assign({sourceIdentity: identity, setup, cases: results}, skippedPresets.length ? {skippedPresets} : {})));
// 旁边的 .keys.json：本次输出的每个变体的摘要和读到的地图；分段时各段只写自己那段（没有 fileSha），由拼回的一方合并后补上整份文件的摘要
const keys = {}, maps = {};
for (const c of shardOf) {
  const m = reuse.has(c.id) ? reuseMaps[c.id] : [...new Set([...mapsOf[c.id], ...snapshotMaps])].sort((a, b) => a - b);
  maps[c.id] = m; keys[c.id] = keyOf(c, m);
}
fs.writeFileSync(KEYS_OUT, JSON.stringify(Object.assign({version: 2, coreFingerprint, keys, maps, reused}, shardSpec ? {} : {fileSha: fileSha(OUT)})));
console.log(JSON.stringify({version: identity.releaseVersion, cases: results.length, reused, sampled, unfinished: results.filter(x => !x.finished).map(x => x.id),
  errors: results.filter(x => x.errors).map(x => x.id), ms: Date.now() - t0}));
process.exit(0);
