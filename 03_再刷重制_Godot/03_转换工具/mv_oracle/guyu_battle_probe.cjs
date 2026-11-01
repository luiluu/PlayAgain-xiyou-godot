'use strict';
// 【cc·八戒·未经审查】谷雨 175 第二期 A 战斗内机制（js/codex/runtime/installNativeGuyuRuntime.js：BattleManager.setup／startTurn／
// startAction／endAction／endTurn／endBattle 包装、param 包装（储备并进最大生命）、gainHp 包装（回血记储备、生未央 20%）、
// Game_Action.apply 包装的 doSpecial（花期 open、终结 finish）、绽放 G.bloom、evalDamageFormula 绽放与终结、胜利掉进阶石 rollStone）。
// 真实 BattleManager：setup→startBattle→推进到第一次输入；之后每步 startAction→行动列表→endAction、或 endTurn＋startTurn。
// 队伍 [175, 1] 同级（进阶按例）、开 2494；敌人生命加 1e9（不夹值，绽放、终结打不死）；Math.random 0.5。
// 不碰二期 B：1 号与谷雨都不挨打（没有代命、归根），不用花荫、转移。
// 每步记 executeHpDamage（技能、出手者、目标、生命伤害，治疗为负）与之后的快照（回合、花期到哪回合、冷却、花期序号、种子、
// 两人的储备、储备上限、最大生命、不含储备的最大生命、生命，五个主动技条件，累计）。只在内存，产物 .sandbox/guyu_battle.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const G = w.Guyu;
if (!G || typeof G.bloom !== 'function') throw new Error('谷雨模块未安装');
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
const toasts = [];
w.$.toaster = o => toasts.push(String(o && o.message));
const key = b => !b ? null : b.isActor() ? 'a' + b.actorId() : 'e' + b.index();
const BIG_HP = 1e9, TROOP = 3, ID = 175, STONE = 2944;
const ACTIVE = [10288, 10289, 10290, 10291, 10292];

