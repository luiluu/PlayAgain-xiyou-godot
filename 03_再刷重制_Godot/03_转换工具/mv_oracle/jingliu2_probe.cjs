'use strict';
// 【cc·白龙_8·未经审查】170 镜流第二期（installNativeYomiJingliuRuntime.js 的 W.CodexJingliu 战斗包装）：
// ① 放血 payBlood（强化剑技第一次打到活着的敌人时：其余活着的出战队友各扣 min(floor(最大生命×3%／5%／8%), 生命−1)，
//    累计进 _codexJingliuBloodTotal，本次伤害 ×(1＋min(累计/(5×最大生命), 上限−1))，上限 1.25／1.5／1.8（学了 10202 为 2.5））；
// ② 追加段 supplemental（endAction 之前）：霜痕尽裂 10188 打有霜痕的主目标再追一段并去霜痕；碎月穿霜 10190 打有裂隙的主目标时
//    其余活着的敌人各追一段、主目标去裂隙；寒川映月 10192 对全部活着的敌人各追一段、主目标去裂隙；追加段用进阶行（学了 10200～10202 加成）；
// ③ 昙华绽放：10193 之后下一次 10192 ×1.0666（伤害钩子）；④ 裂隙演化：学了 10201 时 10189 给的裂隙让目标防御 ×0.89、寒冰抗性 +0.0111；
// ⑤ 追加行动：月魄从 <2 涨到 ≥2（每回合一次）、10192 真放了血且学了 10202（每回合一次）时，行动结束后插到 OTB 行动队首；
// ⑥ 读档 extractSaveContents：重新整理技能（进阶 ≥1 学 10200～10202）；⑦ 渡鸦穿逆祷异化武器时收割（审查第 14 期 P3）。
// 真实 BattleManager／Game_Action（Math.random 0.5）；只在内存，产物 .sandbox/jingliu2.json，拷成 tests/fixtures/jingliu2_oracle.json（不接入全量同步）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame, restore, encode} = host;
const J = w.CodexJingliu, R = w.CodexRaven, A = w.CodexAlienation;
if (!J || !R || !A) throw new Error('模块未安装');
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
const ACTOR = 170, BIG_HP = 1e12, TROOP = 3, FROST = 2628, GAP = 2629;
const key = b => !b ? null : b.isActor() ? 'a' + b.actorId() : 'e' + b.index();
const uncap = () => w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');

