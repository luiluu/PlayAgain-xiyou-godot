'use strict';
// 【cc·悟空·未经审查】伤害／治疗时挂状态定向参照（PushState 一期）：dsPassiveSkill 被动缓存的 pushStates／recPushStates／pushSelfStates，
// 正式版由 installDamageElementRuntime 的 makeDamageValue 包装挂在 result._after，结算（onPreDamageStateEffects）时按 makeDamageValue 的正负挂：
// 正 → PushState 给目标、PushsubState 给自己；负 → RecPushState 给目标（不看阵营）；只认角色行动者；目标已有就不挂；Math.random()*100 < 概率。
// 用例：蔷薇刺鞭 1580（PushState0161 60%）／6510（100%）、先祖赐福 1491（PushsubState0042 20%）、4458（写成 100 不带 %）、4680（0.2% 小数认不出）、蔷薇进阶 6706（RecPushState1561 100%）；
// 掷中／没掷中、目标已有（看回合数有没有被重置）、治疗打友方／敌方、伤害时不挂治疗标签。
// 装备上的标签走同一个缓存（equips().concat(skills(), states())），但新局角色 1 穿不上带这类标签的武器（canEquip 假、会被卸下），这里只用技能量。
// 真实冻结插件、全内存新局；只写 .sandbox/pushstate.json，拷成 tests/fixtures/pushstate_oracle.json（不接入全量同步）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
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
const WATCH = [161, 42, 309, 742, 1561, 521, 1734];
const snap = b => ({states: WATCH.filter(id => b.isStateAffected(id)), turns: Object.fromEntries(WATCH.filter(id => b.isStateAffected(id)).map(id => [id, b._stateTurns[id]]))});
// cfg：skills 角色 1 学的被动、weapon 角色 1 武器、skill 行动技能（公式固定 1000、无浮动不暴击）、target 'enemy'|'ally'、rnd 掷骰、pre 目标先有的状态（回合定为 1）
function run(cfg) {
  newGame(); w.$gameSystem.setDifficultyId(2);
  const a = bare(1); for (const id of cfg.skills || []) a.learnSkill(id);
  // 装备：gainItem 后取背包里新生成的独立装备实例，changeEquip 到对应栏（新局角色 1 能穿 1706 无极西瓜刀、4966 纯美的赞诗）
  for (const [kind, id] of [['weapon', cfg.weapon], ['armor', cfg.armor]]) {
    if (!id) continue;
    const base = kind === 'weapon' ? w.$dataWeapons[id] : w.$dataArmors[id];
    w.$gameParty.gainItem(base, 1);
    const list = kind === 'weapon' ? w.$gameParty.weapons() : w.$gameParty.armors();
    const inst = list[list.length - 1];
    a.changeEquip(kind === 'weapon' ? 0 : a.equipSlots().indexOf(base.etypeId), inst);
  }
  settle(a); a.recoverAll();
  const ally = bare(8); settle(ally); ally.recoverAll(); ally.setHp(1);
  w.Math.random = () => 0.99; w.$gameTroop.setup(1); w.Math.random = () => 0.5;
  const foe = w.$gameTroop.members()[0]; foe.clearStates(); foe.refresh();
  const target = cfg.target === 'ally' ? ally : foe;
  for (const id of cfg.pre || []) { target.addState(id); target._stateTurns[id] = 1; }
  const item = w.$dataSkills[cfg.skill]; item.damage.formula = '1000'; item.damage.variance = 0; item.damage.critical = false;
  const act = new w.Game_Action(a); act.setSkill(cfg.skill);
  const before = {user: snap(a), target: snap(target)};
  w.Math.random = () => cfg.rnd;
  const value = act.makeDamageValue(target, false);
  const confirmed = act.onPreDamageStateEffects(target, value);
  if (cfg.react) act.onReactStateEffects(target, confirmed);
  w.Math.random = () => 0.5;
  return {value, confirmed, equips: a.equips().filter(Boolean).map(e => [e.baseItemId || e.id, e.name]), before, after: {user: snap(a), target: snap(target)},
    cache: {push: (a._passiveCache.pushStates || []).length, rec: (a._passiveCache.recPushStates || []).length, self: (a._passiveCache.pushSelfStates || []).length}};
}
// 时机：记 addState 与 React（onReactStateEffects）的先后——原版 _after 在结算 part() 里执行
function order(cfg) {
  const log = [], react = w.Game_Action.prototype.onReactStateEffects;
  const protos = [w.Game_Battler.prototype, w.Game_Actor.prototype, w.Game_Enemy.prototype].filter(p => Object.prototype.hasOwnProperty.call(p, 'addState'));
  const saved = protos.map(p => p.addState);
  protos.forEach((p, i) => { p.addState = function (id) { if (WATCH.includes(id)) log.push('add:' + id); return saved[i].apply(this, arguments); }; });
  w.Game_Action.prototype.onReactStateEffects = function () { log.push('react'); return react.apply(this, arguments); };
  try {
    const out = run(cfg);
    log.push('pre-done');
    return {log, out: out.after};
  } finally { protos.forEach((p, i) => { p.addState = saved[i]; }); w.Game_Action.prototype.onReactStateEffects = react; }
}
const CASES = [
  ['push.1580.hit', {skills: [1580], skill: 1, target: 'enemy', rnd: 0.5}],
  ['push.1580.miss', {skills: [1580], skill: 1, target: 'enemy', rnd: 0.7}],
  ['push.1580.already', {skills: [1580], skill: 1, target: 'enemy', rnd: 0.1, pre: [161]}],
  ['push.6510.hit', {skills: [6510], skill: 1, target: 'enemy', rnd: 0.99}],
  ['pushsub.1491.hit', {skills: [1491], skill: 1, target: 'enemy', rnd: 0.1}],
  ['pushsub.1491.miss', {skills: [1491], skill: 1, target: 'enemy', rnd: 0.3}],
  ['pushsub.4458.noPercent', {skills: [4458], skill: 1, target: 'enemy', rnd: 0.99}],   // <PushsubState0309: 100>：% 可省
  ['pushsub.4680.decimal', {skills: [4680], skill: 1, target: 'enemy', rnd: 0}],        // <PushsubState0742: 0.2%>：正则认不出小数，不进缓存
  ['rec.6706.ally', {skills: [6706], skill: 8, target: 'ally', rnd: 0.99}],
  ['rec.6706.enemy', {skills: [6706], skill: 8, target: 'enemy', rnd: 0.99}],
  ['rec.6706.damage', {skills: [6706], skill: 1, target: 'enemy', rnd: 0.1}],
  ['equip.1706.weapon', {weapon: 1706, skill: 1, target: 'enemy', rnd: 0.99}],          // 武器 <PushState0521: 100%>
  ['equip.4966.armor', {armor: 4966, skill: 8, target: 'ally', rnd: 0.99}],             // 防具 <RecPushState1734: 100%>
  ['rec.6706.already', {skills: [6706], skill: 8, target: 'ally', rnd: 0.1, pre: [1561]}],
];
const cases = CASES.map(([id, cfg]) => makeCase(id, cfg, () => run(cfg)));
cases.push(makeCase('order.1580', {skills: [1580], skill: 1, target: 'enemy', rnd: 0.1, react: true}, () => order({skills: [1580], skill: 1, target: 'enemy', rnd: 0.1, react: true})));
process.exitCode = finish(host, 'pushstate.json', {scope: 'PushState / RecPushState / PushsubState applied at settlement by sign of makeDamageValue', cases}) ? 0 : 1;
process.exit();
