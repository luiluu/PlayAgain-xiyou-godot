'use strict';
// 【cc·八戒·未经审查】技能熟练度期三参照：各角色模块对 YEP_SkillMasteryLevels 的包装。
// ① raven.data：渡鸦 10122～10139 的运行时熟练度设定（installNativeRavenRuntime finishRavenDatabaseCompatibility／refreshMasteryLimit）：
//    上限（变量 8 为 0／5／20）、所需次数、伤害、MP／TP／HP 费用、冷却公式；
// ② raven.level／cost／gain：渡鸦 Game_Actor.skillMasteryLevel 夹 R.masteryCap、skillMpCost／TpCost 的熟练度折扣、战斗里涨熟练度；
// ③ sukuna.*：宿傩 10229～10238 读来源技能的等级（masterySource）并夹变量 8；onAllActionsEnd 照原链（原始等级涨、包装后比较）；
// ④ garou.*：饿狼 Game_BattlerBase.skillMasteryLevel 借主拳（_garouMasterySource）——装在 Game_Actor 自有的包装之后，看角色时有没有生效；
//    G.advance 的熟练度继承（replaces）；
// ⑤ alien.*：异化无面／百相 Game_Actor.skillMasteryLevel 取 min——传编号与传技能对象两种调用；
// ⑥ notice：通告读的是包装后的等级（宿傩派生技能原始等级涨了不报）。
// 新局（Math.random 0.5），只在内存；产物 .sandbox/skill_mastery3.json，拷成 tests/fixtures/skill_mastery3_oracle.json（不接入全量同步）。
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
const BIG = 1e9, TROOP = 3, RAVEN = 167, SUKUNA = 172, GAROU = 173;
const R = w.CodexRaven, G = w.CodexGarou, A = w.CodexAlienation;
if (!R || !G || !A) throw new Error('渡鸦／饿狼／异化模块未安装');
const anims = [];
const startAnimation = w.Game_Battler.prototype.startAnimation;
w.Game_Battler.prototype.startAnimation = function (id) { anims.push({who: this.isActor() ? 'a' + this.actorId() : 'e' + this.index(), id}); return startAnimation.apply(this, arguments); };
const uncap = () => w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');

// 新局；队伍 ids（生命加 BIG）；敌群 3 每只生命加 BIG
function battle(ids, vars) {
  newGame(); uncap();
  for (const [k, v] of vars || []) w.$gameVariables.setValue(k, v);
  w.eval('$gameParty._actors.length = 0;');
  ids.forEach(id => w.$gameParty.addActor(id));
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  if (w.CodexYunshang) w.CodexYunshang._acted = [];
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) { b._paramPlus[0] = BIG; b.need_refresh = true; b.refresh(); b.recoverAll(); }
  return {bm, foes: w.$gameTroop.members()};
}
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
  user.onAllActionsEnd();
}
const raw = (b, id) => ({level: (b._skillMasteryLevels || {})[id] || 0, uses: (b._skillMasteryUses || {})[id] || 0});
const cases = [];

