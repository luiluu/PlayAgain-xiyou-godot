'use strict';
// 武器解放参照（YEP_WeaponUnleash processUnleash／switchUnleashSkill）：普攻行动在 BattleManager.startAction 里按几率换成别的技能。
// 正式数据只有武器上的 <Weapon Unleash x%: id>（没有 Guard Unleash、加成、自定义）。
// 每例新局、摆好角色（卸下全部装备、装武器、设 TP），BattleManager.setup 一场，角色行动摆好后走真实 startAction 链
// （MOG 连击 → SkillChangeTo → OTB → BuffsStatesCore 行动开始 → WUL processUnleash），只把 WUL 之后的 BEC startAction 换成记录。
// Math.random 换成磁带（见 tape）。记：attackSkillId、每条解放的 canUse、取数次数、最后行动的技能。
// 只在内存；产物 .sandbox/weapon_unleash.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const cases = [];
// 等级上限（YEP_CoreEngine Max Level 10，进度里再提；重制 XState.actor_max_level）提到 99，需求等级高的武器才装得上
for (const x of w.$dataActors) if (x) x.maxLevel = 99;

function bare(a) { a._equips.forEach((e, n) => { if (e.object()) a.forceChangeEquip(n, null); }); }
// 武器的 <req_level:N>（zbxz）：角色先升到这一级（changeLevel，按职业学技能）才装得上
const reqLevel = weaponId => Math.max(1, Number((w.$dataWeapons[weaponId].meta || {}).req_level) || 1);
// 第一个升到需求等级后能装上这把武器（refresh 后仍在手上）、能行动（导入平衡不禁用）的角色
function equipper(weaponId) {
  newGame(); w.$gameParty._inBattle = true;
  const wp = w.$dataWeapons[weaponId];
  for (let id = 1; id < w.$dataActors.length; id++) {
    if (!w.$dataActors[id] || !w.$dataActors[id].name) continue;
    const a = w.$gameActors.actor(id);
    if (!a) continue;
    if (a.level < reqLevel(weaponId)) a.changeLevel(reqLevel(weaponId), false);
    if (!a.canEquip(wp)) continue;
    bare(a); a.forceChangeEquip(0, wp); a.refresh();
    if (a.weapons().some(x => x.id === weaponId) && a.canMove()) return id;
  }
  return 0;
}
// 只有 switchUnleashSkill 里的取数吃磁带（磁带用完报错）；别的包装（行动开始时另有取数）回 0.5，另计次数
function tape(values) {
  const used = [], other = [];
  w.Math.random = function() {
    if (!/switchUnleashSkill/.test(new Error().stack)) { other.push(1); return 0.5; }
    if (used.length >= values.length) throw new Error('随机磁带用完');
    used.push(values[used.length]); return values[used.length - 1];
  };
  return {used, other};
}
function battle(actorId) {
  newGame();
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  w.eval('$gameParty._actors=[];');
  w.$gameParty.addActor(actorId);
  const bm = w.BattleManager; bm.setup(1, false, false);
  const stub = new Proxy(function() {}, {get: (o, k) => k === 'then' ? undefined : (() => stub), apply: () => stub});
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  if (w.CodexYunshang) w.CodexYunshang._acted = [];
  return bm;
}
// spec: {weapon, actor?, tp, rolls:[...], act: 'attack'|'skill1'|<技能号>|'item1'}
function unleashCase(name, spec) {
  cases.push(makeCase(name, spec, () => {
    const actorId = spec.actor || EQUIPPER[spec.weapon];
    if (!actorId) throw new Error('没有能装备的角色 ' + spec.weapon);
    const bm = battle(actorId), a = w.$gameActors.actor(actorId);
    const level = spec.weapon ? reqLevel(spec.weapon) : 1;
    if (a.level < level) a.changeLevel(level, false);
    bare(a);
    if (spec.weapon) a.forceChangeEquip(0, w.$dataWeapons[spec.weapon]);
    a.refresh();
    a.setTp(spec.tp || 0);
    const act = new w.Game_Action(a);
    if (spec.act === 'item1') act.setItem(1);
    else if (spec.act === 'skill1') act.setSkill(1);
    else if (typeof spec.act === 'number') act.setSkill(spec.act);
    else act.setAttack();
    act.setTarget(0);
    a._actions = [act];
    const unleashes = a.weaponUnleashes().map(u => ({skill: u[0], rate: u[1], canUse: a.canUse(w.$dataSkills[u[0]])}));
    const before = act.item().id, attackSkillId = a.attackSkillId();
    const started = [], real = w.Yanfly.WUL.BattleManager_startAction;
    w.Yanfly.WUL.BattleManager_startAction = function() {
      const it = this._subject.currentAction() && this._subject.currentAction().item(); started.push(it ? it.id : 0);
    };
    bm._subject = a; bm._action = null;
    const t = tape(spec.rolls || []);
    try { bm.startAction(); } finally { w.Yanfly.WUL.BattleManager_startAction = real; w.Math.random = function() { return 0.5; }; }
    return {actor: actorId, level: a.level, equips: a.equips().map(e => e ? e.id : 0), tp: a.tp, attackSkillId, canAttack: a.canAttack(), unleashes,
      before, isItem: act.isItem(), started, rolls: t.used.length, otherRolls: t.other.length};
  }));
}

