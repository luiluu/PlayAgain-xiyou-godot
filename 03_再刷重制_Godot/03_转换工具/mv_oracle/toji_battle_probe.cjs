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

const rng = [];  // 'rng' 步给的随机数：Math.random 先取它（甚尔武器库的三次掷：是否追击、选哪把、天逆鉾是否封印），用完回 0.5
function battle(rank) {
  newGame();
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.eval('$gameSwitches.setValue(2494, true); $gameParty._actors=[' + ID + ',1]; $gameParty._battleMembers=[' + ID + ',1,0,0,0];');
  for (const id of [ID, 1]) {
    const b = w.$gameActors.actor(id); b.changeLevel(LEVEL, false); b.recoverAll();
  }
  w.$gameActors.actor(1)._paramPlus[0] = BIG_HP;  // 敌人行动只打 1 号（夹在 99999999）
  const a = w.$gameActors.actor(ID);
  if (rank) { a._AdvancedNum = rank; a.forgetSkill(10208); a.learnSkill(10210); a.learnSkill(10211); }  // 同 repair 的进阶部分
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  w.Math.random = () => 0.99;
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  // 给定的随机数只给甚尔 startAction 包装（武器库三次掷）；云裳 uuid、dsPassiveSkill numRepeats 等照取 0.5
  w.Math.random = () => rng.length && /installNativeTojiRuntime/.test(String(new Error().stack).split('\n')[2] || '') ? rng.shift() : 0.5;
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
function run(steps, draws, rank) {
  const env = battle(rank), {bm, a, foes} = env, out = [];
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
      else if (kind === 'rng') { rng.length = 0; rng.push(...x); }
      else if (kind === 'foe') act(bm, foes[x], y, st[3]);  // 敌人用技能 y 打我方第 st[3] 位
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
// 天逆鉾封印（第二期⑥，applyGlobal）：被封的敌人下一次主动技能（非普攻、非防御）失效并扣一次，普攻与防御不扣；
// 觉醒中的天逆鉾给 2 次
SCRIPTS.seal = [['act', 10215, 0], ['act', 10219, 0], ['foe', 0, 1, 1], ['foe', 0, 2, 0], ['foe', 0, 3, 1], ['foe', 0, 3, 1],
  ['act', 10216, 1], ['act', 10216, 1], ['act', 10219, 2], ['foe', 2, 3, 1], ['foe', 2, 3, 1], ['foe', 2, 3, 1]];
// 术师杀手（第三期⑦）：敌人普攻（西游普攻 1 是魔法）打甚尔受伤 ×0.2 并反弹 10224；打 1 号不反弹；物理技能 3 打甚尔不减不反弹
SCRIPTS.slayer = [['act', 10216, 0], ['foe', 0, 1, 0], ['foe', 1, 1, 1], ['foe', 2, 3, 0], ['foe', 2, 1, 0], ['end'], ['foe', 0, 1, 0]];
// 武器库（第三期⑤，进阶 1）：借万里锁（游云 5 段各溅射 16%）、借释魂刀（穿透 0.33）、借天逆鉾并掷中（武器库·天逆鉾与主技能都封印）、
// 万里锁借游云（＋1 段）、没掷中不追击
SCRIPTS.armory = [['rng', [0.1, 0.0]], ['act', 10216, 0], ['rng', [0.1, 0.5]], ['act', 10216, 1], ['rng', [0.1, 0.9, 0.1]], ['act', 10216, 2],
  ['act', 10213, 0], ['rng', [0.1, 0.0]], ['act', 10217, 0], ['rng', [0.9]], ['act', 10217, 1], ['end']];
const RANKS = {armory: 1};
const DRAWS = {flash: [0], seal: [1, 0]};
// 命中／闪避／暴击（第二期④）：开战后忘掉暴君（暴击回到 1 以下才看得出暴击闪避）、e0 加暴击闪避＋60%（1467）；
// 甚尔打 e0（主技能、武器库、反弹、普通技能 3）与 e0 用物理技能 3 打甚尔，各记 itemHit／itemEva／itemCri；再忘掉五感、天与咒缚各量一遍
function rates() {
  const env = battle(), {a, foes} = env, e = foes[0], out = [];
  a.forgetSkill(10205); e.addState(1467); e.refresh();
  const one = (u, t, sid) => { const x = new w.Game_Action(u); x.setSkill(sid); return {user: key(u), target: key(t), skill: sid, hit: x.itemHit(t), eva: x.itemEva(t), cri: x.itemCri(t)}; };
  const sweep = tag => { for (const sid of [10216, 10220, 10224, 3]) out.push(Object.assign({tag}, one(a, e, sid))); out.push(Object.assign({tag}, one(e, a, 3))); };  // 敌人用物理的 3（普攻 1 在西游是魔法）
  sweep('base'); a.forgetSkill(10206); sweep('noSenses'); a.forgetSkill(10203); sweep('noBond');
  return {agi: [a.agi, e.agi], cev: e.cev, cri: a.cri, rows: out};
}
// 暴君（第二期③）：负面状态与弱化加不上；忘掉暴君后照常加上，再学回暴君时负面状态清掉、正面与系统状态留着（弱化见下）
const TYRANT_STATES = [4, 5, 6, 7, 11, 12, 130, 995, 1541, 1691, 2635];
function tyrant() {
  const env = battle(), {a} = env, out = {};
  const has = () => TYRANT_STATES.filter(id => a.isStateAffected(id));
  const add = () => { TYRANT_STATES.forEach(id => a.addState(id)); a.addDebuff(2, 3); a.addDebuff(6, 3); };
  add(); out.withTyrant = {states: has(), buffs: a._buffs.slice()};
  a.forgetSkill(10205); add(); out.without = {states: has(), buffs: a._buffs.slice()};
  // 原版 clearDebuffs 调的 actor.removeDebuff 在 MV 里不存在：先清完负面状态，碰到第一个弱化就抛错（学技能本身已生效）
  let error = null;
  try { a.learnSkill(10205); } catch (e) { error = String(e.message || e); }
  out.relearned = {states: has(), buffs: a._buffs.slice(), learned: a.isLearnedSkill(10205), error};
  return out;
}
const cases = [makeCase('rates', {level: LEVEL, troop: TROOP, foeState: 1467}, rates), makeCase('tyrant', {level: LEVEL, states: TYRANT_STATES, debuffs: [2, 6]}, tyrant)];
for (const [name, steps] of Object.entries(SCRIPTS)) {
  cases.push(makeCase(`script.${name}`, {actor: ID, level: LEVEL, troop: TROOP, rank: RANKS[name] || 0, steps, draws: DRAWS[name] || []}, () => ({steps: run(steps, DRAWS[name], RANKS[name])})));
}
process.exit(finish(host, 'toji_battle.json', {hostScope: '真实 BattleManager（startBattle 推进到输入）／Game_Action（Math.random 0.5）', cases}) ? 0 : 1);