// 新局、镜流 level 级、进阶 rank、招募、给一把剑（编号 2）、再入队 1；全队生命加 1e12（队友 1 的生命另乘 allyRate）、敌群 3 生命加 1e12；开第一回合
function battle(level, rank, opts = {}) {
  newGame(); uncap();
  w.eval('$gameParty._actors=[];');
  const a = w.$gameActors.actor(ACTOR);
  a._AdvancedNum = rank;
  a.changeLevel(level, false);
  if (rank >= 1) for (const id of [10200, 10201, 10202]) a.learnSkill(id);  // 进阶后读档才会整理学到，这里直接学（同读档整理的结果）
  if (!J.recruit()) throw new Error('招募失败');
  a.forceChangeEquip(0, w.$dataWeapons[2]);
  w.$gameParty.addActor(1);
  for (const b of w.$gameParty.allMembers()) b._paramPlus[0] = BIG_HP;
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  w.CodexYunshang._acted = [];
  for (const e of w.$gameTroop.members()) e._paramPlus[0] = BIG_HP;
  for (const b of [...w.$gameParty.allMembers(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  if (opts.allyHp != null) { const one = w.$gameActors.actor(1); one._hp = opts.allyHp; }
  a._codexJingliuBloodTotal = 0;
  bm.startTurn();
  return {bm, a, foes: w.$gameTroop.members(), one: w.$gameActors.actor(1)};
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
    log.push({skill: this.item().id, target: key(target), value, extra: !!this._codexSupplemental});
    return old.apply(this, arguments);
  };
  try { fn(); } finally { w.Game_Action.prototype.executeHpDamage = old; }
  return log;
}
const queued = (bm, a) => (bm._actionBattlers || []).filter(b => b === a).length;
const snap = (bm, a, foes, one) => ({moon: J.moon(a), bloom: !!a._codexJingliuBloom, blood: a._codexJingliuBloodTotal || 0, allyHp: one.hp,
  frost: foes.map(e => e.isStateAffected(FROST)), gap: foes.map(e => e.isStateAffected(GAP)), def: foes.map(e => e.def), ice: foes.map(e => e.elementRate(3)),
  queued: queued(bm, a), moonExtra: !!a._codexJingliuMoonExtraUsed, bloodExtra: !!a._codexJingliuBloodExtraUsed});
const cast = (ctx, id, target = 0) => { const {bm, a, foes, one} = ctx; a.setMp(a.mmp); a.setTp(a.maxTp());
  const q0 = queued(bm, a); const log = record(() => act(bm, a, id, target)); return {cast: id, target, log, ...snap(bm, a, foes, one), queuedAdded: queued(bm, a) - q0}; };
const cases = [];

// 各强化剑技：先挂印记（10187 霜痕／10189 裂隙）再放；进阶 0 与 1（学了 10200～10202：进阶行加成、10192 放血上限 2.5 与 ×1.1）
const SCRIPTS = {
  frost: [[10187, 0], [10188, 0], [10188, 0]],
  gap: [[10189, 0], [10190, 0], [10190, 0]],
  river: [[10189, 0], [10192, 0], [10192, 1]],
  bloom: [[10193, 0], [10192, 0], [10192, 0]]
};
for (const rank of [0, 1]) for (const [name, script] of Object.entries(SCRIPTS)) {
  cases.push(makeCase(`seq.${name}.r${rank}`, {level: 60, rank, script}, () => {
    const ctx = battle(60, rank);
    const steps = [{start: true, ...snap(ctx.bm, ctx.a, ctx.foes, ctx.one)}];
    for (const [id, t] of script) { ctx.a._codexJingliuMoon = 3; steps.push(cast(ctx, id, t)); }
    return {skills: ctx.a._skills.filter(id => id >= 10187).sort((x, y) => x - y), mhp: ctx.a.mhp, allyMhp: ctx.one.mhp, steps};
  }));
}
// 放血扣不动（队友生命 1）：不加倍率、10192 不给放血追加行动
cases.push(makeCase('blood.empty.r1', {level: 60, rank: 1, allyHp: 1}, () => {
  const ctx = battle(60, 1, {allyHp: 1});
  ctx.a._codexJingliuMoon = 3;
  return {steps: [cast(ctx, 10192, 0)]};
}));
// 追加行动：月魄 1 → 10189 命中回 2（≥2）插队；同回合再从 1 回到 3 不再插；开新回合重置
cases.push(makeCase('extra.moon', {level: 60, rank: 0}, () => {
  const ctx = battle(60, 0);
  const steps = [];
  ctx.a._codexJingliuMoon = 0; steps.push(cast(ctx, 10189, 0));
  ctx.a._codexJingliuMoon = 1; steps.push(cast(ctx, 10189, 0));
  ctx.bm.endTurn(); ctx.bm.startTurn();
  steps.push({turn: true, ...snap(ctx.bm, ctx.a, ctx.foes, ctx.one)});
  ctx.a._codexJingliuMoon = 0; steps.push(cast(ctx, 10187, 1));
  ctx.bm.endBattle(0);
  steps.push({endBattle: true, ...snap(ctx.bm, ctx.a, ctx.foes, ctx.one)});
  return {steps};
}));
// 读档整理：进阶 1 的镜流存档读回来学到 10200～10202，放血累计清零；进阶 0 没有
for (const rank of [0, 1]) {
  cases.push(makeCase(`load.r${rank}`, {level: 30, rank}, () => {
    newGame(); uncap();
    const a = w.$gameActors.actor(ACTOR);
    a.changeLevel(30, false);
    a._AdvancedNum = rank;
    a._codexJingliuBloodTotal = 123;
    const before = a._skills.filter(id => id >= 10187).sort((x, y) => x - y);
    restore(encode());
    const b = w.$gameActors.actor(ACTOR);
    return {before, after: b._skills.filter(id => id >= 10187).sort((x, y) => x - y), blood: b._codexJingliuBloodTotal || 0};
  }));
}
// 渡鸦穿逆祷异化武器：狩猎中鸦啄的收割、神话回响（审查第 14 期 P3）
for (const [name, affix] of [['prayer', 'prayer'], ['plain', null]]) {
  cases.push(makeCase(`raven.${name}`, {affix}, () => {
    newGame(); uncap();
    w.$gameSwitches.setValue(2494, true);
    w.eval('$gameParty._actors=[];');
    const a = w.$gameActors.actor(167);
    a._AdvancedNum = 5; a._codexRavenStage = 5;
    a.changeLevel(60, false);
    R.recruit();
    w.$gameParty.addActor(1);
    // 本体：渡鸦能装、又能挂这个词条（A.create 不抛错且 A.ready）的编号最小的武器
    let base = null, item = null;
    for (const x of w.$dataWeapons) {
      if (!x || !a.canEquip(x)) continue;
      if (!affix) { base = x; item = x; break; }
      try { const made = A.create('w', x.id, 'boss', affix); if (A.ready(a, made)) { base = x; item = made; break; } } catch (e) { /* 不兼容，换下一件 */ }
    }
    if (!item) throw new Error('找不到渡鸦能装的逆祷本体');
    a._equips[0].setObject(item);
    for (const b of w.$gameParty.allMembers()) b._paramPlus[0] = BIG_HP;
    w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
    const bm = w.BattleManager; bm.setup(TROOP, false, false);
    bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
    for (const e of w.$gameTroop.members()) e._paramPlus[0] = BIG_HP;
    for (const b of [...w.$gameParty.allMembers(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
    A.lockParty();
    w.$gameParty._inBattle = true;
    w.CodexYunshang._acted = [];
    bm.startTurn();
    const e = w.$gameTroop.members()[0];
    const steps = [];
    for (const myth of [false, true]) {
      if (myth) { a.setMp(a.mmp); act(bm, a, 10127, a.index()); }
      a._codexRavenResidue = 3; a._codexRavenHunter = true; a.setMp(a.mmp);
      const hp0 = e.hp;
      const log = record(() => act(bm, a, 10122, 0));
      steps.push({myth, log, lost: hp0 - e.hp, hunter: !!a._codexRavenHunter, locked: a._alienBattle ? a._alienBattle.affix : null});
    }
    return {base: base.id, ready: affix ? A.ready(a, item) : null, steps};
  }));
}
process.exit(finish(host, 'jingliu2.json', {hostScope: '真实 BattleManager／Game_Action（Math.random 0.5）；镜流第二期、渡鸦逆祷', cases}) ? 0 : 1);
