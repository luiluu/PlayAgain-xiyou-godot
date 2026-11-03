'use strict';
// 【cc·悟空·未经审查】108 奈叶共享击杀（js/codex/runtime/installNanohaSharedKillRuntime.js）：
// Game_Action.apply 包装：行动者是在出战队伍里的别的角色、奈叶学会并肩适应 10168 与适应 5683 且活着时，
//   打中（result().isHit()）一个原本活着的敌人就记进本次行动的目标表（同一目标只记一次）；
// BattleManager.endAction 包装：原 endAction 之后，目标表里每个已死的敌人给奈叶 addParam(0,10)、addParam(1,30)。
// 奈叶自己的击杀不走这里（actorId===108 排除），由状态 1768 Conclude 给（本探针也量一例，确认不会重复给）。
// 真实 BattleManager／Game_Action（Math.random 0.5）；只在内存，产物 .sandbox/nanoha_kill.json，
// 拷成 tests/fixtures/nanoha_kill_oracle.json（不接入全量同步）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');  // 五乘区（CodexZones）重制不移植（O-044），探针宿主默认开着；关掉让参照不含成长修正（tools50 确认关与不关产物一致或已更新夹具）
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
w.Math.random = () => 0.5;
const NANOHA = 108, MATE = 1, TROOP = 2, BIG_HP = 1e9;

// 新局、开挑战开关 2494（locked 不开：超强者被挪去替补）；队伍 party（角色号，依次入队），各 10 级；敌群 2（三只），hp[i] 为每只开战血量
function battle(party, hp, opts = {}) {
  newGame();
  w.$gameSwitches.setValue(2494, !opts.locked);  // 奈叶是超强者（installBossDifficultyRuntime superStrongIds），开挑战才能出战
  w.eval('$gameParty._actors=[];');
  for (const id of party) {
    const a = w.$gameActors.actor(id);
    a.changeLevel(10, false);
    w.$gameParty.addActor(id);
  }
  // 宿主新局会补回 1、8、9、10（YEP_PartySystem 的 _battleMembers）：队伍与出战都只留 party
  w.$gameParty._actors = party.slice();
  w.$gameParty._battleMembers = party.slice();
  const n = w.$gameActors.actor(NANOHA);
  if (opts.forget) n.forgetSkill(opts.forget);
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  w.CodexYunshang._acted = [];
  const foes = w.$gameTroop.members();
  for (const e of foes) e._paramPlus[0] = BIG_HP;
  for (const b of [...w.$gameParty.members(), ...foes]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  foes.forEach((e, i) => e.setHp(hp[i]));
  if (opts.nanohaDead) n.addState(n.deathStateId());
  if (opts.conclude) n.addState(1768);
  return {bm, n, foes};
}
function act(bm, user, skillId, targetIndex) {
  const action = new w.Game_Action(user);
  if (skillId === 1) action.setAttack(); else action.setSkill(skillId);
  action.setTarget(targetIndex);
  user._actions = [action]; bm._subject = user; bm._action = null;
  bm.startAction();
  for (let i = 0; i < 20000; i++) {
    const ph = bm._phase;
    if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
    else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
  }
}
const snap = (n, foes) => ({members: w.$gameParty.battleMembers().map(m => m.actorId()), plus: [n._paramPlus[0], n._paramPlus[1]], dead: foes.map(e => e.isDead()),
  learned: [10168, 5683].map(id => n.isLearnedSkill(id))});

const cases = [];
cases.push(makeCase('learn', {actor: NANOHA, level: 1}, () => {
  newGame();
  const n = w.$gameActors.actor(NANOHA);
  return {learned: [10168, 5683].map(id => n.isLearnedSkill(id))};
}));
// [名字, 队伍, 敌血量, 行动者, 技能（1＝普攻）, 目标, 选项]
const SPECS = [
  ['mate.attack.kill', [MATE, NANOHA], [1, BIG_HP, BIG_HP], MATE, 1, 0, {}],
  ['mate.attack.nokill', [MATE, NANOHA], [BIG_HP, BIG_HP, BIG_HP], MATE, 1, 0, {}],
  ['mate.aoe.kill2', [MATE, NANOHA], [1, 1, BIG_HP], MATE, 160, -1, {}],
  ['mate.aoe.kill3', [MATE, NANOHA], [1, 1, 1], MATE, 160, -1, {}],
  ['nanoha.absent', [MATE], [1, 1, 1], MATE, 160, -1, {}],
  ['nanoha.locked', [MATE, NANOHA], [1, 1, 1], MATE, 160, -1, {locked: true}],
  ['nanoha.dead', [MATE, NANOHA], [1, 1, 1], MATE, 160, -1, {nanohaDead: true}],
  ['nanoha.no10168', [MATE, NANOHA], [1, 1, 1], MATE, 160, -1, {forget: 10168}],
  ['nanoha.no5683', [MATE, NANOHA], [1, 1, 1], MATE, 160, -1, {forget: 5683}],
  ['nanoha.self.kill', [MATE, NANOHA], [1, BIG_HP, BIG_HP], NANOHA, 1, 0, {conclude: true}],
  ['nanoha.self.nostate', [MATE, NANOHA], [1, BIG_HP, BIG_HP], NANOHA, 1, 0, {}],
];
for (const [name, party, hp, who, skill, target, opts] of SPECS) {
  cases.push(makeCase('kill.' + name, {party, hp, user: who, skill, target, ...opts}, () => {
    const {bm, n, foes} = battle(party, hp, opts);
    const before = snap(n, foes);
    act(bm, w.$gameActors.actor(who), skill, target);
    return {before, after: snap(n, foes)};
  }));
}
// 连着两次：第一次杀一只，第二次打已死以外的活敌不杀（已死的敌人不会再记）
cases.push(makeCase('kill.mate.twice', {party: [MATE, NANOHA], hp: [1, BIG_HP, BIG_HP], user: MATE}, () => {
  const {bm, n, foes} = battle([MATE, NANOHA], [1, BIG_HP, BIG_HP]);
  const mate = w.$gameActors.actor(MATE), steps = [];
  act(bm, mate, 1, 0); steps.push(snap(n, foes));
  act(bm, mate, 160, -1); steps.push(snap(n, foes));
  return {steps};
}));
process.exit(finish(host, 'nanoha_kill.json', {hostScope: '真实 Game_Action.apply／BattleManager.endAction 的奈叶共享击杀包装；Math.random 0.5', cases}) ? 0 : 1);
