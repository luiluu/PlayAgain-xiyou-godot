'use strict';
// 异化战斗参照（installAlienationRuntime 的战斗侧：Game_Troop.setup 的遭遇、Game_Enemy.param／name、startBattle 锁队与蜕壳护盾、
// startTurn 镜骸充能、endTurn 蚀能与腐蚀、startAction／apply／executeHpDamage／endAction 的行动根（烈变与小怪增伤、灾疫腐蚀、镜骸反噬）、
// 胜利发放 grant）。词条效果（installAlienationAffixes／Advanced）不在本参照。
// ① config：bossSources／mobSources／transition 与五种变体（Godot alienation.json 照抄，专项核对）。
// ② encounter.*：$gameMap 设地图、未知存在来源，Game_Troop.setup 后再用排好的 Math.random 序列调一次 A.setupEncounter（序列用完取 0.5），
//    记遭遇结果、各敌人名字与最大生命、取随机数的次数。
// ③ battle.*：A.setupEncounter(force) 指定变体，敌群 2，敌人生命加 1e12；真实 BattleManager 跑行动（同 race_battle_probe 的 act），
//    回合开始照抄 startTurn 包装的镜骸充能，回合末调 A.drain 与 A.tickCorrosion；每步记双方生命、法力、护盾、腐蚀状态与回合、敌人的 _alienEnemy、提示。
// 新游戏（Math.random 0.5），只在内存；产物 .sandbox/alien_battle.json。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const A = w.CodexAlienation, C = A && A.config;
if (!A || !C) throw new Error('异化模块未安装');
const r = v => round(v);
const J = x => JSON.parse(JSON.stringify(x));
const toasts = [];
w.$.toaster = o => toasts.push(String(o && o.message));
// 新局队伍是 1／8／9／10：只留指定的人
function party(ids) { w.$gameParty.members().map(x => x.actorId()).forEach(id => { if (ids.indexOf(id) < 0) w.$gameParty.removeActor(id); }); ids.forEach(id => w.$gameParty.addActor(id)); }
function uncap() { w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });'); }
const cases = [];

// ① 配置
const config = {bossSources: J(C.bossSources), mobSources: J(C.mobSources), transition: J(C.transition),
  variants: A.variants.map(v => ({key: v.key, name: v.name, description: v.description}))};

// ② 遭遇
let draws = 0;
function script(seq) { let i = 0; draws = 0; w.Math.random = function () { draws++; return i < seq.length ? seq[i++] : 0.5; }; }
function enc() {
  const x = A.encounter(); if (!x) return null;
  const m = A.mark(x.reward);
  return {enemyIndex: w.$gameTroop.members().indexOf(x.enemy), variant: x.variant.key, boss: x.enemy._alienEnemy.boss, probability: x.probability,
    reward: {kind: A.kind(x.reward), baseId: A.baseId(x.reward), origin: m.origin, affix: m.affix, uid: m.uid, plainName: m.plainName}};
}
function encounterCase(name, spec) {
  cases.push(makeCase('encounter.' + name, spec, () => {
    newGame(); uncap();
    w.$gameMap._mapId = spec.map;
    if (spec.origin != null) w.$gameMap._codexLeviathanUnknownOrigin = spec.origin; else delete w.$gameMap._codexLeviathanUnknownOrigin;
    w.$gameTroop.setup(spec.troop);
    const sequence = A.ledger().sequence;
    script(spec.random || []);
    A.setupEncounter();
    const n = draws;
    w.Math.random = function () { return 0.5; };
    return {encounter: enc(), draws: n, sequenceGain: A.ledger().sequence - sequence,
      enemies: w.$gameTroop.members().map(e => ({id: e.enemyId(), name: e.name(), mhp: e.mhp, hp: e.hp, boss: !!(w.CodexBossDifficulty && w.CodexBossDifficulty.isBoss(e))}))};
  }));
}
// 小怪来源（十三层 Map029）：先随机选非 Boss 敌人，再判 1%，再按转换表等权选本体
encounterCase('mob_hit', {map: 29, troop: 104, random: [0.7, 0.005, 0.6]});
encounterCase('mob_miss', {map: 29, troop: 104, random: [0.1, 0.01]});
encounterCase('mob_other_troop', {map: 29, troop: 112, random: [0.0, 0.0, 0.0]});
encounterCase('no_source', {map: 1, troop: 104, random: [0.0, 0.0, 0.0]});
// Boss 来源（无垠虚空 Map037 敌群 145）：几率 min(1%, 掉率合计×0.2)，按掉率加权选本体，再随机变体
encounterCase('boss_hit', {map: 37, troop: 145, random: [0.001, 0.5, 0.7]});
encounterCase('boss_miss', {map: 37, troop: 145, random: [0.009]});
encounterCase('boss_150', {map: 38, troop: 150, random: [0.001, 0.95, 0.1]});
// 未知存在（Map152）：来源限定从 Map037／038 进入
encounterCase('origin_ok', {map: 152, troop: 454, origin: 37, random: [0.0, 0.0, 0.3]});
encounterCase('origin_bad', {map: 152, troop: 454, origin: 50, random: [0.0, 0.0, 0.3]});
encounterCase('origin_none', {map: 152, troop: 455, random: [0.0, 0.0, 0.3]});

