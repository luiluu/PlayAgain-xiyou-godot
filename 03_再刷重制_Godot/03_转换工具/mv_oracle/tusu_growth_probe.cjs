'use strict';
// 【cc·白龙_13·未经审查】176 屠苏、177 璇第一期：招募与等级成长（installNativeTusuRuntime／installNativeXuanRuntime 的 recruit，
// installNativeBindingChargeRuntime 的 B.curve／B.bindGrowth，璇的星谱初值 chart 与 syncMarkSkills）。
// ① 招募：入队；首次赠送并装上专属法宝（屠苏 4047 止戈环、璇 4048 璇玑星盘），记 _codexTusuRelicGiven／_codexXuanRelicGiven；已在队返回 false。
//    璇另建星谱（星砂 0、三槽初值、各初值纹 1 级）并按槽学星纹技能。
// ② 等级成长：coefficient（按 1／10／20／30／40／50／60 级插值、向下取整）、unlocked（按解锁等级）、
//    skills() 滤掉没解锁的专属技能（任何角色身上的都按本体等级滤）、changeLevel 逐级 levelUp／levelDown 后按职业习得表补学／忘掉专属技能。
// ③ 「归形」return：战斗外不能用；屠苏旧名「【最终兵器】屠苏」同步时改回「屠苏」。
// 真实新游戏，只在内存；产物 .sandbox/tusu_growth.json，拷成 tests/fixtures/tusu_growth_oracle.json（不进同步），专项 xiyou_tusu。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const MODS = {176: w.CodexTusu, 177: w.CodexXuan};
if (!MODS[176] || !MODS[177] || !w.CodexBinding) throw new Error('屠苏／璇模块未安装');
const LEVELS = [1, 4, 5, 9, 10, 14, 15, 19, 20, 24, 25, 29, 30, 34, 35, 39, 40, 45, 50, 55, 60, 70, 99];
function uncap() {
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
}
function fresh(id) {
  newGame(); uncap();
  w.$gameActors._data[id] = null;
  return w.$gameActors.actor(id);
}
const sorted = a => a.slice().sort((x, y) => x - y);
function equips(a) {
  return a.equips().map((e, i) => e ? {slot: i, etype: a.equipSlots()[i], base: e.baseItemId || e.id} : null).filter(Boolean);
}
const cases = [];
for (const id of [176, 177]) {
  const M = MODS[id], cfg = M.config;
  cases.push(makeCase(`ids.${id}`, {id}, () => {
    const i = M.ids();
    return {actor: i.actor, relic: i.relic, horn: i.horn, skill: i.skill, state: i.state, levels: cfg.growth.levels, damage: cfg.growth.damage,
      unlock: cfg.growth.unlock, chart: cfg.chart || null};
  }));
  cases.push(makeCase(`recruit.${id}`, {id}, () => {
    const a = fresh(id);
    const before = sorted(a._skills);
    const first = M.recruit();
    const out = {first, party: w.$gameParty._actors.slice(), before, skills: sorted(a._skills), equips: equips(a),
      given: !!(a._codexTusuRelicGiven || a._codexXuanRelicGiven), level: a.level, name: a._name,
      armors: w.$gameParty.armors().map(x => x.baseItemId || x.id), chart: a._codexXuanChart ? JSON.parse(JSON.stringify(a._codexXuanChart)) : null};
    out.second = M.recruit();
    w.$gameParty.removeActor(id);
    a.changeEquip(equips(a).find(e => e.base === M.ids().relic).slot, null);
    out.third = M.recruit();
    out.armorsAfter = w.$gameParty.armors().map(x => x.baseItemId || x.id);
    out.equipsAfter = equips(a);
    return out;
  }));
  cases.push(makeCase(`levels.${id}`, {id}, () => {
    const a = fresh(id);
    M.recruit();
    const keys = Object.keys(cfg.growth.damage), ukeys = Object.keys(cfg.growth.unlock);
    const rows = [];
    for (const lv of LEVELS.concat(LEVELS.slice().reverse())) {
      a.changeLevel(lv, false);
      rows.push({level: a.level, learned: sorted(a._skills), listed: sorted(a.skills().map(s => s.id)),
        coef: keys.map(k => M.coefficient(k, a)), unlocked: ukeys.map(k => M.unlocked(a, k) ? 1 : 0)});
    }
    return {keys, ukeys, rows};
  }));
  cases.push(makeCase(`return.${id}`, {id}, () => {
    const a = fresh(id);
    M.recruit();
    a.changeLevel(60, false);
    const sid = M.ids().skill['return'];
    const out = {sid, meets: sid ? a.meetsSkillConditions(w.$dataSkills[sid]) : null};
    if (id === 176) { a._name = '【最终兵器】屠苏'; M.syncGrowth(a); out.name = a._name; a._name = '[最终兵器]屠苏'; M.syncGrowth(a); out.name2 = a._name; }
    return out;
  }));
  // 别人身上的专属技能也按本体等级滤
  cases.push(makeCase(`shared.${id}`, {id}, () => {
    const a = fresh(id);
    M.recruit();
    const i = M.ids(), keys = Object.keys(cfg.growth.unlock).filter(k => i.skill[k]);
    const other = w.$gameActors.actor(1);
    keys.forEach(k => other.learnSkill(i.skill[k]));
    const rows = [];
    for (const lv of [1, 20, 60]) {
      a.changeLevel(lv, false);
      rows.push({level: lv, listed: sorted(other.skills().map(s => s.id).filter(s => i.key[s]))});
    }
    return {skills: keys.map(k => i.skill[k]), rows};
  }));
}
process.exit(finish(host, 'tusu_growth.json', {hostScope: '真实 CodexTusu／CodexXuan.recruit、CodexBinding.bindGrowth（coefficient、unlocked、skills、meetsSkillConditions、levelUp／levelDown 同步）', cases}) ? 0 : 1);
