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
process.exit(finish(host, 'cat.json', {hostScope: '新游戏（Math.random 0.5）；小猫剑圣第一期：招募、槽位、能力值与被动、公式', cases}) ? 0 : 1);
