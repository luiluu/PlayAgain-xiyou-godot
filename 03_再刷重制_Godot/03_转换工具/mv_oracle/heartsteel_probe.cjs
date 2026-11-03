'use strict';
// 【cc·八戒·未经审查】成长装备期一：心之钢／杰作利维坦（installNativeHeartsteelRuntime）与狂妄／杰作无我（installNativeHubrisRuntime）。
// ① 公式：stageOf／stageNeed、hpRate、U.rateFor；② 穿上后的最大生命（阶数倍率、旧版累计生命平加）、物攻（扬名倍率）、
// 技能列表（换成对应的巨人吞噬）与 meetsSkillConditions（战斗外、蓄力、错配）；③ 掉落 clearReward（Map152、来源 38、敌群 454／455、10%、每场一次）；
// ④ 敌人权重；⑤ H.damage 减防；⑥ 真实 BattleManager 打 3 号敌群：心钢蓄力两次→巨人吞噬（伤害、待结算层数、冷却）→回合末回血→胜利保存层数；
// 狂妄击杀敌人→扬名（物攻倍率、剩余回合）→回合递减到清除、胜利保存盛名；狂妄物防穿透前后同一招的伤害。
// 去掉 O-050 两个伤害钩子（同 tusu_battle_probe）。产物 .sandbox/heartsteel.json，拷成 tests/fixtures/heartsteel_oracle.json（不进同步），专项 xiyou_heartsteel。
const {start, makeCase, finish, superReference} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const H = w.CodexHeartsteel, U = w.CodexHubris;
if (!H || !U || !H.unknownHeartOrigin) throw new Error('心钢／狂妄模块未安装');
const SR = superReference(w);
if (!w.$) w.$ = {};
const toasts = [];
w.$.toaster = o => { toasts.push(o.message); };
const stub = new Proxy(function () {}, {get: (_, k) => k === '_waitCount' ? 0 : (() => false), set: () => true});
const sprites = new Map();
w.Game_Battler.prototype.battler = function () {
  if (!sprites.has(this)) sprites.set(this, new Proxy({x: 0, y: 0, _homeX: 0, _homeY: 0, width: 64, height: 64, scale: {x: 1, y: 1}, anchor: {x: 0.5, y: 1}, opacity: 255},
    {get: (t, k) => k in t ? t[k] : (() => false), set: (t, k, v) => {t[k] = v; return true;}}));
  return sprites.get(this);
};
w.BattleManager.actionBattleHud = () => true;
w.BattleManager.otbDisplayWindow = () => stub;
const SKILLS = [H.skillId, H.leviathanSkillId];
function gear(base, fields) {
  w.$gameParty.gainItem(w.$dataArmors[base], 1, false);
  const list = w.$gameParty.armors().filter(x => x.baseItemId === base);
  return Object.assign(list[list.length - 1], fields || {});
}
// 实例的随机词条（<Prefixes>）：记下实例的八项属性与特性，重制照它设实例
const inst = it => ({params: it.params.slice(), traits: it.traits.map(t => [t.code, t.dataId, t.value]), id: it.id});
function equip(a, it) {
  const slot = a.equipSlots().indexOf(it.etypeId);
  a.changeEquip(slot, it);
  a.need_refresh = true; a.refresh();
  return slot;
}
const listed = a => a.skills().map(s => s.id).filter(id => SKILLS.includes(id));
const cases = [];
cases.push(makeCase('math', {}, () => {
  const ks = [0, 1, 99, 100, 101, 299, 300, 599, 600, 999, 1000, 5000, 5049, 5050, 123456];
  return {ks, stage: ks.map(k => H.stageOf(k)), need: [0, 1, 2, 3, 10, 50].map(n => H.stageNeed(n)),
    ids: {armor: H.armorId, leviathan: H.leviathanId, skill: H.skillId, levSkill: H.leviathanSkillId, hubris: U.armorId, ataraxia: U.leviathanId}};
}));
// 心钢：层数、旧版累计生命
for (const base of [7900, 7901]) for (const [stacks, hp] of [[0, 0], [100, 0], [350, 0], [1000, 0], [100, 5000]]) {
  cases.push(makeCase(`heart.param.${base}.${stacks}.${hp}`, {base, stacks, hp}, () => {
    newGame();
    const a = w.$gameActors.actor(1), before = {mhp: a.mhp, atk: a.atk, def: a.def, mdf: a.mdf};
    const it = gear(base, {_codexHeartsteelStacks: stacks, _codexHeartsteelHp: hp});
    const slot = equip(a, it);
    const out = {before, slot, inst: inst(it), mhp: a.mhp, atk: a.atk, def: a.def, mdf: a.mdf, rate: H.hpRate(it), stage: H.stage(it), castScale: H.castScale(a),
      paramPlus0: a.paramPlus(0), listed: listed(a), effectiveHp: H.effectiveHp(a)};
    out.meetsOut = SKILLS.map(id => a.meetsSkillConditions(w.$dataSkills[id]));
    w.$gameParty._inBattle = true;
    for (const wait of [2, 1, 0]) { a._codexHeartsteelWait = wait; out['meets' + wait] = SKILLS.map(id => a.meetsSkillConditions(w.$dataSkills[id])); }
    delete a._codexHeartsteelWait; out.meetsUnset = SKILLS.map(id => a.meetsSkillConditions(w.$dataSkills[id]));
    a.addBuff(0, 5); out.effectiveHpBuffed = H.effectiveHp(a); out.mhpBuffed = a.mhp;
    w.$gameParty._inBattle = false;
    return out;
  }));
}
// 狂妄：物攻、扬名倍率
for (const base of [7902, 7903]) for (const fame of [0, 100, 350]) {
  cases.push(makeCase(`hubris.param.${base}.${fame}`, {base, fame}, () => {
    newGame();
    const a = w.$gameActors.actor(1), before = {mhp: a.mhp, atk: a.atk};
    const it = gear(base, {_codexHubrisFame: fame});
    const slot = equip(a, it);
    const out = {before, slot, inst: inst(it), mhp: a.mhp, atk: a.atk, rate: U.rateFor(it, fame), listed: listed(a)};
    w.$gameParty._inBattle = true;
    a._codexHubrisBuff = {itemId: it.id, rate: U.rateFor(it, fame), round: 0, remaining: 3};
    a.need_refresh = true; a.refresh();
    out.atkBuffed = a.atk;
    w.$gameParty._inBattle = false;
    out.atkOutside = a.atk; out.buffAfterOutside = !!a._codexHubrisBuff;
    return out;
  }));
}
// 掉落：结果、地图、来源（null 时按变量 107）、敌群、随机数
const REWARD = [[0, 152, 38, 0, 454, 0.05], [0, 152, 38, 0, 455, 0.0999], [0, 152, 38, 0, 454, 0.1], [0, 152, 37, 0, 454, 0.05], [0, 152, null, 1, 454, 0.05],
  [0, 152, null, 0, 455, 0.05], [0, 176, 38, 0, 454, 0.05], [0, 152, 38, 0, 453, 0.05], [1, 152, 38, 0, 454, 0.05], [2, 152, 38, 0, 455, 0.05]];
