'use strict';
// 【cc·白龙·未经审查】沙僧二审 S2-1-03：云裳 Game_Action.apply 包装（modules.json 第 31 个）包在黄泉（9）、甚尔（10）、宿傩（18）、饿狼（19）外层，
// 所以这三人的专属技能照样走云裳那一层：命中后觉醒引爆符针一根（_yunTotal 由 executeHpDamage 包装累计）、天衣命中效果。
// 每例：云裳 45 级进阶 1 先对敌人 1 种针（钉影 10270），唤醒穿天衣（9 号）的专属角色，专属角色对敌人 1 放专属技能两次，
// 每步记 executeHpDamage（出手者、技能、目标、生命伤害、暴击）与各敌人剩余针数。
// 真实 BattleManager／Game_Action（Math.random 0.5），关五乘区；只在内存，产物 .sandbox/yunshang_wraps.json，拷成 tests/fixtures/yunshang_wraps_oracle.json（不接入全量同步）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const Y = w.CodexYunshang;
if (!Y || typeof Y.wake !== 'function') throw new Error('云裳模块未安装');
w.eval('CodexZones.ENABLED=false;');
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
if (!w.$) w.$ = {};
w.$.toaster = () => {};
const ACTOR = 174, ROBE = 7929, TROOP = 3, BIG_HP = 1e18;
const key = b => !b ? null : b.isActor() ? 'a' + b.actorId() : 'e' + b.index();

// 云裳 45 级进阶 1 第一位、专属角色 x 55 级第二位穿天衣 9（寸光留仙，命中不带效果）；开 2494；敌人生命加 1e18；startBattle＋startTurn
function battle(x, learn) {
  newGame();
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.$gameSwitches.setValue(2494, true);
  const a = w.$gameActors.actor(ACTOR);
  a._AdvancedNum = 1; a.changeLevel(45, false);
  w.$gameParty.addActor(ACTOR); w.$gameParty.addActor(x);
  for (const list of [w.$gameParty._actors, w.$gameParty._battleMembers]) {
    for (const id of [x, ACTOR]) { const i = list.indexOf(id); if (i >= 0) list.splice(i, 1); }
    list.unshift(ACTOR, x);
  }
  const b = w.$gameActors.actor(x);
  b.changeLevel(55, false);
  for (const id of learn) b.learnSkill(id);
  if (w.CodexSukuna && x === 172) w.CodexSukuna.sync(b);
  w.$gameParty.gainItem(w.$dataArmors[ROBE], 1, false);
  const gear = w.$gameParty.armors().filter(i => (i.baseItemId || i.id) === ROBE).slice(-1)[0];
  b.forceChangeEquip(b.equipSlots().indexOf(4), gear);
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  Y._acted = [];
  for (const e of w.$gameTroop.members()) e._paramPlus[0] = BIG_HP;
  for (const m of [...w.$gameParty.allMembers(), ...w.$gameTroop.members()]) { m.need_refresh = true; m.refresh(); m.recoverAll(); }
  bm.startBattle();
  bm.startTurn();
  return {bm, a, b, party: w.$gameParty.battleMembers().map(m => m.actorId())};
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
  bm._phase = 'turn';
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
const needles = () => w.$gameTroop.members().map(e => (e._yunNeedles || []).length);
const cast = (bm, u, id, target) => { u.setMp(u.mmp); u.setTp(u.maxTp()); u.clearCooldowns && u.clearCooldowns(); return {cast: id, user: key(u), log: record(() => act(bm, u, id, target))}; };
const cases = [];
// 黄泉 169 断罪（10172，溅射 0.33）、宿傩 172 解（10230，冲击＋斩两段）、甚尔 171 万里锁（10217，溅射 0.33，子行动）
for (const [name, x, skill, learn] of [['yomi', 169, 10172, [10171, 10172, 10173, 10174]], ['sukuna', 172, 10230, []], ['toji', 171, 10217, []]]) {
  for (const woke of [true, false]) {
    cases.push(makeCase(`${name}${woke ? '' : '.asleep'}`, {actor: x, skill, learn, robe: ROBE, woke}, () => {
      const {bm, a, b, party} = battle(x, learn);
      const steps = [{start: true, needles: needles(), awake: !!Y.awake(b), cri: b.cri, luk: b.luk, skills: b._skills.slice().sort((p, q) => p - q)}];
      steps.push({...cast(bm, a, 10270, 1), needles: needles(), awake: !!Y.awake(b)});
      if (woke) Y.wake(b); else Y.data(b).wakeUntil = 0;  // 开战神纹自鸣可能已唤醒（进阶 1），没醒的例清掉
      steps.push({wake: woke, needles: needles(), awake: !!Y.awake(b)});
      for (let i = 0; i < 2; i++) steps.push({...cast(bm, b, skill, 1), needles: needles(), awake: !!Y.awake(b)});
      bm.endBattle(0);
      return {party, steps};
    }));
  }
}
process.exit(finish(host, 'yunshang_wraps.json', {hostScope: '真实 BattleManager／Game_Action（Math.random 0.5），关五乘区；云裳包装在黄泉／甚尔／宿傩外层', cases}) ? 0 : 1);
