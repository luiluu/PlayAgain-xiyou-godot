'use strict';
// 【cc·白龙_7·未经审查】173 饿狼第二期（js/codex/runtime/installNativeGarouRuntime.js，W.CodexGarou）定向参照：
// ① paramRate 包装：形态能力倍率 form_multiplier（[mhp,1,atk,def,mat,mdf,agi,1]），没学 10269 破限成长按人类形态；
// ② makeActionTimes 包装：每回合行动＝形态 actions_per_round（没学 10269 为 1），不掷追加行动；
// ③ G.reason／G.advance：等级、累计突破、神之触媒 2939 条件；遗忘→学会→形态+1→同步（法宝进化）→星空扣触媒；
// ④ G.evolveRelic：法宝实例的能力差值、特性差值（比率乘、加值加）、额外备注、等级经验、改名随新模板；
// ⑤ changeEquip 包装同步、canEquip 包装（法宝只给饿狼）；
// ⑥ G.creditVictory：胜利得累计突破（Boss 战 +5、否则 +1，夹到下一形态门槛），四臂以上 50 级 333 突破 Boss 战得一次神之触媒；
//    Boss 战＝敌群有 MOG_BossHP 血条（_bosshp_meter）的成员；
// ⑦ G.sync 把累计突破夹到当前门槛。
// 法宝备注只量「新模板备注（说明块外）各行都在」「额外行还在」两项：describeRelic 每次同步往备注写 <CodexGarouHelp> 说明块，
// 进化时旧说明块的行被当成额外行带走、再被正则半删，备注里会残留旧形态的说明行（界面层，重制说明卡另算，不照搬）。
// 真实冻结插件、全内存新局；只写 .sandbox/garou_progress.json，拷成 tests/fixtures/garou_progress_oracle.json（不接入全量同步）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const G = w.CodexGarou;
if (!G || !G.config) throw new Error('饿狼模块未安装');
const ACTOR = 173, CATALYST = 2939;
const realmArray = values => { const out = w.eval('[]'); for (const v of values) out.push(v); return out; };
const plain = v => JSON.parse(JSON.stringify(v));

function setup(stage, level) {
  newGame();
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  const a = w.$gameActors.actor(ACTOR);
  a._AdvancedNum = stage;
  a.changeLevel(level, false);
  G.sync(a);
  return a;
}
const catalysts = () => w.$gameParty.numItems(w.$dataItems[CATALYST]);
const learned = a => a._skills.filter(id => id >= 10250 && id <= 10269).sort((x, y) => x - y);
const forms = a => G.config.states.filter(id => a.isStateAffected(id));
const noteLines = n => String(n || '').replace(/<CodexGarouHelp>[\s\S]*?<\/CodexGarouHelp>\s*/g, '').split(/\r?\n/).filter(l => l.trim());
function relic(item) {
  if (!item) return null;
  return {base: item.baseItemId, name: item.name, params: plain(item.params), traits: plain(item.traits), noteTemplate: noteLines(w.$dataArmors[item.baseItemId].note).every(l => noteLines(item.note).includes(l)), noteExtra: String(item.note).includes('<GarouProbeExtra>'),
    level: item.level, exp: item.exp, iconIndex: item.iconIndex, stage: item._garouStage};
}
const cases = [];
cases.push(makeCase('module', {}, () => ({stages: G.config.stages.map(s => ({multiplier: s.form_multiplier, actions: s.actions_per_round,
  level: s.minimum_level, breakthroughs: s.cumulative_breakthroughs, relic: s.relic.armor_id, evolution: s.relic.evolution_bonus_per_stack_percent})),
  relics: G.config.relics, material: G.config.material})));

// ①② 各形态 60 级：能力倍率与行动次数；再忘掉 10269 看回退
for (let st = 0; st <= 6; st++) {
  cases.push(makeCase(`rate.s${st}`, {stage: st, level: 60}, () => {
    const a = setup(st, 60);
    const read = () => ({rate: Array.from({length: 8}, (_, i) => a.paramRate(i)), actions: a.makeActionTimes(), param: Array.from({length: 8}, (_, i) => a.param(i))});
    const full = read();
    a.forgetSkill(10269);
    return {skills: learned(a), full, noGrowth: read()};
  }));
}

// ③ 进阶条件
const REASONS = [
  ['lv', {stage: 0, level: 19, bt: 0}], ['bt', {stage: 0, level: 20, bt: 10}], ['ok', {stage: 0, level: 20, bt: 33}],
  ['s3bt', {stage: 3, level: 60, bt: 165}], ['s5cat', {stage: 5, level: 60, bt: 333}], ['s5ok', {stage: 5, level: 60, bt: 333, cat: 1}],
  ['s5lv', {stage: 5, level: 59, bt: 333, cat: 1}], ['max', {stage: 6, level: 60, bt: 333}], ['raw', {stage: 1, level: 30, bt: 500}],
];
for (const [name, cfg] of REASONS) {
  cases.push(makeCase(`reason.${name}`, cfg, () => {
    const a = setup(cfg.stage, cfg.level);
    a._garouBreakthroughs = cfg.bt;
    if (cfg.cat) w.$gameParty.gainItem(w.$dataItems[CATALYST], cfg.cat);
    return {reason: G.reason(a)};
  }));
}