for (const [result, map, origin, v107, troop, r] of REWARD) {
  cases.push(makeCase(`reward.${result}.${map}.${origin}.${v107}.${troop}.${r}`, {result, map, origin, v107, troop, r}, () => {
    newGame();
    w.$gameMap._mapId = map;
    if (origin == null) delete w.$gameMap._codexLeviathanUnknownOrigin; else w.$gameMap._codexLeviathanUnknownOrigin = origin;
    w.$gameVariables.setValue(107, v107);
    w.$gameTroop._troopId = troop;
    w.BattleManager._codexHeartsteelRewardRolled = false; w.BattleManager._codexHubrisRewardRolled = false;
    let draws = 0;
    w.Math.random = () => { draws++; return r; };
    const heart = H.clearReward(result), hubris = U.clearReward(result);
    const again = [H.clearReward(result), U.clearReward(result)];
    w.Math.random = () => 0.5;
    const count = id => w.$gameParty.armors().filter(x => x.baseItemId === id).length;
    return {origin: H.unknownHeartOrigin(), heart, hubris, again, draws, armors: [count(7900), count(7902)],
      recipes: [w.$gameParty.recipeKnown(H.recipeId), w.$gameParty.recipeKnown(U.recipeId)], unlocked: [!!w.$gameParty._codexLeviathanUnlocked, !!w.$gameParty._codexAtaraxiaUnlocked]};
  }));
}
cases.push(makeCase('weight', {}, () => {
  newGame();
  const names = ['史莱姆', '【首领】牛魔王', '【被封印者】某', '【未知存在】某', '木桩', '某分身', '【首领】的召唤物', '【守层者】某'];
  const out = {};
  w.$gameParty._inBattle = true;
  for (const troop of [3, 1]) {
    w.$gameTroop._troopId = troop;
    const fakes = names.map(name => ({isEnemy: () => true, enemy: () => ({name}), _codexHubrisExcluded: false}));
    U._originalEnemies = fakes;
    out[troop] = {heart: fakes.map(e => H.enemyWeight(e)), hubris: fakes.map(e => U.enemyWeight(e))};
  }
  w.$gameParty._inBattle = false;
  return {names, out};
}));
cases.push(makeCase('damage', {}, () => {
  const rows = [];
  for (const [base, def] of [[700, 0], [700, 300], [700, 350], [700, 5000], [12345, 1000], [12345, -50]]) {
    rows.push([base, def, H.damage(null, {def}, {_codexHeartsteelCast: {valid: true, baseDamage: base}}), H.damage(null, {def}, {_codexHeartsteelCast: {valid: false, baseDamage: base}})]);
  }
  return {rows};
}));

