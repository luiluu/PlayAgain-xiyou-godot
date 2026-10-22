'use strict';
// 琦玉专属模块（js/codex/runtime/installQiyuDimensionRuntime.js，CodexQiyuBalance）：新游戏里真正生效的部分。
// ① 163 用技能（DataManager.isSkill，物品不算）时 itemHit=1、itemEva／itemCnt／itemMrf=0：必中、不被反击、不被魔法反射；
//    对照 164 贝吉特（同为导入角色、无此模块）与 162 诛仙（50 级起有 dsPassiveSkill 全局必中被动，物品也必中）。目标敌人带只含给定特性的测试状态（eva 22/1、cnt 22/6、mrf 22/5＝1）。
// ② Game_Actor.addState：163 加 2626 直接返回（数据里没有任何东西加 2626，只防旧档）。
// ③ 新生成的法宝 124「一拳」实例（registerNewItem／gainIndependentItem 都会过 normalizeRelic）：实测特性、每级成长、SkillPass
//    与数据库原件一致（只打修订标记），装给 163 后量能力值。旧档迁移（Q.sync，读档时去 10264、学 10169）不在新游戏范围，不测。
// 真实 BattleManager／Game_Action，Math.random 0.5；只在内存，产物 .sandbox/qiyu.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const Q = w.CodexQiyuBalance;
if (!Q || Q.actorId !== 163) throw new Error('琦玉模块未安装');
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
const BIG_HP = 1e12;
// 测试状态：复制中毒（4）的已解析字段，特性只留给定的，自定义效果清空（同 imported_balance_probe）；Godot 按 setup.fake 建同形状态
const FAKE = {};
for (const [name, traits] of [['eva', [{code: 22, dataId: 1, value: 1}]], ['cnt', [{code: 22, dataId: 6, value: 1}]],
  ['mrf', [{code: 22, dataId: 5, value: 1}]]]) {
  const st = w.JsonEx.makeDeepCopy(w.$dataStates[4]);
  FAKE[name] = w.$dataStates.length;
  Object.assign(st, {id: FAKE[name], name: '测试·' + name, traits, note: '', meta: {}, autoRemovalTiming: 0, iconIndex: 0});
  for (const k of Object.keys(st.customEffectEval || {})) st.customEffectEval[k] = '';
  w.$dataStates.push(st);
}
const fakeSetup = names => Object.fromEntries(names.map(n => [n, {id: FAKE[n], traits: w.$dataStates[FAKE[n]].traits}]));
// 测试物品：复制物品 1 的已解析字段，改成物理伤害（命中类型 1、单体敌人、公式 100）
const ITEM = w.$dataItems.length;
w.$dataItems.push(Object.assign(w.JsonEx.makeDeepCopy(w.$dataItems[1]), {id: ITEM, name: '测试·物理物品', scope: 1, hitType: 1,
  occasion: 0, consumable: false, effects: [], damage: {type: 1, formula: '100', elementId: 0, variance: 0, critical: false}}));

