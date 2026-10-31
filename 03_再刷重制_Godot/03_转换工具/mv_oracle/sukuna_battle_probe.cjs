'use strict';
// 【Claude·八戒·未经审查】宿傩 172 战斗内机制与黑闪（installNativeBlackFlashRuntime.js，第三期加 flash 一段）（js/codex/runtime/installNativeSukunaRuntime.js 的 S.begin／finish／endRound、
// Game_Action.apply／itemEva／executeHpDamage／gainHp／meetsSkillConditions／skillTpCost／skills 包装）。
// 每例一段脚本：真实 BattleManager.startAction→行动列表→endAction（宿傩或敌人行动），BattleManager.endTurn（回合结束）；
// 每步记 executeHpDamage（行动技能、出手者、目标、结果 hpDamage）与之后的快照（看破层、蓄力、伤口、领域、准备层、适应、
// 技能条件、TP 消耗、战斗中技能列表）。敌群 3 三只、双方生命加 1e12，Math.random 0.5；只在内存，产物 .sandbox/sukuna_battle.json。
// 不走 BattleManager.startBattle（会跑开战事件），S.round 与战斗数据按其包装手动清；开战 TP 由 Godot 专项单独断言。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const S = w.CodexSukuna, B = w.CodexBlackFlash;
if (!S || typeof S.begin !== 'function') throw new Error('宿傩模块未安装');
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
const key = b => !b ? null : b.isActor() ? 'a' + b.actorId() : 'e' + b.index();
const BIG_HP = 1e12, TROOP = 3, LEVEL = 55, ID = 172;
const MARKS = [2636, 2637, 2638, 2639, 2640, 2641, 2642];