// ③ 战斗
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
w.eval('CodexZones.ENABLED=false;');
const BIG_HP = 1e12;
function battle(spec) {
  newGame(); uncap();
  const a = w.$gameActors.actor(1), b = w.$gameActors.actor(8);
  a.changeLevel(30, false); b.changeLevel(30, false);
  party([1, 8]);
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(spec.troop || 2, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  const enemies = w.$gameTroop.members();
  enemies.forEach(e => { e._paramPlus[0] = BIG_HP; if (spec.enemyAtkPlus) e._paramPlus[2] = spec.enemyAtkPlus; });
  if (spec.variant) A.setupEncounter({enemy: enemies[spec.enemy || 0], kind: 'w', baseId: 3980, origin: spec.variant === 'mob' ? 'mob' : 'boss',
    variant: spec.variant === 'mob' ? null : spec.variant, affix: spec.affix || 'inversebone'});
  for (const x of [...w.$gameParty.members(), ...enemies]) { x.need_refresh = true; x.refresh(); x.recoverAll(); }
  // startBattle 包装：先锁队，原 startBattle 之后蜕壳护盾与提示（不走原 startBattle 画面，只照包装的两段）
  A.lockParty();
  const x = A.encounter();
  if (x) { const e = x.enemy, d = e._alienEnemy; if (d.variant === 'shell' && !d.shieldGranted) { d.shieldGranted = true; e._shield = Number(e.shield || 0) + Math.floor(e.mhp * .1); }
    A.notify(e.name() + '：' + x.variant.description + ' 胜利保证异化装备。'); }
  w.$gameParty._inBattle = true;
  w.CodexYunshang._acted = [];
  return {bm, a, b, enemies};
}
function act(bm, user, skillId, targetIndex) {
  const action = new w.Game_Action(user);
  if (skillId === 2) action.setGuard(); else action.setSkill(skillId);
  action.setTarget(targetIndex);
  user._actions = [action]; bm._subject = user; bm._action = null;
  bm.startAction();
  for (let i = 0; i < 20000; i++) {
    const ph = bm._phase;
    if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
    else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
  }
  if (bm._phase === 'action' || bm._phase === 'actionList' || bm._phase === 'actionTargetList') bm.endAction();
  return action;
}
const CORROSION = C.ids.corrosion;
const unit = x => ({hp: r(x.hp), mp: r(x.mp), mhp: x.mhp, shield: r(x._shield || 0), corrosion: x.isStateAffected(CORROSION),
  corrosionTurns: x.isStateAffected(CORROSION) ? x._stateTurns[CORROSION] : null, corrosionUntil: x._alienCorrosionUntil == null ? null : x._alienCorrosionUntil});
const alienOf = e => e._alienEnemy ? (({variant, boss, shieldGranted, mirrorRound, mirrorCharged, plagueRound, drainRound}) =>
  ({variant, boss, shieldGranted, mirrorRound, mirrorCharged, plagueRound, drainRound}))(e._alienEnemy) : null;
const reading = ctx => ({enemies: ctx.enemies.map(e => Object.assign(unit(e), {name: e.name(), alien: alienOf(e)})), a: unit(ctx.a), b: unit(ctx.b)});
function battleCase(name, spec, steps) {
  cases.push(makeCase('battle.' + name, Object.assign({actor: 1, ally: 8, troop: 2}, spec, {steps}), () => {
    toasts.length = 0;
    const ctx = battle(spec), rows = [];
    const startToasts = toasts.slice();
    const locked = [ctx.a, ctx.b].map(x => x._alienBattle ? {affix: x._alienBattle.affix} : null);
    for (const st of steps) {
      toasts.length = 0;
      if (st.roundStart) {
        // startTurn 包装（old 之后）：镜骸在新回合重新充能
        w.$gameTroop._turnCount = st.roundStart; const rr = A.round();
        w.$gameTroop.members().forEach(e => { const d = e._alienEnemy; if (d && d.variant === 'mirror' && d.mirrorRound !== rr) { d.mirrorRound = rr; d.mirrorCharged = true; } });
        rows.push(Object.assign({roundStart: st.roundStart}, reading(ctx), {toasts: toasts.slice()}));
        continue;
      }
      if (st.roundEnd) {
        // endTurn 包装（old 之后）：蚀能、腐蚀结算
        w.$gameTroop._turnCount = st.roundEnd; const rr = A.round();
        w.$gameTroop.members().forEach(A.drain);
        w.$gameParty.battleMembers().concat(w.$gameTroop.members()).forEach(t => A.tickCorrosion(t, rr));
        rows.push(Object.assign({roundEnd: st.roundEnd}, reading(ctx), {toasts: toasts.slice()}));
        continue;
      }
      if (st.set) {
        if (st.set.enemyHpRate != null) { const e = ctx.enemies[st.set.enemy || 0]; e._hp = Math.floor(e.mhp * st.set.enemyHpRate); }
        if (st.set.actorMpRate != null) ctx.a._mp = Math.floor(ctx.a.mmp * st.set.actorMpRate);
        if (st.set.allyMpRate != null) ctx.b._mp = Math.floor(ctx.b.mmp * st.set.allyMpRate);
        if (st.set.kill != null) { const e = ctx.enemies[st.set.kill]; e._hp = 0; e.addState(e.deathStateId()); }
        rows.push(Object.assign({set: st.set}, reading(ctx)));
        continue;
      }
      if (st.grant) {
        const before = w.$gameParty.weapons().length;
        const ok = A.grant(), x = A.encounter();
        rows.push(Object.assign({grant: true, ok, weapons: w.$gameParty.weapons().length - before,
          recent: J(A.ledger().recent).map(v => ({origin: v.origin, uid: v.uid, kind: v.kind})), granted: !!(x && x.granted)}, reading(ctx), {toasts: toasts.slice()}));
        continue;
      }
      w.$gameTroop._turnCount = st.round;
      const user = st.user === 'b' ? ctx.b : st.user && st.user[0] === 'e' ? ctx.enemies[Number(st.user.slice(1))] : ctx.a;
      user.setTp(100); user._mp = user.mmp;
      act(ctx.bm, user, st.skill, st.target || 0);
      rows.push(Object.assign({step: st}, reading(ctx), {toasts: toasts.slice()}));
    }
    const x = A.encounter();
    return {startToasts, locked, encounter: x ? {enemyIndex: ctx.enemies.indexOf(x.enemy), variant: x.variant.key, probability: x.probability} : null,
      enemies: ctx.enemies.map(e => ({id: e.enemyId(), mhp: e.mhp, name: e.name()})), rows};
  }));
}
// 对照：没有异化
battleCase('none', {enemyAtkPlus: 300}, [{round: 1, user: 'e0', skill: 1, target: 0}, {round: 1, skill: 1, target: 0}]);
// 烈变：生命 ×1.5，主动攻击生命伤害 +15%
battleCase('flare', {variant: 'flare', enemyAtkPlus: 300}, [{round: 1, user: 'e0', skill: 1, target: 0}, {round: 1, user: 'e1', skill: 1, target: 0}, {round: 1, skill: 1, target: 0}]);
// 小怪异化：生命 ×1.25，+10%；名字【异化】
battleCase('mob', {variant: 'mob', enemy: 1, enemyAtkPlus: 300}, [{round: 1, user: 'e1', skill: 1, target: 0}, {round: 1, user: 'e0', skill: 1, target: 0}]);
// 蜕壳：开场 10% 生命护盾
battleCase('shell', {variant: 'shell', enemyAtkPlus: 300}, [{round: 1, skill: 1, target: 0}, {round: 1, skill: 1, target: 1}, {round: 1, user: 'e0', skill: 1, target: 0}]);
// 蚀能：偶数回合末吸 MP 比例最高的活角色 10% 最大法力，按实际吸取比例回 2% 最大生命
battleCase('drain', {variant: 'drain'}, [{set: {enemyHpRate: 0.5}}, {set: {actorMpRate: 0.3}}, {roundEnd: 1}, {roundEnd: 2}, {roundEnd: 2},
  {set: {allyMpRate: 0.02}}, {roundEnd: 4}]);
// 灾疫：每回合第一个伤害技能对命中的目标附加两回合腐蚀；腐蚀每回合末扣 2% 最大生命，两回合后自然消失
battleCase('plague', {variant: 'plague', enemyAtkPlus: 300}, [{round: 1, user: 'e0', skill: 1, target: 0}, {round: 1, user: 'e0', skill: 1, target: 1},
  {roundEnd: 1}, {round: 2, user: 'e0', skill: 1, target: 1}, {roundEnd: 2}, {roundEnd: 3}]);
// 镜骸：每回合第一次被角色主动打中时，行动结束反噬 min(5% 扣血, 8% 行动者最大生命)
battleCase('mirror', {variant: 'mirror'}, [{roundStart: 1}, {round: 1, skill: 1, target: 0}, {round: 1, skill: 1, target: 0}, {round: 1, user: 'b', skill: 1, target: 0},
  {roundStart: 2}, {round: 2, user: 'b', skill: 1, target: 0}, {round: 2, skill: 1, target: 1}]);
// 胜利发放：敌人没倒不发；倒了发进背包、记最近掉落、提示；不重复发
battleCase('grant', {variant: 'flare'}, [{grant: true}, {set: {kill: 0}}, {grant: true}, {grant: true}]);
// 锁队：带异化装备的角色开战时冻结词条
cases.push(makeCase('lock', {actor: 1}, () => {
  newGame(); uncap();
  const a = w.$gameActors.actor(1); party([1, 8]);
  // 直接放进武器栏（穿戴限制属工坊侧，不在本参照）
  const i = A.create('w', 1042, 'mob', 'inversebone'); a._equips[0].setObject(i);
  A.lockParty();
  return {locked: [1, 8].map(id => { const x = w.$gameActors.actor(id)._alienBattle; return x ? {affix: x.affix, uid: A.mark(x.item).uid, config: J(x.config), selected: x.selected} : null; })};
}));
process.exit(finish(host, 'alien_battle.json', {hostScope: '新游戏（Math.random 0.5）；异化遭遇、敌人变体、腐蚀与胜利发放', config, cases}) ? 0 : 1);
