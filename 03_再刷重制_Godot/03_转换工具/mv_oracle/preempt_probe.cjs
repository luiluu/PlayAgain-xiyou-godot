'use strict';
// 【cc·哪吒·未经审查】先制／偷袭（BattleManager.onEncounter 与开战顺序）定向参照（preempt1）。
// 量：① 先制率／偷袭率公式（Game_Party.ratePreemptive／rateSurprise 基础 0.05／0.03 对调、队伍能力 3 ×4／2 清零、dsPassiveSkill passivePREE 加／passiveASUP 按比例减、
//   0～1 夹值、agility 用谁〔未进战斗时 members() 是整个名册，不是出战栏〕、倒下／后备成员的被动算不算）；
// ② onEncounter 的掷骰（两次 Math.random 总是各取一次、先制与偷袭互斥、临界值 < 严格小于）；
// ③ 开战后第一回合的行动顺序（偷袭＝只排敌人、先制＝只排我方，OTB 的「下个回合」仍是全员；追加行动照常）、开场文字、能否输入；
// ④ 先制时逃跑必成功、endTurn 清标志。
// 只记公式与结构；原版没有概率采样，不用随机采样糊。全内存新局，只写 .sandbox/preempt.json，拷成 tests/fixtures/preempt_oracle.json（冻结参照，不进 PROBES，专项 xiyou_preempt）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');
const stub = new Proxy(function () {}, {get: (_, k) => k === '_waitCount' ? 0 : (() => false), set: () => true});
const sprites = new Map();
w.Game_Battler.prototype.battler = function () {
  if (!sprites.has(this)) sprites.set(this, new Proxy({x: 0, y: 0, _homeX: 0, _homeY: 0, width: 64, height: 64, scale: {x: 1, y: 1}, anchor: {x: 0.5, y: 1}, opacity: 255},
    {get: (t, k) => k in t ? t[k] : (() => false), set: (t, k, v) => {t[k] = v; return true;}}));
  return sprites.get(this);
};
w.BattleManager.actionBattleHud = () => true;
w.BattleManager.otbDisplayWindow = () => stub;
if (!w.$) w.$ = {};
w.$.toaster = () => {};
let seq = [0.5], pos = 0, draws = 0;
const rnd = () => { draws++; const v = seq[pos % seq.length]; pos++; return v; };
w.Math.random = rnd;
const setSeq = s => { seq = s; pos = 0; draws = 0; w.Math.random = rnd; };  // newGame 会把 Math.random 重置成 0.5，每次设序列都重新装
const errors = [];
const keyOf = b => !b ? null : (b.isActor() ? 'A' + b.actorId() : 'E' + b.index());
// 开一场战：cfg = {party:[角色号…]（名册）, battle:[出战栏…]（默认＝名册前 4）, agi:{角色号:敏捷加值}, troopAgi:敌人敏捷加值, skills:{角色号:[技能号]}, ability:{角色号:[队伍能力号]}, dead:[角色号], troop}
function setupBattle(cfg) {
  newGame(); setSeq([0.5]); w.Math.random = w.Math.random;
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.$gameSwitches.setValue(2494, true);
  const party = cfg.party || [1, 8, 9, 10], battle = cfg.battle || party.slice(0, 4);
  w.eval(`$gameParty._actors=[${party}]; $gameParty._battleMembers=[${battle},${battle.length < 5 ? '0' : ''}];`.replace(',]', ']'));
  for (const id of party) { const a = w.$gameActors.actor(id); a.changeLevel(60, false); a._skills = w.eval('[]'); a._states = w.eval('[]'); }
  for (const [id, delta] of Object.entries(cfg.agi || {})) w.$gameActors.actor(+id)._paramPlus[6] = delta;
  for (const [id, list] of Object.entries(cfg.skills || {})) { const a = w.$gameActors.actor(+id); for (const s of list) a.learnSkill(s); }
  // 队伍能力（特性 64）：用冻结数据里真带该特性的护甲（163＝防偷袭 2、316＝先制率上升 3、3796＝两个都有）；ability: {角色号: [护甲号]}
  for (const [id, list] of Object.entries(cfg.ability || {})) {
    const a = w.$gameActors.actor(+id); a.canEquip = () => true;
    for (const armorId of list) { const base = w.$dataArmors[armorId]; a._equips[a.equipSlots().indexOf(base.etypeId)].setObject(base); }
  }
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(cfg.troop || 3, true, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.SceneManager._scene = {_otbDisplayWindow: stub};
  for (const a of party.map(id => w.$gameActors.actor(id))) {
    a.need_refresh = true; a.need_refresh_param = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]; a.refresh();
    if (a.initPassiveCache) a.initPassiveCache(); if (a.refreshPassiveCache) a.refreshPassiveCache(); a.recoverAll();
    for (const [id, list] of Object.entries(cfg.ability || {})) if (+id === a.actorId()) for (const armorId of list) { const base = w.$dataArmors[armorId]; a._equips[a.equipSlots().indexOf(base.etypeId)].setObject(base); }
  }
  for (const id of cfg.dead || []) { const a = w.$gameActors.actor(id); a.setHp(0); }
  if (cfg.gap !== undefined) {  // 敌方平均敏捷调到「我方平均 + gap」（我方按全名册 members() 算，同 Game_Party.agility）；敌人能力值有倍率，逐步逼近
    const target = w.$gameParty.agility() + cfg.gap;
    for (let i = 0; i < 12; i++) {
      const diff = target - w.$gameTroop.agility();
      if (Math.abs(diff) < 1e-9) break;
      for (const e of w.$gameTroop.members()) { e._paramPlus[6] += diff / (i < 6 ? 1 : 2); e.need_refresh = true; e.refresh(); if (e.param_mark_dirty) e.param_mark_dirty(); }
    }
  }
  if (cfg.troopAgi !== undefined) for (const e of w.$gameTroop.members()) { e._paramPlus[6] = cfg.troopAgi; e.need_refresh = true; e.refresh(); }
  return bm;
}
const catching = (fn) => { try { return fn(); } catch (e) { errors.push(String(e && e.stack || e).split('\n').slice(0, 3).join(' | ')); return null; } };
function rates(cfg) {
  const bm = setupBattle(cfg), p = w.$gameParty, t = w.$gameTroop;
  const o = {
    partyMembers: p.members().map(a => a.actorId()), battleMembers: p.battleMembers().map(a => a.actorId()), inBattle: p.inBattle(),
    partyAgi: p.agility(), troopAgi: t.agility(), troopMembers: t.members().length,
    ability: {2: p.hasCancelSurprise(), 3: p.hasRaisePreemptive()},
    passive: {}, ratePreemptive: bm.ratePreemptive(), rateSurprise: bm.rateSurprise(),
    gameRatePre: p.ratePreemptive(t.agility()), gameRateSur: p.rateSurprise(t.agility())
  };
  for (const a of p.members()) {
    let pre = 0, asup = 0;
    catching(() => { a.iteratePassiveSkill('passivePREE', m => { pre += Number(m); }); a.iteratePassiveSkill('passiveASUP', m => { asup += Number(m); }); });
    o.passive[a.actorId()] = {pre, asup};
  }
  return o;
}
const cases = [];
const add = (id, cfg, fn) => cases.push(makeCase(id, cfg, () => { const r = fn(); return Object.assign({sourceErrors: errors.splice(0)}, r); }));
// ① 公式
const PA = {party: [1, 8, 9, 10]};
add('rate.base', {}, () => rates({}));
for (const d of [-20, -1, 0, 1, 20]) add(`rate.gap.troop${d >= 0 ? '+' : ''}${d}`, {d}, () => rates({gap: d}));  // 敌方平均敏捷 = 我方平均 + d：相等时算「我方 ≥」
add('rate.gap.troopHigh.ab3', {}, () => rates({gap: 50, ability: {1: [316]}}));
add('rate.gap.troopHigh.ab2', {}, () => rates({gap: 50, ability: {1: [163]}}));
add('rate.gap.troopHigh.pre', {}, () => rates({gap: 50, skills: {1: [1110]}}));
add('rate.gap.troopHigh.asup', {}, () => rates({gap: 50, skills: {1: [1053]}}));
for (const [name, ab] of [['cancelSurprise', [163]], ['raisePre', [316]], ['both', [3796]], ['onOneActor', [316]]]) add(`rate.ability.${name}`, {ab}, () => rates({ability: name === 'onOneActor' ? {10: ab} : {1: ab}}));
const PRE = [1110, 1113, 7849, 2782, 5937, 8017], ASUP = [1053, 1084, 1897, 2782, 5937, 8017];
for (const id of [1110, 7849, 2782, 5937, 8017, 1053, 1084, 1897]) add(`rate.skill.${id}`, {id}, () => rates({skills: {1: [id]}}));
add('rate.skill.preStack', {}, () => rates({skills: {1: [1110, 1113]}}));
add('rate.skill.preTwoActors', {}, () => rates({skills: {1: [1110], 8: [1113]}}));
add('rate.skill.pre100plus', {}, () => rates({skills: {1: [7849, 1110]}}));
add('rate.skill.asupStack', {}, () => rates({skills: {1: [1053], 8: [1084]}}));
add('rate.skill.preAndAsup', {}, () => rates({skills: {1: [2782]}}));
add('rate.skill.preWithAbility3', {}, () => rates({skills: {1: [1110]}, ability: {8: [316]}}));
add('rate.skill.asupWithBaseLowAgi', {}, () => rates({skills: {1: [1053]}, gap: 50}));
add('rate.skill.asupWithAbility2', {}, () => rates({skills: {1: [1053]}, ability: {8: [163]}}));
add('rate.skill.reserveMember', {}, () => rates({party: [1, 8, 9, 10, 11], battle: [1, 8, 9, 10], skills: {11: [7849, 1053]}}));
add('rate.skill.deadMember', {}, () => rates({skills: {8: [7849]}, dead: [8]}));
add('rate.reserveAgi.high', {}, () => rates({party: [1, 8, 9, 10, 11], battle: [1, 8, 9, 10], agi: {11: 500}}));
add('rate.reserveAgi.low', {}, () => rates({party: [1, 8, 9, 10, 11], battle: [1, 8, 9, 10], agi: {11: -500}}));
for (const troop of [3, 165, 824]) add(`rate.troop.${troop}`, {troop}, () => rates({troop}));
// ② 掷骰
for (const [name, s] of [['preYes', [0.04, 0.02]], ['preYesSurYes', [0.04, 0.01]], ['sur', [0.06, 0.02]], ['neither', [0.06, 0.04]], ['preEdge', [0.05, 0.5]], ['surEdge', [0.5, 0.03]],
  ['zero', [0, 0]], ['one', [0.999, 0.999]], ['seq3', [0.5, 0.5, 0.01, 0.01]]]) add(`roll.${name}`, {s}, () => {
  const bm = setupBattle({}); setSeq(s);
  const r = {ratePre: bm.ratePreemptive(), rateSur: bm.rateSurprise()}; setSeq(s);
  bm.onEncounter();
  return {...r, preemptive: bm._preemptive, surprise: bm._surprise, draws};
});
for (const [name, cfg] of [['ab3', {ability: {1: [316]}}], ['ab2', {ability: {1: [163]}}], ['pre100', {skills: {1: [7849]}}], ['asup100sur', {skills: {1: [1053]}, gap: 50}]])
  for (const [rn, s] of [['lo', [0.19, 0.04]], ['mid', [0.5, 0.04]], ['hi', [0.999, 0.999]]]) add(`roll.${name}.${rn}`, {s}, () => {
    const bm = setupBattle(cfg); setSeq(s); const r = {ratePre: bm.ratePreemptive(), rateSur: bm.rateSurprise()}; setSeq(s); bm.onEncounter();
    return {...r, preemptive: bm._preemptive, surprise: bm._surprise, draws};
  });
