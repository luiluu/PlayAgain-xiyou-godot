'use strict';
// 【cc·八戒·未经审查】谷雨 175 战斗界面（js/codex/runtime/installNativeGuyuRuntime.js 474～680 与 installThreeGrowthRelicRuntime.js 76～111）：
// 侧栏名字行的状态字 G.statusText、生命条护盾合计 G.totalShield、转移说明 G.transferText／G.transferPreview（含不合法的原因）、
// 赠春／还春选择窗 Window_GuyuTransfer（命令表、建窗时与打开时的宽高行数、打开时默认光标与顶行）、shortNumber、
// performAction／performActionEnd 包装请求的动作，以及法宝说明卡条目（R.syncItem 写进备注的 <pos=APs …> 行、名字、说明）。
// 战斗同 guyu_battle_probe：真实 BattleManager、队伍 [175, 1] 同级、敌人生命加 1e9、Math.random 0.5、去掉五乘区与路线压制（O-050）。
// 每步之后记 ui：两人的状态字与护盾合计、选择窗命令表、两种方向 × 四种比例（0.25／0.5／0.75 与不支持的 0.6）× 两个目标（自己、1 号）的预览与说明。
// 只在内存，产物 .sandbox/guyu_ui.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const G = w.Guyu, R = w.CodexThreeGrowth;
if (!G || typeof G.statusText !== 'function' || !w.Window_GuyuTransfer || !R) throw new Error('谷雨界面／三法宝成长模块未安装');
const hooks = w.CodexDamageHooks || [];
for (const name of ['route-suppress', 'zones-correction']) {
  const i = hooks.findIndex(h => h.name === name);
  if (i < 0) throw new Error('伤害钩子 ' + name + ' 不在');
  hooks.splice(i, 1);
}
if (!w.CodexRouteSuppress || typeof w.CodexRouteSuppress.otherScale !== 'function') throw new Error('路线压制模块不在');
w.CodexRouteSuppress.otherScale = () => 1;
const stub = new Proxy(function () {}, {get: (_, k) => k === '_waitCount' ? 0 : (() => false), set: () => true});
const sprites = new Map();
w.Game_Battler.prototype.battler = function () {
  if (!sprites.has(this)) sprites.set(this, new Proxy({x: 0, y: 0, _homeX: 0, _homeY: 0, width: 64, height: 64,
    scale: {x: 1, y: 1}, anchor: {x: 0.5, y: 1}, opacity: 255},
  {get: (t, k) => k in t ? t[k] : (() => false), set: (t, k, v) => {t[k] = v; return true;}}));
  return sprites.get(this);
};
w.BattleManager.actionBattleHud = () => true;
w.BattleManager.otbDisplayWindow = () => stub;
if (!w.$) w.$ = {};
w.$.toaster = () => {};
const BIG_HP = 1e9, TROOP = 3, ID = 175, RELIC = 7912;
const ACTIVE = [10288, 10289, 10290, 10291, 10292];

