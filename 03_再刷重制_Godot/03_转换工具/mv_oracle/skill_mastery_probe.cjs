'use strict';
// 【cc·八戒·未经审查】技能熟练度 YEP_SkillMasteryLevels v1.00（插件参数＋技能备注）期一参照：
// ① table：每个技能的熟练度上限 masteryMaxLevel、升级所需次数 masteryFormula(1／2／5)、伤害公式 masteryDamage(1000, 0／1／3)
//    （主体是新局的 1 号角色，没有熟练度；只列与默认不同的技能）；
// ② gain.*：战斗里用技能（paySkillCost 记一笔，onAllActionsEnd 计一次使用、够数升级、升级放动画 742）；
//    变量 13＝1 时按变量 8 夹等级；敌人也涨；
// ③ damage.*：熟练度等级 0／1／3 时同一行动的扣血（installDamageElementRuntime 的 mastered 步骤），含治疗与固定伤害；
// ④ save：熟练度随存档往返。
// 真实 BattleManager／Game_Action（Math.random 0.5）；只在内存，产物 .sandbox/skill_mastery.json，
// 拷成 tests/fixtures/skill_mastery_oracle.json（不接入全量同步）。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
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
const BIG = 1e9, TROOP = 3;
const anims = [];
const startAnimation = w.Game_Battler.prototype.startAnimation;
w.Game_Battler.prototype.startAnimation = function (id) { anims.push({who: this.isActor() ? 'a' + this.actorId() : 'e' + this.index(), id}); return startAnimation.apply(this, arguments); };

// 新局、队伍只有 1 号（生命加 BIG）；敌群 3 每只生命加 BIG；vars：[[编号, 值]]
function battle(vars) {
  newGame();
  for (const [k, v] of vars || []) w.$gameVariables.setValue(k, v);
  w.eval('$gameParty._actors.length = 0;');
  w.$gameParty.addActor(1);
  const a = w.$gameActors.actor(1);
  a._paramPlus[0] = BIG;
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  if (w.CodexYunshang) w.CodexYunshang._acted = [];
  for (const e of w.$gameTroop.members()) e._paramPlus[0] = BIG;
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  return {bm, a, foes: w.$gameTroop.members()};
}
// 一次行动：startAction 到行动结束，然后 onAllActionsEnd（原版 processTurn 在行动者没有下一个行动时调）
let allEnd = 0;
const onAllActionsEnd = w.Game_Battler.prototype.onAllActionsEnd;
w.Game_Battler.prototype.onAllActionsEnd = function () { allEnd++; return onAllActionsEnd.apply(this, arguments); };
function act(bm, user, skillId, targetIndex) {
  const action = new w.Game_Action(user); action.setSkill(skillId); action.setTarget(targetIndex);
  user._actions = [action]; bm._subject = user; bm._action = null;
  user.setMp(user.mmp); user.setTp(100);
  bm.startAction();
  for (let i = 0; i < 20000; i++) {
    const ph = bm._phase;
    if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
    else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
  }
  const before = allEnd;
  user.onAllActionsEnd();
  return allEnd - before;
}
function record(fn) {
  const log = [], old = w.Game_Action.prototype.executeHpDamage;
  w.Game_Action.prototype.executeHpDamage = function (target, value) { log.push(value); return old.apply(this, arguments); };
  try { fn(); } finally { w.Game_Action.prototype.executeHpDamage = old; }
  return log;
}
const snap = (b, id) => ({level: b.skillMasteryLevel(id), uses: b.skillMasteryUses(id), max: b.skillMasteryUsageMax(id)});
const cases = [];

// ① 全部技能（名字非空）的解析结果；默认行列在 default，其余列在 rows
cases.push(makeCase('table', {subject: 'a1'}, () => {
  newGame();
  const a = w.$gameActors.actor(1), action = new w.Game_Action(a), S = w.$dataSkills;
  const row = s => [s.masteryMaxLevel, ...[1, 2, 5].map(l => round(s.masteryFormula.call(a, l, s))),
    ...[0, 1, 3].map(l => round(s.masteryDamage.call(action, 1000, l, s)))];
  const def = JSON.stringify(row(S[1])), rows = {};
  let count = 0;
  for (let id = 1; id < S.length; id++) {
    const s = S[id]; if (!s || !s.name) continue; count++;
    const r = row(s); if (JSON.stringify(r) !== def) rows[id] = r;
  }
  return {count, default: row(S[1]), rows};
}));
// ② 涨熟练度：每次行动后的等级、本级已用次数、本级所需次数；升级动画
const GAINS = [['attack', 1, 14, []], ['magic', 9, 7, []], ['custom', 4938, 14, []], ['heal', 8, 7, []], ['guard', 2, 3, []],
  ['cap1', 1, 14, [[13, 1], [8, 1]]], ['cap0', 1, 8, [[13, 1], [8, 0]]], ['capoff', 1, 8, [[13, 0], [8, 1]]]];
