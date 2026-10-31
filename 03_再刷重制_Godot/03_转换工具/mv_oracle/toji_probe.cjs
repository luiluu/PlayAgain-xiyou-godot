'use strict';
// 【cc·八戒·未经审查】甚尔 171 第一期（js/codex/runtime/installNativeTojiRuntime.js 的 param／xparam／refreshPassiveCache 包装、
// T.outputGrowth、T.damage 与伤害钩子 toji、repair、T.recruit）。不进战斗。
// ① stats：等级 1／10／20／35／50／70／99 × 进阶 0／1（进阶后照原版读档 extractSaveContents 包装跑 repair）× 生命满／半：
//    八项能力、暴击、被动缓存终伤／暴伤、技能表、outputGrowth(非主／主)；每档对敌群 3 第 1 只量 10216～10223 的 makeDamageValue
//    （分散度 0、不会心，同 slice_probe）与 CodexDamage 明细。另一档戴藏兵咒灵 4580。
// ② recruit：新局招募（生成法宝装上、两条提示）、再招募（已在队返回 false）、背包里已有一件藏兵咒灵时拿那件。
// 难度 2、Math.random 0.5（敌群生成时 0.99，同 slice_probe）；只在内存，产物 .sandbox/toji.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const T = w.CodexToji;
if (!T || typeof T.outputGrowth !== 'function') throw new Error('甚尔模块未安装');
const ID = 171, ARMOR = 4580, TROOP = 3, SKILLS = [10216, 10217, 10218, 10219, 10220, 10221, 10222, 10223];
const toasts = [];
w.$.toaster = o => toasts.push(String(o && o.message));
const P = ['mhp', 'mmp', 'atk', 'def', 'mat', 'mdf', 'agi', 'luk'];
const r6 = x => typeof x === 'number' ? +x.toFixed(6) : x;
const brief = bd => bd && {base: r6(bd.base), row: bd.rows && bd.rows[0] && Object.fromEntries(Object.entries(bd.rows[0]).map(([k, v]) => [k, r6(v)]))};

function fresh() {
  newGame();
  w.eval('$gameSystem.setDifficultyId(2); $gameSwitches.setValue(2494, true);');
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
}
function target() {
  w.Math.random = () => 0.99;
  w.$gameTroop.setup(TROOP);
  w.Math.random = () => 0.5;
  const e = w.$gameTroop.members()[0];
  if (e.refreshPassiveCache) e.refreshPassiveCache();
  return e;
}
function measure(a, e, sid) {
  const item = w.$dataSkills[sid], saved = item.damage.variance;
  item.damage.variance = 0;
  const act = new w.Game_Action(a); act.setSkill(sid);
  act.itemCri = () => 0;
  const row = {skill: sid};
  try { row.value = act.makeDamageValue(e, false); row.breakdown = brief(act._codexDamageBreakdown); }
  catch (err) { row.error = String(err.message || err); }
  item.damage.variance = saved;
  return row;
}
function snap(a, e) {
  if (a.initPassiveCache) { a.initPassiveCache(); a.refreshPassiveCache(); }
  const c = a._passiveCache || {};
  return {level: a.level, hp: a.hp, param: P.map(k => a[k]), cri: r6(a.cri), globalHarmRi: r6(c.globalHarmRi || 0), critHarmRi: r6(c.critHarmRi || 0),
    skills: a.skills().map(s => s.id).filter(id => id >= 10203 && id <= 10228),
    growth: [r6(T.outputGrowth(a, false)), r6(T.outputGrowth(a, true))], damage: SKILLS.map(sid => measure(a, e, sid))};
}

const cases = [];
for (const rank of [0, 1]) {
  for (const lv of [1, 10, 20, 35, 50, 70, 99]) {
    for (const half of [false, true]) {
      cases.push(makeCase('stats.r' + rank + '.lv' + lv + (half ? '.half' : ''), {rank, level: lv, half}, () => {
        fresh();
        const e = target();
        let a = w.$gameActors.actor(ID);
        a.changeLevel(lv, false);
        if (rank) { a._AdvancedNum = rank; host.restore(host.encode()); a = w.$gameActors.actor(ID); }
        a.recoverAll();
        if (half) a._hp = Math.floor(a.mhp / 2);
        return snap(a, rank ? target() : e);
      }));
    }
  }
}
cases.push(makeCase('stats.armor.lv50', {rank: 0, level: 50, armor: true}, () => {
  fresh();
  const e = target();
  const a = w.$gameActors.actor(ID);
  a.changeLevel(50, false);
  T.recruit();
  a.recoverAll();
  return Object.assign(snap(a, e), {armor: a.equips().map(x => x ? (x.baseItemId || x.id) : 0)});
}));
function party() {
  const a = w.$gameActors.actor(ID);
  const count = w.$gameParty.allItems().filter(x => x && w.DataManager.isArmor(x) && (x.baseItemId || x.id) === ARMOR).length;
  return {inParty: w.$gameParty._actors.indexOf(ID) >= 0, equips: a.equips().map(x => x ? (x.baseItemId || x.id) : 0), spare: count};
}
cases.push(makeCase('recruit.new', {}, () => {
  fresh(); toasts.length = 0;
  const first = T.recruit(), after = party(), firstToasts = toasts.slice();
  toasts.length = 0;
  const again = T.recruit();
  return {first, after, firstToasts, again, againToasts: toasts.slice(), final: party()};
}));
cases.push(makeCase('recruit.owned', {}, () => {
  fresh(); toasts.length = 0;
  w.$gameParty.gainItem(w.$dataArmors[ARMOR], 1);
  const before = party();
  const ok = T.recruit();
  return {before, ok, after: party(), toasts: toasts.slice()};
}));

if (!finish(host, 'toji.json', {cases})) process.exitCode = 1;
process.exit();
