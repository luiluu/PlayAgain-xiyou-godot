'use strict';
// 【cc·八戒·未经审查】谷雨 175 第一期（js/codex/runtime/installNativeGuyuRuntime.js 战斗外部分：syncSkills（setup／changeLevel／
// 读档 extractSaveContents）、skills 包装、skillMpCost 包装、meetsSkillConditions 包装、evalDamageFormula 治疗与 applyPassiveHealRate、
// G.healRatio、G.recruit）。不进战斗。
// ① stats：等级 1／5／9／10／15／20／25／35／40／45／59／60／99 × 进阶 0／5（进阶后照原版读档包装 syncAll）：已学的谷雨技能、
//    skills() 列出的、五个主动技的 MP 消耗与技能条件、最大 MP、治疗比例、对自己的泽苍生 evalDamageFormula 与 makeDamageValue（分散度 0）；
//    战斗中（见 inBattle）谷雨的条件与 canUse、1 号主角用谷雨主动技的条件（不能用）。
// ② recruit：新局招募（生成百谷生装上、提示）、再招募（已在队返回 false）、背包里已有一件时拿那件、送过法宝后离队再招募（不再送）。
// 难度 2、Math.random 0.5；只在内存，产物 .sandbox/guyu.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');  // 五乘区（CodexZones）重制不移植（O-044），探针宿主默认开着；关掉让参照不含成长修正（tools50 确认关与不关产物一致或已更新夹具）
const G = w.Guyu;
if (!G || typeof G.syncSkills !== 'function') throw new Error('谷雨模块未安装');
const ID = 175, RELIC = 7912, ACTIVE = [10288, 10289, 10290, 10291, 10292];
const toasts = [];
w.$.toaster = o => toasts.push(String(o && o.message));
const r6 = x => typeof x === 'number' ? +x.toFixed(6) : x;
const own = ids => ids.filter(id => id >= 10288 && id <= 10299);

function fresh() {
  newGame();
  w.eval('$gameSystem.setDifficultyId(2); $gameSwitches.setValue(2494, true);');
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
}
function heal(a) {
  const item = w.$dataSkills[10288], saved = item.damage.variance;
  item.damage.variance = 0;
  const act = new w.Game_Action(a); act.setSkill(10288);
  const out = {formula: r6(act.evalDamageFormula(a))};
  try { out.value = act.makeDamageValue(a, false); } catch (err) { out.failed = String(err.message || err); }
  item.damage.variance = saved;
  return out;
}
function snap(a) {
  const hero = w.$gameActors.actor(1);
  return {level: a.level, stage: Number(a._AdvancedNum || 0), mmp: a.mmp, mcr: r6(a.mcr), learned: own(a._skills.slice()).sort((x, y) => x - y),
    listed: own(a.skills().map(s => s.id)), mp: ACTIVE.map(id => a.skillMpCost(w.$dataSkills[id])),
    meets: ACTIVE.map(id => a.meetsSkillConditions(w.$dataSkills[id])), healRatio: r6(G.healRatio(a)), heal: heal(a), battle: inBattle(a, hero)};
}
// 战斗中（只开 $gameParty._inBattle，不走 BattleManager，谷雨的战斗内状态 activeBattle 仍为假）：五个主动技都是「仅战斗」，
// 战斗外 meetsSkillConditions 原生就是假；这里量谷雨与 1 号主角的条件与 canUse（MP 满）
function inBattle(a, hero) {
  w.$gameParty._inBattle = true;
  try {
    return {meets: ACTIVE.map(id => a.meetsSkillConditions(w.$dataSkills[id])), canUse: ACTIVE.map(id => a.canUse(w.$dataSkills[id])),
      hero: ACTIVE.map(id => hero.meetsSkillConditions(w.$dataSkills[id]))};
  } finally { w.$gameParty._inBattle = false; }
}

const cases = [];
for (const stage of [0, 5]) {
  for (const lv of [1, 5, 9, 10, 15, 20, 25, 35, 40, 45, 59, 60, 99]) {
    cases.push(makeCase('stats.s' + stage + '.lv' + lv, {stage, level: lv}, () => {
      fresh();
      let a = w.$gameActors.actor(ID);
      a.changeLevel(lv, false);
      if (stage) { a._AdvancedNum = stage; host.restore(host.encode()); a = w.$gameActors.actor(ID); }
      a.recoverAll();
      return snap(a);
    }));
  }
}
function party() {
  const a = w.$gameActors.actor(ID);
  const count = w.$gameParty.allItems().filter(x => x && w.DataManager.isArmor(x) && (x.baseItemId || x.id) === RELIC).length;
  return {inParty: w.$gameParty._actors.indexOf(ID) >= 0, equips: a.equips().map(x => x ? (x.baseItemId || x.id) : 0), spare: count,
    granted: !!w.$gameSystem._guyuRelicGranted, learned: own(a._skills.slice()).sort((x, y) => x - y)};
}
cases.push(makeCase('recruit.new', {}, () => {
  fresh(); toasts.length = 0; G._notifiedRelic = false;
  const first = G.recruit(), after = party(), firstToasts = toasts.slice();
  toasts.length = 0;
  const again = G.recruit();
  return {first, after, firstToasts, again, againToasts: toasts.slice(), final: party()};
}));
cases.push(makeCase('recruit.owned', {}, () => {
  fresh(); toasts.length = 0; G._notifiedRelic = false;
  w.$gameParty.gainItem(w.$dataArmors[RELIC], 1);
  const before = party();
  const ok = G.recruit();
  return {before, ok, after: party(), toasts: toasts.slice()};
}));
// 送过法宝后离队再招募：不再送；这次运行里已提示过送法宝，提示换成不带法宝的那句
cases.push(makeCase('recruit.again', {}, () => {
  fresh(); toasts.length = 0; G._notifiedRelic = false;
  G.recruit();
  w.$gameParty.removeActor(ID);
  toasts.length = 0;
  const ok = G.recruit();
  return {ok, after: party(), toasts: toasts.slice()};
}));

if (!finish(host, 'guyu.json', {cases})) process.exitCode = 1;
process.exit();
