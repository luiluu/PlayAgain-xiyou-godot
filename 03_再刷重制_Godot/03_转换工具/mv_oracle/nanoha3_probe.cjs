'use strict';
// 【cc·悟空·未经审查】108 奈叶二期①参照：大招自定义 MP 消耗与伤害后多段。宿主设置沿用 nanoha2_probe（真实 BattleManager／Game_Action，Math.random 0.5）；
// 只在内存，产物 .sandbox/nanoha3.json，拷成 tests/fixtures/nanoha3_oracle.json（不接入全量同步）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
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



// 大招 5703～5709：YEP_SkillCore <Custom MP Cost>（cost＝⌊mp×比例⌋，顺手写 user._costmp＝⌊mp×比例/2000⌋）
// 与 <Post-Damage Eval>（_costmp>0 时再 gainHp(-value) 共 _costmp-1 次；Bailong_NaiyeACS_FastSettlement 段数超 512 合并尾段）
const log = [];
let inAction = false;
const oldGain = w.Game_Battler.prototype.gainHp;
w.Game_Battler.prototype.gainHp = function (v) { if (inAction && this.isEnemy()) log.push({t: this.index(), d: v, hp: this.hp}); return oldGain.apply(this, arguments); };
const oldPop = w.Game_Battler.prototype.startDamagePopup;
let pops = 0;
w.Game_Battler.prototype.startDamagePopup = function () { if (inAction && this.isEnemy()) pops++; return oldPop.apply(this, arguments); };
const post = [];
const oldPost = w.Game_Action.prototype.applyPostDamageEval;
w.Game_Action.prototype.applyPostDamageEval = function (target, value) { post.push({t: target.index(), value, costmp: this.subject()._costmp, mp: this.subject().mp}); return oldPost.apply(this, arguments); };
const cases = [];
const SKILLS = [5703, 5704, 5705, 5706, 5708, 5709];
function cast(skill, mp, hp, mmp) {
  const {bm, n, foes} = battle([NANOHA], hp);
  n._paramPlus[1] = mmp; n.need_refresh = true; n.refresh();
  n.setMp(mp);
  const before = {mp: n.mp, mmp: n.mmp, mcr: n.mcr, mat: n.mat, luk: n.luk, elem7: foes[0].elementRate(7), mdf: foes[0].mdf, cost: n.skillMpCost(w.$dataSkills[skill]), costmpAfterQuery: n._costmp};
  delete n._costmp;
  log.length = 0; post.length = 0; pops = 0;
  const hp0 = foes.map(e => e.hp);
  inAction = true;
  try { act(bm, n, skill, 0); } finally { inAction = false; }
  return {before, mpAfter: n.mp, costmpAfter: n._costmp, hp0, hp1: foes.map(e => e.hp), dead: foes.map(e => e.isDead()),
    post: post.slice(), gains: log.length <= 40 ? log.slice() : {count: log.length, first: log.slice(0, 5), last: log.slice(-3)}, pops};
}
for (const s of SKILLS) for (const mp of [1500, 6667, 23000]) {
  cases.push(makeCase(`cast.${s}.${mp}`, {skill: s, mp, mmp: 50000}, () => cast(s, mp, [BIG_HP, BIG_HP, BIG_HP], 50000)));
}
// 打死：第一只血少，多段中途死
cases.push(makeCase('cast.5706.kill', {skill: 5706, mp: 23000}, () => cast(5706, 23000, [30000, BIG_HP, BIG_HP], 50000)));
cases.push(makeCase('cast.5703.kill', {skill: 5703, mp: 23000}, () => cast(5703, 23000, [30000, BIG_HP, BIG_HP], 50000)));
// 普攻对照（分辨伤害链差别与多段无关）
cases.push(makeCase('cast.1.6667', {skill: 1, mp: 6667, mmp: 50000}, () => cast(1, 6667, [BIG_HP, BIG_HP, BIG_HP], 50000)));
// 极端段数（超 512，ACS 快速结算）
cases.push(makeCase('cast.5709.extreme', {skill: 5709, mp: 1500000}, () => cast(5709, 1500000, [BIG_HP * 1000, BIG_HP, BIG_HP], 2000000)));
// 智能 AI（Codex_SmartBattleAI makeAction）：奈叶会小魔炮 5692 时候选换成六档魔炮（不必学会），估伤按付费后 MP、再 ×max(1,⌊付前MP×比例/2000⌋)
function ai(mp, hp, opts = {}) {
  const {bm, n, foes} = battle([NANOHA], hp);
  n._paramPlus[1] = 50000; n.need_refresh = true; n.refresh();
  if (opts.noCannon) n.forgetSkill(5692); else n.learnSkill(5692);
  n.setMp(mp);
  w.ConfigManager.codexSmartAI = true;
  delete n._costmp;
  const action = n.makeAction();
  const item = action && action.item && action.item();
  return {mp: n.mp, learned5692: n.isLearnedSkill(5692), costmp: n._costmp === undefined ? null : n._costmp,
    skill: item ? item.id : null, target: action ? action._targetIndex : null,
    skills: n.skills().map(s => s.id).filter(id => id >= 5690 && id <= 5710)};
}
for (const mp of [0, 1500, 6667, 23000, 50000]) cases.push(makeCase(`ai.${mp}`, {mp}, () => ai(mp, [BIG_HP, BIG_HP, BIG_HP])));
cases.push(makeCase('ai.23000.lowfoe', {mp: 23000}, () => ai(23000, [5000, BIG_HP, BIG_HP])));
cases.push(makeCase('ai.23000.noCannon', {mp: 23000, noCannon: true}, () => ai(23000, [BIG_HP, BIG_HP, BIG_HP], {noCannon: true})));
process.exit(finish(host, 'nanoha3.json', {hostScope: '真实 BattleManager.startAction 下奈叶大招 5703～5709 的自定义 MP 消耗与伤害后多段', cases}) ? 0 : 1);
