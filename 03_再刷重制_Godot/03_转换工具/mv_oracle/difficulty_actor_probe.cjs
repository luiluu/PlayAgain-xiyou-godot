'use strict';
// 难度 7～9 角色侧（哪吒 diff2）：原版灭世 7、洪荒 8 只能从天灾 6 在大厅 Map004 EV41 进（第 2 页 1 层「挑战灭世难度」、
// 第 6 页 13 层再开洪荒＋CE1442 选五个诅咒）；混沌 9 只在 31 层后的 EV62 第 4 页（关掉全部难度开关、只改怪物属性 SetID 9，
// 可另选「灭世难度debuff」整组学会）。slice_probe 的角色侧只到 6 档、且是手写的被动名单；这里跑原版事件本身：
//   天灾开局＝Map001 EV1 选天灾那一支（含 CE1443）＋天道使者四个变量＋大厅 EV20 的增减技能（2571／2786 与按难度开关学被动，不含成就奖励）＋CE1319 天道诅咒，
//   再按用例接着跑 EV41／EV62 的页（选项按 picks 依次应答）。
// 每例从新局起跑（每档难度一次 newGame）。记：难度号、难度开关、相关变量、样本角色的全部技能、状态、
// 1 级能力（被动刷新后）与开战能力（dsPassiveSkill Scene_Battle.start 的 StartPushState，随机数 0.5，再刷新被动）。
// 产物 .sandbox/difficulty_actor.json（generated/oracle/difficulty_actor.json，tests/xiyou_difficulty_actor 读）。
const fs = require('fs'), path = require('path');
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval(`
ImageManager.isReady = function() { return true; };
Game_CharacterBase.prototype.isAnimationPlaying = function() { return false; };
Game_CharacterBase.prototype.isBalloonPlaying = function() { return false; };
`);
if (w.$) w.$.toaster = () => {};
w.SceneManager.isSceneChanging = () => false;
w.SceneManager._scene = Object.create(w.Scene_Map.prototype);
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const map = id => JSON.parse(fs.readFileSync(path.join(APP, 'data', 'Map' + String(id).padStart(3, '0') + '.json'), 'utf8'));
const M1 = map(1), M4 = map(4);
const page = (m, ev, p) => m.events[ev].pages[p - 1].list;
// 取一段命令，缩进整体左移到 0，末尾补结束命令
const seg = (list, from, to) => {
  const out = list.slice(from, to + 1), base = out[0].indent;
  return out.map(c => ({...c, indent: c.indent - base})).concat([{code: 0, indent: 0, parameters: []}]);
};
const M1E1 = page(M1, 1, 1), EV20 = page(M4, 20, 1);
const at = (list, code, pred) => list.findIndex(c => c.code === code && pred(c.parameters));
// 天灾那一支：402 [5,"天灾难度"] 之后到下一个 404 之前
const tz0 = at(M1E1, 402, p => p[1] === '天灾难度') + 1, tz1 = M1E1.findIndex((c, i) => i > tz0 && c.code === 404) - 1;
const curse0 = at(M1E1, 122, p => p[0] === 8), curse1 = at(M1E1, 122, p => p[0] === 14);
const ev20a = at(EV20, 318, p => p[1] === 1 && p[3] === 2571), ev20b = EV20.length - 2;
const OPENING = [seg(M1E1, tz0, tz1), seg(M1E1, curse0, curse1), seg(EV20, ev20a, ev20b), w.$dataCommonEvents[1319].list];
// 设计检查：段首尾就是预期命令
if (M1E1[tz0 - 1].parameters[1] !== '天灾难度' || M1E1[tz0].parameters[0] !== 'Difficulty SetID 6' || EV20[ev20b].code !== 412)
  throw new Error('开局段定位失败');

