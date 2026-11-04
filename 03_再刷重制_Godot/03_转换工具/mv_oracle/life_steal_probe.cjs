'use strict';
// 【cc·哪吒·未经审查】YEP_LifeSteal 技能吸血定向参照（steal1）：冻结数据里只有两种写法——技能 <HP Life Steal: N%>（112 个，全是伤害类型 1）与
// 状态 <DBHPLSteal: N%>（11 个，改过的插件把它当吸血量的乘数）；角色／职业／装备／状态层的 Rate／Flat／CUSTOM／GUARD／CANCEL 数据里一条都没用。
// 原版结算：Game_Action.executeHpDamage 包装（装在 YEP_DamageCore 之外、AbsorptionBarrier／ShieldSystem 之内），内层返回后读 target._result.hpDamage，
// >0 且没被 CANCEL／GUARD 就 subject.lifeSteal(damage,'hpPhysical|Magical|Certain',…)：floor(damage×(1-(1-rate)×…)) → 乘各状态 DBHPLSteal% → 角色额外掷 RecPushState → gainHp(floor)。
// 本探针量：吸多少（含浮点、DBHPLSteal 叠乘、不封顶＝溢出照吸再被 mhp 夹）、对谁（角色／敌人行动者）、什么时候（日志：gainHp／addState 与目标扣血、护盾、反击的先后）、
// 致死／护盾／miss／零伤害／反射／多段是否还吸、RecPushState 的掷骰与挂给谁。
// 全内存新局，只写 .sandbox/life_steal.json，拷成 tests/fixtures/life_steal_oracle.json（不接入全量同步）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');
const realmArray = values => { const out = w.eval('[]'); for (const v of values) out.push(v); return out; };
function bare(id) {
  const a = w.$gameActors.actor(id);
  a._skills = realmArray([]); a._states = realmArray([]); a._equips.forEach(x => x.setObject(null));
  a._paramPlus = realmArray([0, 0, 0, 0, 0, 0, 0, 0]);
  return a;
}
function settle(a) {
  a.need_refresh = true;
  a.need_refresh_param = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
  a.refresh(); if (a.initPassiveCache) a.initPassiveCache(); a.refreshPassiveCache();
}
const WATCH = [1561, 1734, 133, 410, 542, 614, 411, 962];
const LOGWIN = {push() {}, displayActionResults() {}, displayCounter() {}, displayReflection() {}, displaySubstitute() {}, displayAffectedStatus() {}};
function installLog(log, names) {
  const restore = [];
  const wrap = (proto, key, fn) => { if (Object.prototype.hasOwnProperty.call(proto, key)) { const old = proto[key]; proto[key] = fn(old); restore.push(() => { proto[key] = old; }); } };
  for (const proto of [w.Game_Battler.prototype, w.Game_Actor.prototype, w.Game_Enemy.prototype]) {
    wrap(proto, 'gainHp', old => function (v) { log.push('gainHp:' + names(this) + ':' + v); return old.apply(this, arguments); });
    wrap(proto, 'addState', old => function (id) { if (WATCH.includes(id)) log.push('addState:' + names(this) + ':' + id); return old.apply(this, arguments); });
  }
  wrap(w.Game_Action.prototype, 'executeHpDamage', old => function (t, v) { log.push('hpDamage>' + names(t) + ':' + v); const r = old.apply(this, arguments); log.push('hpDamage<' + names(t) + ':' + t.result().hpDamage); return r; });
  return () => restore.forEach(f => f());
}
// 把技能改成固定伤害 1000（无浮动不暴击），记下还原函数
function fixSkill(id, formula, hitType) {
  const s = w.$dataSkills[id], save = [s.damage.formula, s.damage.variance, s.damage.critical, s.hitType];
  s.damage.formula = formula || '1000'; s.damage.variance = 0; s.damage.critical = false;
  if (hitType !== undefined) s.hitType = hitType;
  return () => { s.damage.formula = save[0]; s.damage.variance = save[1]; s.damage.critical = save[2]; s.hitType = save[3]; };
}
function summary(b) {
  return {equips: b.equips ? b.equips().filter(x => x).map(x => (x.wtypeId !== undefined ? 'w' : 'a') + x.id) : [], hp: b.hp, mp: b.mp, mhp: b.mhp, states: WATCH.filter(id => b.isStateAffected(id)), resHp: b.result().hpDamage, resAff: b.result().hpAffected,
    stateIds: b.states().map(s => s.id).sort((x, y) => x - y)};
}
// cfg：user 'actor'|'enemy'、skill、formula、hitType、userStates、skills（角色额外学的）、weapon／armor（装备基础物品）、userHp、targetHp、targetStates、rnd、bareUser、invoke
function run(cfg) {
  newGame(); w.$gameSystem.setDifficultyId(2);
  const a = bare(1); for (const id of cfg.skills || []) a.learnSkill(id);
  for (const [kind, id] of [['weapon', cfg.weapon], ['armor', cfg.armor]]) {
    if (!id) continue;
    const base = kind === 'weapon' ? w.$dataWeapons[id] : w.$dataArmors[id];
    // 直接把基础物品塞进格子（跳过 canEquip：这些装备有等级门槛；吸血只读 equips() 的备注）
    const slot = kind === 'weapon' ? 0 : a.equipSlots().indexOf(base.etypeId);
    a.canEquip = () => true;  // 新局角色 1 穿不上有等级门槛的装备（refresh 会卸下）；吸血只读 equips() 的备注
    a._equips[slot].setObject(base);
    (cfg._put = cfg._put || []).push(() => a._equips[slot].setObject(base));  // refresh 会按等级门槛卸掉，settle 之后再塞一次
  }
  a._paramPlus[0] = cfg.mhpPlus === undefined ? 50000 : cfg.mhpPlus;
  settle(a); a.recoverAll(); for (const f of cfg._put || []) f(); delete cfg._put;
  const ally = bare(8); ally._paramPlus[0] = 50000; settle(ally); ally.recoverAll();
  w.Math.random = () => 0.99; w.$gameTroop.setup(cfg.troop || 1); w.Math.random = () => 0.5;
  const foe = w.$gameTroop.members()[0]; foe.clearStates(); foe.need_refresh = true; foe.refresh(); if (foe.refreshPassiveCache) foe.refreshPassiveCache();  // krz_state_re 的 need_refresh_lifesteal 等缓存开关只在 need_refresh 时才建（同 settle 对角色）
  const foe2 = w.$gameTroop.members()[1]; if (foe2) { foe2.need_refresh = true; foe2.refresh(); }
  const user = cfg.user === 'enemy' ? foe : a;
  const target = cfg.user === 'enemy' ? a : foe;
  for (const id of cfg.userStates || []) { user.addState(id); }
  for (const id of cfg.targetStates || []) { target.addState(id); }
  if (cfg.shield) { target._shieldValue = cfg.shield; }
  user.setHp(cfg.userHp === undefined ? 1 : typeof cfg.userHp === 'string' ? user.mhp + parseInt(cfg.userHp.slice(3)) : cfg.userHp);
  if (cfg.targetHp !== undefined) target.setHp(cfg.targetHp);
  const restoreSkill = fixSkill(cfg.skill, cfg.formula, cfg.hitType);
  const log = [], nameOf = b => b === a ? 'A' : b === ally ? 'B' : b === foe ? 'E' : b === foe2 ? 'E2' : '?';
  const restoreLog = installLog(log, nameOf);
  const act = new w.Game_Action(user); act.setSkill(cfg.skill);
  w.$gameParty._inBattle = true;
  w.BattleManager._subject = user; w.BattleManager._action = act; w.BattleManager._logWindow = LOGWIN;
  if (w.CodexYunshang && !w.CodexYunshang._acted) w.CodexYunshang._acted = w.eval('[]');
  const before = {user: summary(user), target: summary(target)};
  w.Math.random = () => cfg.rnd === undefined ? 0.5 : cfg.rnd;
  const targets = cfg.multi ? [target, foe2].filter(Boolean) : [target];
  if (cfg.invoke) { w.BattleManager.invokeAction(user, target); } else { for (const t of targets) act.apply(t); }
  w.Math.random = () => 0.5;
  const after = {user: summary(user), target: summary(target), target2: cfg.multi && foe2 ? summary(foe2) : null};
  const skillRow = w.$dataSkills[cfg.skill];
  restoreLog(); restoreSkill(); w.$gameParty._inBattle = false;
  return {skillNote: skillRow.note.split(/[\r\n]+/).filter(l => /STEAL/i.test(l)), hitType: cfg.hitType === undefined ? skillRow.hitType : cfg.hitType, before, after, log,
    userHpDelta: after.user.hp - before.user.hp, targetHpDelta: after.target.hp - before.target.hp};
}
// 代表技能：每个 (百分比, hitType) 挑最小号一个
const reps = (() => {
  const seen = new Map();
  for (let id = 1; id < w.$dataSkills.length; id++) {
    const s = w.$dataSkills[id]; if (!s) continue;
    const m = /<HP Life Steal: (\d+)%>/i.exec(s.note || ''); if (!m || s.damage.type !== 1) continue;
    const key = m[1] + ':' + s.hitType;
    if (!seen.has(key)) seen.set(key, id);
  }
  return [...seen.entries()].map(([k, id]) => ({pct: +k.split(':')[0], hit: +k.split(':')[1], id}));
})();
const CASES = [];
for (const r of reps) CASES.push([`rate.${r.pct}.hit${r.hit}.s${r.id}`, {skill: r.id, userHp: 1}]);
const S30 = reps.find(r => r.pct === 30).id, S1000 = reps.find(r => r.pct === 1000).id, S50 = reps.find(r => r.pct === 50).id;
const S10 = reps.find(r => r.pct === 10).id, S20 = reps.find(r => r.pct === 20).id;
// 浮点：多种伤害值（0.3×777 之类）
for (const f of ['1', '3', '7', '777', '1234', '99999', '0.5', '1.9', '12345.678']) CASES.push([`float.30.f${f}`, {skill: S30, formula: f}]);
for (const f of ['7', '777', '1234']) CASES.push([`float.10.f${f}`, {skill: S10, formula: f}], [`float.20.f${f}`, {skill: S20, formula: f}], [`float.50.f${f}`, {skill: S50, formula: f}]);
CASES.push(
  ['hp.full', {skill: S30, userHp: 'mhp+0'}],
  ['hp.overheal', {skill: S1000, userHp: 1, mhpPlus: 0}],     // 吸 10000 远超 mhp：不封顶、被 mhp 夹
  ['hp.nearFull', {skill: S30, userHp: 'mhp-5'}],
  ['state.72', {skill: S30, userStates: [72]}],
  ['state.380', {skill: S30, userStates: [380]}],
  ['state.628', {skill: S30, userStates: [628]}],
  ['state.2570', {skill: S30, userStates: [2570]}],
  ['state.2580', {skill: S30, userStates: [2580]}],
  ['state.72+2570', {skill: S30, userStates: [72, 2570]}],
  ['state.72+380', {skill: S30, userStates: [72, 380]}],
  ['state.72.f777', {skill: S30, userStates: [72], formula: '777'}],
  ['state.2570.f777', {skill: S30, userStates: [2570], formula: '777'}],
  ['state.72.f1', {skill: S30, userStates: [72], formula: '1'}],
  ['enemyUser', {skill: S30, user: 'enemy'}],
  ['enemyUser.state72', {skill: S30, user: 'enemy', userStates: [72]}],
  ['zero.damage', {skill: S30, formula: '0'}],
  ['neg.damage', {skill: S30, formula: '-500', userHp: 100}],
  ['overkill', {skill: S30, targetHp: 1}],
  ['kill.exact', {skill: S30, targetHp: 1000}],
  ['multi', {skill: S30, troop: 2, multi: true}],
  ['hit.certain', {skill: S30, hitType: 0}],
  ['hit.physical', {skill: S30, hitType: 1}],
  ['hit.magical', {skill: S30, hitType: 2}],
  // RecPushState：吸血时角色自己掷（Math.random()*100 < 概率）、挂给自己；敌人不掷
  ['rec.skill6706.hit', {skill: S30, skills: [6706], rnd: 0.5}],
  ['rec.skill6706.miss', {skill: S30, skills: [6706], rnd: 0.99}],
  ['rec.skill6706.rnd0', {skill: S30, skills: [6706], rnd: 0}],
  ['rec.skill5498.20', {skill: S30, skills: [5498], rnd: 0.1}],
  ['rec.skill5498.20.miss', {skill: S30, skills: [5498], rnd: 0.3}],
  ['rec.armor4966', {skill: S30, armor: 4966, rnd: 0.5}],
  ['rec.armor1702.50', {skill: S30, armor: 1702, rnd: 0.3}],
  ['rec.armor1702.50.miss', {skill: S30, armor: 1702, rnd: 0.7}],
  ['rec.weapon1675.5', {skill: S30, weapon: 1675, rnd: 0.04}],
  ['rec.weapon1616.50', {skill: S30, weapon: 1616, rnd: 0.3}],
  ['rec.two', {skill: S30, skills: [6706, 5498], rnd: 0.1}],
  ['rec.already', {skill: S30, skills: [6706], rnd: 0.1, userStates: [1561]}],
  ['rec.enemyNo', {skill: S30, user: 'enemy', rnd: 0}],
  ['rec.state72.zeroScale', {skill: S30, skills: [6706], userStates: [72], rnd: 0.1}],
  ['rec.dmgZero', {skill: S30, skills: [6706], formula: '0', rnd: 0}],
  ['rec.flat0', {skill: S30, skills: [6706], formula: '1', rnd: 0}],  // 吸到 floor(0.3)=0：<=0 就 return，不掷
  // 其余伤害层：护盾（ShieldSystem 账本）先吸收的伤害还吸不吸
  ['shield.partial', {skill: S30, shield: 400}],
  ['shield.full', {skill: S30, shield: 5000}],
  // 反射／反击／掩护：subject 是谁就谁吸
  ['invoke.counter', {skill: S30, user: 'enemy', invoke: true}]
);
const cases = CASES.map(([id, cfg]) => makeCase(id, cfg, () => run(cfg)));
process.exitCode = finish(host, 'life_steal.json', {scope: 'YEP_LifeSteal skill HP life steal (<HP Life Steal: N%>) + state DBHPLSteal scaling + RecPushState on steal', reps, cases}) ? 0 : 1;
process.exit();
