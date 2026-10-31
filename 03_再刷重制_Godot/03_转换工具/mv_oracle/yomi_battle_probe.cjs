'use strict';
// 【Claude·白龙_5·未经审查】黄泉 169 战斗收尾（js/codex/runtime/installNativeYomiJingliuRuntime.js 的 CodexYomi 战斗包装）：
// ① itemHit／itemEva：黄泉 10171～10174 必中（1／0），对照角色 1 用同技能照常算；目标敌人带只含闪避特性的测试状态。
// ② numRepeats：(10174 为 6，其余 2)＋min(6, floor(幸运/6666))；对照角色 1 为 1。
// ③ 残梦：meetsSkillConditions 10174 要残梦≥9，paySkillCost 10174 扣 9；10171 不受影响。
// ④ 真实行动（敌群 3 三只、敌人血量极大）：10171～10174 × 学没学 10185；记每段 executeHpDamage 的目标、扩散倍率
//    （action._codexYomiSpreadRate）、伤害值与是否暴击，行动后各敌人的状态与残梦。
// ⑤ BattleManager.endBattle 清残梦。
// 真实 BattleManager／Game_Action，Math.random 0.5；只在内存，产物 .sandbox/yomi_battle.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const Y = w.CodexYomi;
if (!Y || typeof Y.dream !== 'function') throw new Error('黄泉模块未安装');
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
const BIG_HP = 1e12, TROOP = 3, LEVEL = 55, WEAPON = 11;
// 测试状态：复制中毒（4）的已解析字段，只留闪避特性（同 qiyu_probe）；Godot 按 setup.fake 建同形状态
const st = w.JsonEx.makeDeepCopy(w.$dataStates[4]), EVA = w.$dataStates.length;
Object.assign(st, {id: EVA, name: '测试·eva', traits: [{code: 22, dataId: 1, value: 1}], note: '', meta: {}, autoRemovalTiming: 0, iconIndex: 0});
for (const k of Object.keys(st.customEffectEval || {})) st.customEffectEval[k] = '';
w.$dataStates.push(st);

function battle(actorId, learn, luk) {
  newGame();
  w.eval('$gameParty._actors=[];');
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');  // 等级上限照 slice_probe 放开到 99
  w.$gameParty.addActor(actorId); w.$gameParty.addActor(1);
  for (const id of [actorId, 1]) {
    const a = w.$gameActors.actor(id); a.changeLevel(LEVEL, false); a._paramPlus[0] = BIG_HP; a.recoverAll();
  }
  const a = w.$gameActors.actor(actorId);
  for (const id of learn) a.learnSkill(id);
  if (luk) a._paramPlus[7] += luk;
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  w.CodexYunshang._acted = [];
  for (const e of w.$gameTroop.members()) e._paramPlus[0] = BIG_HP;
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
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
    log.push({target: key(target), spread: this._codexYomiSpreadRate || 0, value, critical: !!target.result().critical});
    return old.apply(this, arguments);
  };
  try { fn(); } finally { w.Game_Action.prototype.executeHpDamage = old; }
  return log;
}
const SKILLS = [10171, 10172, 10173, 10174];
const cases = [];
cases.push(makeCase('module', {}, () => ({mark: 2627, randomDebuffs: [22, 32, 37, 67, 75, 88]})));
// ① 命中／闪避
for (const id of [169, 1]) for (const skill of SKILLS) for (const states of [[], ['eva']]) {
  cases.push(makeCase(`rates.a${id}.s${skill}.${states.length ? 'eva' : 'plain'}`, {actor: id, skill, states, fake: {eva: {id: EVA, traits: st.traits}}}, () => {
    const {a, foes} = battle(id, SKILLS, 0);
    const t = foes[0]; for (const n of states) t.addState(EVA); t.refresh();
    const action = new w.Game_Action(a); action.setSkill(skill);
    return {hit: action.itemHit(t), eva: action.itemEva(t), targetEva: t.eva};
  }));
}
// ② 连击次数
for (const id of [169, 1]) for (const luk of [0, 20000, 60000]) for (const skill of [10171, 10174]) {
  cases.push(makeCase(`repeats.a${id}.s${skill}.luk${luk}`, {actor: id, skill, lukPlus: luk}, () => {
    const {a} = battle(id, SKILLS, luk);
    const action = new w.Game_Action(a); action.setSkill(skill);
    return {luk: a.luk, repeats: action.numRepeats()};
  }));
}
// ③ 残梦门槛与扣除
for (const dream of [0, 8, 9, 12]) {
  cases.push(makeCase(`dream.d${dream}`, {actor: 169, dream, weapon: WEAPON}, () => {
    const {a} = battle(169, SKILLS, 0);
    a._equips[0].setObject(w.$dataWeapons[WEAPON]); a.refresh();  // 技能要刀（武器类型 11），给 11 小太刀
    a._codexYomiDream = dream;
    const out = {dream: Y.dream(a), meets10174: a.meetsSkillConditions(w.$dataSkills[10174]), meets10171: a.meetsSkillConditions(w.$dataSkills[10171])};
    a.paySkillCost(w.$dataSkills[10171]); out.after10171 = Y.dream(a);
    a.paySkillCost(w.$dataSkills[10174]); out.after10174 = Y.dream(a);
    return out;
  }));
}
// ④ 真实行动
for (const skill of SKILLS) for (const pass of [false, true]) {
  const learn = SKILLS.concat(pass ? [10185] : []);
  cases.push(makeCase(`act.s${skill}.${pass ? 'p10185' : 'plain'}`, {actor: 169, skill, learn, troop: TROOP, level: LEVEL, dream: skill === 10174 ? 9 : 0}, () => {
    const {bm, a, foes} = battle(169, learn, 0);
    a._codexYomiDream = skill === 10174 ? 9 : 0;
    const log = record(() => act(bm, a, skill, 0));
    return {log, dream: Y.dream(a), luk: a.luk, states: foes.map(e => e._states.slice().sort((x, y) => x - y)),
      debuffs: foes.map(e => Y.debuffCount(e))};
  }));
}
// ⑤ 战斗结束清残梦
cases.push(makeCase('end', {actor: 169, dream: 7}, () => {
  const {bm, a} = battle(169, SKILLS, 0);
  a._codexYomiDream = 7;
  bm.endBattle(0);
  return {dream: Y.dream(a)};
}));
process.exit(finish(host, 'yomi_battle.json', {hostScope: '真实 BattleManager／Game_Action（Math.random 0.5）；黄泉战斗包装', cases}) ? 0 : 1);
