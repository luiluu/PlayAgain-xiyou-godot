'use strict';
// 【cc·白龙_9·未经审查】174 云裳第一期（js/codex/runtime/installNativeYunshangRuntime.js 的 W.CodexYunshang）：
// ① 技能同步 Y.sync 与按等级／进阶学会的技能、八项能力值（最大生命／魔攻／敏捷倍率）、被动缓存的暴伤／终伤（云丝展幅、织神天梭）；
// ② 公式 CodexYunshang.formula（战斗外，防取目标魔防）；③ 招募（入队、本档第一次进背包一件织神天梭）；
// ④ 战斗：必中、戴织神天梭必暴击与结算 ×1.99、双针段数 ×2 与 ×0.555、云丝展幅打全体与 ×0.5／0.66／0.77、伤害行动定魔法；
//    能不能用：没解锁、敕衣点神要有人穿天衣、收针要有人觉醒。
// 觉醒、天衣各件、赠行／储行、拆段、符针是第二期，本探针不放。
// 真实 BattleManager／Game_Action（Math.random 0.5）；只在内存，产物 .sandbox/yunshang.json，拷成 tests/fixtures/yunshang_oracle.json（不接入全量同步）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const Y = w.CodexYunshang;
if (!Y || typeof Y.formula !== 'function') throw new Error('云裳模块未安装');
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
const ACTOR = 174, RELIC = 7935, BIG_HP = 1e12, TROOP = 3, DEF_PLUS = 5000;
const key = b => !b ? null : b.isActor() ? 'a' + b.actorId() : 'e' + b.index();
const skills = a => a._skills.filter(id => id >= 10270 && id <= 10287).sort((x, y) => x - y);
const params = a => [0, 1, 2, 3, 4, 5, 6, 7].map(i => a.param(i));
const cache = a => { a.initPassiveCache(); a.refreshPassiveCache(); const c = a._passiveCache; return {crit: c.critHarmRi || 0, final: c.globalHarmRi || 0}; };
const maxLevel = () => w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
// 新建角色（1 级 setup，进阶 0）→ 写进阶次数 → 升到 level（changeLevel 包装里同步）
function grow(level, stage) {
  const a = w.$gameActors.actor(ACTOR);
  a._AdvancedNum = stage;
  a.changeLevel(level, false);
  return a;
}
function wearRelic(a) {
  w.$gameParty.gainItem(w.$dataArmors[RELIC], 1, false);
  const gear = w.$gameParty.armors().filter(i => (i.baseItemId || i.id) === RELIC).slice(-1)[0];
  a.changeEquip(a.equipSlots().indexOf(w.$dataArmors[RELIC].etypeId), gear);
  // krz_state_re 的倍率缓存：换装不清，最大生命的 ×1.33 要等下次 need_refresh 才算进去（缓存的时机问题，不是规则）；这里照其它探针刷新一次
  a.need_refresh = true; a.refresh();
  return gear;
}

