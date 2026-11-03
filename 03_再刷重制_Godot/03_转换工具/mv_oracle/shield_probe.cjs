'use strict';
// 护盾（ShieldSystem v2.8，冻结源参数 decayRate 0.20／damageReduction 0.5）与真气、来源护盾账本挂在同一条链上的原版表现：
// grant  加盾公式（5648／5651／5671／5672／5674）evalDamageFormula，受益者带 <ShieldEffect> 状态／装备、真气金身、已有护盾；
// read   读 a.shield 的伤害公式（5649／5650／5670／5673）；
// hit    Game_Action.executeHpDamage（盾小于／等于／大于伤害、小数盾、致死、治疗、0、吸取、真气护法）；
// gain   Game_Battler.gainHp（公式 b.gainHp、Establish 附加伤害走这里）；
// regen  Game_Battler.regenerateAll（再生／流血经护盾、maxSlipDamage、每回合衰减、倒下的也衰减）。
// 夹具同 formula_effect_probe：固定能力值、清空状态，特性对象只用 setup 写明的状态与装备；内存新局，只写 .sandbox/shield.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), w = host.w, cases = [];
w.eval('CodexZones.ENABLED=false;');  // 五乘区（CodexZones）重制不移植（O-044），探针宿主默认开着；关掉让参照不含成长修正（tools50 确认关与不关产物一致或已更新夹具）
host.newGame();
w.$gameParty._inBattle = true;
const SUBJECT = [12000, 500, 321, 456, 210, 789, 100, 100], TARGET = [10000, 1000, 100, 100, 100, 100, 100, 100];
const result = b => ({hpAffected: b.result().hpAffected, hpDamage: b.result().hpDamage, success: b.result().success});
const snap = b => ({hp: b.hp, mp: b.mp, tp: b.tp, shield: b.shield, rawShield: b._shield, dead: b.isDead(), result: result(b),
  bonus: b.shieldEffectBonus()});
const stub = new Proxy(function() {}, {get: (_t, k) => k === '_waitCount' ? 0 : (() => false), set: () => true});
function battlers(setup) {
  w.BattleManager.setup(157, true, false);
  w.BattleManager._logWindow = stub; w.BattleManager._spriteset = stub; w.BattleManager._statusWindow = stub;
  w.BattleManager.startBattle();
  const enemy = w.$gameTroop.members()[0];
  const a = setup.pair === 'enemy_actor' ? enemy : w.$gameActors.actor(1);
  const b = setup.pair === 'self' ? a : setup.pair === 'actor_enemy' ? enemy : w.$gameActors.actor(8);
  for (const [battler, params, side] of [[a, SUBJECT, 'a'], [b, TARGET, 'b']]) {
    if (side === 'b' && a === b) continue;
    battler.param = i => params[i];
    battler._states = new w.Array(); battler._stateTurns = {}; battler._buffs = new w.Array(8).fill(0); battler._buffTurns = new w.Array(8).fill(0);
    battler._hp = side === 'a' ? 12000 : 10000; battler._mp = 100; battler._tp = 55; battler._shield = 0;
    battler.clearResult(); battler._damagePopup = [];
    const f = setup[side] || {};
    // 特性对象：只有 setup 写明的状态（备注带 ShieldEffect）与装备
    const extra = (f.armors || []).map(id => w.$dataArmors[id]);
    battler.traitObjects = function() { return this.states().concat(extra); };
    for (const id of f.states || []) { battler._states.push(id); battler._stateTurns[id] = 3; }
    if (f.zhenqi) battler._codexZhenqi = {qi: 0, firsts: {}, realm: f.zhenqi.realm, pending: [], daofa: Object.fromEntries(f.zhenqi.daofa.map(k => [k, 1])), spec: {}};
    else if (battler.isActor()) delete battler._codexZhenqi;
    if (f.hp !== undefined) battler._hp = f.hp;
    if (f.dead) { battler._hp = 0; battler._states.push(1); battler._stateTurns[1] = 1; }
    if (f.shield !== undefined) battler._shield = f.shield;
    if (f.hrg !== undefined) battler.xparam = i => i === 7 ? f.hrg : 0;
    // krz_state_re 缓存 states()：换了状态要标记重算
    battler.need_refresh_states = true; battler.need_refresh = true;
  }
  return {a, b};
}
function measure(setup) {
  const {a, b} = battlers(setup);
  const action = new w.Game_Action(a);
  action.setSkill(setup.skill || 1);
  if (setup.drain) { const item = action.item(); const copy = {...item, damage: {...item.damage, type: 5}}; action.item = () => copy; }
  w.Math.random = () => 0.5;
  const before = {a: snap(a), b: snap(b)};
  let value = null;
  try {
    if (setup.kind === 'grant' || setup.kind === 'read') value = action.evalDamageFormula(b);
    else if (setup.kind === 'hit') action.executeHpDamage(b, setup.value);
    else if (setup.kind === 'gain') b.gainHp(setup.value);
    else if (setup.kind === 'regen') b.regenerateAll();
    return {value, before, after: {a: snap(a), b: snap(b)}};
  } finally {
    for (const battler of new Set([a, b])) for (const key of ['param', 'traitObjects', 'xparam']) delete battler[key];
    for (const battler of new Set([a, b])) if (battler.isActor()) delete battler._codexZhenqi;
  }
}
const add = (id, setup) => cases.push(makeCase(id, setup, () => measure(setup)));
// 加盾：受益者是 b（b.addShield）或 a（a.addShield，5671 只能自己）
const BONUS = {none: {}, s1177: {states: [1177]}, s1174_1177: {states: [1174, 1177]}, s1757_armor4546: {states: [1757], armors: [4546]},
  pre: {shield: 100.5}, jinshen3: {zhenqi: {realm: 3, daofa: ['jinshen']}}, jinshen5_s1179: {zhenqi: {realm: 5, daofa: ['jinshen']}, states: [1179]}};