const rng = [];  // 'rng' 给的随机数：只给谷雨运行时（rollStone 的 Math.randomInt），用完回 0.5
function battle(level, rank) {
  newGame();
  w.eval('$gameSystem.setDifficultyId(2); $gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.eval('$gameSwitches.setValue(2494, true); $gameParty._actors=[' + ID + ',1]; $gameParty._battleMembers=[' + ID + ',1,0,0,0];');
  for (const id of [ID, 1]) { const b = w.$gameActors.actor(id); b.changeLevel(level, false); }
  const a = w.$gameActors.actor(ID);
  a._AdvancedNum = rank || 0; G.syncSkills(a);
  for (const id of [ID, 1]) w.$gameActors.actor(id).recoverAll();
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  w.Math.random = () => 0.99;
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  w.Math.random = () => rng.length && /installNativeGuyuRuntime/.test(String(new Error().stack).split('\n').slice(2, 4).join()) ? rng.shift() : 0.5;
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
function act(bm, user, skillId, targetIndex) {
  const action = new w.Game_Action(user); action.setSkill(skillId); action.setTarget(targetIndex);
  user._actions = [action]; bm._subject = user; bm._action = null;
  bm.startAction();
  for (let i = 0; i < 20000; i++) {
    const ph = bm._phase;
    if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
    else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
  }
  bm._phase = 'turn';
}
function row(b) { return {e: G.reserve(b), cap: G.isGuyu(b) ? null : G.cap(b), mhp: b.mhp, base: G.baseMhp(b), hp: b.hp}; }
function snapshot(env) {
  const {a, hero} = env, t = G.totals || {};
  return {round: G.round, flowerUntil: G.flowerUntil, openAt: G.openAt, serial: G.flowerSerial, seed: G.seed ? G.seed.index() : null,
    battle: !!G.activeBattle, party: [row(a), row(hero)], meets: ACTIVE.map(id => a.meetsSkillConditions(w.$dataSkills[id])),
    totals: {generated: t.generated, wasted: t.wasted, spent: t.spent, blooms: t.blooms}};
}
function run(steps, level, rank) {
  const env = battle(level, rank), {bm, a, hero, foes} = env, out = [];
  const who = x => x === 'g' ? a : hero;
  const log = [], old = w.Game_Action.prototype.executeHpDamage;
  w.Game_Action.prototype.executeHpDamage = function (target, value) {
    const r = old.apply(this, arguments);
    log.push({skill: this.item().id, user: key(this.subject()), target: key(target), hp: target.result().hpDamage});
    return r;
  };
  try {
    out.push({step: ['start'], snap: snapshot(env)});
    for (const st of steps) {
      log.length = 0;
      const [kind, x, y, z] = st;
      if (kind === 'act') act(bm, who(x), y, z);
      else if (kind === 'turn') { bm._enteredEndPhase = false; bm._phase = 'turn'; bm.endTurn(); bm.startTurn(); bm._phase = 'turn'; }
      else if (kind === 'hp') who(x).setHp(y);
      else if (kind === 'mp') a.setMp(a.mmp);
      else if (kind === 'foehp') foes[x]._hp = y;
      out.push({step: st, hits: log.slice(), snap: snapshot(env), foes: foes.map(t => t.isAlive())});
    }
    bm.endBattle(0);
    out.push({step: ['endBattle'], snap: snapshot(env)});
  } finally { w.Game_Action.prototype.executeHpDamage = old; }
  return out;
}
// 治疗都是全体（scope 8）；1 号攻击用普攻 1；防御 2
const SCRIPTS = {
  // 10 级：满血治疗全进储备（1 号到上限、多的浪费）；不在花期攻击不绽放；开花期打 e1；1 号攻击绽放（付储备 25%、打种子）；
  // 1 号防御不绽放；谷雨治疗也绽放（谷雨自己的储备）；花期两回合后收束、冷却到 +2 回合；冷却时开不了，到了再开
  lv10: [['act', 'g', 10288, 0], ['act', 'h', 1, 0], ['act', 'g', 10289, 1], ['act', 'h', 1, 0], ['act', 'h', 2, 0], ['act', 'g', 10288, 0],
    ['turn'], ['act', 'h', 1, 2], ['turn'], ['act', 'h', 1, 0], ['turn'], ['mp'], ['act', 'g', 10289, 0], ['turn'], ['act', 'g', 10289, 2], ['act', 'h', 1, 0]],
  // 35 级：受伤后治疗（回血与储备同记治疗量）；终结在不在花期的条件；开花期、终结（付全部储备、打目标、收束、冷却）；种子倒下换第一个活着的敌人
  lv35: [['hp', 'h', 1], ['act', 'g', 10288, 0], ['act', 'g', 10289, 0], ['act', 'h', 1, 1], ['act', 'g', 10292, 2], ['act', 'h', 1, 0],
    ['turn'], ['turn'], ['mp'], ['act', 'g', 10288, 0], ['act', 'g', 10289, 0], ['foehp', 0, 1], ['act', 'h', 1, 1], ['act', 'h', 1, 1]],
  // 45 级（生未央）：不在花期治疗多 20%；花期里治疗不多加
  lv45: [['act', 'g', 10288, 0], ['act', 'g', 10289, 1], ['act', 'g', 10288, 0], ['act', 'g', 10292, 1]],
  // 60 级 5 阶（我即万物之春）：绽放、终结都不付储备
  lv60: [['act', 'g', 10288, 0], ['act', 'g', 10289, 1], ['act', 'h', 1, 1], ['act', 'g', 10292, 1], ['turn'], ['turn'], ['act', 'g', 10289, 0]],
};
const LEVELS = {lv10: [10, 0], lv35: [35, 0], lv45: [45, 0], lv60: [60, 5]};
// 胜利掉谷种金缮石：谷雨在队、还差进阶、背包里少于差额、Math.randomInt(50)==0 才掉 1 个
function stone(rank, have, draw) {
  newGame();
  w.eval('$gameSystem.setDifficultyId(2); $gameSwitches.setValue(2494, true); $gameParty._actors=[' + ID + ',1]; $gameParty._battleMembers=[' + ID + ',1,0,0,0];');
  w.$gameActors.actor(ID)._AdvancedNum = rank;
  if (have) w.$gameParty.gainItem(w.$dataItems[STONE], have);
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  w.Math.random = () => 0.5;
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  rng.length = 0; rng.push(draw); toasts.length = 0;
  w.Math.random = () => rng.length && /installNativeGuyuRuntime/.test(String(new Error().stack).split('\n').slice(2, 4).join()) ? rng.shift() : 0.5;
  bm.endBattle(0);
  return {stones: w.$gameParty.numItems(w.$dataItems[STONE]), toasts: toasts.filter(t => /谷种/.test(t)), battle: !!G.activeBattle};
}
const cases = [];
for (const [name, steps] of Object.entries(SCRIPTS)) {
  const [level, rank] = LEVELS[name];
  cases.push(makeCase(`script.${name}`, {actor: ID, level, rank, troop: TROOP, steps}, () => ({steps: run(steps, level, rank)})));
}
for (const [name, rank, have, draw] of [['drop', 0, 0, 0], ['roll', 0, 0, 0.5], ['enough', 3, 2, 0], ['short', 3, 1, 0], ['full', 5, 0, 0]]) {
  cases.push(makeCase(`stone.${name}`, {rank, have, draw}, () => stone(rank, have, draw)));
}
process.exit(finish(host, 'guyu_battle.json', {hostScope: '真实 BattleManager（startBattle 推进到输入）／Game_Action（Math.random 0.5）', cases}) ? 0 : 1);