// ---- 真实战斗 ----
const key = b => !b ? null : b.isActor() ? 'a' + b.actorId() : 'e' + b.index();
const hits = [];
const oldExec = w.Game_Action.prototype.executeHpDamage;
w.Game_Action.prototype.executeHpDamage = function (t, v) { hits.push([key(this.subject()), key(t), v]); return oldExec.apply(this, arguments); };
const PARTY = [1, 8, 9, 10], TROOP = 3, BIG_HP = 1e9;
function battle(base, fields) {
  newGame();
  w.eval('$gameSystem.setDifficultyId(2);');
  w.eval('$gameParty._actors=[' + PARTY + ']; $gameParty._battleMembers=[' + PARTY + ',0];');
  const a = w.$gameActors.actor(1), it = gear(base, fields);
  equip(a, it);
  for (const id of PARTY) w.$gameActors.actor(id).recoverAll();
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  w.Math.random = () => 0.99;
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  w.Math.random = () => 0.5;
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  for (const t of w.$gameTroop.members()) t._paramPlus[0] = BIG_HP;
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  bm.startBattle();
  for (let tick = 0; tick < 5000 && bm._phase !== 'input'; tick++) {
    if (w.$gameMessage.isBusy()) { w.$gameMessage.clear(); continue; }
    bm.update();
  }
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) b.recoverAll();
  return {bm, a, it};
}
function run(bm) {
  for (let i = 0; i < 20000; i++) {
    const ph = bm._phase;
    if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
    else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
  }
  bm._phase = 'turn';
}
function act(bm, user, skillId, target) {
  const action = new w.Game_Action(user); action.setSkill(skillId); action.setTarget(target);
  user._actions = [action]; bm._subject = user; bm._action = null;
  hits.length = 0;
  bm.startAction(); run(bm);
  return hits.slice();
}
function turn(bm) { bm._enteredEndPhase = false; bm._phase = 'turn'; bm.endTurn(); bm.startTurn(); bm._phase = 'turn'; }
function heartSnap(ctx) {
  const {a, it} = ctx;
  return {hp: a.hp, mhp: a.mhp, wait: a._codexHeartsteelWait, casted: !!a._codexHeartsteelCasted, pending: H.pending(it), stacks: H.stacks(it),
    meets: SKILLS.map(id => a.meetsSkillConditions(w.$dataSkills[id])), round: w.$gameTroop.turnCount()};
}
for (const [base, stacks] of [[7900, 100], [7901, 0]]) {
  cases.push(makeCase(`heart.battle.${base}.${stacks}`, {base, stacks}, () => {
    const ctx = battle(base, {_codexHeartsteelStacks: stacks}), {bm, a, it} = ctx, sid = H.skillFor(it), rows = [];
    const e0 = w.$gameTroop.members()[0];
    rows.push(['start', heartSnap(ctx), {inst: inst(it), enemies: w.$gameTroop.members().map(e => e.enemy().name), e0def: e0.def}]);
    rows.push(['early', act(bm, a, sid, 0), heartSnap(ctx)]);  // 蓄力没满：放不出
    rows.push(['attack1', act(bm, a, 1, 0).length, heartSnap(ctx)]);
    rows.push(['attack2', act(bm, a, 1, 0).length, heartSnap(ctx)]);
    rows.push(['eff', H.effectiveHp(a), a.mhp]);
    rows.push(['cast', act(bm, a, sid, 0), heartSnap(ctx)]);
    rows.push(['recast', act(bm, a, sid, 0), heartSnap(ctx)]);
    a.setHp(1);
    turn(bm);
    rows.push(['turn', heartSnap(ctx)]);
    turn(bm);
    rows.push(['turn2', heartSnap(ctx)]);
    for (let i = 0; i < 3; i++) act(bm, a, 1, 0);
    rows.push(['attacks3', heartSnap(ctx)]);
    rows.push(['cast2', act(bm, a, sid, 0), heartSnap(ctx)]);
    bm.endBattle(0);
    rows.push(['victory', {stacks: H.stacks(it), pending: H.pending(it), mhp: a.mhp, desc: it.description}]);
    return {rows};
  }));
}
cases.push(makeCase('heart.battle.escape', {}, () => {
  const ctx = battle(7900, {_codexHeartsteelStacks: 5}), {bm, a, it} = ctx;
  act(bm, a, 1, 0); act(bm, a, 1, 0);
  const cast = act(bm, a, H.skillId, 0);
  const pending = H.pending(it);
  bm.endBattle(1);
  return {cast, pending, stacks: H.stacks(it)};
}));
function hubrisSnap(ctx) {
  const {a, it} = ctx, b = a._codexHubrisBuff;
  return {atk: a.atk, buff: b ? {rate: b.rate, round: b.round, remaining: b.remaining} : null, pending: U.pending(it), fame: U.growth(it), moves: a._codexHubrisMoves || 0, round: w.$gameTroop.turnCount()};
}
for (const [base, fame] of [[7902, 0], [7903, 300]]) {
  cases.push(makeCase(`hubris.battle.${base}.${fame}`, {base, fame}, () => {
    const ctx = battle(base, {_codexHubrisFame: fame}), {bm, a, it} = ctx, rows = [];
    const enemies = w.$gameTroop.members();
    rows.push(['start', hubrisSnap(ctx), {inst: inst(it), enemies: enemies.map(e => e.enemy().name), count: enemies.length, def: enemies.map(e => e.def)}]);
    rows.push(['attack', act(bm, a, 1, 0), hubrisSnap(ctx)]);
    enemies[0].setHp(1);
    rows.push(['kill', act(bm, a, 1, 0), hubrisSnap(ctx), enemies[0].isDead()]);
    rows.push(['attackBuffed', act(bm, a, 1, 1), hubrisSnap(ctx)]);
    for (let i = 0; i < 5; i++) { turn(bm); rows.push(['turn' + i, hubrisSnap(ctx)]); }
    if (enemies.length > 2) {
      enemies[2].setHp(1); act(bm, a, 1, 2); rows.push(['kill2', hubrisSnap(ctx)]);
    }
    bm.endBattle(0);
    rows.push(['victory', {fame: U.growth(it), pending: U.pending(it), buff: !!a._codexHubrisBuff, atk: a.atk}]);
    return {rows};
  }));
}
// 原版击杀记不上：死亡状态在行动结束后才挂（YEP 延后倒下），executeHpDamage 包装里 isDead() 还是假，_codexHubrisKilledByParty 设不上，
// 上面两例击杀后都没有扬名。fix：照修复后的口径（生命打到 0 就算本方击杀）补记，量原版其余结算（O-待定 狂妄击杀判定）。
// boss：敌人改名【首领】，打掉 10% 一段算一次（首领分段，原版本来就能触发）。
const enemyName = id => w.$dataEnemies[id].name;
for (const mode of ['fix', 'boss']) for (const [base, fame] of [[7902, 0], [7903, 300]]) {
  cases.push(makeCase(`hubris.${mode}.${base}.${fame}`, {mode, base, fame}, () => {
    const exec = w.Game_Action.prototype.executeHpDamage;
    if (mode === 'fix') w.Game_Action.prototype.executeHpDamage = function (t, v) { const before = t.hp, out = exec.apply(this, arguments); if (v > 0 && t.isEnemy() && before > 0 && t.hp <= 0) t._codexHubrisKilledByParty = !!(this.subject() && this.subject().isActor()); return out; };
    const eid = w.$dataTroops[TROOP].members[0].enemyId, oldName = enemyName(eid);
    if (mode === 'boss') w.$dataEnemies[eid].name = '【首领】' + oldName;
    try {
      const ctx = battle(base, {_codexHubrisFame: fame}), {bm, a, it} = ctx, rows = [], enemies = w.$gameTroop.members();
      rows.push(['start', hubrisSnap(ctx), {inst: inst(it), mhp: enemies.map(e => e.mhp)}]);
      if (mode === 'fix') {
        enemies[0].setHp(1); rows.push(['kill', act(bm, a, 1, 0), hubrisSnap(ctx)]);
        rows.push(['attackBuffed', act(bm, a, 1, 1), hubrisSnap(ctx)]);
        act(bm, w.$gameActors.actor(8), 1, 1); act(bm, w.$gameActors.actor(8), 1, 1);
        enemies[1].setHp(1); rows.push(['killByOther', act(bm, w.$gameActors.actor(8), 1, 1), hubrisSnap(ctx)]);  // 狂妄者上一次行动打过 e1、队友补刀：贡献在 2 次行动内，算协助
        for (let i = 0; i < 2; i++) { turn(bm); rows.push(['turn' + i, hubrisSnap(ctx)]); }
        act(bm, a, 1, 2); act(bm, w.$gameActors.actor(8), 1, 2); enemies[2].setHp(1);
        rows.push(['assist', act(bm, w.$gameActors.actor(8), 1, 2), hubrisSnap(ctx)]);  // 狂妄者打过、队友补刀：算协助
        for (let i = 2; i < 6; i++) { turn(bm); rows.push(['turn' + i, hubrisSnap(ctx)]); }
      } else {
        const e = enemies[0];
        e.setHp(Math.floor(e.mhp * 0.95)); rows.push(['seg', act(bm, a, 1, 0), hubrisSnap(ctx), e._codexHubrisSeg || 0]);
        e.setHp(Math.floor(e.mhp * 0.62)); rows.push(['seg2', act(bm, a, 1, 0), hubrisSnap(ctx), e._codexHubrisSeg || 0]);
        e.setHp(Math.floor(e.mhp * 0.50)); rows.push(['segOther', act(bm, w.$gameActors.actor(8), 1, 0), hubrisSnap(ctx), e._codexHubrisSeg || 0]);
        for (let i = 0; i < 5; i++) { turn(bm); rows.push(['turn' + i, hubrisSnap(ctx)]); }
        e.setHp(Math.floor(e.mhp * 0.05)); rows.push(['seg9', act(bm, a, 1, 0), hubrisSnap(ctx), e._codexHubrisSeg || 0]);
      }
      a.setHp(0); a.refresh(); rows.push(['dead', hubrisSnap(ctx)]);
      bm.endBattle(0);
      rows.push(['victory', {fame: U.growth(it), pending: U.pending(it), buff: !!a._codexHubrisBuff}]);
      return {rows};
    } finally { w.Game_Action.prototype.executeHpDamage = exec; w.$dataEnemies[eid].name = oldName; }
  }));
}
// 物防穿透：同一个角色先不带、再带狂妄打同一个敌人
cases.push(makeCase('hubris.pierce', {}, () => {
  const out = {};
  for (const base of [0, 7902, 7903]) {
    const ctx = battle(base || 7900, {});
    if (!base) { ctx.a.changeEquip(ctx.a.equipSlots().indexOf(17), null); ctx.a.need_refresh = true; ctx.a.refresh(); }
    const e = w.$gameTroop.members()[1];
    out[base] = {inst: inst(ctx.it), atk: ctx.a.atk, def: e.def, hits: act(ctx.bm, ctx.a, 1, 1)};
  }
  return out;
}));
// 审查第 29 期：endAction 前半段次序（P3-1）与心钢拦截在谷雨 apply 之内（P3-2）。
// order.tusu：队伍 [1, 8, 176, 10]，屠苏 60 级化武剑给穿狂妄的 1 号；1 号先打 e0（贡献），e0 留 1 血，补 3 兵势后斩锋打 e1，
// 剑气纵横（屠苏 endAction 前半段，内部施放）打死 e0。原版狂妄前半段在屠苏之后，本次 endAction 就结算出扬名（击杀按修复口径记）。
// order.guyu：队伍 [175, 1]，谷雨 35 级开花期打 e0，穿心之钢的 1 号被事件强制放没蓄满的巨人吞噬：心钢在谷雨 apply 里层拦下，
// 谷雨已置行动执行标记，花期绽放照样触发（付储备、打种子）。
const T = w.CodexTusu, G = w.Guyu, Bd = w.CodexBinding;
const RELICS = [4047, 4048, 7912], pristine = RELICS.map(id => JSON.parse(JSON.stringify(w.$dataArmors[id])));
function battle2(party, levels, base, fields, prep) {
  newGame();
  RELICS.forEach((id, i) => { w.$dataArmors[id] = JSON.parse(JSON.stringify(pristine[i])); });
  w.CodexThreeGrowth.sync();
  w.eval('$gameSystem.setDifficultyId(2); $gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  SR.enableSuperSwitch();
  if (prep) prep();
  w.eval('$gameParty._actors=[' + party + ']; $gameParty._battleMembers=[' + party + ',0];');
  for (const [id, lv] of Object.entries(levels)) w.$gameActors.actor(+id).changeLevel(lv, false);
  const a = w.$gameActors.actor(1), it = gear(base, fields);
  equip(a, it);
  if (party.includes(175)) G.syncSkills(w.$gameActors.actor(175));
  for (const id of party) w.$gameActors.actor(id).recoverAll();
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  w.Math.random = () => 0.99;
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  w.Math.random = () => 0.5;
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  for (const t of w.$gameTroop.members()) t._paramPlus[0] = BIG_HP;
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  bm.startBattle();
  for (let tick = 0; tick < 5000 && bm._phase !== 'input'; tick++) {
    if (w.$gameMessage.isBusy()) { w.$gameMessage.clear(); continue; }
    bm.update();
  }
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) b.recoverAll();
  return {bm, a, it};
}
function forced(bm, user, skillId, targetIndex) {
  hits.length = 0;
  user.forceAction(skillId, targetIndex); bm.forceAction(user); bm._subject = null;
  for (let i = 0; i < 20000 && (bm._actionForcedBattler || bm._subject || ['action', 'actionList', 'actionTargetList', 'phaseChange'].includes(bm._phase)); i++) {
    if (bm._actionForcedBattler && !bm._subject) { bm.processForcedAction(); continue; }
    const ph = bm._phase;
    if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
    else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
  }
  bm._phase = 'turn';
  return hits.slice();
}
cases.push(makeCase('order.tusu', {base: 7902}, () => {
  const exec = w.Game_Action.prototype.executeHpDamage;
  w.Game_Action.prototype.executeHpDamage = function (t, v) { const before = t.hp, out = exec.apply(this, arguments); if (v > 0 && t.isEnemy() && before > 0 && t.hp <= 0) t._codexHubrisKilledByParty = !!(this.subject() && this.subject().isActor()); return out; };
  try {
    const ctx = battle2([1, 8, 176, 10], {176: 60}, 7902, {_codexHubrisFame: 0}, () => T.recruit()), {bm, a, it} = ctx, rows = [];
    const enemies = w.$gameTroop.members(), tusu = w.$gameActors.actor(176), K = k => T.ids().skill[k];
    rows.push(['start', hubrisSnap(ctx), {inst: inst(it)}]);
    act(bm, tusu, K('huawu.sword'), w.$gameParty.members().indexOf(a));
    rows.push(['huawu', hubrisSnap(ctx), Bd.host(tusu) ? 'a' + Bd.host(tusu).actorId() : null]);
    rows.push(['attack', act(bm, a, 1, 0), hubrisSnap(ctx)]);
    enemies[0].setHp(1);
    Bd.gain(tusu, 3);
    rows.push(['zhanfeng', act(bm, a, K('arm.zhanfeng'), 1), hubrisSnap(ctx), enemies[0].isDead()]);
    turn(bm);
    rows.push(['turn', hubrisSnap(ctx)]);
    return {rows};
  } finally { w.Game_Action.prototype.executeHpDamage = exec; }
}));
function guyuSnap(ctx) {
  const g = w.$gameActors.actor(175), t = G.totals || {};
  return {heart: heartSnap(ctx), flowerUntil: G.flowerUntil, seed: G.seed ? G.seed.index() : null, reserve: [G.reserve(g), G.reserve(ctx.a)], blooms: t.blooms, spent: t.spent};
}
cases.push(makeCase('order.guyu', {base: 7900}, () => {
  const ctx = battle2([175, 1], {175: 35, 1: 35}, 7900, {_codexHeartsteelStacks: 0}), {bm, a, it} = ctx, rows = [];
  const g = w.$gameActors.actor(175);
  rows.push(['start', guyuSnap(ctx), {inst: inst(it)}]);
  act(bm, g, 10288, 0); act(bm, g, 10288, 0);
  rows.push(['heal', guyuSnap(ctx)]);
  rows.push(['open', act(bm, g, 10289, 0), guyuSnap(ctx)]);
  rows.push(['forced', forced(bm, a, H.skillFor(it), 1), guyuSnap(ctx)]);
  rows.push(['attack', act(bm, a, 1, 1), guyuSnap(ctx)]);
  return {rows};
}));
// 尾项二：智能 AI 估伤（Codex_SmartBattleAI safeDamage 的心钢分支：常态上限用当前 mhp，乘 castScale，物防最多减一半）
for (const [base, stacks] of [[7900, 0], [7900, 350], [7901, 100]]) {
  cases.push(makeCase(`ai.${base}.${stacks}`, {base, stacks}, () => {
    const ctx = battle(base, {_codexHeartsteelStacks: stacks}), {a, it} = ctx, e = w.$gameTroop.members()[0], rows = [];
    for (const plus of [0, 5000000]) {
      e._paramPlus[3] = plus; e.need_refresh = true; e.refresh();
      for (const id of SKILLS) {
        const action = new w.Game_Action(a); action.setSkill(id);
        rows.push({plus, skill: id, def: e.def, mhp: a.mhp, scale: H.castScale(a), safe: w.CodexSmartAI.safeDamage(a, e, w.$dataSkills[id], action)});
      }
    }
    return {inst: inst(it), rows};
  }));
}
// 尾项二：甚尔封印 2634 让主动技能失效时（_tojiSuppressed），心钢不减蓄力、狂妄不计行动；普攻不失效照减；失效的巨人吞噬照样进冷却（包装在 applyGlobal 之前）
for (const [base, fields] of [[7900, {_codexHeartsteelStacks: 0}], [7902, {_codexHubrisFame: 0}]]) {
  cases.push(makeCase(`suppress.${base}`, {base}, () => {
    const ctx = battle(base, fields), {bm, a, it} = ctx, rows = [];
    const snap = () => ({wait: H.remaining(a), moves: a._codexHubrisMoves || 0, casted: !!a._codexHeartsteelCasted, charges: a._tojiSealCharges || 0, sealed: a.isStateAffected(2634)});
    const active = a.skills().map(s => s.id).find(id => id > 2 && !SKILLS.includes(id) && w.$dataSkills[id].stypeId != null);
    a.addState(2634); a._tojiSealCharges = 2;
    rows.push(['start', snap(), {inst: inst(it), active}]);
    rows.push(['attack', act(bm, a, 1, 0).length, snap()]);
    rows.push(['skill1', act(bm, a, active, 0).length, snap()]);
    rows.push(['skill2', act(bm, a, active, 0).length, snap()]);
    rows.push(['free', act(bm, a, active, 0).length, snap()]);
    return {rows};
  }));
}
cases.push(makeCase('suppress.cast', {base: 7900}, () => {
  const ctx = battle(7900, {_codexHeartsteelStacks: 0}), {bm, a, it} = ctx, sid = H.skillFor(it), rows = [];
  a._codexHeartsteelWait = 0; a.addState(2634); a._tojiSealCharges = 1;
  rows.push(['start', heartSnap(ctx), {inst: inst(it)}]);
  rows.push(['cast', act(bm, a, sid, 0).length, heartSnap(ctx), a.isStateAffected(2634)]);
  return {rows};
}));
// 尾项二：提示（$.toaster）。第一次得到一族才报解锁，再得到不报；掉落先报解锁（gainItem 里）再报获得
cases.push(makeCase('toast.unlock', {}, () => {
  newGame(); toasts.length = 0;
  const rows = [];
  for (const base of [7900, 7900, 7901, 7902, 7903]) {
    w.$gameParty.gainItem(w.$dataArmors[base], 1, false);
    rows.push([base, toasts.splice(0)]);
  }
  return {rows};
}));
cases.push(makeCase('toast.reward', {}, () => {
  newGame(); toasts.length = 0;
  w.$gameMap._mapId = 152; w.$gameMap._codexLeviathanUnknownOrigin = 38; w.$gameTroop._troopId = 454;
  w.BattleManager._codexHeartsteelRewardRolled = false; w.BattleManager._codexHubrisRewardRolled = false;
  w.Math.random = () => 0.05;
  const heart = H.clearReward(0), heartToasts = toasts.splice(0), hubris = U.clearReward(0), hubrisToasts = toasts.splice(0);
  w.$gameMap._mapId = 176; w.$gameMap._codexLeviathanUnknownOrigin = 165; w.$gameTroop._troopId = 570; w.BattleManager._codexLeviathanCoreRolled = false;
  const core = H.awardCore(0), coreToasts = toasts.splice(0);
  w.Math.random = () => 0.5;
  return {heart, heartToasts, hubris, hubrisToasts, core, coreToasts, origin: H.unknownCoreOrigin()};
}));
process.exit(finish(host, 'heartsteel.json', {hostScope: '真实 CodexHeartsteel／CodexHubris（param、paramPlus、skills、meetsSkillConditions、clearReward、enemyWeight、damage、BattleManager 各包装）', cases}) ? 0 : 1);
