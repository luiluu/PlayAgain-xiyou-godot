'use strict';
// 【cc·八戒·未经审查】甚尔 171 第二期战斗内机制（js/codex/runtime/installNativeTojiRuntime.js 的 startBattle／endBattle、
// removeState（复活）、startAction／actionActionEffect（多段、单目标）、endAction（切换形态）、apply（段数计数、万里锁溅射、天逆鉾封印）、
// meetsSkillConditions 与类别封印豁免、Window_SkillList.includes（战斗中技能列表）；黑闪 startAction 包装的觉醒游云额外一击）。
// 真实 BattleManager：setup→startBattle→推进到第一次输入（开战事件照跑）；之后每步 startAction→行动列表→endAction、或 endTurn。
// 队伍 [171, 1] 各 55 级（进阶 0，不触发武器库）、开 2494；敌人生命加 1e18（甚尔 55 级一段约 2e14，1e12 几下就打死）；我方不加（甚尔最大生命过 99999999 会被云裳包装的最终夹值压回，见交付单）；Math.random 0.5；黑闪判定按脚本给的随机数（B.random）。
// 每步记 executeHpDamage（技能、出手者、目标、生命伤害、暴击）与之后的快照（形态状态、普攻技能、技能条件、战斗中技能列表、
// 各敌人身上的封印 2634 与次数、黑闪状态）。追加次数用状态 1541（攻击次数＋1）／2564（＋3）；类别封印用状态 130（封战技）。
// 只在内存，产物 .sandbox/toji_battle.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const T = w.CodexToji, B = w.CodexBlackFlash;
if (!T || typeof T.setShape !== 'function' || !B) throw new Error('甚尔／黑闪模块未安装');
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
const key = b => !b ? null : b.isActor() ? 'a' + b.actorId() : 'e' + b.index();
const BIG_HP = 1e18, TROOP = 3, LEVEL = 55, ID = 171;
const SHAPES = [2630, 2631, 2632, 2633], SEAL = 2634, AWAKE = 2635;
const SKILLS = [10212, 10213, 10214, 10215, 10216, 10217, 10218, 10219];