// 新局、云裳 level 级 stage 进阶入队并排到第一位（_actors 与出战表 _battleMembers 都挪；addActor 会把 1、8、9、10 补回来，清队无效；出战 174、1、8、9）、
// 可选戴织神天梭；全队与敌群 3 生命加 1e12、敌人物防 +5000；开第一回合
function battle(level, stage, relic) {
  newGame(); maxLevel();
  w.$gameSwitches.setValue(2494, true);  // 挑战开关：超强者才能出战（同 garou_battle_probe）
  const a = grow(level, stage);
  w.$gameParty.addActor(ACTOR);
  for (const list of [w.$gameParty._actors, w.$gameParty._battleMembers]) { list.splice(list.indexOf(ACTOR), 1); list.unshift(ACTOR); }
  if (relic) wearRelic(a);
  for (const b of w.$gameParty.allMembers()) b._paramPlus[0] = BIG_HP;
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  w.CodexYunshang._acted = [];
  for (const e of w.$gameTroop.members()) { e._paramPlus[0] = BIG_HP; e._paramPlus[3] = DEF_PLUS; }
  for (const b of [...w.$gameParty.allMembers(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  bm.startTurn();
  return {bm, a, party: w.$gameParty.battleMembers().map(b => b.actorId())};
}
function act(bm, user, skillId, targetIndex, prep) {
  const action = new w.Game_Action(user); action.setSkill(skillId); action.setTarget(targetIndex);
  if (prep) prep(action);
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
    log.push({user: key(this.subject()), skill: this.item().id, target: key(target), value, critical: !!target.result().critical});
    return old.apply(this, arguments);
  };
  try { fn(); } finally { w.Game_Action.prototype.executeHpDamage = old; }
  return log;
}
const MEETS = [10270, 10271, 10272, 10273, 10274, 10277];
const snap = a => { a.setMp(a.mmp); a.setTp(a.maxTp()); return {meets: MEETS.map(id => a.meetsSkillConditions(w.$dataSkills[id]))}; };
const cast = (bm, a, id, target = 0) => { a.setMp(a.mmp); a.setTp(a.maxTp()); a.clearCooldowns && a.clearCooldowns(); return {cast: id, log: record(() => act(bm, a, id, target)), ...snap(a)}; };
const cases = [];

// ① 技能、能力值、被动缓存：各级 × 进阶
for (const [level, stage] of [[1, 0], [10, 0], [20, 0], [25, 0], [30, 0], [35, 0], [35, 1], [40, 1], [45, 1], [50, 1], [50, 2], [55, 2], [60, 2]]) {
  cases.push(makeCase(`skills.lv${level}.s${stage}`, {level, stage}, () => {
    newGame(); maxLevel();
    const a = grow(level, stage);
    return {skills: skills(a), params: params(a), cache: cache(a)};
  }));
}
// 戴织神天梭：终伤 +3（不看云丝展幅）；能力值不变
for (const level of [10, 30]) {
  cases.push(makeCase(`relic.lv${level}`, {level, stage: 0}, () => {
    newGame(); maxLevel();
    const a = grow(level, 0);
    wearRelic(a);
    return {skills: skills(a), params: params(a), cache: cache(a)};
  }));
}
// 降级：changeLevel 往下也同步（35 级进阶 1 → 20 级）
cases.push(makeCase('skills.down', {level: 20, stage: 1, from: 35}, () => {
  newGame(); maxLevel();
  const a = grow(35, 1);
  a.changeLevel(20, false);
  return {skills: skills(a), params: params(a), cache: cache(a)};
}));
// ② 公式（战斗外：防＝目标魔防）
cases.push(makeCase('formula', {level: 45, stage: 1}, () => {
  newGame(); maxLevel();
  const a = grow(45, 1);
  const e = new w.Game_Enemy(2, 0, 0);
  const rows = [];
  for (const mdfPlus of [0, 30000]) {
    e._paramPlus[5] = mdfPlus;
    for (const id of [10270, 10271, 10274, 10282, 10286, 10272]) {
      const action = new w.Game_Action(a); action.setSkill(id);
      rows.push({id, mdf: e.mdf, value: Y.formula(action, a, e)});
    }
  }
  return {mat: a.mat, def: a.def, mdf: a.mdf, rows};
}));
// ③ 招募：新局（队里 1、8、9、10）、开挑战开关 2494 后招两次（超强者门槛在公共事件那一层，重制 mv_script 的 _recruit_blocked 已接）
cases.push(makeCase('recruit', {level: 1}, () => {
  newGame();
  w.$gameSwitches.setValue(2494, true);
  Y.recruit();
  const count = () => w.$gameParty.armors().filter(i => (i.baseItemId || i.id) === RELIC).length;
  const first = {party: w.$gameParty.members().map(b => b.actorId()), relics: count(), worn: w.$gameActors.actor(ACTOR).equips().filter(Boolean).map(i => i.baseItemId || i.id)};
  Y.recruit();
  return {first, again: {party: w.$gameParty.members().map(b => b.actorId()), relics: count()}, skills: skills(w.$gameActors.actor(ACTOR))};
}));
// ④ 战斗：钉影 10270、拆神 10271、普通攻击 1 各打一次（主目标 0）；比值看本例第一段
for (const [level, stage, relic] of [[20, 0, false], [25, 0, false], [30, 0, false], [30, 0, true], [35, 1, false], [35, 1, true]]) {
  const id = `battle.lv${level}.s${stage}${relic ? '.relic' : ''}`;
  cases.push(makeCase(id, {level, stage, relic}, () => {
    const {bm, a, party} = battle(level, stage, relic);
    const steps = [{start: true, ...snap(a)}];
    steps.push(cast(bm, a, 10270, 1));
    if (level >= 10) steps.push(cast(bm, a, 10271, 0));
    steps.push(cast(bm, a, 1, 2));
    bm.endBattle(0);
    return {party, skills: skills(a), cri: a.cri, steps};
  }));
}
// ===== 第二期 A 批：觉醒、收针、余辉、符针、御风、赠行／储行、六衡裁身、万法同裳、七曜流霞 =====
// battle2：开挑战开关、云裳 level 级 stage 进阶（可戴织神天梭、天衣 robe），1 号 55 级（可穿天衣 allyRobe）；队伍 174、1、8、9、10；
// 只给敌人加生命（符针例另给敌人物攻 +5000、1 号生命 +1e6，让钉影虚弱的 ×0.67 看得出）；startBattle 再开第一回合（startBattle 包装：建战斗数据、天衣无缝全醒；startTurn 包装：神纹自鸣随机唤醒）
const ROBE = k => 7920 + k;
function wearRobe(a, k) {
  w.$gameParty.gainItem(w.$dataArmors[ROBE(k)], 1, false);
  const gear = w.$gameParty.armors().filter(i => (i.baseItemId || i.id) === ROBE(k)).slice(-1)[0];
  a.forceChangeEquip(a.equipSlots().indexOf(4), gear);
  a.need_refresh = true; a.refresh();
}
function battle2(o) {
  newGame(); maxLevel();
  w.$gameSwitches.setValue(2494, true);
  const a = grow(o.level, o.stage);
  w.$gameParty.addActor(ACTOR);
  for (const list of [w.$gameParty._actors, w.$gameParty._battleMembers]) { list.splice(list.indexOf(ACTOR), 1); list.unshift(ACTOR); }
  const ally = w.$gameActors.actor(1);
  ally.changeLevel(55, false);
  if (o.relic) wearRelic(a);
  if (o.robe != null) wearRobe(a, o.robe);
  if (o.allyRobe != null) wearRobe(ally, o.allyRobe);
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  w.CodexYunshang._acted = [];
  for (const e of w.$gameTroop.members()) { e._paramPlus[0] = BIG_HP; e._paramPlus[2] = o.foeAtk || 0; }
  ally._paramPlus[0] = o.allyHp || 0;
  for (const b of [...w.$gameParty.allMembers(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  bm.startBattle();
  bm.startTurn();
  return {bm, a, ally};
}
const yd = b => { const d = Y.data(b); return d ? {key: d.key, wakeUntil: d.wakeUntil, stored: d.stored, gifts: d.gifts} : null; };
const qcount = () => { const out = {}; for (const b of (w.BattleManager._actionBattlers || [])) { const k = key(b); out[k] = (out[k] || 0) + 1; } return out; };
const ys = (a, ally) => ({round: Y.round(), awake: [!!Y.awake(a), !!Y.awake(ally)], data: [yd(a), yd(ally)],
  tags: JSON.parse(JSON.stringify(Y._giftSources || {})), queue: qcount(), afterglow: !!a._yunAfterglow});
const cast2 = (bm, u, id, target, prep) => { u.setMp(u.mmp); u.setTp(u.maxTp()); u.clearCooldowns && u.clearCooldowns(); return {cast: id, user: key(u), log: record(() => act(bm, u, id, target, prep))}; };
const step = (x, a, ally, extra) => ({...x, ...ys(a, ally), ...(extra || {})});

// 觉醒：开局神纹自鸣唤醒随机一个没醒的天衣穿戴者（两人时 randomInt(2)＝1 号）；云裳对自己用敕衣点神；觉醒到下一回合末
cases.push(makeCase('p2.wake', {level: 45, stage: 1, robe: 8, allyRobe: 9}, () => {
  const {bm, a, ally} = battle2({level: 45, stage: 1, robe: 8, allyRobe: 9});
  const steps = [step({start: true}, a, ally)];
  steps.push(step(cast2(bm, a, 10273, 0), a, ally, {meets: MEETS.map(id => a.meetsSkillConditions(w.$dataSkills[id]))}));
  bm.startTurn(); steps.push(step({turn: true}, a, ally));
  bm.startTurn(); steps.push(step({turn: true}, a, ally));
  return {steps};
}));
// 天衣无缝：开战全醒；万法同裳穿在云裳身上（双攻取高、物魔两路各算一次）
cases.push(makeCase('p2.seamless', {level: 55, stage: 2, robe: 13, allyRobe: 9}, () => {
  const {bm, a, ally} = battle2({level: 55, stage: 2, robe: 13, allyRobe: 9});
  const steps = [step({start: true, params: params(a)}, a, ally)];
  steps.push(step(cast2(bm, a, 10270, 1), a, ally));
  steps.push(step(cast2(bm, ally, 1, 2), a, ally));
  return {steps};
}));
// 收针：选觉醒中的 1 号（action._yunWakeTarget），伤害按其剩余觉醒回合数，并消耗觉醒
cases.push(makeCase('p2.gather', {level: 50, stage: 2, robe: 8, allyRobe: 9}, () => {
  const {bm, a, ally} = battle2({level: 50, stage: 2, robe: 8, allyRobe: 9});
  const steps = [step({start: true, meets: MEETS.map(id => a.meetsSkillConditions(w.$dataSkills[id]))}, a, ally)];
  steps.push(step(cast2(bm, a, 10270, 1), a, ally));
  steps.push(step(cast2(bm, a, 10274, 1, x => { x._yunWakeTarget = 1; }), a, ally, {meets: MEETS.map(id => a.meetsSkillConditions(w.$dataSkills[id]))}));
  return {steps};
}));
// 余辉：戴织神天梭时有人被唤醒，下一次主动伤害 ×1.33（只一次）
cases.push(makeCase('p2.afterglow', {level: 35, stage: 1, relic: true, allyRobe: 9}, () => {
  const {bm, a, ally} = battle2({level: 35, stage: 1, relic: true, allyRobe: 9});
  const steps = [step({start: true}, a, ally)];
  steps.push(step(cast2(bm, a, 10270, 1), a, ally));
  steps.push(step(cast2(bm, a, 10270, 1), a, ally));
  return {steps};
}));
// 符针：千丝成阵每个目标种 3 根（没穿天衣、不觉醒）；敌人行动前引爆身上全部，且这次伤害 ×0.67（觉醒中的伤害引爆一根见 p2.seamless）
// 天衣有等级需求（req_level），穿不上时原版不生效，所以各例按需求给等级
cases.push(makeCase('p2.needle', {level: 45, stage: 1, foeAtk: 5000, allyHp: 1000000}, () => {
  const {bm, a, ally} = battle2({level: 45, stage: 1, foeAtk: 5000, allyHp: 1000000});
  const foes = w.$gameTroop.members();
  const needles = () => foes.map(e => (e._yunNeedles || []).length);
  const steps = [step({start: true, needles: needles()}, a, ally)];
  steps.push(step({...cast2(bm, a, 10270, 1), needles: needles()}, a, ally));
  steps.push(step({...cast2(bm, a, 10271, 0), needles: needles()}, a, ally));
  steps.push(step({...cast2(bm, foes[1], 1, 1), needles: needles()}, a, ally));
  steps.push(step({...cast2(bm, foes[1], 1, 1), needles: needles()}, a, ally));
  return {steps};
}));
// 御风：全队敏捷 ×1.33（到下一回合末）
cases.push(makeCase('p2.wind', {level: 20, stage: 0}, () => {
  const {bm, a, ally} = battle2({level: 20, stage: 0});
  const agi = () => w.$gameParty.battleMembers().map(b => b.agi);
  const steps = [step({start: true, agi: agi()}, a, ally)];
  steps.push(step({...cast2(bm, a, 10272, 0), agi: agi()}, a, ally));
  bm.startTurn(); steps.push(step({turn: true, agi: agi()}, a, ally));
  bm.startTurn(); steps.push(step({turn: true, agi: agi()}, a, ally));
  return {steps};
}));
// 赠行（同袍换日）：1 号穿天衣得赠行 10284，赠云裳一次行动，每回合最多 3 次；觉醒后 freeGift 免费赠 2 次
cases.push(makeCase('p2.gift', {level: 20, stage: 0, allyRobe: 11}, () => {
  const {bm, a, ally} = battle2({level: 20, stage: 0, allyRobe: 11});
  const gm = () => ally.meetsSkillConditions(w.$dataSkills[10284]);
  const steps = [step({start: true, skills: ally.skills().map(s => s.id).filter(id => id >= 10270), giftMeets: gm()}, a, ally)];
  for (let i = 0; i < 3; i++) steps.push(step({...cast2(bm, ally, 10284, 0), giftMeets: gm()}, a, ally));
  Y.wake(ally);
  steps.push(step({free: Y.freeGift(ally, a), again: Y.freeGift(ally, a)}, a, ally));
  return {steps};
}));
// 储行（寸光留仙）：1 号用收存余光收起本回合剩下的原有行动（再加 1 份，最多 3），放行加回；觉醒时每回合开始多存 1 份、放行每份 2 次
cases.push(makeCase('p2.store', {level: 20, stage: 0, allyRobe: 9}, () => {
  const {bm, a, ally} = battle2({level: 20, stage: 0, allyRobe: 9});
  const steps = [step({start: true, storeMeets: ally.meetsSkillConditions(w.$dataSkills[10285])}, a, ally)];
  steps.push(step(cast2(bm, ally, 10285, 0), a, ally));
  steps.push(step({release: Y.release(ally), again: Y.release(ally)}, a, ally));
  Y.wake(ally);
  bm.startTurn(); steps.push(step({turn: true}, a, ally));
  steps.push(step({release: Y.release(ally)}, a, ally));
  return {steps};
}));
// 六衡裁身：选魔攻，其余五项各 33% 裁入；觉醒后改选两项（第二项自动补物攻）
cases.push(makeCase('p2.cut', {level: 30, stage: 0, allyRobe: 8}, () => {
  const {bm, a, ally} = battle2({level: 30, stage: 0, allyRobe: 8});
  const steps = [step({start: true, params: params(ally)}, a, ally)];
  steps.push(step({cut: Y.cut(ally, [4]), params: params(ally)}, a, ally));
  Y.wake(ally);
  steps.push(step({woke: true, params: params(ally)}, a, ally));
  return {steps};
}));
// 七曜流霞：没醒时（进阶 0 没有唤醒手段）伤害元素换成选定的一个（默认 2）；天衣无缝觉醒后三个元素各算一次
for (const [level, stage] of [[55, 0], [55, 2]]) {
  cases.push(makeCase(`p2.seven.lv${level}.s${stage}`, {level, stage, robe: 14}, () => {
    const {bm, a, ally} = battle2({level, stage, robe: 14});
    const steps = [step({start: true}, a, ally)];
    steps.push(step(cast2(bm, a, 10270, 1), a, ally));
    steps.push(step(cast2(bm, a, 1, 2), a, ally));
    return {steps};
  }));
}
// ===== 第二期 B 批（前一半）：赊账与赊月偿星 2、幽灵与不渡黄泉 3、山河作骨 0、百厄成锦 1、逆命换锦 4、一身两世 12 =====
// 云裳 20 级进阶 0（没有神纹自鸣），1 号 55 级穿天衣；数值只比同一例里的比值（z3 把各数除以本例第一个非零基准）
const st3 = b => b._states.filter(i => i !== 1).map(i => [i, b._stateTurns[i]]);
const yd3 = b => { const d = Y.data(b); return d ? {debt: d.debts.reduce((s, x) => s + x.amount, 0), due: d.debts.map(x => x.due), bank: d.bank, ghost: d.ghost, ghostDone: d.ghostDone,
  ghostUsed: d.ghostUsed, revived: d.revived, captured: d.captured.map(x => [x.id, x.turns, x.cleaned])} : null; };
const v3 = (a, ally, foes) => ({hp: [a.mhp - a.hp, ally.mhp - ally.hp], alive: [a.isAlive(), ally.isAlive()], mp: ally.mp / ally.mmp, d: yd3(ally),
  st: [st3(a), st3(ally), ...foes.map(st3)]});
const p3 = (id, o, body) => cases.push(makeCase(id, o, () => {
  const {bm, a, ally} = battle2(o), foes = w.$gameTroop.members();
  const steps = [];
  const at = (x, extra) => steps.push({...x, ...ys(a, ally), ...v3(a, ally, foes), ...(extra || {})});
  body({bm, a, ally, foes, at});
  return {steps};
}));
// 赊月偿星：承伤 50% 记债（到期回合＝round+1）；行动的伤害还债 33%；觉醒后下一次主动命中把全部债转成符针附加伤害（×188.88）；endBattle 结清
p3('p3.debt', {level: 20, stage: 0, allyRobe: 2, foeAtk: 5000, allyHp: 1000000}, ({bm, a, ally, foes, at}) => {
  at({start: true, skills: ally.skills().map(s => s.id).filter(id => id >= 10270)});
  at(cast2(bm, foes[1], 1, 1));
  at(cast2(bm, ally, 1, 2));
  at(cast2(bm, foes[1], 1, 1));
  Y.wake(ally);
  at(cast2(bm, ally, 1, 2));
  at(cast2(bm, foes[1], 1, 1));
  bm.endBattle(0);
  at({end: true});
});
// 到期：回合末（endTurn 包装）扣到期的债；round 1 记的债 round 2 末到期
const endTurn = bm => { bm._phase = 'turnEnd'; bm._enteredEndPhase = true; bm.endTurn(); };
p3('p3.debt.due', {level: 20, stage: 0, allyRobe: 2, foeAtk: 5000, allyHp: 1000000}, ({bm, a, ally, foes, at}) => {
  at(cast2(bm, foes[1], 1, 1));
  endTurn(bm); at({endTurn: 1});
  bm.startTurn(); at({turn: 2});
  endTurn(bm); at({endTurn: 2});
});
// 不渡黄泉：每场首次倒下留衣魂 2 次真实行动（生命 1、不算阵亡），用完倒下；觉醒中用完 2 次回 50% 生命／MP；第二次倒下照常阵亡
for (const woke of [false, true]) p3(`p3.ghost${woke ? '.awake' : ''}`, {level: 20, stage: 0, allyRobe: 3, foeAtk: 500000}, ({bm, a, ally, foes, at}) => {
  if (woke) Y.wake(ally);
  at({start: true});
  at(cast2(bm, foes[1], 1, 1));
  at(cast2(bm, ally, 1, 2));
  at(cast2(bm, ally, 1, 2));
  at(cast2(bm, foes[1], 1, 2));
});
// 敌人打的是 8 号、不打云裳：云裳是超强者，原版天灾／地狱路线压制承伤 ×1.2／×1.5（installSuperStrongRouteRuntime），重制还没移植（交接板「统一调整阶段」）
// 山河作骨：1 号觉醒时队友承伤 33% 分给他（记进 bank，上限最大生命 ×3）；山河击取 bank 转附加伤害（×188.88）、守势到下一回合末，期间被敌人打反击一次（×0.5）
p3('p3.mountain', {level: 20, stage: 0, allyRobe: 0, foeAtk: 300, allyHp: 1000000}, ({bm, a, ally, foes, at}) => {
  Y.wake(ally);
  at({start: true, skills: ally.skills().map(s => s.id).filter(id => id >= 10270)});
  at(cast2(bm, foes[1], 1, 2));
  at(cast2(bm, ally, 10282, 1));
  at(cast2(bm, foes[1], 1, 1));
  at(cast2(bm, foes[1], 1, 1));
});
// 百厄成锦：收录身上新得的普通减益（没醒 3 个、醒 6 个；醒着当场去掉），下一次主动伤害命中转给主目标（醒：全部敌人）
for (const woke of [false, true]) p3(`p3.hundred${woke ? '.awake' : ''}`, {level: 20, stage: 0, allyRobe: 1}, ({bm, a, ally, foes, at}) => {
  if (woke) Y.wake(ally);
  at({start: true});
  ally.addState(5); ally.addState(6); ally.addState(55);
  at({added: true});
  at(cast2(bm, ally, 1, 1));
});
// 逆命换锦：没醒时换锦把自己的一个减益与目标的一个增益互换（原版选择窗，这里给 _yunExchangeSelf／_yunExchangeEnemy）；醒着（每次觉醒一次）全队减益转全敌、夺 3 个增益
for (const woke of [false, true]) p3(`p3.exchange${woke ? '.awake' : ''}`, {level: 20, stage: 0, allyRobe: 4}, ({bm, a, ally, foes, at}) => {
  if (woke) Y.wake(ally);
  ally.addState(5); a.addState(6); foes[1].addState(55); foes[2].addState(43);
  at({start: true, skills: ally.skills().map(s => s.id).filter(id => id >= 10270)});
  at(cast2(bm, ally, 10283, 1, x => { x._yunExchangeSelf = 5; x._yunExchangeEnemy = 55; }));
  at(cast2(bm, ally, 10283, 2, x => { x._yunExchangeSelf = 5; x._yunExchangeEnemy = 43; }));
});
// 一身两世：伤害行动结束后按每段命中复演一次（每回合一次；觉醒时每次 2 遍、不限回合）
p3('p3.clone', {level: 20, stage: 0, allyRobe: 12}, ({bm, a, ally, foes, at}) => {
  at({start: true});
  at(cast2(bm, ally, 1, 1));
  at(cast2(bm, ally, 1, 1));
  Y.wake(ally);
  at(cast2(bm, ally, 1, 1));
});
// ===== 第二期 B 批后一半：千军入袖 5、空袖藏星 6（借技能）、九曲回针 7（针眼）、孤灯照众 10 =====
const cds = u => [10270, 10271, 10272].map(id => u.cooldown ? u.cooldown(id) : 0);
const castKeep = (bm, u, id, target) => { u.setMp(u.mmp); u.setTp(u.maxTp()); return {cast: id, user: key(u), log: record(() => act(bm, u, id, target))}; };
const party3 = () => w.$gameParty.battleMembers().map(st3);
// 千军入袖：收袖时群攻改成打一个目标、伤害按全部敌人各算一次相加；觉醒中打倒目标时溢出的伤害依次传给其余敌人
p3('p4.sleeve', {level: 20, stage: 0, allyRobe: 5}, ({bm, a, ally, foes, at}) => {
  at({start: true});
  at(cast2(bm, ally, 160, 0));
  at(cast2(bm, ally, 160, 0, x => { x._yunSleeve = true; }));
  Y.wake(ally);
  foes[0].setHp(1000);
  at(cast2(bm, ally, 160, 0, x => { x._yunSleeve = true; }));
});
// 空袖藏星：借出场队友会的普通技能（天衣铺战前设置，没醒 1 个、醒 3 个）；醒着用借来的技能时物攻／魔攻至少取主人的
p3('p4.borrow', {level: 45, stage: 0, robe: 6}, ({bm, a, ally, foes, at}) => {
  Y.setting(a).borrow = [{owner: 1, skill: 311}, {owner: 1, skill: 160}];
  const m = () => [311, 160].map(id => a.meetsSkillConditions(w.$dataSkills[id]));
  at({start: true, skills: a.skills().map(s => s.id).filter(id => id < 10270), meets: m()});
  at(cast2(bm, a, 311, 1));
  Y.wake(a);
  at({woke: true, skills: a.skills().map(s => s.id).filter(id => id < 10270), meets: m()});
  at(cast2(bm, a, 311, 1));
  at(cast2(bm, a, 160, 1));
});
// 九曲回针：针眼（战前设置）觉醒时清冷却、每回合一次越过冷却；用过针眼后，用别的技能（每回合最多 3 种）各让针眼冷却 −1
p3('p4.eye', {level: 45, stage: 0, robe: 7}, ({bm, a, ally, foes, at}) => {
  Y.setting(a).eye = 10271;
  const m = () => [10271].map(id => { a.setMp(a.mmp); return a.meetsSkillConditions(w.$dataSkills[id]); });
  at({start: true, cds: cds(a), meets: m()});
  at({...castKeep(bm, a, 10271, 1), cds: cds(a), meets: m()});
  Y.wake(a);
  at({woke: true, cds: cds(a), meets: m()});
  at({...castKeep(bm, a, 10271, 1), cds: cds(a), meets: m()});
  at({...castKeep(bm, a, 10271, 1), cds: cds(a), meets: m()});
  at({...castKeep(bm, a, 10270, 1), cds: cds(a), meets: m()});
  at({...castKeep(bm, a, 10270, 1), cds: cds(a), meets: m()});
  at({...castKeep(bm, a, 1, 1), cds: cds(a), meets: m()});
});
// 孤灯照众：没醒时自己每回合第一次新得的普通增益分给全队；醒着时任何人新得的普通增益（每回合最多 3 种）分给全队（含敌人得到的，见 O 项）
p3('p4.lamp', {level: 20, stage: 0, allyRobe: 10}, ({bm, a, ally, foes, at}) => {
  at({start: true, party: party3()});
  ally.addState(55); at({party: party3()});
  ally.addState(43); at({party: party3()});
  a.addState(64); at({party: party3()});
  Y.wake(ally);
  foes[1].addState(65); at({party: party3()});
  a.addState(72); a.addState(78); at({party: party3()});
  ally.addState(82); at({party: party3()});
});
process.exit(finish(host, 'yunshang.json', {hostScope: '真实 BattleManager／Game_Action（Math.random 0.5）；云裳第一期＋第二期 A 批＋B 批', cases}) ? 0 : 1);
