'use strict';
// 178 哈基米（小猫剑圣，installImportedBalanceRuntime.js「小猫剑圣 v1.0」段，W.CodexCat）第一期：招募、能力值与被动、伤害公式。
// ① 招募：公共事件 9017 的 CodexCat.recruit()——学 6216、忘 6235，生成并装上独立法宝 7999「抱剑喵铃」（只给一次，记 $gameSystem），
//    没持剑时生成并装上练习剑 2，入队；第二次调用返回 false。号角 2899 在 178 入队后不能用（canUse）。
// ② 槽位：去掉副手（装备类型 2），不能双持。
// ③ 能力值：param 包装（学了 10442 且 10 级起速度 ×1.88；装着法宝 7999 时攻击／速度／幸运 ×1.6，取整夹值）；
//    持剑（学了 10441 且武器槽是剑 wtype 2）时剑的贡献翻倍：paramPlus（全量＋全量−去剑）、特性 11／21／23 的 1+(v−1)×2、
//    22／33／34／61 的 ×2、备注数值标签 ×2、元素增幅 ×2；sparam 6／7 ×0.8／×0.88。
// ④ 公式：CodexCat.formula(user,item,b)＝(atk×1500＋agi×3000)×权重×成长×(1＋熟练)×段倍率；熟练在新游戏为 0。
// 真实新游戏、Math.random 0.5，只在内存；产物 .sandbox/cat.json。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const C = w.CodexCat;
if (!C || C.ids.actor !== 178) throw new Error('小猫剑圣模块未安装');
const P = [0, 1, 2, 3, 4, 5, 6, 7], X = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
const r = v => round(v);
// 等级上限照 slice_probe 放开到 99
function uncap() {
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
}
function fresh() {
  newGame(); uncap();
  w.$gameActors._data[178] = null;
  return w.$gameActors.actor(178);
}
function equipInfo(a) {
  return a.equips().map((e, i) => e ? {slot: i, etype: a.equipSlots()[i], kind: w.DataManager.isWeapon(e) ? 'weapon' : 'armor',
    base: e._catProbeBase || e.baseItemId || e.id, level: e.level === undefined ? null : e.level, name: e.name} : null).filter(Boolean);
}
// 能力值读数：param／paramPlus／xparam／sparam、元素增幅（CodexElements.bonus）、被动缓存里与伤害有关的几项
function stats(a) {
  a.refresh();
  if (a.initPassiveCache) { a.initPassiveCache(); a.refreshPassiveCache(); }
  const pc = a._passiveCache || {};
  return {param: P.map(i => a.param(i)), paramPlus: P.map(i => r(a.paramPlus(i))), xparam: X.map(i => r(a.xparam(i))),
    sparam: X.map(i => r(a.sparam(i))), elementBonus: [1, 2, 3, 8].map(e => r(w.CodexElements.bonus(a, e))),
    attackTimesAdd: r(a.attackTimesAdd()), globalHarmRi: r(Number(pc.globalHarmRi || 0)), critHarmRi: r(Number(pc.critHarmRi || 0)),
    passiveKeys: Object.keys(pc).sort()};
}
// 把剑（数据库编号）直接装进武器槽（独立实例），绕过 canEquip，同 custom_params_probe
function putWeapon(a, id) {
  const before = w.$gameParty.weapons().slice();
  w.$gameParty.gainItem(w.$dataWeapons[id], 1);
  const it = w.$gameParty.weapons().find(x => before.indexOf(x) < 0) || w.$dataWeapons[id];
  it._catProbeBase = id;  // 带 <Prefixes> 的武器（56、1044）生成的实例 baseItemId 指向词缀合成记录，这里记下请求的数据库编号
  a._equips[0].setObject(it);
  w.$gameParty.loseItem(it, 1, false);
  return it;
}
function putRelic(a) {
  const before = w.$gameParty.armors().slice();
  w.$gameParty.gainItem(w.$dataArmors[C.ids.relic], 1);
  const it = w.$gameParty.armors().find(x => before.indexOf(x) < 0);
  const slot = a.equipSlots().indexOf(13);
  a._equips[slot].setObject(it);
  w.$gameParty.loseItem(it, 1, false);
  return it;
}
const cases = [];
cases.push(makeCase('module', {}, () => ({version: C.version, ids: C.ids})));
// ② 槽位与双持（刚生成）
cases.push(makeCase('slots', {actor: 178}, () => {
  const a = fresh();
  return {slots: a.equipSlots(), dual: a.isDualWield(), skills: a._skills.slice(), equips: equipInfo(a)};
}));
// ① 招募
cases.push(makeCase('recruit', {actor: 178, ce: C.ids.ce.recruit}, () => {
  const a = fresh();
  const hornBefore = w.$gameActors.actor(1).canUse(w.$dataItems[C.ids.horn]);
  const first = C.recruit();
  const second = C.recruit();
  const inv = {weapons: w.$gameParty.weapons().map(x => x.baseItemId || x.id), armors: w.$gameParty.armors().map(x => x.baseItemId || x.id)};
  return {first, second, party: w.$gameParty._actors.slice(), skills: a._skills.slice(), equips: equipInfo(a),
    relicGranted: !!w.$gameSystem._codexCatRelicGranted, starterGranted: !!a._codexCatStarterGranted, inventory: inv,
    hornBefore, hornAfter: w.$gameActors.actor(1).canUse(w.$dataItems[C.ids.horn]), level: a.level, stats: stats(a)};
}));
// ③ 能力值：配置 × 等级（同一实例连续升级）
const CONFIGS = {none: [], sword: ['sword2'], relic: ['relic'], both: ['sword2', 'relic'], sword56: ['sword56'],
  sword671: ['sword671'], sword1044: ['sword1044'], axe: ['weapon3']};