function battle(level, rank, relic) {
  newGame();
  w.eval('$gameSystem.setDifficultyId(2); $gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  if (relic) { w.$gameSwitches.setValue(2494, true); G._notifiedRelic = false; G.recruit(); }
  w.eval('$gameSwitches.setValue(2494, true); $gameParty._actors=[' + ID + ',1]; $gameParty._battleMembers=[' + ID + ',1,0,0,0];');
  for (const id of [ID, 1]) w.$gameActors.actor(id).changeLevel(level, false);
  const a = w.$gameActors.actor(ID);
  a._AdvancedNum = rank || 0; G.syncSkills(a);
  for (const id of [ID, 1]) w.$gameActors.actor(id).recoverAll();
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  w.Math.random = () => 0.99;
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  w.Math.random = () => 0.5;
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  for (const t of w.$gameTroop.members()) t._paramPlus[0] = BIG_HP;
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  bm.startBattle();
  for (let tick = 0; tick < 5000 && bm._phase !== 'input'; tick++) {
    if (w.$gameMessage.isBusy()) { w.$gameMessage.clear(); continue; }
    bm.update();
  }
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) b.recoverAll();
  return {bm, a, hero: w.$gameActors.actor(1), foes: w.$gameTroop.members()};
}
// mode／ratio 写在行动上（同 Window_GuyuTransfer 的 choose 处理）；不给时行动上没有，按 give／CFG.transfer.ratio
function act(bm, user, skillId, targetIndex, mode, ratio) {
  const action = new w.Game_Action(user); action.setSkill(skillId); action.setTarget(targetIndex);
  if (mode !== undefined) { action._guyuTransferMode = mode; action._guyuRatio = ratio; }
  user._actions = [action]; bm._subject = user; bm._action = null;
  bm.startAction();
  for (let i = 0; i < 20000; i++) {
    const ph = bm._phase;
    if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
    else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
  }
  bm._phase = 'turn';
}
// Window_GuyuTransfer.makeCommandList 照原样跑在一个只收命令的对象上（不建位图）
function commands(a) {
  const list = [], old = w.BattleManager.actor;
  w.BattleManager.actor = () => a;
  try {
    w.Window_GuyuTransfer.prototype.makeCommandList.call({addCommand: (name, symbol, enabled, ext) => list.push({name, symbol, enabled, ext})});
  } finally { w.BattleManager.actor = old; }
  return list;
}
const MODES = ['give', 'back'], RATIOS = [0.25, 0.5, 0.75, 0.6];
function ui(env) {
  const {a, hero} = env, out = {status: [G.statusText(a), G.statusText(hero)], totalShield: [G.totalShield(a), G.totalShield(hero)],
    reserve: [G.reserve(a), G.reserve(hero)], ratios: G.transferRatios(a), commands: commands(a), transfer: []};
  for (const mode of MODES) for (const ratio of RATIOS) for (const [t, name] of [[a, 'g'], [hero, 'h']]) {
    const p = G.transferPreview(a, t, mode, ratio);
    out.transfer.push({mode, ratio, target: name, valid: p.valid, amount: p.amount, capped: !!p.capped, reason: p.reason,
      text: G.transferText(a, t, mode, ratio)});
  }
  // 行动上没写方向与比例（自动战斗、技能顺序表给的转移）：按 give 与 CFG.transfer.ratio
  const d = G.transferPreview(a, hero);
  out.transferDefault = {valid: d.valid, amount: d.amount, mode: d.mode, ratio: d.ratio, text: G.transferText(a, hero)};
  return out;
}
function run(steps, level, rank, relic) {
  const env = battle(level, rank, relic), {bm, a, hero, foes} = env, out = [];
  const who = x => x === 'g' ? a : hero;
  out.push({step: ['start'], ui: ui(env)});
  for (const st of steps) {
    const [kind, x, y, z, m, r] = st;
    if (kind === 'act') act(bm, who(x), y, z, m, r);
    else if (kind === 'turn') { bm._enteredEndPhase = false; bm._phase = 'turn'; bm.endTurn(); bm.startTurn(); bm._phase = 'turn'; }
    else if (kind === 'hp') who(x).setHp(y);
    else if (kind === 'mp') a.setMp(a.mmp);
    else if (kind === 'foe') act(bm, foes[x], y, z);
    out.push({step: st, ui: ui(env)});
  }
  bm.endBattle(0);
  out.push({step: ['endBattle'], ui: ui(env)});
  return out;
}
// 治疗都是全体（scope 8）；转移选 1 号（我方第 2 位）；1 号普攻 1、敌人普攻 1
const SCRIPTS = {
  // 5 级：只有 50%（hasSpring 要 10 级）；没储备时的原因；治疗后给出 50%；1 号满了转不进（接收者储备已满）、给出被上限截住
  lv5: [['act', 'g', 10288, 0], ['act', 'g', 10290, 1, 'give', 0.5], ['act', 'g', 10288, 0], ['act', 'g', 10288, 0], ['act', 'g', 10288, 0]],
  // 35 级：三种比例；给出 25%（赋待绽：下次花期）、花期（花期N、待绽）、1 号绽放后待绽消失、收回 75%、花荫（护盾合计）、敌人打 1 号吸收、
  // 其他来源护盾与花荫相加；两回合后花期收束、花荫撤销
  lv35: [['act', 'g', 10288, 0], ['act', 'g', 10288, 0], ['act', 'g', 10290, 1, 'give', 0.25], ['act', 'g', 10289, 0], ['act', 'h', 1, 0],
    ['act', 'g', 10290, 1, 'back', 0.75], ['mp'], ['act', 'g', 10291, 0], ['foe', 0, 1, 1], ['turn'], ['turn']],
  // 35 级众生之劫：1 号残血被打死 → 代命、谷雨归根（归根N）；转移全不合法；下一回合末再生
  sub: [['act', 'g', 10288, 0], ['hp', 'h', 1], ['foe', 0, 1, 1], ['turn'], ['turn']],
  // 60 级 5 阶戴万象长春盏：储备大（万）、给出 75%
  lv60: [['act', 'g', 10288, 0], ['act', 'g', 10288, 0], ['act', 'g', 10290, 1, 'give', 0.75]],
};
const LEVELS = {lv5: [5, 0], lv35: [35, 0], sub: [35, 0], lv60: [60, 5, true]};
const cases = [];
// 法宝说明先量：R.sync 会改数据库里的原件（$dataArmors），60 级的战斗例之后原件已进化，新招募的实例跟着是进化后的
// 法宝说明：R.syncItem 写进备注的 APs 行（备注里的先后，说明卡逆序显示）、每级成长标签、名字、说明
function relicText(x) {
  const note = String(x.note || '');
  return {name: x.name, description: x.description, aps: (note.match(/<pos=APs text=[^>]*>/g) || []).map(s => s.replace(/^<pos=APs text=/, '').replace(/ size=18 color=rgba\(255,255,255,1\) line=false align=0>$/, '')),
    perLevel: note.match(/<\w+ Param \+\d+ per Level>/g) || [], quality: note.match(/<(?:quality|ici):\d+>/g) || []};
}
cases.push(makeCase('relic', {}, () => {
  newGame();
  w.eval('$gameSystem.setDifficultyId(2); $gameSwitches.setValue(2494, true); $gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  G._notifiedRelic = false; G.recruit();
  const a = w.$gameActors.actor(ID), slot = a.equips().findIndex(x => x && (x.baseItemId || x.id) === RELIC);
  const out = {};
  for (const lv of [1, 59, 60, 50]) { a.changeLevel(lv, false); out['lv' + lv] = relicText(a.equips()[slot]); }
  return out;
}));
for (const [name, steps] of Object.entries(SCRIPTS)) {
  const [level, rank, relic] = LEVELS[name];
  cases.push(makeCase(`script.${name}`, {actor: ID, level, rank, relic: !!relic, troop: TROOP, steps}, () => ({steps: run(steps, level, rank, relic)})));
}
// shortNumber：亿／万一位小数（toFixed），以下取整
const NUMS = [0, 1, 9999, 9999.9, 10000, 12345, 99950, 99999, 123456789, 99999999, 100000000, 149999999, 1e12, 0.7];
cases.push(makeCase('short', {nums: NUMS}, () => ({out: NUMS.map(n => G.shortNumber(n))})));
// 状态字在战斗外与谷雨不在队时为空
cases.push(makeCase('status.idle', {}, () => {
  newGame();
  w.eval('$gameSwitches.setValue(2494, true); $gameParty._actors=[' + ID + ',1]; $gameParty._battleMembers=[' + ID + ',1,0,0,0];');
  const a = w.$gameActors.actor(ID), hero = w.$gameActors.actor(1);
  const outside = [G.statusText(a), G.statusText(hero)];
  const env = battle(35, 0); w.eval('$gameParty._battleMembers=[1,0,0,0,0];');
  return {outside, noGuyu: [G.statusText(env.hero)]};
}));
// 选择窗：建窗时（createAllWindows，BattleManager.actor() 为空）定下宽高；打开时 refresh 换命令表、select 默认项（宽高不变）
cases.push(makeCase('window', {}, () => {
  const out = {};
  for (const level of [5, 35]) {
    const env = battle(level, 0);
    act(env.bm, env.a, 10288, 0);
    const old = w.BattleManager.actor;
    w.BattleManager.actor = () => null;
    let win;
    try {
      win = new w.Window_GuyuTransfer(0, 0);
      const created = {width: win.width, height: win.height, items: win.maxItems(), pageRows: win.maxPageRows()};
      w.BattleManager.actor = () => env.a;
      win.refresh();
      const ratios = G.transferRatios(env.a);
      let index = ratios.indexOf(0.5) * 2;
      if (index < 0 || !win.isCommandEnabled(index)) index = win._list.findIndex(x => x.enabled);
      win.select(Math.max(0, index));
      out['lv' + level] = {created, opened: {width: win.width, height: win.height, items: win.maxItems(), pageRows: win.maxPageRows(),
        index: win.index(), top: win.topRow(), names: win._list.map(x => x.name), enabled: win._list.map(x => x.enabled)}};
    } finally { w.BattleManager.actor = old; }
  }
  return out;
}));
// performAction（requestMotion）与 performActionEnd 的动作；归根时不换动作；内部行动（绽放）不换
cases.push(makeCase('motion', {}, () => {
  const env = battle(35, 0), {a} = env, got = [];
  const req = a.requestMotion;
  a.requestMotion = m => got.push(m);
  const rows = [];
  try {
    for (const id of [...ACTIVE, 1, 2]) {
      got.length = 0;
      const action = new w.Game_Action(a); action.setSkill(id);
      a.performAction(action);
      const during = got.slice(); got.length = 0;
      a.performActionEnd();
      rows.push({skill: id, perform: during, end: got.slice()});
    }
    got.length = 0;
    const inner = new w.Game_Action(a); inner.setSkill(10288); inner._guyuInternal = true;
    a.performAction(inner);
    rows.push({skill: 10288, internal: true, perform: got.slice()});
  } finally { a.requestMotion = req; }
  return {rows, visuals: G.visuals};
}));
process.exit(finish(host, 'guyu_ui.json', {hostScope: '真实 BattleManager（startBattle 推进到输入）／Game_Action（Math.random 0.5）', cases}) ? 0 : 1);