for (const skill of [5648, 5651, 5672, 5674]) for (const [name, f] of Object.entries(BONUS)) add(`grant.${skill}.${name}`, {kind: 'grant', skill, pair: 'actors', b: f});
for (const [name, f] of Object.entries(BONUS)) add(`grant.5671.self.${name}`, {kind: 'grant', skill: 5671, pair: 'self', a: f});
add('grant.5671.other', {kind: 'grant', skill: 5671, pair: 'actors', a: {states: [1177]}, b: {shield: 7}});
// 读 a.shield
for (const skill of [5649, 5650, 5670, 5673]) for (const shield of [0, 1234.5, 98765]) add(`read.${skill}.${shield}`, {kind: 'read', skill, pair: 'actors', a: {shield}});
// executeHpDamage：敌人打角色 8
for (const [shield, value, hp] of [[0, 1000, 10000], [500, 1000, 10000], [1000, 1000, 10000], [1500.5, 1000, 10000], [500, 1001, 10000],
  [333.3, 1000, 10000], [500, 1000, 300], [100, 2000, 500], [500, -300, 5000], [500, 0, 5000], [0.4, 1, 5000]])
  add(`hit.${shield}_${value}_${hp}`, {kind: 'hit', pair: 'enemy_actor', value, b: {shield, hp}});
for (const [shield, value] of [[500, 1000], [1500, 1000]]) add(`hit.enemy.${shield}_${value}`, {kind: 'hit', pair: 'actor_enemy', value, b: {shield}});
for (const [shield, value, hp] of [[500, 1000, 600], [0, 1000, 600], [2000, 1000, 600]])
  add(`hit.drain.${shield}_${value}_${hp}`, {kind: 'hit', pair: 'enemy_actor', value, drain: true, b: {shield, hp}});
for (const shield of [0, 300, 900]) add(`hit.hufa4.${shield}`, {kind: 'hit', pair: 'enemy_actor', value: 1000, b: {shield, zhenqi: {realm: 4, daofa: ['hufa']}}});
// gainHp：角色走 krz_state_re 的 Game_Actor.gainHp（自有属性，盖过 ShieldSystem 的 gainHp 钩子），由 setHp 钩子吸收，结果槽记原值；敌人结果槽记减免后
for (const [shield, value] of [[500, -1000], [1000, -1000], [1500, -1000], [0, -1000], [500, 200], [250.5, -1000]])
  for (const pair of ['actors', 'actor_enemy']) add(`gain.${pair}.${shield}_${value}`, {kind: 'gain', pair, value, b: {shield}});
// regenerateAll
for (const [shield, hrg, hp, dead] of [[0, 0, 10000], [3, 0, 10000], [4, 0, 10000], [5, 0, 10000], [999, 0, 10000], [1500.5, 0, 10000],
  [500, -0.1, 10000], [1500, -0.1, 10000], [100, -0.1, 300], [5000, -0.1, 300], [200, 0.05, 9000], [1000, 0, 0, true]])
  for (const pair of ['actors', 'actor_enemy']) add(`regen.${pair}.${shield}_${hrg}_${hp}${dead ? '_dead' : ''}`, {kind: 'regen', pair, b: {shield, hrg, hp, dead: !!dead}});
process.exit(finish(host, 'shield.json', {plugin: w.PluginManager.parameters('ShieldSystem'), cases}) ? 0 : 1);
