'use strict';
// 【cc·悟空·未经审查】v0.62 神话／混沌神话词条概率随难度浮动（v0.62.12 js/codex/runtime/installAffixDifficultyRateRuntime.js，CodexAffixRate）。
// - route.*：各路线开关（未选、简单～宝宝、洪荒）下的 route／factor／label，与修行·详细页（CodexGuide.detailRows）末尾追加的几行；
// - curse.*：洪荒按诅咒倍率取倍率（curseBonus 换成给定值）；
// - choose.*：几件装备的词条行（高阶行、普通行）在给定预掷随机数下 DreamX.RandomPrefixSuffix.choose 的结果、
//   lineTier、行内概率与用掉的随机数个数（RomDreamXNum）。
// 产物 .sandbox/affix_rate.json → tests/fixtures/affix_rate_oracle.json。
// 跑法：XIYOU_APP=…/冻结正式源/v0.62.12/app.nw node affix_rate_probe.cjs
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const C = w.CodexAffixRate;
if (!C || typeof C.factor !== 'function') throw new Error('词条难度模块未安装');
const ROUTES = {none: [], easy: [2492], normal: [2491], hard: [2500], hell: [2494], calamity: [2489], calamity2: [2461],
  doom: [2487], doom2: [2462], baby: [2496], primordial: [2483], primordial2: [2463], hellAndDoom: [2494, 2487]};
const SAMPLES = [['Armors', 7900, 6], ['Armors', 121, 0], ['Armors', 4472, 9], ['Armors', 3650, 6], ['Armors', 4538, 4],
  ['Armors', 4473, 9], ['Weapons', 53, 0]];
const ROLLS = [0, 0.004, 0.0099, 0.01, 0.0199, 0.0225, 0.0299, 0.0375, 0.05, 0.1, 0.15, 0.2, 0.2849, 0.3, 0.37, 0.4,
  0.4999, 0.5, 0.55, 0.75, 0.9999];
const CHOOSE_ROUTES = ['none', 'easy', 'hell', 'calamity', 'doom', 'baby', 'primordial'];
function setRoute(sws) { newGame(); for (const id of sws) w.$gameSwitches.setValue(id, true); }
const cases = [];
for (const [key, sws] of Object.entries(ROUTES)) {
  cases.push(makeCase('route.' + key, {switches: sws}, () => {
    setRoute(sws);
    const r = C.route();
    const all = w.CodexGuide.detailRows(w.$gameActors.actor(1));
    const at = all.findIndex(x => x && x.type === 'head' && String(x.text).indexOf('高阶词条概率') === 0);
    return {route: r ? r.key : null, factor: C.factor(), label: C.label(), curse: C.curse(), tail: at > 0 ? all.slice(at - 1) : null};
  }));
}
for (const h of [1, 1.5, 2.25, 3.5375, 6.075, 8]) {
  cases.push(makeCase('curse.' + h, {switches: [2483], curse: h}, () => {
    setRoute([2483]);
    const H = w.CodexHonghuang, old = H.curseBonus;
    H.curseBonus = () => h;
    try { return {factor: C.factor(), label: C.label(), rate1: C.rate(1), rate20: C.rate(20)}; } finally { H.curseBonus = old; }
  }));
}
for (const route of CHOOSE_ROUTES) {
  for (const [table, id, ri] of SAMPLES) {
    cases.push(makeCase(`choose.${route}.${table}.${id}.${ri}`, {switches: ROUTES[route], table, id, row: ri}, () => {
      setRoute(ROUTES[route]);
      const data = table === 'Armors' ? w.$dataArmors : w.$dataWeapons;
      const item = data[id], obj = item.DXRPSAffixChoices[ri];
      const meta = item.meta || {};
      const dt = meta.prefixSuffixUseArmorDatabase ? w.$dataArmors : meta.prefixSuffixUseWeaponDatabase ? w.$dataWeapons : data;
      const rows = [];
      for (const v of ROLLS) {
        const P = w.$gameParty;
        P.RomDreamX = [v]; for (let i = 1; i < 20; i++) P.RomDreamX.push(0.5);
        P.RomDreamXNum = 0; P.RomDreamXs = new Array(20).fill(0); P.RomDreamXsNum = 0;
        const got = w.DreamX.RandomPrefixSuffix.choose(obj, dt);
        rows.push({roll: v, id: got == null ? 0 : Number(got), used: P.RomDreamXNum});
      }
      return {tier: C.lineTier(obj, dt), factor: C.factor(), chances: obj.lineChoices.map(l => l.chance), rows};
    }));
  }
}
process.exit(finish(host, 'affix_rate.json', {hostScope: '神话／混沌神话词条概率随难度（v0.62.12 installAffixDifficultyRateRuntime）', cases}) ? 0 : 1);