// ① 渡鸦技能的熟练度设定（变量 8：0／5／20）
cases.push(makeCase('raven.data', {ids: [10122, 10139], var8: [0, 5, 20]}, () => {
  newGame();
  const a = w.$gameActors.actor(1), out = {};
  for (const v8 of [0, 5, 20]) {
    w.$gameVariables.setValue(8, v8);
    const rows = {};
    for (let id = 10122; id <= 10139; id++) {
      const s = w.$dataSkills[id];
      rows[id] = [s.masteryMaxLevel, s.masteryFormula.call(a, 1, s), s.masteryFormula.call(a, 3, s), s.masteryDamage.call(a, 1000, 3, s),
        s.masteryMpCost.call(a, 100, 3, s), s.masteryTpCost.call(a, 100, 3, s), s.masteryHpCost.call(a, 100, 3, s), s.masteryCooldown.call(a, 5, 3, s)];
    }
    out[v8] = rows;
  }
  return out;
}));
// ② 渡鸦：原始等级 12、变量 8＝5 时的包装等级（编号、技能对象）、是否满级；普通角色同样写法不夹
cases.push(makeCase('raven.level', {raw: 12, var8: 5}, () => {
  newGame();
  w.$gameVariables.setValue(8, 5);
  const out = {};
  for (const id of [RAVEN, 1]) {
    const a = w.$gameActors.actor(id);
    a.checkSkillMasteryLevels(); a._skillMasteryLevels[10122] = 12; a._skillMasteryLevels[10127] = 3;
    out[id] = {num: a.skillMasteryLevel(10122), obj: a.skillMasteryLevel(w.$dataSkills[10122]), maxed: a.isMaxedSkillMasteryLevel(10122),
      other: a.skillMasteryLevel(10127), rate: round(a.skillMasteryRate(10122))};
  }
  return out;
}));
// 渡鸦 MP／TP 费用：熟练度 0／3／7／20（变量 8＝20）
cases.push(makeCase('raven.cost', {levels: [0, 3, 7, 20], var8: 20}, () => {
  newGame(); uncap();
  w.$gameVariables.setValue(8, 20);
  const a = w.$gameActors.actor(RAVEN); a.changeLevel(60, false); a.recoverAll();
  const out = {};
  for (const lv of [0, 3, 7, 20]) {
    const row = {};
    for (let id = 10122; id <= 10127; id++) { a.setSkillMasteryLevel(id, lv); row[id] = [a.skillMasteryLevel(id), a.skillMpCost(w.$dataSkills[id]), a.skillTpCost(w.$dataSkills[id])]; }
    out[lv] = row;
  }
  return {mmp: a.mmp, out};
}));
// 渡鸦战斗里用 10122 共 14 次（变量 8＝2：升到 2 级后满级）
cases.push(makeCase('raven.gain', {skill: 10122, casts: 30, var8: 2}, () => {
  const {bm} = battle([RAVEN], [[8, 2]]);
  const a = w.$gameActors.actor(RAVEN), steps = [];
  for (let i = 0; i < 30; i++) { anims.length = 0; act(bm, a, 10122, 0); steps.push({...raw(a, 10122), lv: a.skillMasteryLevel(10122), anims: anims.filter(x => x.id === 742).length}); }
  return {steps};
}));
// ③ 宿傩：来源技能 10229 原始 4 级、10234 原始 9 级；变量 8 为 0／3
cases.push(makeCase('sukuna.level', {raw: {10229: 4, 10234: 9, 10231: 2}, var8: [0, 3]}, () => {
  const out = {};
  for (const v8 of [0, 3]) {
    newGame(); w.$gameVariables.setValue(8, v8);
    const row = {};
    for (const id of [SUKUNA, 1]) {
      const a = w.$gameActors.actor(id);
      a.checkSkillMasteryLevels(); Object.assign(a._skillMasteryLevels, {10229: 4, 10234: 9, 10231: 2});
      row[id] = {};
      for (const sid of [10229, 10230, 10231, 10232, 10233, 10234, 10237, 10238, 10239])
        row[id][sid] = [a.skillMasteryLevel(sid), a.skillMasteryLevel(w.$dataSkills[sid]), a.isMaxedSkillMasteryLevel(sid)];
    }
    out[v8] = row;
  }
  return out;
}));
// 宿傩：战斗里 onAllActionsEnd 计 10234（派生斩，读 10229 的等级）与 10229 各若干次
cases.push(makeCase('sukuna.gain', {queue: [10234, 10229], rounds: 14}, () => {
  battle([SUKUNA]);
  const a = w.$gameActors.actor(SUKUNA), steps = [];
  for (let i = 0; i < 14; i++) {
    anims.length = 0; a._actionMastery = i % 2 ? [10234] : [10234, 10229]; a.onAllActionsEnd();
    steps.push({s34: raw(a, 10234), s29: raw(a, 10229), lv34: a.skillMasteryLevel(10234), anims: anims.filter(x => x.id === 742).length});
  }
  return {steps};
}));
// ④ 饿狼：主拳原始 3 级，追击技能 0 级；_garouMasterySource 指向主拳时，角色的 skillMasteryLevel 与 Game_BattlerBase 那一层各读多少
cases.push(makeCase('garou.borrow', {mainLevel: 3}, () => {
  newGame(); uncap();
  const a = w.$gameActors.actor(GAROU); a._AdvancedNum = 2; a.changeLevel(60, false); G.sync(a);
  const main = G.main(a), other = 10262;
  a.setSkillMasteryLevel(main, 3);
  a._garouMasterySource = main;
  const out = {main, own: Object.prototype.hasOwnProperty.call(w.Game_Actor.prototype, 'skillMasteryLevel'),
    actor: a.skillMasteryLevel(other), actorObj: a.skillMasteryLevel(w.$dataSkills[other]),
    base: w.Game_BattlerBase.prototype.skillMasteryLevel.call(a, other)};
  delete a._garouMasterySource;
  out.after = a.skillMasteryLevel(other);
  return out;
}));
// 饿狼进阶继承：每一阶前给被替换的技能写等级／次数，进阶后看新技能
cases.push(makeCase('garou.advance', {}, () => {
  newGame(); uncap();
  w.$gameSwitches.setValue(2494, true);
  const a = w.$gameActors.actor(GAROU);
  if (!G.recruit()) throw new Error('招募失败');
  const keys = {}; (Array.isArray(G.config.skills) ? G.config.skills : Object.values(G.config.skills)).forEach(s => { keys[s.key] = s.database_id; });
  const steps = [];
  for (let st = 0; st < 6; st++) {
    const next = G.config.stages[st + 1];
    a.changeLevel(next.minimum_level, false);
    a._garouBreakthroughs = next.cumulative_breakthroughs;
    if (st === 5) w.$gameParty.gainItem(w.$dataItems[2939], 1);
    // 现有技能（10250～10261）按编号写不同的等级／次数（次数 5 不够 6、不升级；10256 写 7 次：继承后 setSkillMasteryUses 够数升一级）
    for (let id = 10250; id <= 10261; id++) if (a._skills.indexOf(id) >= 0 && !(a._skillMasteryLevels || {})[id]) {
      a.setSkillMasteryLevel(id, id - 10248 + st); a.setSkillMasteryUses(id, id === 10256 ? 5 : 2); }
    if (a._skills.indexOf(10256) >= 0) { a.checkSkillMasteryLevels(); a._skillMasteryUses[10256] = 7; }
    const result = G.advance(a, st);
    const lv = {};
    for (let id = 10250; id <= 10261; id++) if (a._skillMasteryLevels && a._skillMasteryLevels[id] !== undefined) lv[id] = [a._skillMasteryLevels[id], a._skillMasteryUses[id]];
    steps.push({result, stage: G.stage(a), lv});
  }
  return {steps};
}));
// ⑤ 异化无面（借队友 8 的 1924）、百相（observed 1926）：自己原始等级 50，队友 8 原始 10、等级 30；本人 99 级
function alienSetup(affix, config) {
  newGame(); uncap();
  const a = w.$gameActors.actor(1), b = w.$gameActors.actor(8);
  a.changeLevel(99, false); b.changeLevel(30, false);
  b.learnSkill(1924); b.learnSkill(1926);
  const item = A.create('w', 1044, 'boss', affix);
  A.mark(item).config = JSON.parse(JSON.stringify(config));
  a._equips[0].setObject(item);
  A.lockParty();
  for (const x of [a, b]) { x.checkSkillMasteryLevels(); x._skillMasteryLevels[1924] = x === a ? 50 : 10; x._skillMasteryLevels[1926] = x === a ? 50 : 10; x._skillMasteryLevels[9] = x === a ? 50 : 10; }
  return {a, b};
}
cases.push(makeCase('alien.faceless', {pairs: [[8, 1924]]}, () => {
  const {a} = alienSetup('faceless', {actorId: 1, pairs: [{ownerId: 8, skillId: 1924, replaceId: 160}]});
  return {num: a.skillMasteryLevel(1924), obj: a.skillMasteryLevel(w.$dataSkills[1924]), other: a.skillMasteryLevel(9),
    maxed: a.isMaxedSkillMasteryLevel(1924), rate: round(a.skillMasteryRate(1924))};
}));
cases.push(makeCase('alien.mimic', {observed: [1926]}, () => {
  const {a} = alienSetup('mimic', {actorId: 1, replace: 160});
  w.$gameParty._inBattle = true;
  const d = A.forActor(a); d.observed = [1926]; d.selected = 1926;
  a.changeLevel(40, false);
  return {num: a.skillMasteryLevel(1926), obj: a.skillMasteryLevel(w.$dataSkills[1926]), other: a.skillMasteryLevel(9)};
}));
// ⑥ 通告：宿傩派生技能 10234 原始等级涨了（读 10229），不报；10229 自己涨报
function notices(fn) {
  const rows = [], on = e => rows.push(e.detail);
  w.document.addEventListener('codex-skill-level-up', on);
  return Promise.resolve().then(fn).then(() => new Promise(r => setTimeout(r, 0))).then(() => { w.document.removeEventListener('codex-skill-level-up', on); return rows; });
}
(async () => {
  let c;
  try {
    newGame();
    const a = w.$gameActors.actor(SUKUNA);
    const rows = await notices(() => { a.setSkillMasteryLevel(10234, 5); a.setSkillMasteryLevel(10229, 2); });
    const raven = w.$gameActors.actor(RAVEN);
    w.$gameVariables.setValue(8, 3);
    const capped = await notices(() => { raven.checkSkillMasteryLevels(); raven._skillMasteryLevels[10122] = 3; raven.setSkillMasteryLevel(10122, 5); });
    c = {id: 'notice', setup: {}, observed: JSON.parse(JSON.stringify({rows, capped, raw: raw(raven, 10122)})), errors: []};
  } catch (e) { c = {id: 'notice', setup: {}, observed: null, errors: [String(e && e.stack || e).slice(0, 1500)]}; }
  cases.push(c);
  process.exit(finish(host, 'skill_mastery3.json', {hostScope: '真实 BattleManager／Game_Action（Math.random 0.5）；YEP_SkillMasteryLevels 期三（角色模块包装）', cases}) ? 0 : 1);
})();