for (const [name, skill, casts, vars] of GAINS) {
  cases.push(makeCase(`gain.${name}`, {skill, casts, vars, user: 'a1', target: 0}, () => {
    const {bm, a} = battle(vars);
    const steps = [];
    for (let i = 0; i < casts; i++) {
      anims.length = 0;
      const ends = act(bm, a, skill, skill === 8 || skill === 2 ? a.index() : 0);
      steps.push({...snap(a, skill), ends, anims: anims.filter(x => x.id === 742)});
    }
    return {steps};
  }));
}
cases.push(makeCase('gain.enemy', {skill: 1, casts: 7, user: 'e0'}, () => {
  const {bm, a, foes} = battle();
  const steps = [];
  for (let i = 0; i < 7; i++) { anims.length = 0; act(bm, foes[0], 1, a.index()); steps.push({...snap(foes[0], 1), anims: anims.filter(x => x.id === 742)}); }
  return {steps};
}));
// 菜单（不在战斗）付费不记
cases.push(makeCase('gain.menu', {skill: 8}, () => {
  newGame();
  const a = w.$gameActors.actor(1);
  a.setMp(a.mmp); a.paySkillCost(w.$dataSkills[8]); a.onAllActionsEnd();
  return snap(a, 8);
}));
// ③ 伤害：先 setSkillMasteryLevel，同一行动的扣血
const DMG = [['attack', 1, 0], ['magic', 9, 0], ['custom', 4938, 0], ['heal', 8, 'self'], ['fixed', 14, 0]];
for (const [name, skill, tgt] of DMG) {
  cases.push(makeCase(`damage.${name}`, {skill, levels: [0, 1, 3]}, () => {
    const out = {};
    for (const lv of [0, 1, 3]) {
      const {bm, a} = battle();
      a.setSkillMasteryLevel(skill, lv);
      if (tgt === 'self') a.setHp(1);
      out[lv] = {log: record(() => act(bm, a, skill, tgt === 'self' ? a.index() : 0)), after: snap(a, skill)};
    }
    return out;
  }));
}
// ④ 存档往返
cases.push(makeCase('save', {}, () => {
  newGame();
  const a = w.$gameActors.actor(1);
  a.setSkillMasteryLevel(1, 4); a.setSkillMasteryUses(1, 3); a.setSkillMasteryLevel(9, 2);
  const json = host.encode();
  host.restore(json);
  const b = w.$gameActors.actor(1);
  return {a1: snap(b, 1), a9: snap(b, 9), raw: {levels: b._skillMasteryLevels, uses: b._skillMasteryUses}};
}));
// ⑤ 期二：升级通告（installSkillLevelNoticeRuntime：同一微任务里同一角色同一技能合并成一行 from→to；只有角色；新局、读档期间不报）
//    与战力（CodexCombatPower.actor：签名里有 _skillMasteryLevels，改熟练度后不强制也重算）
function notices(fn) {
  const rows = [], on = e => rows.push(e.detail);
  w.document.addEventListener('codex-skill-level-up', on);
  return Promise.resolve().then(fn).then(() => new Promise(r => setTimeout(r, 0))).then(() => { w.document.removeEventListener('codex-skill-level-up', on); return rows; });
}
const asyncCases = [];
asyncCases.push(['notice.battle', {skill: 1, casts: 13, user: 'a1'}, async () => {
  const {bm, a, foes} = battle();
  const out = [];
  for (let i = 0; i < 13; i++) out.push(await notices(() => act(bm, a, 1, 0)));
  out.push(await notices(() => { for (let i = 0; i < 7; i++) act(bm, foes[0], 1, a.index()); }));
  return {steps: out};
}]);
asyncCases.push(['notice.set', {}, async () => {
  newGame();
  const a = w.$gameActors.actor(1);
  const merged = await notices(() => { a.setSkillMasteryLevel(9, 2); a.setSkillMasteryLevel(9, 4); a.setSkillMasteryLevel(1, 1); });
  const down = await notices(() => a.setSkillMasteryLevel(9, 1));
  const config = (w.ConfigManager.codexSkillLevelNotice = false, await notices(() => a.setSkillMasteryLevel(9, 3)));
  w.ConfigManager.codexSkillLevelNotice = true;
  const json = host.encode();
  const load = await notices(() => host.restore(json));
  return {merged, down, config, load, levels: {s9: w.$gameActors.actor(1).skillMasteryLevel(9)}};
}]);
asyncCases.push(['power', {actor: 1, level: 30, skill: 1, mastery: 3}, async () => {
  newGame();
  const P = w.CodexCombatPower, a = w.$gameActors.actor(1);
  a.changeLevel(30, false); a.recoverAll();
  const before = P.actor(a, true);
  a.setSkillMasteryLevel(1, 3);
  const cached = P.actor(a), forced = P.actor(a, true);
  return {before: before.total, cached: cached.total, forced: forced.total, burst: [before.evaluation.burst, forced.evaluation.burst]};
}]);
(async () => {
  for (const [id, setup, fn] of asyncCases) {
    let c;
    try { c = {id, setup, observed: JSON.parse(JSON.stringify(await fn(), (k, v) => typeof v === 'number' ? round(v) : v)), errors: []}; }
    catch (e) { c = {id, setup, observed: null, errors: [String(e && e.stack || e).slice(0, 1500)]}; }
    cases.push(c);
  }
  process.exit(finish(host, 'skill_mastery.json', {hostScope: '真实 BattleManager／Game_Action（Math.random 0.5）；YEP_SkillMasteryLevels 期一、期二（通告、战力）', cases}) ? 0 : 1);
})();
