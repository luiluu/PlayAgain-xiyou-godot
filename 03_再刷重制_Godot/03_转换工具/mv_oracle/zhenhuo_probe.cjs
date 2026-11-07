'use strict';
// 【cc·白龙·未经审查】至尊宝 36「真火印记」追击（新源 js/codex/runtime/installZhenhuoMarkRuntime.js，v0.53.01～v0.53.03）。
// ① mark.*：至尊宝（学没学被动 1089）放 1083／1086 打敌群 3 的 0 号：各敌人有没有印记 108、108 回合数、至尊宝有没有 109、
//    queueForceAction 记录、命中目标序列。
// ② chase.*：先用 Z.mark 给 0 号挂印记（来源至尊宝），再由至尊宝／角色 1 放 1086（火）或普攻 1（不含火）打 0 号：queueForceAction 记录（来源、技能、队位）。
// ③ scale.*：至尊宝放 1090 打 0 号，学 1089 与没学各一次，逐段伤害（比值即 0.6＋1%×等级）。
// ④ state109：角色 addState(109) 后有没有 109。原版这条屏蔽没生效（Game_Actor.addState 被 StrongActorClassification／Toji／
//    Qiyu 先包过，装在 Game_Battler 上的包装角色走不到），所以 mark.*.p1089 里 109 照挂、旧自动施法按至尊宝队位 queueForceAction。
// 真实 BattleManager／Game_Action，Math.random 0.5；只在内存，产物 .sandbox/zhenhuo.json，拷成 tests/fixtures/zhenhuo_oracle.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');  // 五乘区（成长改伤害）重制不移植，量伤害前关掉
const Z = w.__codexZhenhuoV05301;
if (!Z || typeof Z.isOwner !== 'function') throw new Error('真火印记模块未安装');
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
const BIG_HP = 1e12, TROOP = 3, LEVEL = 55, ZZB = 36;
const forces = [];
const queue = w.BattleManager.queueForceAction;
w.BattleManager.queueForceAction = function (user, skillId, target) {
  forces.push([user.isEnemy() ? 0 : 1, user.isActor() ? user.actorId() : user.index(), skillId, typeof target === 'number' ? target : 0]);
  return queue.apply(this, arguments);
};

function battle(learn) {
  newGame();
  w.eval('$gameParty._actors=[];');
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.$gameParty.addActor(ZZB); w.$gameParty.addActor(1);
  for (const id of [ZZB, 1]) {
    const a = w.$gameActors.actor(id); a.changeLevel(LEVEL, false); a._paramPlus[0] = BIG_HP; a.recoverAll();
  }
  const a = w.$gameActors.actor(ZZB);
  a.forgetSkill(1089);
  for (const id of learn) a.learnSkill(id);
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  if (w.CodexYunshang) w.CodexYunshang._acted = [];
  for (const e of w.$gameTroop.members()) e._paramPlus[0] = BIG_HP;
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  forces.length = 0;
  return {bm, a, one: w.$gameActors.actor(1), foes: w.$gameTroop.members()};
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
}
function record(fn) {
  const log = [], old = w.Game_Action.prototype.executeHpDamage;
  w.Game_Action.prototype.executeHpDamage = function (target, value) {
    log.push({target: key(target), value, critical: !!target.result().critical});
    return old.apply(this, arguments);
  };
  try { fn(); } finally { w.Game_Action.prototype.executeHpDamage = old; }
  return log;
}
const view = (a, foes) => ({
  marks: foes.map(e => e.isStateAffected(108)), turns: foes.map(e => e.isStateAffected(108) ? Number(e._stateTurns[108]) || 0 : 0),
  owner109: a.isStateAffected(109), ownerIndex: a.index(), forces: forces.slice()});
const cases = [];
cases.push(makeCase('module', {}, () => ({chase: Z.chase, version: Z.version})));
// ① 挂印记
for (const skill of [1083, 1086]) for (const passive of [true, false]) {
  const learn = [1083, 1086].concat(passive ? [1089] : []);
  cases.push(makeCase(`mark.s${skill}.${passive ? 'p1089' : 'plain'}`, {skill, learn, troop: TROOP, level: LEVEL}, () => {
    const {bm, a, foes} = battle(learn);
    const log = record(() => act(bm, a, skill, 0));
    return {log: log.map(l => l.target), ...view(a, foes)};
  }));
}
// ② 追击
for (const [user, skill] of [[ZZB, 1086], [1, 1086], [1, 1]]) {
  cases.push(makeCase(`chase.a${user}.s${skill}`, {user, skill, learn: [1083, 1086, 1089], troop: TROOP, level: LEVEL}, () => {
    const {bm, a, one, foes} = battle([1083, 1086, 1089]);
    bm._subject = a; Z.mark(foes[0]); bm._subject = null;  // 印记来源＝至尊宝（setStateOrigin 取 BattleManager._subject），回合 2
    const marked = foes.map(e => e.isStateAffected(108));
    const u = user === ZZB ? a : one;
    act(bm, u, skill, 0);  // 原版追击排进 $gameTemp 的强制行动公共事件、由事件解释器在本次行动中途插入；这里不跑事件，只比排队记录
    return {markedBefore: marked, ...view(a, foes)};
  }));
}
// ③ 追击伤害倍率
// scale.p1089.noscale：学 1089 但关掉本模块倍率（Z.noScale），倍率按 p1089 ÷ p1089.noscale 比。
for (const [name, learn, noScale] of [['p1089', [1089], false], ['p1089.noscale', [1089], true], ['plain', [], false]]) {
  cases.push(makeCase(`scale.${name}`, {learn, noScale, troop: TROOP, level: LEVEL}, () => {
    const {bm, a} = battle(learn);
    Z.noScale = noScale;
    try {
      const log = record(() => act(bm, a, 1090, 0));
      return {log, scale: Z.scaleOf(a)};
    } finally { Z.noScale = false; }
  }));
}
// ④ 角色挂不上 109
cases.push(makeCase('state109', {}, () => {
  const {a} = battle([1089]);
  a.addState(109);
  return {owner109: a.isStateAffected(109)};
}));
process.exit(finish(host, 'zhenhuo.json', {hostScope: '真实 BattleManager／Game_Action（Math.random 0.5）；真火印记 apply／makeDamageValue／addState 包装', cases}) ? 0 : 1);