function battle() {
  newGame();
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.eval('$gameSwitches.setValue(2494, true); $gameParty._actors=[' + ID + ',1]; $gameParty._battleMembers=[' + ID + ',1,0,0,0];');
  for (const id of [ID, 1]) {
    const b = w.$gameActors.actor(id); b.changeLevel(LEVEL, false); b.recoverAll();
  }
  const a = w.$gameActors.actor(ID);
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  w.Math.random = () => 0.99;
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  w.Math.random = () => 0.5;
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  for (const t of w.$gameTroop.members()) t._paramPlus[0] = BIG_HP;
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  const before = SHAPES.filter(id => a.isStateAffected(id));
  bm.startBattle();
  for (let tick = 0; tick < 5000 && bm._phase !== 'input'; tick++) {
    if (w.$gameMessage.isBusy()) { w.$gameMessage.clear(); continue; }
    bm.update();
  }
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) b.recoverAll();
  a.setTp(100);
  return {bm, a, foes: w.$gameTroop.members(), before};
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
function listed(a) {
  const win = {_actor: a, _stypeId: 1};
  return a.skills().map(s => s.id).filter(id => SKILLS.indexOf(id) >= 0 && w.Window_SkillList.prototype.includes.call(win, w.$dataSkills[id]));
}
function snapshot(env) {
  const {a, foes} = env, st = B.status(a);
  return {
    shapes: SHAPES.filter(id => a.isStateAffected(id)), attack: a.attackSkillId(), alive: a.isAlive(),
    meets: SKILLS.map(id => a.meetsSkillConditions(w.$dataSkills[id])),
    listed: listed(a),
    awake: a.isStateAffected(AWAKE),
    flash: {focus: st.focus, chain: st.chain, awake: st.awake},
    foes: foes.map(t => ({seal: t.isStateAffected(SEAL), charges: t._tojiSealCharges || 0})),
  };
}
function run(steps, draws) {
  const env = battle(), {bm, a, foes} = env, out = [];
  const seq = (draws || []).slice();
  B.random = function () { return seq.length ? seq.shift() : 0.5; };
  const log = [], old = w.Game_Action.prototype.executeHpDamage;
  w.Game_Action.prototype.executeHpDamage = function (target, value) {
    const r = old.apply(this, arguments);
    log.push({skill: this.item().id, user: key(this.subject()), target: key(target), hp: target.result().hpDamage, critical: !!target.result().critical});
    return r;
  };
  try {
    out.push({step: ['start'], before: env.before, snap: snapshot(env)});
    for (const st of steps) {
      log.length = 0;
      const [kind, x, y] = st;
      if (kind === 'act') act(bm, a, x, y);
      else if (kind === 'end') { bm._enteredEndPhase = false; bm._phase = 'turn'; bm.endTurn(); bm._phase = 'turn'; }
      else if (kind === 'state') a.addState(x);
      else if (kind === 'unstate') a.removeState(x);
      else if (kind === 'die') { a.addState(a.deathStateId()); }
      else if (kind === 'revive') { a.removeState(a.deathStateId()); a.setHp(a.mhp); }
      out.push({step: st, hits: log.slice(), snap: snapshot(env)});
    }
    bm.endBattle(0);
    out.push({step: ['endBattle'], snap: snapshot(env)});
  } finally { w.Game_Action.prototype.executeHpDamage = old; B.random = function () { return Math.random(); }; }
  return out;
}
const SCRIPTS = {
  // 开战第一形态；游云 5 段；切万里锁（1 段×4＋其余敌人 33% 溅射）；切释魂刀（1 段、×(5＋追加)×0.95）；切天逆鉾（1 段、封印）；
  // 当前形态的切换不能用；回合结束
  shapes: [['act', 10216, 0], ['act', 10213, 0], ['act', 10217, 1], ['act', 10214, 0], ['act', 10218, 0], ['act', 10215, 0], ['act', 10219, 2],
    ['act', 10212, 0], ['act', 10216, 0], ['end']],
  // 追加次数：＋1 时游云 6 段、万里锁 2 段（第 2 段 ×0.8）、释魂刀 1 段 ×6×0.95、天逆鉾 2 段；＋3 时游云 8 段
  extra: [['state', 1541], ['act', 10216, 0], ['act', 10213, 0], ['act', 10217, 0], ['act', 10214, 0], ['act', 10218, 1], ['act', 10215, 0],
    ['act', 10219, 1], ['unstate', 1541], ['state', 2564], ['act', 10212, 0], ['act', 10216, 2]],
  // 阵亡与复活：切到释魂刀后阵亡（形态随死亡清掉），复活回游云；类别封印 130 下切换仍可用、主技能照常
  revive: [['act', 10214, 0], ['die'], ['revive'], ['state', 130], ['act', 10213, 0], ['act', 10217, 0], ['unstate', 130]],
  // 黑闪：游云第 1 段判定成功 → 觉醒；觉醒中游云 5＋1 段、万里锁溅射 50%、释魂刀穿透 80%、天逆鉾 2 次封印
  flash: [['act', 10216, 0], ['act', 10216, 0], ['act', 10213, 0], ['act', 10217, 0], ['act', 10214, 0], ['act', 10218, 1], ['act', 10215, 0],
    ['act', 10219, 2], ['end']],
};
const DRAWS = {flash: [0]};
const cases = [];
for (const [name, steps] of Object.entries(SCRIPTS)) {
  cases.push(makeCase(`script.${name}`, {actor: ID, level: LEVEL, troop: TROOP, steps, draws: DRAWS[name] || []}, () => ({steps: run(steps, DRAWS[name])})));
}
process.exit(finish(host, 'toji_battle.json', {hostScope: '真实 BattleManager（startBattle 推进到输入）／Game_Action（Math.random 0.5）', cases}) ? 0 : 1);