function run(list, picks, mapId, eventId) {
  const it = new w.Game_Interpreter(); it.setup(w.JsonEx.makeDeepCopy(list), eventId || 0);
  if (mapId) it._mapId = mapId;
  const messages = []; let n = 0, frames = 0;
  for (; frames < 20000 && it.isRunning(); frames++) {
    w.Graphics.frameCount++; it.update();
    const m = w.$gameMessage; if (!m.isBusy()) continue;
    if (m.isChoice()) { const pick = n < picks.length ? picks[n++] : 0; messages.push({choices: m.choices().slice(), pick}); m.onChoice(pick); }
    m.clear();
  }
  return {finished: !it.isRunning(), usedPicks: n, choices: messages};
}
const P = ['mhp', 'mmp', 'atk', 'def', 'mat', 'mdf', 'agi', 'luk'];
const X = ['hit', 'eva', 'cri', 'cev', 'mev', 'mrf', 'cnt', 'hrg', 'mrg', 'trg'];
const S = ['tgr', 'grd', 'rec', 'pha', 'mcr', 'tcr', 'pdr', 'mdr', 'fdr', 'exr'];
const ELEMENTS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15];
const snap = b => ({param: P.map(k => round(b[k])), xparam: X.map(k => round(b[k])), sparam: S.map(k => round(b[k])), elementRates: ELEMENTS.map(e => round(b.elementRate(e)))});
const battleRefresh = a => { if (a.initPassiveCache) { a.initPassiveCache(); a.refreshPassiveCache(); } };
const SAMPLE = [1, 8, 9, 10, 2, 52, 12, 30];   // 队伍四人＋开局可选 2、52＋不在队的 12、30
const SWITCHES = [2496, 2492, 2491, 2490, 2500, 2494, 2489, 2487, 2483, 2461, 2462, 2463, 2485, 2486, 2493, 2497, 2481];
const VARS = [8, 9, 12, 13, 14, 20, 1395, 1396, 1397, 1482, 1491, 1639, 2530, 1468, 1469, 1470, 1471, 1472];
function observe(runs, sample) {
  const actors = {};
  for (const id of sample || SAMPLE) {
    const a = w.$gameActors.actor(id);
    battleRefresh(a);
    const row = {skills: a._skills.slice().sort((x, y) => x - y), states: a._states.slice().sort((x, y) => x - y), lv1: snap(a)};
    // 开战：dsPassiveSkill Scene_Battle.start 的 StartPushState（自己），Math.random 0.5
    a.initPassiveCache();
    const added = [];
    a.equips().concat(a.skills()).filter(Boolean).forEach(o => {
      for (const k in (o.meta || {})) if (k.startsWith('StartPushState')) {
        const sid = Number(k.replace('StartPushState', '')), pr = parseFloat(String(o.meta[k]).trim().replace('%', ''));
        if (!isNaN(pr) && 0.5 * 100 < pr) { a.addState(sid); added.push(sid); }
      }
    });
    a.refresh(); a.refreshPassiveCache();
    row.startStates = added; row.battleStates = a._states.slice().sort((x, y) => x - y); row.battle = snap(a);
    actors[id] = row;
  }
  const sw = {}, vars = {};
  SWITCHES.forEach(s => sw[s] = w.$gameSwitches.value(s)); VARS.forEach(v => vars[v] = w.$gameVariables.value(v));
  return {runs, difficultyId: w.$gameSystem.difficultyId(), switches: sw, vars, actors};
}
// 用例：stages 依次跑（ev＝Map004 事件号、page＝页号、v20＝跑前设的楼层变量、picks＝选项应答）
const D7 = {ev: 41, page: 2, v20: 1, picks: [2, 0]};                       // 挑战灭世难度→是
const D8 = {ev: 41, page: 6, v20: 13, picks: [1, 0, 0, 0, 0, 0, 0]};       // 离开→是（再开洪荒）→五个诅咒各选第 1 项
// EV62 第 4 页两个连着的选项窗被原版插件并成一个（8 项）：第 7 项「选择怪物难度属性」→第二页→混沌
const D9 = {ev: 62, page: 4, picks: [6, 5, 3]};
const D9M = {ev: 62, page: 4, picks: [3, 0]};                              // 灭世难度debuff→获取所有难度（之后再跑一次 D9）
const specs = [
  {id: 'd6.opening', stages: []},
  {id: 'd7.miemie', stages: [D7]},
  {id: 'd8.honghuang', stages: [D7, D8]},
  {id: 'd9.chaos', stages: [D7, D8, D9]},
  {id: 'd9.chaos_miemie_debuff', stages: [D7, D8, D9M, D9]},
  {id: 'd9.from_tianzai', stages: [D9]},
];
// floor1：新源 v0.44 起难度传承等按角色备注 <KyoTier> 分强弱（CodexTier）。另跑一组同样的阶段、只看不在队的强者 11、超强者 96 与 148
// （一护，v0.62 新角色）；单独成例（id 加 .tier、setup 带 sample），旧例与顶层 sample 逐字节不变
const TIER_SAMPLE = [11, 96, 148];
specs.slice().forEach(spec => specs.push({id: spec.id + '.tier', stages: spec.stages, sample: TIER_SAMPLE}));
const cases = specs.map(spec => makeCase('diffactor.' + spec.id, spec, () => {
  newGame(); w.$gameMessage.clear();
  w.eval('$gameParty.ActorMaxLevel = 99;');
  const runs = OPENING.map(list => run(list, [], 1, 1));
  for (const st of spec.stages) {
    if (st.v20 !== undefined) w.$gameVariables.setValue(20, st.v20);
    runs.push(run(page(M4, st.ev, st.page), st.picks, 4, st.ev));
  }
  return observe(runs, spec.sample);
}));
process.exit(finish(host, 'difficulty_actor.json', {hostScope: '正式事件跑天灾开局与大厅 EV41／EV62 进灭世、洪荒、混沌后的角色技能、状态、能力值', sample: SAMPLE, cases}) ? 0 : 1);
