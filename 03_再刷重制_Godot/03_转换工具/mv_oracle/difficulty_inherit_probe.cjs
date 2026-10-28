'use strict';
// installNativeDifficultyInheritanceRuntime 的入队／读档／开战同步（CodexDifficulty.syncActor／syncNativeTier）：
// 主角（角色 1）已学的难度技能 × 全局难度开关 × 补强档开关 2461～2463 × 强弱者分档技能，对普通（<167）与新增（≥167）队员，
// 分别读 Game_Party.addActor（入队）、makeSaveContents→extractSaveContents（读档）、BattleManager.startBattle（开战，仅 ≥167 同步）之后各队员的难度类技能与状态。
// 冻结 v0.28 参照；内存新局，不写存档。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame, restore, encode} = host;
const cases = [];
const ORDINARY = [8, 9, 12, 14, 100, 141, 166];
const NEWER = [167, 168, 169, 170, 173, 174, 175, 176, 178];
const ROLE = [5968, 5969, 5970, 5971, 5972, 5973, 6216, 6235];
// 难度类技能名单（与参照插件的 managed 同口径）＋强弱者分档＋洪荒压制被动
function trackedIds() {
  const out = new Set(ROLE);
  w.$dataSkills.forEach(s => { if (s && /^(?:轮回模式·|灭世挑战|(?:宝宝|简单|普通|困难|地狱|天灾)难度$|难度适应$|天道诅咒$)/.test(s.name || '')) out.add(s.id); });
  const hh = w.$dataSkills.filter(s => s && /<CodexHonghuangSuppress>/i.test(s.note || ''))[0];
  if (hh) out.add(hh.id);
  w.$dataCommonEvents[1442].list.forEach(c => { if (c.code === 355 || c.code === 655) { const re = /\.learnSkill\((\d+)\)/g; let m; while ((m = re.exec(c.parameters[0]))) out.add(Number(m[1])); } });
  return [...out].sort((a, b) => a - b);
}
const TRACK = trackedIds();
function row(id) {
  const a = w.$gameActors.actor(id);
  return {skills: TRACK.filter(s => a.isLearnedSkill(s)), states: a._states.slice().sort((x, y) => x - y)};
}
function readAll(ids) { const o = {}; ids.forEach(id => { o[id] = row(id); }); return o; }
const LEADS = {
  none: [], base5547: [5547], base5548: [5548, 5980], base5561: [5561], honghuang: [5564, 5980],
  cls6216: [6216], cls6235: [6235], cls6216_5548: [6216, 5548, 5980], tier5969: [5969], tier5968: [5968], tier5971_5972: [5971, 5972], tier_all: [5969, 5971, 5973],
};
const DIFFS = {none: [], d2492: [2492], d2491: [2491], d2494: [2494], d2483: [2483], d2500: [2500]};
const TIERS = {none: [], t2461: [2461], t2462: [2462], t2463: [2463], t_all: [2461, 2462, 2463]};
function profile(lead, diff, tier) {
  for (const id of LEADS[lead]) w.$gameActors.actor(1).learnSkill(id);
  for (const sw of DIFFS[diff]) w.$gameSwitches.setValue(sw, true);
  for (const sw of TIERS[tier]) w.$gameSwitches.setValue(sw, true);
}
const IDS = ORDINARY.concat(NEWER);
for (const lead of Object.keys(LEADS))
  for (const diff of Object.keys(DIFFS))
    for (const tier of Object.keys(TIERS)) {
      const spec = {lead, diff, tier, ids: IDS}, name = `${lead}.${diff}.${tier}`;
      // 入队：先定主角与开关，再逐个入队（入队前同步）
      cases.push(makeCase(`recruit.${name}`, {mode: 'recruit', ...spec}, () => {
        newGame(); w.eval('$gameParty._actors=[1];');
        profile(lead, diff, tier);
        IDS.forEach(id => w.$gameParty.addActor(id));
        return readAll(IDS);
      }));
      // 读档：先没有档位时入队（不同步），再设档位、存档、读回
      cases.push(makeCase(`load.${name}`, {mode: 'load', ...spec}, () => {
        newGame(); w.eval('$gameParty._actors=[1];');
        IDS.forEach(id => w.$gameParty.addActor(id));
        profile(lead, diff, tier);
        restore(encode());
        return readAll(IDS);
      }));
      // 开战：入队后档位才变，BattleManager.startBattle 钩子只同步 ≥167 的队员
      cases.push(makeCase(`battle.${name}`, {mode: 'battle', ...spec}, () => {
        newGame(); w.eval('$gameParty._actors=[1];');
        IDS.forEach(id => w.$gameParty.addActor(id));
        profile(lead, diff, tier);
        w.BattleManager.setup(4, false, false);
        w.BattleManager.startBattle();
        return readAll(IDS);
      }));
    }
process.exit(finish(host, 'difficulty_inherit.json', {hostScope: '真实 Game_Party.addActor／DataManager.extractSaveContents／BattleManager.startBattle 钩子（CodexDifficulty.syncActor／syncNativeTier）；track＝难度类技能名单＋强弱者分档＋洪荒压制', track: TRACK, cases}) ? 0 : 1);