// ③ 开战流程：startBattle → startInput（→ OTB startTurn）
function flow(flag, cfg) {
  const bm = setupBattle(cfg || {});
  bm._preemptive = flag === 'pre'; bm._surprise = flag === 'sur';
  w.$gameMessage.clear();
  const o = {};
  o.startBattle = catching(() => { bm.startBattle(); return true; });
  o.messages = (w.$gameMessage._texts || []).slice();
  o.phaseAfterStart = bm._phase;
  setSeq([0.5]);
  o.startInput = catching(() => { bm.startInput(); return true; });
  o.phase = bm._phase; o.turnCount = w.$gameTroop.turnCount();
  o.current = (bm._actionBattlers || []).map(keyOf);
  o.next = (bm._nextTurnActionBattlers || []).map(keyOf);
  o.flags = [bm._preemptive, bm._surprise];
  o.actorActionsMade = w.$gameParty.members().map(a => a._actions.length);
  o.enemyActionsMade = w.$gameTroop.members().map(a => a._actions.length);
  o.canInput = w.$gameParty.canInput();
  o.draws = draws;
  o.subject = keyOf(bm._subject);  // OTB startTurn 已取出第一位行动者，_actionBattlers 里不再有他
  o.isOTB = bm.isOTB();
  return o;
}
for (const flag of ['none', 'pre', 'sur']) {
  add(`flow.${flag}`, {flag}, () => flow(flag));
  add(`flow.${flag}.bigTroop`, {flag}, () => flow(flag, {troop: 824}));
}
add('flow.sur.deadMember', {}, () => flow('sur', {dead: [8]}));
add('flow.pre.deadMember', {}, () => flow('pre', {dead: [8]}));
add('flow.preExtraActions', {}, () => { w.$gameParty; const r = flow('pre', {}); return r; });
// ④ 逃跑、endTurn
function escapeCase(flag, rnd) {
  const bm = setupBattle({});
  bm._preemptive = flag === 'pre'; bm._surprise = flag === 'sur'; bm._escapeRatio = 0.1;
  const o = {};
  catching(() => { bm.startBattle(); });
  bm._preemptive = flag === 'pre'; bm._surprise = flag === 'sur'; bm._escapeRatio = 0.1;
  setSeq([rnd]); w.$gameParty.performEscape = () => {}; bm.displayEscapeSuccessMessage = () => {}; bm.displayEscapeFailureMessage = () => {};
  o.ok = catching(() => { bm.processEscape(); return true; });
  o.escaped = bm._escaped; o.draws = draws;
  return o;
}
for (const flag of ['none', 'pre', 'sur']) for (const rnd of [0.05, 0.99]) add(`escape.${flag}.r${rnd}`, {flag, rnd}, () => escapeCase(flag, rnd));
for (const flag of ['pre', 'sur']) add(`endTurn.${flag}`, {flag}, () => {
  const bm = setupBattle({}); catching(() => bm.startBattle());
  bm._preemptive = flag === 'pre'; bm._surprise = flag === 'sur';
  const o = {before: [bm._preemptive, bm._surprise]};
  catching(() => { bm.endTurn(); });
  o.after = [bm._preemptive, bm._surprise]; o.phase = bm._phase;
  return o;
});
const ok = finish(host, 'preempt.json', {cases});
process.exit(ok ? 0 : 1);