// 先在任何战斗之前挑好角色（与战斗状态无关）
const WEAPONS = [77, 83, 93, 207, 392, 393, 405, 412, 429, 680, 744, 1062, 1388, 1504, 1505, 1508, 1887];
const EQUIPPER = {};
for (const id of WEAPONS) EQUIPPER[id] = equipper(id);
// 78 戮仙剑原版谁都装不上（refresh 卸下，见 attack_query 154-weapon78-unequippable），不列。
// 每把：掷 0 必中第一条能用的；掷 0.999999 都不中（100% 仍中）；TP 0 与 100 两档（497／792／5636 要 TP）
for (const id of WEAPONS) for (const tp of [0, 100]) {
  unleashCase(`w${id}.tp${tp}.hit`, {weapon: id, tp, rolls: [0, 0, 0]});
  unleashCase(`w${id}.tp${tp}.miss`, {weapon: id, tp, rolls: [0.999999, 0.999999, 0.999999]});
}
// 边界：掷数恰等于几率算中（Math.random() > rate 才跳过），略大一点不中
for (const id of [207, 429, 744, 1505, 1062]) {
  const rate = w.$dataWeapons[id].weaponUnleash[0][1];   // 解析后的几率（x×0.01）
  unleashCase(`w${id}.edge-eq`, {weapon: id, tp: 100, rolls: [rate], rate});
  unleashCase(`w${id}.edge-over`, {weapon: id, tp: 100, rolls: [rate + 1e-9], rate});
}
// 多条按顺序各掷一次，第一条中的为准
unleashCase('w680.second', {weapon: 680, tp: 100, rolls: [0.7, 0.3]});
unleashCase('w680.third', {weapon: 680, tp: 100, rolls: [0.7, 0.5, 0.1]});
unleashCase('w680.third-tp0', {weapon: 680, tp: 0, rolls: [0.7, 0.5, 0.1]});   // 497 要 1 TP：跳过不掷
unleashCase('w405.second', {weapon: 405, tp: 100, rolls: [0.5, 0.3]});
// 不是此刻的攻击就不换：替换攻击的武器拿技能 1、直接放解放技能、用物品；空手
unleashCase('w429.skill1', {weapon: 429, tp: 100, rolls: [0, 0], act: 'skill1'});
unleashCase('w207.skill127', {weapon: 207, tp: 100, rolls: [0], act: 127});
unleashCase('w207.item1', {weapon: 207, tp: 100, rolls: [0], act: 'item1'});
unleashCase('bare.attack', {actor: 1, weapon: 0, tp: 100, rolls: [0]});

process.exit(finish(host, 'weapon_unleash.json', {cases}) ? 0 : 1);
