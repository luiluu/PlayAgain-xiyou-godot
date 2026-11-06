'use strict';
// 【cc·悟空·未经审查】179 流萤第一期（v0.62.12 js/codex/runtime/installLiuyingRuntime.js 的 W.CodexLiuying，运行时 1.2.0）：
// ① 学忘同步 L.sync（changeLevel／levelUp 触发；按等级 1／20／35、进阶 1／2／3 学忘 10622～10632＋梦应）、学 10628 连带学梦应；
// ② 能力值：param 生命／敏捷倍率与攻击 +5000、paramPlus 逐火生命与专武攻击／敏捷 30×等级、shieldEffectBonus、actionPlusSet；
// ③ 逐火 gainRewards：前 2000 场每场 +10，之后 10×2000/已胜场数；缺 wins 时按生命÷10 估一次；
// ④ 公式 CodexLiuying.damage（战斗外：护盾、_codexLbCastShield）与 AI 估值；⑤ 招募（专武 4004、法宝 4582）；
// ⑥ 战斗：必中、段数（天火 5／8、燃烧 9）、天火要剑；伤害钩子比值（每次新开一场，只取天火第一段：印记、付费、再释放是第二期）。
// 真实 BattleManager／Game_Action（Math.random 0.5：再释放 0.2 不触发）；只在内存，产物 .sandbox/liuying.json，拷成 tests/fixtures/liuying_oracle.json。
// 跑法：XIYOU_APP=…/冻结正式源/v0.62.12/app.nw node liuying_probe.cjs
const {start, makeCase, finish, superReference} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const L = w.CodexLiuying;
if (!L || typeof L.damage !== 'function') throw new Error('流萤模块未安装');
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
w.eval('CodexZones.ENABLED=false;');  // 五乘区（CodexZones）重制不移植（O-044）：关掉让参照不含成长修正（专武品质 9 会改它）
superReference(w);  // O-050：超强者路线压制（流萤是超强者：承伤 ×1.5 等）重制不移植，去掉让参照对得上
const ACTOR = 179, WEAPON = 4004, ARMOR = 4582, BIG_HP = 1e12, TROOP = 3;
const P = L.passives, MENG = L.mengYingId();
const LIST = [10622, 10623, 10624, 10625, 10626, 10627, 10628, 10629, 10630, 10631, 10632, MENG];
const key = b => !b ? null : b.isActor() ? 'a' + b.actorId() : 'e' + b.index();
const skills = a => a._skills.filter(id => LIST.includes(id)).sort((x, y) => x - y);
const params = a => [0, 1, 2, 3, 4, 5, 6, 7].map(i => a.param(i));
const fresh = () => {
  newGame();
  w.eval('$gameParty._actors=[];$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.$gameSwitches.setValue(2494, true);  // 流萤是超强者（installBossDifficultyRuntime 包了 recruit／addActor），开挑战才能招募
  return w.$gameActors.actor(ACTOR);
};
const slotOf = (a, base) => a.equipSlots().indexOf(base.etypeId);
const worn = (a, base) => { const e = a.equips()[slotOf(a, base)]; return e ? Number(e.originalBaseItemId || e.baseItemId || e.id) : 0; };
const setPassives = (a, on) => { for (const id of [P.guoZai, P.ziXian, P.chiRan, P.zhuiLuo, P.xingHe, P.feiYing, P.changYe, P.mingTian]) {
  if (on.includes(id)) { if (!a.isLearnedSkill(id)) a._skills.push(id); } else a._skills = a._skills.filter(x => x !== id);
} a.refresh(); };
const cases = [];
// 进阶阶数（原版 _AdvancedNum）
const rankSet = (a, r) => { a._AdvancedNum = r; };

// ① 学忘：新角色（不触发 sync）、changeLevel 到各级（触发 sync），进阶 0～3
cases.push(makeCase('skills.new', {level: 1, rank: 0}, () => { const a = fresh(); return {level: a.level, skills: skills(a)}; }));
for (const level of [1, 19, 20, 34, 35, 60]) {
  for (const rank of [0, 1, 2, 3]) {
    if (rank > 0 && level !== 60 && level !== 1) continue;
    cases.push(makeCase(`skills.lv${level}.r${rank}`, {level, rank}, () => {
      const a = fresh();
      rankSet(a, rank);
      a.changeLevel(level, false);
      return {skills: skills(a)};
    }));
  }
}
// 越阶清理：60 级三阶学全后降回 0 阶，经 levelUp 再整理一次
cases.push(makeCase('skills.rankdown', {level: 59, rank: 3}, () => {
  const a = fresh(); rankSet(a, 3); a.changeLevel(59, false);
  const before = skills(a); rankSet(a, 0); a.levelUp();
  return {before, after: skills(a), level: a.level};
}));
// 学 10628 连带学梦应（不经 sync）
cases.push(makeCase('skills.learnZhuiLuo', {level: 1}, () => { const a = fresh(); a.learnSkill(P.zhuiLuo); return {skills: skills(a), meng: MENG}; }));

// ② 能力值矩阵：60 级；有无专武／法宝；被动组合
const COMBOS = [[], [P.guoZai], [P.ziXian], [P.zhuiLuo], [P.mingTian], [P.guoZai, P.ziXian, P.zhuiLuo, P.mingTian]];
for (const gear of ['none', 'both']) {
  cases.push(makeCase(`params.${gear}`, {level: 60, gear}, () => {
    const a = fresh(); a.changeLevel(60, false);
    if (gear === 'both') { if (!L.recruit()) throw new Error('招募失败'); }
    const rows = COMBOS.map(on => { setPassives(a, on); return {on, params: params(a), plus: [0, 2, 6].map(i => a.paramPlus(i)),
      shieldBonus: a.shieldEffectBonus(), actionPlus: a.actionPlusSet().slice()}; });
    return {weapon: worn(a, w.$dataWeapons[WEAPON]), armor: worn(a, w.$dataArmors[ARMOR]), rows};
  }));
}
// 一阶再动 +1
cases.push(makeCase('params.rank1', {level: 60, rank: 1}, () => {
  const a = fresh(); rankSet(a, 1); a.changeLevel(60, false); return {actionPlus: a.actionPlusSet().slice(), skills: skills(a)};
}));

// ③ 逐火：[ember, wins]（wins 为 null 表示字段缺失）；每例胜一场、再胜一场
for (const [ember, wins] of [[0, null], [500, null], [20000, null], [20000, 2000], [20000, 4000], [30, 100], [0, 0]]) {
  cases.push(makeCase(`ember.${ember}.${wins}`, {ember, wins}, () => {
    const a = fresh(); a.changeLevel(10, false);
    if (!L.recruit()) throw new Error('招募失败');
    a._codexLbEmber = ember; if (wins == null) delete a._codexLbEmberWins; else a._codexLbEmberWins = wins;
    const bm = w.BattleManager, out = [];
    for (let i = 0; i < 2; i++) {
      bm._rewards = {gold: 0, exp: 0, items: []};
      bm.gainRewards();
      out.push({ember: a._codexLbEmber, wins: a._codexLbEmberWins, plus0: a.paramPlus(0)});
    }
    // 不戴专武不涨
    const slot = slotOf(a, w.$dataWeapons[WEAPON]); a.changeEquip(slot, null);
    bm._rewards = {gold: 0, exp: 0, items: []}; bm.gainRewards();
    out.push({ember: a._codexLbEmber, wins: a._codexLbEmberWins, unequipped: true});
    return {steps: out};
  }));
}

// ④ 公式（战斗外）
cases.push(makeCase('formula', {level: 60}, () => {
  const a = fresh(); a.changeLevel(60, false);
  if (!L.recruit()) throw new Error('招募失败');
  const e = new w.Game_Enemy(3, 0, 0), rows = [];
  for (const shield of [0, 12345, 9.6e6]) {
    for (const cast of [null, 0, 777]) {
      a._shield = shield; if (cast == null) delete a._codexLbCastShield; else a._codexLbCastShield = cast;
      for (const id of [10622, 10623, 10624]) rows.push({id, shield, cast, value: L.damage(a, e, id)});
    }
  }
  a._shield = 0; delete a._codexLbCastShield;
  const est = w.CodexAIEstimators.map(f => f(a, e, w.$dataSkills[10622], null, w.$dataSkills[10622].damage.formula)).filter(v => v !== undefined);
  return {mhp: a.mhp, atk: a.atk, agi: a.agi, rows, other: L.damage(w.$gameActors.actor(1), e, 10622), none: L.damage(null, e, 10622), est};
}));

// ⑤ 招募
cases.push(makeCase('recruit.locked', {level: 1}, () => {
  const a = fresh(); w.$gameSwitches.setValue(2494, false);
  return {first: L.recruit(), party: w.$gameParty._actors.slice()};
}));
cases.push(makeCase('recruit', {level: 1}, () => {
  const a = fresh();
  const first = L.recruit();
  return {first, again: L.recruit(), party: w.$gameParty._actors.slice(), weaponSlot: slotOf(a, w.$dataWeapons[WEAPON]),
    armorSlot: slotOf(a, w.$dataArmors[ARMOR]), weapon: worn(a, w.$dataWeapons[WEAPON]), armor: worn(a, w.$dataArmors[ARMOR]),
    skills: skills(a)};
}));

// ⑥ 战斗
function battle(level, rank, on, gear) {
  const a = fresh(); rankSet(a, rank); a.changeLevel(level, false);
  if (!L.recruit()) throw new Error('招募失败');
  if (!gear.weapon) a.changeEquip(slotOf(a, w.$dataWeapons[WEAPON]), null);
  if (!gear.armor) a.changeEquip(slotOf(a, w.$dataArmors[ARMOR]), null);
  if (on) setPassives(a, on);
  w.$gameParty.addActor(1);
  for (const b of w.$gameParty.allMembers()) b._paramPlus[0] = BIG_HP;
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  if (w.CodexYunshang) w.CodexYunshang._acted = [];
  for (const e of w.$gameTroop.members()) e._paramPlus[0] = BIG_HP;
  for (const b of [...w.$gameParty.allMembers(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  bm.startTurn();
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
}
function record(fn) {
  const log = [], old = w.Game_Action.prototype.executeHpDamage;
  w.Game_Action.prototype.executeHpDamage = function (target, value) {
    log.push({user: key(this.subject()), skill: this.item().id, target: key(target), value, critical: !!target.result().critical});
    return old.apply(this, arguments);
  };
  try { fn(); } finally { w.Game_Action.prototype.executeHpDamage = old; }
  return log;
}
// 必中、段数、天火要剑
cases.push(makeCase('battle.basics', {level: 60, rank: 2}, () => {
  const {bm, a, foes} = battle(60, 2, null, {weapon: true, armor: true});
  const act1 = new w.Game_Action(a); act1.setSkill(10622);
  const act2 = new w.Game_Action(a); act2.setSkill(10623);
  const out = {hit: [act1.itemHit(foes[0]), act2.itemHit(foes[0])], eva: [act1.itemEva(foes[0]), act2.itemEva(foes[0])],
    repeats: [act1.numRepeats(), act2.numRepeats()], meets: [a.meetsSkillConditions(w.$dataSkills[10622]), a.meetsSkillConditions(w.$dataSkills[10623])],
    canUse: [a.canUse(w.$dataSkills[10622]), a.canUse(w.$dataSkills[10623])]};
  setPassives(a, [P.guoZai, P.ziXian, P.chiRan, P.zhuiLuo, P.feiYing]);  // 忘掉星河
  const act3 = new w.Game_Action(a); act3.setSkill(10622); out.repeatsNoXingHe = act3.numRepeats();
  a.changeEquip(slotOf(a, w.$dataWeapons[WEAPON]), null);
  out.unarmed = {meets: a.meetsSkillConditions(w.$dataSkills[10622]), canUse: a.canUse(w.$dataSkills[10622])};
  bm.endBattle(0);
  return out;
}));
// 伤害钩子比值：每例一场新战斗，天火对 0 号敌人；记全部扣血段（Godot 一期只比第一段的比值）
const HOOKS = [
  ['base', [], {weapon: false, armor: false}],
  ['weapon', [], {weapon: true, armor: false}],
  ['armor', [], {weapon: false, armor: true}],
  ['ziXian', [P.ziXian], {weapon: false, armor: false}],
  ['chiRan', [P.chiRan], {weapon: false, armor: false}],
  ['zhuiLuo', [P.zhuiLuo], {weapon: false, armor: false}],
  ['changYe', [P.changYe], {weapon: false, armor: false}],
  ['xingHe', [P.xingHe], {weapon: false, armor: false}],
  ['all', [P.guoZai, P.ziXian, P.chiRan, P.zhuiLuo, P.xingHe, P.feiYing, P.changYe, P.mingTian], {weapon: true, armor: true}],
];
for (const [name, on, gear] of HOOKS) {
  cases.push(makeCase(`hook.${name}`, {level: 60, rank: 0, on, gear}, () => {
    const {bm, a, foes} = battle(60, 0, on, gear);
    if (!gear.weapon) {  // 天火要剑：换一把能装的、编号最小的剑（不是专武）
      const wt = w.$dataSkills[10622].requiredWtypeId1;
      const sword = w.$dataWeapons.find(x => x && x.wtypeId === wt && x.id !== WEAPON && a.canEquip(x));
      if (sword) a.forceChangeEquip(0, sword);
    }
    a.refresh();
    const stats = {mhp: a.mhp, atk: a.atk, agi: a.agi, shield: a.shield, weapon: (a.weapons()[0] || {}).id || 0};
    const log = record(() => act(bm, a, 10622, 0));
    bm.endBattle(0);
    return {stats, first: log[0] || null, count: log.length, log: log.slice(0, 12)};
  }));
}
// 燃烧第一段（二阶解锁），三敌
cases.push(makeCase('hook.ranshao', {level: 60, rank: 2}, () => {
  const {bm, a} = battle(60, 2, null, {weapon: true, armor: true});
  a.refresh();
  const log = record(() => act(bm, a, 10623, 0));
  bm.endBattle(0);
  return {first: log[0] || null, count: log.length};
}));
process.exit(finish(host, 'liuying.json', {hostScope: '真实 BattleManager／Game_Action（Math.random 0.5）；流萤第一期（v0.62.12）', cases}) ? 0 : 1);