function battle(rank) {
  newGame();
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  // 直接定队伍与出战位：宿傩 0 号、1 号主角
  // 超强角色出战要开关（installBossDifficultyRuntime superStrongEnabled）：开 2494
  w.eval('$gameSwitches.setValue(2494, true); $gameParty._actors=[' + ID + ',1]; $gameParty._battleMembers=[' + ID + ',1,0,0,0];');
  const a = w.$gameActors.actor(ID);
  a._AdvancedNum = rank;
  for (const id of [ID, 1]) {
    const b = w.$gameActors.actor(id); b.changeLevel(LEVEL, false); b._paramPlus[0] = BIG_HP; b.recoverAll();
  }
  S.sync(a);
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  if (w.CodexYunshang) w.CodexYunshang._acted = [];
  // S.startBattle 包装的前半（不调原 startBattle）
  S.round = 0; delete a._codexSukuna;
  B.round = 0; B.serial = 0; B.nested = 0; B.clear(a);  // 黑闪 startBattle 包装的前半
  for (const t of w.$gameTroop.members()) { delete t._codexSukunaTarget; t._paramPlus[0] = BIG_HP; }
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  a.setTp(100);
  return {bm, a, foes: w.$gameTroop.members()};
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
function snapshot(env) {
  const {a, foes} = env, d = S.temp(a);
  const marks = b => b._states.filter(x => MARKS.indexOf(x) >= 0).sort((x, y) => x - y);
  return {
    round: S.round, tp: a.tp, emp: d.emp,
    flash: (st => ({focus: st.focus, chain: st.chain, awake: st.awake, probability: st.probability}))(B.status(a)),
    sukuna: {domain: d.domain, prep: d.prep, available: d.available, adapt: d.adapt, chase: d.chase, states: marks(a)},
    foes: foes.map(t => { const q = S.targetData(t); return {layers: q.layers, charged: !!q.charged, states: marks(t)}; }),
    meets: [10229, 10230, 10231, 10232, 10233].map(id => a.meetsSkillConditions(w.$dataSkills[id])),
    tpCost: [10229, 10230, 10231].map(id => a.skillTpCost(w.$dataSkills[id])),
    listed: a.skills().map(s => s.id).filter(id => id >= 10229 && id <= 10249),
  };
}
function run(rank, steps, draws) {
  const env = battle(rank), {bm, a, foes} = env, out = [];
  const seq = (draws || []).slice();
  B.random = function () { return seq.length ? seq.shift() : 0.5; };  // 黑闪判定按脚本给的随机数，用完回 0.5
  const log = [], old = w.Game_Action.prototype.executeHpDamage;
  w.Game_Action.prototype.executeHpDamage = function (target, value) {
    const r = old.apply(this, arguments);
    log.push({skill: this.item().id, user: key(this.subject()), target: key(target), hp: target.result().hpDamage, critical: !!target.result().critical});
    return r;
  };
  try {
    for (const st of steps) {
      log.length = 0;
      const [kind, x, y] = st;
      if (kind === 'act') act(bm, a, x, y);
      else if (kind === 'guard') { act(bm, a, 2, 0); a.setTp(100); }  // 防御后 TP 定回 100：原版防御 apply 给 tpGain 10，重制防御支没给（另报总装）
      else if (kind === 'foe') act(bm, foes[x], 1, 0);  // 敌人普通攻击打宿傩
      else if (kind === 'end') { bm._enteredEndPhase = false; bm._phase = 'turn'; bm.endTurn(); bm._phase = 'turn'; }
      else if (kind === 'shield') foes[x]._shield = y;
      else if (kind === 'heal') { const t = foes[x]; t.setHp(1); const before = t.hp; t.gainHp(y); out.push({step: st, healed: t.hp - before, snap: snapshot(env)}); t.recoverAll(); continue; }
      out.push({step: st, hits: log.slice(), snap: snapshot(env)});
    }
  } finally { w.Game_Action.prototype.executeHpDamage = old; B.random = function () { return Math.random(); }; }
  return out;
}
const SCRIPTS = {
  // 0 进阶：看破每回合最多 +2、伤口、追斩、咒力体术回 TP、敌人行动给自己加层、神灶蓄力与消耗、受治疗减半
  layers: [0, [['act', 10229, 0], ['act', 10229, 0], ['act', 10229, 0], ['heal', 0, 100000], ['end'], ['act', 10229, 0], ['act', 10238, 1],
    ['foe', 1], ['end'], ['act', 10232, 0], ['act', 10232, 0], ['act', 10230, 2], ['end'], ['heal', 0, 100000]]],
  // 1 进阶（空间斩）：三层转终式、真伤免护盾、终式清层；捌打护盾目标两段
  terminal: [1, [['act', 10229, 0], ['act', 10229, 0], ['end'], ['act', 10229, 0], ['shield', 0, 1e9], ['end'], ['act', 10229, 0],
    ['shield', 1, 1e9], ['act', 10230, 1], ['end'], ['act', 10231, 2]]],
  // 2 进阶（十指）：领域展开、领域中解／捌半价、回合结束御厨子·斩击、准备层、到期神灶：开、冷却
  domain: [2, [['act', 10231, 0], ['act', 10229, 1], ['end'], ['act', 10230, 1], ['end'], ['end'], ['end'], ['end'], ['end'], ['end'], ['end']]],
  // 3 进阶（二十指、次元斩、魔虚罗）：被敌人主行动扣血适应（每回合一次、上限 3）、适应加成、次元斩
  adapt: [3, [['foe', 0], ['foe', 1], ['act', 10229, 0], ['end'], ['foe', 0], ['end'], ['foe', 2], ['end'], ['foe', 0], ['act', 10229, 0], ['act', 10229, 0], ['end'],
    ['act', 10229, 0], ['act', 10231, 1], ['end']]],
  // 黑闪（第三期）：失败攒集中、体术黑闪成功→觉醒（2639）与斩击强化、主技能吃强化后清、捌冲击段判定、防御断连闪、
  // 觉醒到期、领域到期时觉醒中的内部神灶：开 ×1.2、终式不判黑闪
  flash: [0, [['act', 10238, 0], ['act', 10238, 0], ['act', 10229, 1], ['act', 10230, 1], ['guard'], ['end'], ['end'], ['end'], ['end'],
    ['act', 10231, 2], ['act', 10230, 2], ['end'], ['end'], ['end'], ['end'], ['act', 10238, 0], ['act', 10229, 0]], [0.9, 0, 0, 0, 0, 0]],
};
const cases = [];
cases.push(makeCase('module', {}, () => ({domain: 2636, wound: 2637, maho: 2638, awake: 2639, layerStates: [2640, 2641, 2642]})));
for (const [name, [rank, steps, draws]] of Object.entries(SCRIPTS)) {
  cases.push(makeCase(`script.${name}`, {actor: ID, rank, level: LEVEL, troop: TROOP, steps, draws: draws || []}, () => ({steps: run(rank, steps, draws)})));
}
process.exit(finish(host, 'sukuna_battle.json', {hostScope: '真实 BattleManager／Game_Action（Math.random 0.5）；宿傩战斗包装（不调 startBattle）', cases}) ? 0 : 1);