for (const [name, gear] of Object.entries(CONFIGS)) {
  cases.push(makeCase('stats.' + name, {actor: 178, gear, levels: [1, 9, 10, 35, 65, 99]}, () => {
    const a = fresh(); const rows = {};
    a.releaseUnequippableItems = function () {};  // 同 custom_params_probe：低等级／非剑类武器也留在槽里（Godot keep_unequippable）
    for (const g of gear) {
      if (g === 'relic') putRelic(a); else putWeapon(a, Number(g.replace(/\D+/, '')));
    }
    for (const lv of [1, 9, 10, 35, 65, 99]) {
      a.changeLevel(lv, false);
      rows[lv] = Object.assign({level: a.level, skills: a._skills.slice(), sword: C.hasSword(a), relic: C.hasRelic(a)}, stats(a));
    }
    return {equips: equipInfo(a), rows};
  }));
}
// ④ 公式：五个剑技 × 等级，未持剑与持练习剑（公式只读 atk／agi 与等级，目标不参与）
const SKILLS = [10437, 10438, 10439, 10440, 10445];
for (const gear of [[], ['sword2', 'relic']]) {
  cases.push(makeCase('formula.' + (gear.length ? 'equipped' : 'bare'), {actor: 178, gear, skills: SKILLS, levels: [1, 5, 10, 20, 30, 34, 35, 50, 81, 99]}, () => {
    const a = fresh();
    a.releaseUnequippableItems = function () {};
    if (gear.length) { putWeapon(a, 2); putRelic(a); }
    w.$gameTroop.setup(1);
    const t = w.$gameTroop.members()[0], rows = [];
    for (const lv of [1, 5, 10, 20, 30, 34, 35, 50, 81, 99]) {
      a.changeLevel(lv, false); a.refresh();
      for (const sid of SKILLS) {
        const x = new w.Game_Action(a); x.setSkill(sid);
        rows.push({level: lv, skill: sid, value: r(x.evalDamageFormula(t)), growth: r(C.growth(a)), mastery: C.mastery(a), atk: a.atk, agi: a.agi});
      }
    }
    return {rows};
  }));
}
// ⑤ 剑技连携（CAT BEGIN／CAT STRIKE，processActionSequence 包装）：真实 BattleManager 跑整个行动序列，敌群 2 第一个敌人。
// 每步记：C.trace（逐段 key／命中／伤害／暴击／是否连携段）、每段 CodexCat.formula 原值、之后的剑心层数与状态、目标的识破／剑痕标记与状态、
// 至圣斩冷却 holyReady。回合直接写 $gameTroop._turnCount（round()＝max(1, turnCount)）。防御步（技能 2）走 endAction 的喵铃。
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
const BIG_HP = 1e12;
// 五乘区修正（CodexZones，伤害里的 growthMultiplier）按数值平衡不移植（O-044），同 attack_element／settlement 探针关掉
w.eval('CodexZones.ENABLED=false;');
function chainBattle(level, learn, relic, extra) {
  const a = fresh();
  a.releaseUnequippableItems = function () {};
  a.changeLevel(level, false);
  putWeapon(a, 2);
  if (relic) putRelic(a);
  for (const s of learn) a.learnSkill(s);
  for (const s of extra.forget || []) a.forgetSkill(s);
  w.eval('$gameParty._actors=[];');
  w.$gameParty.addActor(178); w.$gameParty.addActor(1);
  for (const x of [a, w.$gameActors.actor(1)]) x._paramPlus[0] = BIG_HP;
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(2, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  w.CodexYunshang._acted = [];
  for (const e of w.$gameTroop.members()) { e._paramPlus[0] = BIG_HP; e._paramPlus[6] = extra.enemyAgiPlus || 0; }
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  return {bm, a, t: w.$gameTroop.members()[0]};
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
  return action;
}
const CAT_STATES = [2713, 2714, 2715, 2716, 2717];
function chainCase(name, level, learn, relic, steps, extra = {}) {
  cases.push(makeCase('chain.' + name, {actor: 178, troop: 2, target: 0, level, learn, relic, sword: 2, bigHp: BIG_HP, steps,
    forget: extra.forget || [], enemyAgiPlus: extra.enemyAgiPlus || 0}, () => {
    const {bm, a, t} = chainBattle(level, learn, relic, extra);
    const head = {skills: a._skills.slice(), atk: a.atk, agi: a.agi, cri: r(a.cri), hit: r(a.hit), level: a.level,
      enemy: {id: t.enemyId(), level: t.level === undefined ? null : t.level, params: P.map(i => t.param(i)), xparam: X.map(i => r(t.xparam(i))), hp: t.hp}};
    const old = C.formula, rows = [];
    let raw = [];
    C.formula = function () { const v = old.apply(this, arguments); raw.push(v); return v; };
    try {
      for (const st of steps) {
        w.$gameTroop._turnCount = st.round;
        a.setTp(100);
        C.trace = []; raw = [];
        const hp0 = t.hp, action = act(bm, a, st.skill, 0), cast = action._catCast;
        rows.push({skill: st.skill, round: st.round, trace: C.trace.slice(), raw: raw.slice(), hpLost: hp0 - t.hp,
          heart: C.heart(a), actorStates: CAT_STATES.filter(id => a.isStateAffected(id)), targetStates: CAT_STATES.filter(id => t.isStateAffected(id)),
          marks: JSON.parse(JSON.stringify(t._codexCatMarks || {})), holyReady: a._codexCatBattle ? a._codexCatBattle.holyReady : null,
          bellRound: a._codexCatBattle ? a._codexCatBattle.bellRound : null, ended: !!(cast && cast.ended), chain: !!(cast && cast.chain), tp: a.tp});
      }
    } finally { C.formula = old; C.trace = null; }
    return Object.assign(head, {rows});
  }));
}
const S = C.ids.skill;
chainCase('basic', 10, [S.slash, S.cross], false, [{skill: S.slash, round: 1}, {skill: S.slash, round: 1}, {skill: S.cross, round: 2}, {skill: S.cross, round: 4}]);
chainCase('noheart', 30, [S.slash, S.cross, S.flurry, S.holy, S.sword], false,
  [{skill: S.cross, round: 1}, {skill: S.slash, round: 1}, {skill: S.cross, round: 1}, {skill: S.flurry, round: 2}, {skill: S.holy, round: 2}, {skill: S.slash, round: 5}],
  {forget: [S.heart]});
chainCase('heart30', 30, [S.slash, S.cross, S.flurry, S.holy, S.sword], false,
  [{skill: S.cross, round: 1}, {skill: S.slash, round: 1}, {skill: S.cross, round: 1}, {skill: S.flurry, round: 2}, {skill: S.holy, round: 2}, {skill: S.slash, round: 5}]);
chainCase('full', 30, [S.slash, S.cross, S.flurry, S.holy, S.sword, S.speed, S.heart], true,
  [{skill: S.slash, round: 1}, {skill: S.cross, round: 1}, {skill: S.flurry, round: 2}, {skill: 2, round: 2}, {skill: 2, round: 2},
    {skill: S.holy, round: 2}, {skill: S.slash, round: 3}, {skill: 2, round: 3}, {skill: S.cross, round: 4}, {skill: S.flurry, round: 4}]);
chainCase('speed35', 35, [S.slash, S.cross, S.flurry, S.holy, S.sword, S.speed, S.heart], true,
  [{skill: S.flurry, round: 1}, {skill: S.cross, round: 1}, {skill: S.flurry, round: 1}, {skill: S.holy, round: 1}]);
chainCase('slow20', 20, [S.slash, S.cross, S.flurry, S.sword], false, [{skill: S.flurry, round: 1}, {skill: S.slash, round: 1}, {skill: S.cross, round: 1}]);
// 连斩速度段：敌人速度加到与哈基米相近（+0 段）、略慢（+1 段）
chainCase('agiEven', 30, [S.slash, S.cross, S.flurry, S.sword], false, [{skill: S.flurry, round: 1}, {skill: S.slash, round: 1}, {skill: S.cross, round: 1}], {enemyAgiPlus: 600});
chainCase('agiNear', 30, [S.slash, S.cross, S.flurry, S.sword], false, [{skill: S.flurry, round: 1}], {enemyAgiPlus: 150});
// ⑥ 使用条件（meetsSkillConditions 包装的 legal＋178 物理技能要持剑）：战斗中、TP 100、学会 10437～10446，
// 等级 × 武器（无、练习剑 2、木棒 3）× 至圣斩冷却（holyReady 5，回合 4／5）逐个技能比 meetsSkillConditions 与 canUse。
cases.push(makeCase('legal', {actor: 178, troop: 2, levels: [1, 10, 20, 30, 35], weapons: [0, 2, 3], holyReady: 5, rounds: [4, 5],
  skills: [1, 10437, 10438, 10439, 10440, 10441, 10442, 10443, 10444, 10445, 10446]}, () => {
  const {a} = chainBattle(1, [], false, {});
  const rows = [];
  for (const lv of [1, 10, 20, 30, 35]) {
    a.changeLevel(lv, false);
    for (let id = 10437; id <= 10446; id++) a.learnSkill(id);
    for (const wp of [0, 2, 3]) {
      if (wp) putWeapon(a, wp); else a._equips[0].setObject(null);
      for (const round of [4, 5]) {
        w.$gameTroop._turnCount = round;
        a._codexCatBattle = {heart: 0, holyReady: 5, bellRound: 0};
        a.setTp(100); a.refresh();
        for (const id of [1, 10437, 10438, 10439, 10440, 10441, 10442, 10443, 10444, 10445, 10446]) {
          const sk = w.$dataSkills[id];
          rows.push({level: a.level, weapon: wp, round, skill: id, meets: a.meetsSkillConditions(sk), canUse: a.canUse(sk), stype: sk.stypeId});
        }
      }
    }
  }
  return {skills: a._skills.slice(), rows};
}));
process.exit(finish(host, 'cat.json', {hostScope: '新游戏（Math.random 0.5）；小猫剑圣第一期：招募、槽位、能力值与被动、公式', cases}) ? 0 : 1);
