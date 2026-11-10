'use strict';
// 敌群事件参照（扩楼层：一至三、五至九、十一至十二层守层者 4/5/8/28/39/52/53/67/109/110 、十层守层者 69（另有 333 给自己加状态 44）与十三至十九层守层者 111／118／138／172／173／174／333（变量 842 为 0 时先调公共事件 1398：334 完全回复、313 全队加状态、333 加状态，再强制 6069／6105／8111）、二十层守层者 456（842 为 0 时公共事件 1399 天道领域＋强制 6070／8111，否则 1400 天道领域*伪＋强制 6071；第 3 回合起每 3 回合随机 844 强制 6101～6104 与 8111）、二十一层守层者 457 与二十二层守层者 458（同 456；第 3 页生命≤20% 且变量 853＝1 的 101 对话与专属强制 3559／3560 首两回合参照不覆盖）、二十三层守层者 459（只有两页，不交礼开场比 456 多强制 6105／6107，没有第 3 页）、二十四层守层者 460（同 459）、二十五层守层者 461（同 459）、二十六层守层者 462（金角、银角两名守层者，同 459；另加玩家集火敌人 1 的两例）、二十七层守层者 463、二十八层守层者 464（同 459）与二十四层副本熊族桃园首领 526 雄霸（第 2 页第 1 回合 333 给自己状态 44、339 强制技能 3813）第 1 回合的强制行动 339 → 技能 8111「轮回模式·平衡伤害」→ 状态 1460「轮回困难v1」）。
// 二十九层太白金星 465 同 459；三十层玉皇大帝 466 不交礼开场另加强制 6101，另加 HP≤25% 的两例（hpRate：第 3 页 101 对话、336 变身 538、1399、强制 6070／6105）。
// 三十一至三十三层守层者 467 女娲／468 伏羲／469 鸿蒙老祖（四页：第 3 回合起每 3 回合随机强制、第 1 回合变量 842＝0 时公共事件 1397 霸者领域＋强制 6068／6055／6057／6051／8111、
// HP≤30% 第 3 页 101 对话＋1397、HP≤10% 第 4 页 101 对话＋336 变身 929／929／930＋1399）与三十层求道者门后 Map055 引路人 794（HP≤20% 第 4 页变身 922）：
// 各加 HP≤30%（hpRate 0.3）一例；HP≤10% 一例另预置第 3 页已执行（flags：第 3 页先回满会让第 4 页条件不再成立，实战是先过 30% 再过 10%）。
// 十三至十九层补已交见面礼（变量 842＝1）分支，确认不触发开场领域与强制行动。
// 十五层副本敌群 160（控尸者 HP≤1% 时两只丧尸附加状态 1）：开战前控尸者 HP 设 1（守层者那套两回合检查以 e0 为首领，不适用这个敌群）（preset，只到第 1 回合输入前）。
// 真实 BattleManager 跑前两回合（日志窗/精灵组用空代理，同 sequence_probe）：普通难度、开局队伍 1/8/9/10（1 级，开局被动），
// 角色输入一律普通攻击敌人 0；Math.random 敌群生成时 0.99（不出神话），之后 0.5（分散度为 0、不会心）。
// 记录：每次开始行动（回合数、行动者、技能、是否强制）、每次 invokeAction 的目标血量变化与伤害弹字（startDamagePopup 时的 hpDamage）、
// 行动者攻击/魔攻，以及战斗中的状态。只写 .sandbox/troop_events.json。
const fs = require('fs'), path = require('path');
const {boot} = require('./hboot.cjs'), {sourceIdentity} = require('./source_identity.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity = sourceIdentity(APP), r = boot(APP, {tolerant: true, log: false}), w = r.window;
if (r.errors.length || !w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败');
const PARTY = [1, 8, 9, 10];
const stub = new Proxy(function () {}, {get: (t, k) => k === '_waitCount' ? 0 : (() => false), set: () => true});
const sprite = () => {
  const store = {x: 0, y: 0, _homeX: 0, _homeY: 0, width: 64, height: 64, scale: {x: 1, y: 1}, anchor: {x: 0.5, y: 1}, opacity: 255};
  return new Proxy(store, {get: (t, k) => k in t ? t[k] : (() => false), set: (t, k, v) => { t[k] = v; return true; }});
};
const sprites = new Map();
w.BattleManager.actionBattleHud = function () { return true; };
w.BattleManager.otbDisplayWindow = function () { return stub; };
w.Game_Battler.prototype.battler = function () { if (!sprites.has(this)) sprites.set(this, sprite()); return sprites.get(this); };
const key = b => b.isActor() ? 'a' + b.actorId() : 'e' + b.index();
let popups = null;
w.Game_Battler.prototype.startDamagePopup = function () {
  if (popups) popups.push({target: key(this), hpDamage: this._result.hpDamage, hpAffected: this._result.hpAffected});
};
// 插件指令 battleback … scroll speed（三十一层起守层者第 2 页）：只改战斗背景画面；无场景时原函数读 SceneManager._scene._spriteset 报错，
// 按「没有 spriteset 就返回」处理（同原函数在 spriteset 缺失时的分支）。
const alterBattleback = w.BattleManager.alterBattleback;
w.BattleManager.alterBattleback = function (line) { return w.SceneManager._scene ? alterBattleback.call(this, line) : undefined; };
// rules-gaps6：敌群页把敌人全体战斗不能（雷劫使 823 第 15 回合、神劫使 824 第 30 回合的 333 状态 1）时原版走 processVictory，
// 胜利界面插件读 SceneManager._scene 的窗口，无场景引擎里报错。没有场景时只记到战斗结束（旧例没有一例走到胜利，不受影响）
const processVictory = w.BattleManager.processVictory;
w.BattleManager.processVictory = function () {
  if (w.SceneManager._scene) return processVictory.call(this);
  this._phase = 'battleEnd';
};

// 覆盖记录（cc events13，环境变量 XIYOU_COVER=1 才开，默认不记、troop_events.json 逐字节不变）：每例记解释器实际执行到的
// 「位置:下标」（敌群页 tTpP、公共事件 ceN，按 _list 对象认），101 连带消费的 401／102 续行也算；另写 .sandbox/troop_events_cover.json，
// byCase 以 cases 序号为键，给 03_转换工具/敌群页覆盖.py 和 Godot 侧 xiyou_troop_events --coverage 对照。
// rules-gaps5：事件里的随机变量（122 操作数「随机」）逐支预置。EVENT_R 非空时 122 随机取 floor(n·EVENT_R)（只在这条指令里换 Math.random，
// 别处照旧 0.5）。T1_TURN3 第 1 页「回合 3+3·X」按变量 844 随机四选一强制（2018 是二选一），旧 t1 例取 0.5 只走一支；
// 这里给其余每支各跑一例（eventRandom＝k/n），从 $dataTroops 的 122 读取值域，不手写分支表。
let EVENT_R = null;
// rules-gaps7：换队伍（嘤嘤怪 1 的页按角色 4／20／29 在队、会不会技能 23／509／201／575 走分支：111 角色条件第 3 类是「技能」）。
// PARTY_CASE 非空时开局队伍换成 PARTY_CASE.party，开战（BattleManager.setup）后按 PARTY_CASE.skills（{角色号: [技能…]}，负数＝忘掉）
// 学会／忘掉技能；记 party／actorSkills 字段，旧例不写
let PARTY_CASE = null;
function runParty(pc, fn) {
  PARTY_CASE = pc;
  try { return fn(); } finally { PARTY_CASE = null; }
}
const c122 = w.Game_Interpreter.prototype.command122;
w.Game_Interpreter.prototype.command122 = function (params) {
  if (EVENT_R === null || Number((params || this._params)[3]) !== 2) return c122.apply(this, arguments);
  const mr = w.Math.random;
  w.Math.random = () => EVENT_R;
  try { return c122.apply(this, arguments); } finally { w.Math.random = mr; }
};
function eventRandomBranches(troopId) {
  const out = [];
  for (const pg of w.$dataTroops[troopId].pages) for (const c of pg.list)
    if (c.code === 122 && c.parameters[0] <= 844 && 844 <= c.parameters[1] && c.parameters[3] === 2) {
      const n = c.parameters[5] - c.parameters[4] + 1;
      for (let k = 0; k < n; k++) if (k !== Math.floor(n * 0.5) && !out.includes(k / n)) out.push(k / n);
    }
  return out;
}
function runEventRandom(troopId, r, flags = null, turnPreset = 2) {
  EVENT_R = r;
  try { return Object.assign(run(troopId, false, null, 0, 0, flags, turnPreset), {variant: 't1', eventRandom: r}); } finally { EVENT_R = null; }
}
const COVER = process.env.XIYOU_COVER === '1', coverByCase = [];
let ran = null;
if (COVER) {
  const where = new Map();
  w.$dataTroops.forEach(t => t && t.pages.forEach((pg, p) => where.set(pg.list, 't' + t.id + 'p' + p)));
  w.$dataCommonEvents.forEach(ce => ce && where.set(ce.list, 'ce' + ce.id));
  const exec = w.Game_Interpreter.prototype.executeCommand;
  w.Game_Interpreter.prototype.executeCommand = function () {
    const at = ran && where.get(this._list), start = this._index, cmd = at && this.currentCommand();
    const res = exec.apply(this, arguments);
    if (cmd) {
      ran.add(at + ':' + start);
      if (cmd.code === 101) for (let i = start + 1; i < this._index; i++) ran.add(at + ':' + i);
    }
    return res;
  };
}

// hpRate：开战前把敌人 0 的 HP 设为上限的这个比例（向下取整），照常跑两回合；消息忙时直接关掉（模拟玩家读完），
// 记录 messages（每条的回合与文字）与回合结束时各敌人的 enemyId（三十层敌群 466：HP≤25% 第 3 页 101 对话、336 变身 538、1399、强制 6070／6105）。
// flags：开战前把这些敌群页标为已执行（$gameTroop._eventFlags），旧例不写字段。
// hpEnemy：hpRate 预置的敌人序号（默认 0 不写字段）。
// vars：开战前另设的变量（{变量号: 值}，默认不写字段）。
// GC 11-08（tools-troop-shards）：分段并行。XIYOU_PROBE_SHARD=i/n 时只跑「全局用例序号 % n == i」的用例（序号＝run() 被调用的先后，
// 与单进程的 cases 顺序一致），其余返回占位、最后滤掉；XIYOU_TROOP_OUT 改写输出路径。拼回见 同步正式西游.py 的 TROOP_MERGE_JS
// （按序号交错，与单进程逐字相同）。不设就是单进程，行为与旧版完全相同。XIYOU_COVER 的下标是全局的，所以不许与分段同用。
const SHARD = (() => {
  const m = /^(\d+)\/(\d+)$/.exec(process.env.XIYOU_PROBE_SHARD || '');
  if (!m) return null;
  const i = Number(m[1]), n = Number(m[2]);
  if (!(n >= 1 && i < n)) throw new Error('XIYOU_PROBE_SHARD 不合法：' + process.env.XIYOU_PROBE_SHARD);
  if (process.env.XIYOU_COVER === '1') throw new Error('XIYOU_COVER 记录的下标是全局的，不能与 XIYOU_PROBE_SHARD 同用');
  return {i, n};
})();
// XIYOU_PROBE_FROM=k（开发用）：只跑全局用例序号 ≥ k 的「尾部新例」，输出只含这些例，必须同时给 XIYOU_TROOP_OUT（免得盖掉整份产物）；
// 可与 XIYOU_PROBE_SHARD 同用。新例的序号看 cases 总数（上一份产物的 cases.length）。
const FROM = Number(process.env.XIYOU_PROBE_FROM || 0);
if (FROM > 0 && !process.env.XIYOU_TROOP_OUT) throw new Error('XIYOU_PROBE_FROM 只出部分用例，必须同时给 XIYOU_TROOP_OUT');
if (FROM > 0 && process.env.XIYOU_COVER === '1') throw new Error('XIYOU_COVER 记录的下标是全局的，不能与 XIYOU_PROBE_FROM 同用');
const PARTIAL = !!SHARD || FROM > 0;
let caseCounter = 0;
// ---- 按用例增量（tools-probe-deps2）：用例清单在 troop_event_cases.cjs。每一例的键＝它的描述（run() 的参数、换队伍／事件随机的上下文、
// 调用方补的 variant 等标签）的 SHA-256；结果只由「描述＋公共指纹（XIYOU_TROOP_CORE：来源、本体代码、helper）」决定（每例从新局起跑，
// 见 run() 开头）。同步把上次的结果（XIYOU_TROOP_PREV）和它的键表（XIYOU_TROOP_PREV_KEYS：{core, keys, fileSha}）交进来：公共指纹相同时，
// 键对得上的用例原样取回，只跑新增或描述变了的例；取回的例每 100 个抽 1 个重跑比对，不同就整份重跑并打 TROOP_INCREMENTAL_MISMATCH。
// 审计（XIYOU_TROOP_AUDIT=1，同步每日一次）：整份重跑，同时拿每个「本可取回」的例与上次结果逐字比对，有不同就失败（退出码 3）——
// 说明键漏了某个依赖。XIYOU_TROOP_INCREMENTAL=0 不取回。XIYOU_COVER、XIYOU_PROBE_FROM 不取回。
// 规划：先把清单跑一遍规划（run() 只返回描述，不开战），算出全部键，再真跑；两遍里 run() 被调用的顺序相同（清单是确定的）。
const LIMIT = Number(process.env.XIYOU_TROOP_LIMIT || 0);   // 只给测试用：清单只留前 n 例（产物不是完整产物）
let PHASE = 'run';
const computed = new Map();      // 全局序号 → 本进程真跑出的结果（整份重跑时不重复跑）
let REUSE = null, CHECK = new Set(), lastGate = null;
function gate(desc) {
  const idx = caseCounter++;
  if (PHASE === 'plan') return {idx, early: {__plan: desc}};
  if (idx < FROM || (LIMIT > 0 && idx >= LIMIT) || (SHARD && idx % SHARD.n !== SHARD.i)) return {idx, early: {__skip: true}};
  if (computed.has(idx)) return {idx, early: computed.get(idx)};
  if (REUSE && REUSE.has(idx) && !CHECK.has(idx)) return {idx, early: {__reuse: idx}};
  return {idx};
}
function finish(g, out) { computed.set(g.idx, out); return out; }
// switches：开战前打开的开关（[开关号…]，默认不写字段；rules-gaps6 木桩抵抗档 174～177、S3西游模式 682）。
function run(troopId, paid = false, preset = null, target = 0, hpRate = 0, flags = null, turnPreset = 0, hpEnemy = 0, vars = null, switches = null) {
  const g = gate({troopId, paid, preset, target, hpRate, flags, turnPreset, hpEnemy, vars, switches, party: PARTY_CASE, eventR: EVENT_R}); if (g.early) return g.early;
  if (COVER) { ran = new Set(); coverByCase.push(ran); }
  // rules-gaps5：上一例的敌我精灵代理不再用到；不清的话 Map 一直攥着历届 Game_Battler，900 多例后默认堆 OOM（XIYOU_COVER 时更快）
  sprites.clear();
  w.eval('ConfigManager.applyData({});DataManager.setupNewGame();$gameSystem.setDifficultyId(3);for(var i=1;i<5000;i++)if($gameVariables._data[i]===undefined)$gameVariables._data[i]=0;');
  const party = PARTY_CASE ? PARTY_CASE.party : PARTY;
  w.eval('$gameParty._actors=[];' + JSON.stringify(party) + '.forEach(function(id){$gameParty.addActor(id);});');
  w.$gameVariables.setValue(842, paid ? 1 : 0);
  if (vars) for (const k of Object.keys(vars)) w.$gameVariables.setValue(Number(k), vars[k]);
  if (switches) for (const k of switches) w.$gameSwitches.setValue(k, true);
  for (const id of party) {
    const a = w.$gameActors.actor(id);
    [6168, 5980, 5548].concat([1, 2, 3, 4, 5, 6, 7, 52].includes(id) ? [2571, 2786] : []).forEach(k => a.learnSkill(k));
    a.refresh(); a.recoverAll();
  }
  if (!w.$dataMap) w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const BM = w.BattleManager;
  w.Math.random = () => 0.99;
  BM.setup(troopId, false, false);
  BM._logWindow = stub; BM._spriteset = stub; BM._statusWindow = stub;
  w.Math.random = () => 0.5;
  if (PARTY_CASE) for (const id of Object.keys(PARTY_CASE.skills || {})) for (const k of PARTY_CASE.skills[id]) {
    const a = w.$gameActors.actor(Number(id));
    if (k > 0) a.learnSkill(k); else a.forgetSkill(-k);
  }
  const out = {troop: troopId, paid, actions: [], invokes: [], errors: [], battlers: {}};
  if (vars) out.vars = vars;
  if (switches) out.switches = switches;
  if (PARTY_CASE) { out.party = party; out.actorSkills = PARTY_CASE.skills || {}; }
  if (target !== 0) out.target = target;   // 玩家普通攻击的敌人序号（默认 0 不写字段，旧例逐字节不变）
  // turnPreset：开战前把回合计数设为这个值（金之巨人 830 第 20 回合强制 8203：从头打到 20 回合队伍早已倒下），跑到该回合结束；
  // 开战检查与第 N 回合的消息一并记录
  if (turnPreset) { out.turnPreset = turnPreset; out.messages = []; w.$gameTroop._turnCount = turnPreset; }
  if (flags) { out.flags = flags; for (const i of flags) w.$gameTroop._eventFlags[i] = true; }
  if (hpRate) {
    out.hpRate = hpRate; out.messages = [];
    if (hpEnemy) out.hpEnemy = hpEnemy;
    const e0 = w.$gameTroop.members()[hpEnemy];
    e0.setHp(Math.floor(e0.mhp * hpRate));
    out.hpPreset = e0.hp;
  }
  // preset：开战前把敌人 HP 设成定值（{敌人序号: hp}），只跑到第 1 回合输入前，记开场敌群事件的结果
  if (preset) {
    out.preset = preset;
    for (const i of Object.keys(preset)) w.$gameTroop.members()[Number(i)].setHp(preset[i]);
  }
  // 下一回合开始（BattleManager.startTurn，回合末事件已跑完）时各敌人的状态与剩余回合：Godot run_turn 跑完一回合（含回合末事件）后就是这个时点
  // （沙僧50 内容批 P2-C1：领域事件给全体敌人的 44 第 1 回合末 2→1）
  const st0 = BM.startTurn;
  out.turnStarts = [];
  BM.startTurn = function () {
    if (w.$gameTroop._turnCount > 0) {
      const enemies = {};
      for (const e of w.$gameTroop.members()) enemies[key(e)] = {hp: e.hp, states: e._states.slice(), turns: Object.assign({}, e._stateTurns)};
      out.turnStarts.push({after: w.$gameTroop._turnCount, enemies});
    }
    return st0.apply(this, arguments);
  };
  const inv = BM.invokeAction, sa = BM.startAction;
  BM.startAction = function () {
    const s = this._subject, act = s && s.currentAction();
    out.actions.push({turn: w.$gameTroop._turnCount, subject: s && key(s), skill: act && act.item() ? act.item().id : null,
      forced: !!(act && act._forcing), processingForced: !!this._processingForcedAction});
    return sa.call(this);
  };
  BM.invokeAction = function (su, t) {
    const hp0 = t.hp; popups = [];
    const res = inv.call(this, su, t);
    out.invokes.push({turn: w.$gameTroop._turnCount, subject: key(su), skill: this._action && this._action.item() ? this._action.item().id : null,
      target: key(t), hpBefore: hp0, hpAfter: t.hp, popups, userAtk: su.atk, userMat: su.mat,
      userStates: su._states.slice(), targetStates: t._states.slice()});
    popups = null;
    return res;
  };
  try {
    BM.startBattle();
    for (let i = 0; i < 20000; i++) {
      if (BM._phase === 'battleEnd' || w.$gameTroop._turnCount > (turnPreset ? turnPreset + 1 : 2) || BM.isBattleEnd && BM._phase === null) break;
      if (preset && BM._phase === 'input') break;
      if ((hpRate || turnPreset) && w.$gameMessage.isBusy()) {
        out.messages.push({turn: w.$gameTroop._turnCount, texts: w.$gameMessage._texts.slice(), faceName: w.$gameMessage.faceName()});
        w.$gameMessage.clear();
        continue;
      }
      if (BM._phase === 'input') {
        const act = BM.inputtingAction();
        if (act) { act.setAttack(); act.setTarget(target); }
        BM.selectNextCommand();
        continue;
      }
      BM.update();
    }
  } catch (e) { out.errors.push(String(e && e.stack || e).slice(0, 800)); }
  BM.invokeAction = inv; BM.startAction = sa; BM.startTurn = st0;
  ran = null;
  // rules-gaps6：敌群页里的 353 游戏结束（圣劫使 825 第 30 回合）在无场景引擎里只留下 SceneManager._nextScene，
  // 不清的话之后每例 BattleManager 都当作「正在换场景」、停在 start 不动。记下换到的场景再清掉（旧例没有换场景，不写字段）
  if (w.SceneManager._nextScene) { out.sceneChange = w.SceneManager._nextScene.constructor.name; w.SceneManager._nextScene = null; }
  for (const b of w.$gameParty.battleMembers().concat(w.$gameTroop.members()))
    out.battlers[key(b)] = {hp: b.hp, mhp: b.mhp, atk: b.atk, mat: b.mat, agi: b.agi, states: b._states.slice()};
  if (hpRate) out.enemyIds = w.$gameTroop.members().map(e => e.enemyId());
  out.turnCount = w.$gameTroop._turnCount;
  out.phase = BM._phase;
  return finish(g, out);
}

// rules-gaps9：只在战斗里跑的公共事件（内容覆盖检查.py 的 battleOnlyCommonEvents：场合＝战斗的技能／物品效果 44 起点可达、
// 地图页与别的场合都调不到；这里按原版数据同法算，不读切片，所以比切片里的多几个，Godot 侧跳过切片没有的）。上面的敌群例玩家只普攻，
// 这些事件几乎跑不到。每个直接起点各一例：敌群 2、全员 HP 加到打不死，CE 里第一个「111 角色在队」的角色（没有就 1 号）当使用者，
// 学会起点技能（物品就给 5 个），第 1 回合输入时用它打敌人 0，其余人防御；CE 里有「111 角色会技能 K」时分 met（都学会）／unmet（都忘掉）两例，
// 没有就一例 plain。跑到第 1 回合结束，记行动序列（行动者、技能或物品、是否强制）、公共事件开跑时刻，
// 以及事件之后下一个非强制行动开始时（或回合结束）CE 里 313／333 提到的那些状态在谁身上（snap）。
// 用例带 party 字段，oracle_additions 按 (troop, paid, variant) 成键；variant＝'ce<号>.<met|unmet|plain>'。
const SKILL_CE = (() => {
  const ces = w.$dataCommonEvents, occ = new Map();
  const calls = list => new Set((list || []).filter(c => c.code === 117 && ces[c.parameters[0]]).map(c => c.parameters[0]));
  const closure = start => { const seen = new Set(start), q = [...start];
    while (q.length) for (const x of calls(ces[q.pop()].list)) if (!seen.has(x)) { seen.add(x); q.push(x); }
    return seen; };
  const srcs = new Map();
  for (const [kind, tab] of [['skill', w.$dataSkills], ['item', w.$dataItems]]) for (const r of tab) if (r) for (const e of r.effects || [])
    if (e.code === 44 && ces[e.dataId]) {
      if (!occ.has(e.dataId)) occ.set(e.dataId, new Set());
      occ.get(e.dataId).add(r.occasion);
      if (r.occasion === 1) { if (!srcs.has(e.dataId)) srcs.set(e.dataId, []);
        srcs.get(e.dataId).push({kind, id: r.id, single: r.effects.filter(x => x.code === 44).length === 1}); }
    }
  const mapStart = new Set();
  for (const f of fs.readdirSync(path.join(APP, 'data'))) if (/^Map\d{3}\.json$/.test(f))
    for (const e of JSON.parse(fs.readFileSync(path.join(APP, 'data', f), 'utf8')).events || []) if (e)
      for (const pg of e.pages || []) for (const x of calls(pg.list)) mapStart.add(x);
  const only = [...occ].filter(([, s]) => s.size === 1 && s.has(1)).map(([id]) => id);
  const other = [...occ].filter(([, s]) => !(s.size === 1 && s.has(1))).map(([id]) => id);
  const bad = closure([...mapStart, ...other]);
  const out = [];
  for (const ce of [...closure(only)].filter(x => !bad.has(x) && srcs.has(x)).sort((a, b) => a - b)) {
    const list = ces[ce].list, sub = closure([ce]);
    const conds = list.filter(c => c.code === 111 && c.parameters[0] === 4);
    // 使用者：CE 里第一个「111 角色在队」的角色，没有就第一个 111 角色条件、再没有就第一个强制行动（339）的角色，都没有取 1 号。
    // 队伍：使用者在前，再放 CE 里 111／313／339 提到的其余角色（原版 339 对不在队的角色照样强制，重制只认在队的，实战这些人都在队），
    // 不满 4 人用 1／8／9／10 补
    const forcedActors = [...sub].flatMap(id => ces[id].list.filter(c => c.code === 339 && c.parameters[0] === 1).map(c => c.parameters[1]));
    const user = ((conds.find(c => c.parameters[2] === 0) || conds[0] || {parameters: [4, forcedActors[0] || 1]}).parameters[1]);
    const named = [...sub].flatMap(id => ces[id].list.filter(c => c.code === 111 && c.parameters[0] === 4).map(c => c.parameters[1])
      .concat(ces[id].list.filter(c => c.code === 313 && c.parameters[0] === 0 && c.parameters[1] > 0).map(c => c.parameters[1])))
      .concat(forcedActors).filter(a => w.$dataActors[a]);
    const party = [...new Set([user, ...named, 1, 8, 9, 10])].slice(0, 4);
    const learn = conds.filter(c => c.parameters[2] === 3).map(c => [c.parameters[1], c.parameters[3]]);
    const watch = new Set();
    for (const id of sub) for (const c of ces[id].list) if (c.code === 313 || c.code === 333) watch.add(c.parameters[3] !== undefined && c.code === 313 ? c.parameters[3] : c.parameters[2]);
    const src = srcs.get(ce).find(s => s.single) || srcs.get(ce)[0];
    for (const v of learn.length ? ['met', 'unmet'] : ['plain']) out.push({ce, user, party, learn, src, watch: [...watch].sort((a, b) => a - b), v});
  }
  return out;
})();
// 1516 鼬万花筒：261 播放影片在无场景引擎里 Graphics._playVideo 读不到 video 元素报错、事件停下；没有 _video 时按「放完」处理
const playVideo = w.Graphics.playVideo;
w.Graphics.playVideo = function () { return this._video ? playVideo.apply(this, arguments) : undefined; };
const isVideoPlaying = w.Graphics.isVideoPlaying;
w.Graphics.isVideoPlaying = function () { return this._video ? isVideoPlaying.apply(this, arguments) : false; };
function runSkillCE(sc) {
  const g = gate({skillCE: sc}); if (g.early) return g.early;
  if (COVER) { ran = new Set(); coverByCase.push(ran); }
  sprites.clear();
  const party = sc.party;
  w.eval('ConfigManager.applyData({});DataManager.setupNewGame();$gameSystem.setDifficultyId(3);for(var i=1;i<5000;i++)if($gameVariables._data[i]===undefined)$gameVariables._data[i]=0;');
  // 照常 addActor（继承难度等）；部分高号角色（超强者等）默认难度会被拦，之后直接写 _actors 补上
  w.eval('$gameParty._actors=[];' + JSON.stringify(party) + '.forEach(function(id){$gameParty.addActor(id);});$gameParty._actors=' + JSON.stringify(party) + ';');
  const skills = {[sc.user]: sc.src.kind === 'skill' ? [sc.src.id] : []};
  for (const [a, k] of sc.learn) (skills[a] = skills[a] || []).push(sc.v === 'met' ? k : -k);
  for (const id of party) { const a = w.$gameActors.actor(id); a._paramPlus[0] = 999999999; }
  for (const id of Object.keys(skills)) for (const k of skills[id]) { const a = w.$gameActors.actor(Number(id)); if (k > 0) a.learnSkill(k); else a.forgetSkill(-k); }
  if (sc.src.kind === 'item') w.$gameParty.gainItem(w.$dataItems[sc.src.id], 5);
  for (const id of party) { const a = w.$gameActors.actor(id); a.refresh(); a.recoverAll(); a._tp = 100; }
  if (!w.$dataMap) w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const BM = w.BattleManager;
  w.Math.random = () => 0.99;
  BM.setup(2, false, false);
  BM._logWindow = stub; BM._spriteset = stub; BM._statusWindow = stub;
  w.Math.random = () => 0.5;
  w.$gameTroop.members().forEach(e => { e._paramPlus[0] = 999999999; e.recoverAll(); });
  const out = {troop: 2, paid: false, variant: 'ce' + sc.ce + '.' + sc.v, skillCE: sc.ce, party, actorSkills: skills,
    use: [sc.src.kind, sc.src.id, sc.user], watch: sc.watch, actions: [], invokes: [], events: [], errors: [], battlers: {}};
  const snap = () => { const s = {};
    for (const b of w.$gameParty.battleMembers().concat(w.$gameTroop.members())) s[key(b)] = b._states.filter(x => sc.watch.includes(x));
    return s; };
  const sa = BM.startAction, setupCE = w.Game_Interpreter.prototype.setupReservedCommonEvent, et = BM.endTurn;
  // 使用者排在本回合最后出手时没有「下一个非强制行动」：在回合结束（状态按回合解除之前）取快照
  BM.endTurn = function () { if (!out.snap && out.events.some(e => e.commonEvent === sc.ce)) out.snap = snap(); return et.apply(this, arguments); };
  BM.startAction = function () {
    const s = this._subject, act = s && s.currentAction(), forcing = !!(act && act._forcing);
    if (!forcing && !out.snap && out.events.some(e => e.commonEvent === sc.ce)) out.snap = snap();
    out.actions.push({subject: s && key(s), item: act && act.item() ? [act.isItem() ? 'item' : 'skill', act.item().id] : null, forced: forcing});
    return sa.call(this);
  };
  w.Game_Interpreter.prototype.setupReservedCommonEvent = function () {
    const id = w.$gameTemp._commonEventId, ok = setupCE.apply(this, arguments);
    if (ok) out.events.push({commonEvent: id, afterActions: out.actions.length});
    return ok;
  };
  let used = false;
  try {
    BM.startBattle();
    for (let i = 0; i < 20000; i++) {
      if (BM._phase === 'battleEnd' || w.$gameTroop._turnCount > 1) break;
      // 有选项的消息选最后一项（多是「否」／「再想想」：CE1501 爱莉希雅、CE1627 流派选择菜单选别的会 119 跳回菜单无限循环），再关掉
      if (w.$gameMessage.isBusy()) { if (w.$gameMessage.isChoice()) w.$gameMessage.onChoice(w.$gameMessage.choices().length - 1); w.$gameMessage.clear(); continue; }
      if (BM._phase === 'input') {
        const actor = BM.actor(), act = BM.inputtingAction();
        if (act && actor && actor.actorId() === sc.user && !used) {
          if (sc.src.kind === 'item') act.setItem(sc.src.id); else act.setSkill(sc.src.id);
          act.setTarget(0); used = true;
        } else if (act) act.setGuard();
        BM.selectNextCommand();
        continue;
      }
      BM.update();
    }
  } catch (e) { out.errors.push(String(e && e.stack || e).slice(0, 800)); }
  BM.startAction = sa; BM.endTurn = et; w.Game_Interpreter.prototype.setupReservedCommonEvent = setupCE;
  ran = null;
  if (w.SceneManager._nextScene) { out.sceneChange = w.SceneManager._nextScene.constructor.name; w.SceneManager._nextScene = null; }
  if (!out.snap) out.snap = snap();
  for (const b of w.$gameParty.battleMembers().concat(w.$gameTroop.members())) out.battlers[key(b)] = {hp: b.hp, mhp: b.mhp, states: b._states.slice()};
  out.turnCount = w.$gameTroop._turnCount;
  out.phase = BM._phase;
  return finish(g, out);
}

const buildCases = require('./troop_event_cases.cjs');
const CASE_API = {w, run, runEventRandom, runParty, runSkillCE, eventRandomBranches, SKILL_CE};
const sha256 = v => require('crypto').createHash('sha256').update(typeof v === 'string' || Buffer.isBuffer(v) ? v : JSON.stringify(v)).digest('hex');
const KEYS_OUT = process.env.XIYOU_TROOP_KEYS_OUT || (process.env.XIYOU_TROOP_OUT || path.join(__dirname, '.sandbox/troop_events.json')).replace(/\.json$/, '.keys.json');
const OUT = process.env.XIYOU_TROOP_OUT || path.join(__dirname, '.sandbox/troop_events.json');
const fileSha = f => sha256(fs.readFileSync(f));
// 公共指纹：同步给（含影响面声明折算后的 helper）；手动跑时退回本地算
const CORE = process.env.XIYOU_TROOP_CORE || sha256(['local', identity, ['troop_event_probe.cjs', 'hboot.cjs', 'fs_guard.cjs', 'manual_sandbox.cjs', 'source_identity.cjs']
  .map(f => fileSha(path.join(__dirname, f))), (() => { try { return require('jsdom/package.json').version; } catch (e) { return ''; } })()]);
const AUDIT = process.env.XIYOU_TROOP_AUDIT === '1';
const incrementalOk = process.env.XIYOU_TROOP_INCREMENTAL !== '0' && !COVER && !(FROM > 0);
PHASE = 'plan';
caseCounter = 0;
const planned = buildCases(CASE_API);
const planKeys = [], seenKeys = new Map();
for (const item of (LIMIT > 0 ? planned.slice(0, LIMIT) : planned)) {
  const k = sha256(item), n = seenKeys.get(k) || 0;
  seenKeys.set(k, n + 1);
  planKeys.push(k + '#' + n);
}
PHASE = 'run';
caseCounter = 0;
// 上次的结果：公共指纹、文件摘要、条数都对得上才用
const prevByKey = new Map();
if (incrementalOk && process.env.XIYOU_TROOP_PREV && process.env.XIYOU_TROOP_PREV_KEYS) {
  try {
    const doc = JSON.parse(fs.readFileSync(process.env.XIYOU_TROOP_PREV_KEYS, 'utf8')), prev = JSON.parse(fs.readFileSync(process.env.XIYOU_TROOP_PREV, 'utf8'));
    if (doc.version === 1 && doc.core === CORE && doc.fileSha === fileSha(process.env.XIYOU_TROOP_PREV) && Array.isArray(doc.keys)
        && doc.keys.length === prev.cases.length && JSON.stringify([prev.sourceIdentity, prev.party, prev.difficulty]) === JSON.stringify([identity, PARTY, 3]))
      doc.keys.forEach((k, i) => { if (!prevByKey.has(k)) prevByKey.set(k, prev.cases[i]); });
  } catch (e) { prevByKey.clear(); }
}
const reusable = new Map();   // 全局序号 → 上次的结果
planKeys.forEach((k, i) => { if (prevByKey.has(k) && !(SHARD && i % SHARD.n !== SHARD.i)) reusable.set(i, prevByKey.get(k)); });
const EVERY = Math.max(1, Number(process.env.XIYOU_TROOP_CHECK_EVERY || 100));
if (!AUDIT && reusable.size) {
  REUSE = reusable;
  CHECK = new Set([...reusable.keys()].filter((_, i) => i % EVERY === 0));
}
let list = buildCases(CASE_API);
if (LIMIT > 0) list = list.slice(0, LIMIT);
let reused = REUSE ? REUSE.size - CHECK.size : 0, checked = 0, mismatched = [];
for (const idx of CHECK) {
  checked++;
  if (JSON.stringify(computed.get(idx)) !== JSON.stringify(REUSE.get(idx))) mismatched.push(planKeys[idx]);
}
if (mismatched.length) {
  console.error('TROOP_INCREMENTAL_MISMATCH ' + JSON.stringify({checked, mismatched: mismatched.length, sample: mismatched.slice(0, 3),
    note: '取回的用例与重跑不同：键漏了某个依赖。本轮整份重跑'}));
  REUSE = null; CHECK = new Set(); reused = 0;
  caseCounter = 0;
  list = buildCases(CASE_API);   // computed 里已有的例不重跑
  if (LIMIT > 0) list = list.slice(0, LIMIT);
}
if (AUDIT) {
  const wrong = [];
  for (const [idx, old] of reusable) if (JSON.stringify(computed.get(idx)) !== JSON.stringify(old)) wrong.push(planKeys[idx]);
  if (wrong.length) {
    console.error('TROOP_AUDIT_FAIL ' + JSON.stringify({audited: reusable.size, different: wrong.length, sample: wrong.slice(0, 5),
      note: '键相同的用例这次重跑与上次结果不同：指纹漏了依赖（或探针不确定），先查清再同步'}));
    process.exit(3);
  }
  console.error('TROOP_AUDIT_OK ' + JSON.stringify({audited: reusable.size}));
}
const result = {sourceIdentity: identity, party: PARTY, difficulty: 3, cases: list.map(c => c && c.__reuse !== undefined ? REUSE.get(c.__reuse) : c)};
if (PARTIAL) result.cases = result.cases.filter(c => !c.__skip);
if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname, '.sandbox'), {recursive: true});
fs.writeFileSync(OUT, JSON.stringify(result, null, 1));
if (!COVER && !(FROM > 0)) fs.writeFileSync(KEYS_OUT, JSON.stringify(Object.assign({version: 1, core: CORE, keys: planKeys, reused, checked}, PARTIAL ? {} : {fileSha: fileSha(OUT)})));
if (COVER) fs.writeFileSync(path.join(__dirname, '.sandbox/troop_events_cover.json'), JSON.stringify({sourceIdentity: identity,
  note: 'troop_event_probe XIYOU_COVER=1：原版解释器实际执行到的敌群页／公共事件指令（位置:下标）',
  byCase: Object.fromEntries(coverByCase.map((s, i) => [String(i), [...s].sort()]))}));
process.stdout.write(JSON.stringify(result.cases.map(c => ({troop: c.troop, actions: c.actions.length, invokes: c.invokes.length, errors: c.errors.length, turn: c.turnCount, phase: c.phase}))) + '\n');
process.exit(0);