function battle(actorId, troop, states) {
  newGame();
  w.eval('$gameParty._actors=[];');
  w.$gameParty.addActor(actorId); w.$gameParty.addActor(1);
  for (const id of [actorId, 1]) {
    const a = w.$gameActors.actor(id); a.changeLevel(50, false); a._paramPlus[0] = BIG_HP; a.recoverAll();
  }
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(troop, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  w.CodexYunshang._acted = [];
  for (const e of w.$gameTroop.members()) e._paramPlus[0] = BIG_HP;
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  const foes = w.$gameTroop.members();
  // 测试状态加给全部敌人（9934 是随机两个敌人，目标不固定）
  for (const e of foes) { for (const n of states) e.addState(FAKE[n]); e.need_refresh = true; e.refresh(); }
  return {bm, a: w.$gameActors.actor(actorId), ally: w.$gameActors.actor(1), foes};
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
// 记 executeHpDamage 的（行动者，目标）：反射时目标是行动者自己，反击时行动者是敌人
function record(fn) {
  const log = [], old = w.Game_Action.prototype.executeHpDamage;
  w.Game_Action.prototype.executeHpDamage = function (target, value) {
    log.push({subject: key(this.subject()), target: key(target), item: this.item().id, isSkill: this.isSkill()});
    return old.apply(this, arguments);
  };
  try { fn(); } finally { w.Game_Action.prototype.executeHpDamage = old; }
  return log;
}
const cases = [];
const ACTORS = [163, 164, 162];
const SKILLS = [1, 9934, 9938, 9939];
cases.push(makeCase('module', {}, () => ({actorId: Q.actorId, armorId: Q.armorId, revision: Q.revision})));
// ① 四个比率：技能与测试物品，目标无状态／带全部三种测试状态
for (const id of ACTORS) {
  for (const states of [[], ['eva', 'cnt', 'mrf']]) {
    for (const [kind, itemId] of [...SKILLS.map(s => ['skill', s]), ['item', ITEM]]) {
      cases.push(makeCase(`rates.a${id}.${kind}${itemId}.${states.length ? 'all' : 'plain'}`,
        {actor: id, troop: 2, kind, item: itemId, states, fake: fakeSetup(states),
          itemData: kind === 'item' ? {hitType: 1, scope: 1, damage: w.$dataItems[ITEM].damage} : null}, () => {
          const {a, foes} = battle(id, 2, states);
          const action = new w.Game_Action(a);
          if (kind === 'skill') action.setSkill(itemId); else action.setItem(itemId);
          const t = foes[0];
          return {hit: action.itemHit(t), eva: action.itemEva(t), cnt: action.itemCnt(t), mrf: action.itemMrf(t),
            isPhysical: action.isPhysical(), isMagical: action.isMagical(), targetEva: t.eva, targetCnt: t.cnt, targetMrf: t.mrf};
        }));
    }
  }
}
// ① 真实行动：普攻（魔法）打魔法反射敌人、普通一拳 9934（物理）打反击敌人
for (const id of ACTORS) {
  for (const [skill, state] of [[1, 'mrf'], [9934, 'cnt'], [9938, 'cnt']]) {
    cases.push(makeCase(`invoke.a${id}.s${skill}.${state}`, {actor: id, troop: 2, skill, states: [state], fake: fakeSetup([state])}, () => {
      const {bm, a, foes} = battle(id, 2, [state]); a.learnSkill(skill);
      const log = record(() => act(bm, a, skill, 0));
      return {log, reflected: log.some(r => r.subject === key(a) && r.target === key(a)),
        countered: log.some(r => r.subject !== null && r.subject.startsWith('e') && r.target === key(a)),
        hitFoe: log.some(r => r.subject === key(a) && r.target && r.target.startsWith('e'))};
    }));
  }
}
// ② 2626
for (const id of ACTORS) {
  cases.push(makeCase(`state2626.a${id}`, {actor: id, state: 2626}, () => {
    newGame(); const a = w.$gameActors.actor(id); a.addState(2626);
    return {affected: a.isStateAffected(2626), states: a._states.slice()};
  }));
}
// ③ 新生成的法宝 124（招募公共事件 2523 用的就是 gainItem），装给 163（等级 30），法宝 1 级与 5 级
cases.push(makeCase('relic124', {actor: 163, armor: 124, level: 30, relicLevels: [null, 5]}, () => {
  newGame();
  const before = w.$gameParty.equipItems().slice();
  w.$gameParty.gainItem(w.$dataArmors[124], 1);
  const it = w.$gameParty.equipItems().find(x => before.indexOf(x) < 0);
  if (!it) throw new Error('未生成法宝 124');
  const db = w.$dataArmors[124], J = o => w.JSON.parse(w.JSON.stringify(o));
  const skillPass = o => Object.keys(o.meta).filter(k => k.startsWith('SkillPass')).sort().map(k => [k, o.meta[k]]);
  const inst = {base: it.baseItemId, revision: it._codexQiyuBalanceRevision, traits: J(it.traits), params: Array.from(it.params),
    perLevel: Array.from(it.paramPlusPerLevel || []), skillPass: skillPass(it), noteSameAsDb: it.note.trim() === db.note.trim()};
  const dbRow = {traits: J(db.traits), perLevel: Array.from(db.paramPlusPerLevel || []), skillPass: skillPass(db)};
  w.$gameActors._data[163] = null;
  const a = w.$gameActors.actor(163); a.changeLevel(30, false);
  const slot = a.equipSlots().indexOf(it.etypeId);
  a.changeEquip(slot, it);
  if (a.equips()[slot] !== it) throw new Error('163 没装上法宝 124');
  const rows = [];
  for (const lv of [null, 5]) {
    if (lv != null) it.level = lv;
    Q.refreshActor(a);
    rows.push({setLevel: lv, level: it.level, paramPlus: Array.from({length: 8}, (_, i) => a.paramPlus(i)),
      params: Array.from({length: 8}, (_, i) => a.param(i))});
  }
  return {inst, db: dbRow, slot, rows};
}));
process.exit(finish(host, 'qiyu.json', {hostScope: '真实 BattleManager／Game_Action（Math.random 0.5）；琦玉模块新游戏生效部分', cases}) ? 0 : 1);