// ③④ 进阶一路到星空：人类形态招募拿到 7904，改动实例后逐阶进阶
cases.push(makeCase('advance.chain', {stage: 0, level: 20, relicLevel: 37, relicExp: 123, paramDelta: [1000, 0, 500, 0, 0, 0, 0, 7],
  extraTraits: [{code: 21, dataId: 2, value: 1.5}, {code: 22, dataId: 0, value: 0.05}, {code: 31, dataId: 3, value: 0}], extraNote: '<GarouProbeExtra>'}, () => {
  const a = setup(0, 20);
  w.$gameSwitches.setValue(2494, true);   // 饿狼是超强者：号角门槛要挑战开关（或地狱以上难度）
  if (!G.recruit()) throw new Error('招募失败');
  const item = G.gear(a);
  item.level = 37; item.exp = 123;
  [1000, 0, 500, 0, 0, 0, 0, 7].forEach((v, i) => { item.params[i] += v; });
  item.traits.push({code: 21, dataId: 2, value: 1.5}, {code: 22, dataId: 0, value: 0.05}, {code: 31, dataId: 3, value: 0});
  item.note += '\n<GarouProbeExtra>';
  const steps = [{stage: G.stage(a), relic: relic(item)}];
  for (let st = 0; st < 6; st++) {
    const next = G.config.stages[st + 1];
    a.changeLevel(next.minimum_level, false);
    a._garouBreakthroughs = next.cumulative_breakthroughs;
    if (st === 5) w.$gameParty.gainItem(w.$dataItems[CATALYST], 2);
    const stale = G.advance(a, st + 1);
    const result = G.advance(a, st);
    steps.push({stale, result, stage: G.stage(a), skills: learned(a), forms: forms(a), catalysts: catalysts(), relic: relic(G.gear(a)),
      same: G.gear(a) === item, bt: a._garouBreakthroughs});
  }
  steps.push({again: G.advance(a, 6)});
  return {steps};
}));
// 条件不足时 advance 不动
cases.push(makeCase('advance.blocked', {stage: 5, level: 60, bt: 333}, () => {
  const a = setup(5, 60);
  a._garouBreakthroughs = 333;
  return {result: G.advance(a, 5), stage: G.stage(a), skills: learned(a), catalysts: catalysts()};
}));

// ⑤ 换装同步与法宝专属
cases.push(makeCase('equip.evolve', {stage: 3, level: 40}, () => {
  const a = setup(3, 40);
  const item = w.$gameParty.gainIndependentItem(w.$dataArmors[7904], 1)[0];
  const before = relic(item);
  const other = w.$gameActors.actor(1);
  const canOther = other.canEquip(item), canGarou = a.canEquip(item);
  a.changeEquip(a.equipSlots().indexOf(13), item);
  return {before, after: relic(G.gear(a)), canOther, canGarou};
}));

// ⑥ 胜利得突破
const VICTORIES = [
  ['plain', {stage: 0, level: 20, bt: 0, boss: false}], ['boss', {stage: 0, level: 20, bt: 0, boss: true}],
  ['cap', {stage: 0, level: 20, bt: 31, boss: true}], ['s6cap', {stage: 6, level: 60, bt: 333, boss: true}],
  ['catalyst', {stage: 5, level: 50, bt: 330, boss: true}], ['granted', {stage: 5, level: 50, bt: 330, boss: true, granted: true}],
  ['lowlv', {stage: 5, level: 49, bt: 330, boss: true}], ['notboss', {stage: 5, level: 50, bt: 332, boss: false}],
  ['s6', {stage: 6, level: 60, bt: 332, boss: true}],
];
for (const [name, cfg] of VICTORIES) {
  cases.push(makeCase(`victory.${name}`, cfg, () => {
    const a = setup(cfg.stage, cfg.level);
    a._garouBreakthroughs = cfg.bt;
    if (cfg.granted) a._garouCatalystGranted = true;
    w.$gameMessage.clear();
    G._battleGarou = a; G._bossBattle = cfg.boss; G._victoryCredited = false;
    G.creditVictory();
    const first = {bt: a._garouBreakthroughs, catalysts: catalysts(), granted: !!a._garouCatalystGranted, texts: plain(w.$gameMessage._texts)};
    G.creditVictory();   // 同一场只记一次
    return {first, again: {bt: a._garouBreakthroughs, catalysts: catalysts()}};
  }));
}
// Boss 战判定：所有敌人建出后 _bosshp_meter 为真的编号
cases.push(makeCase('boss.meter', {}, () => {
  newGame();
  const ids = [];
  for (let id = 1; id < w.$dataEnemies.length; id++) if (w.$dataEnemies[id] && new w.Game_Enemy(id, 0, 0)._bosshp_meter) ids.push(id);
  return {ids, total: w.$dataEnemies.length - 1};
}));

// ⑦ 同步夹突破
for (const [st, bt] of [[2, 999], [6, 999], [0, -5], [4, 12.7]]) {
  cases.push(makeCase(`sync.s${st}.${bt}`, {stage: st, level: 60, bt}, () => {
    const a = setup(st, 60);
    a._garouBreakthroughs = bt;
    G.sync(a);
    return {bt: a._garouBreakthroughs, cap: G.breakthroughCap(a)};
  }));
}
process.exit(finish(host, 'garou_progress.json', {hostScope: '正式 CodexGarou：paramRate／makeActionTimes／reason／advance／evolveRelic／changeEquip／canEquip／creditVictory／sync', cases}) ? 0 : 1);
