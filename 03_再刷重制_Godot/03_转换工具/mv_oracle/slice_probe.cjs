// 首期切片探针：在正式 v0.04 引擎里按真实开局状态新开一局，输出能力值与伤害明细，作为 Godot 实现的对照基准。
// 开局被动照 v0.13 原版开局实际所学（Map001 选难度 → Map002 第 5 页 → 大厅 EV20；技能学会后按战斗开始的方式刷新被动缓存）：
//   有名字的角色：天道诅咒 6168（变量 14＝1）、难度适应 5980（简单～困难）、难度被动（简单 5547、普通 5548、困难 5549）；
//   开局可选的角色（1～7、52）另有万众一心 2571、SupperStar 2786（大厅 EV20「增减技能」）。v0.13 不送暴爽 2747（Map002 第 4 页的开关 685 无处打开）。
//   战斗开始状态（被动的 StartPushState）直接附加：995（6168）、1691（5980）、1629（5561 宝宝）、1630（5547）、1631（5548）。
//   宝宝难度另有 StartAEPushState1055（给全体敌人加状态）不在本探针里（不模拟开战）；天灾的 5968/5969 已退役（无效果）不加。
// 伤害：分散度清零、不会心；value=CodexDamage 结算值，final=onPreDamageStateEffects（Confirm＋固定减伤，不含 React）。
// 敌群生成时 Math.random 固定为 0.99（避开精英/神话随机），之后固定 0.5。
// 用法：node slice_probe.cjs [难度ID...] → 只写 .sandbox/slice/slice_d<N>.json；验收后由资料库侧复制到 generated/oracle。
'use strict';
const fs = require('fs'), path = require('path');
const {boot} = require('./hboot.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const OUT = path.resolve(__dirname, '.sandbox/slice');
const SLICE = JSON.parse(fs.readFileSync(path.join(__dirname, '../xiyou_slice.json'), 'utf8'));
const ACTORS = SLICE.actors, TROOPS = SLICE.troops;
// 与 dsPassiveSkill 战斗开始时相同：先清空被动缓存再刷新一次（直接多次 refresh 会重复累加）
const battleRefresh = a => { if (a.initPassiveCache) { a.initPassiveCache(); a.refreshPassiveCache(); } };
const P = ['mhp', 'mmp', 'atk', 'def', 'mat', 'mdf', 'agi', 'luk'];
const X = ['hit', 'eva', 'cri', 'cev', 'mev', 'mrf', 'cnt', 'hrg', 'mrg', 'trg'];
const S = ['tgr', 'grd', 'rec', 'pha', 'mcr', 'tcr', 'pdr', 'mdr', 'fdr', 'exr'];
const r6 = x => typeof x === 'number' ? +x.toFixed(6) : x;
const snap = b => ({param: P.map(k => b[k]), xparam: X.map(k => r6(b[k])), sparam: S.map(k => r6(b[k])),
  elementRates: [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15].map(e => r6(b.elementRate(e)))});
const brief = bd => bd && {base: r6(bd.base), basis: r6(bd.basis), weights: (bd.weights || []).map(r6), normal: r6(bd.normal), terminal: r6(bd.terminal),
  row: bd.rows && bd.rows[0] && Object.fromEntries(Object.entries(bd.rows[0]).map(([k, v]) => [k, r6(v)]))};

const {sourceIdentity} = require('./source_identity.cjs');
function run(difficulty) {
  const identity = sourceIdentity(APP);
  const r = boot(APP, {tolerant: true, log: false});
  const w = r.window;
  const failed = w.CodexRuntime.status().filter(m => m.state !== 'installed');
  if (r.errors.length || failed.length || !w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败');
  w.eval('ConfigManager.applyData({}); DataManager.setupNewGame(); $gameSystem.setDifficultyId(' + difficulty + ');');
  // 开局公共事件「初始化」(812) 会把公式用到的变量置 0；这里不跑事件，统一把未定义变量当 0（Godot 版同样处理）
  w.eval('for (var i = 1; i < 5000; i++) if ($gameVariables._data[i] === undefined) $gameVariables._data[i] = 0;');
  const difficultyPassive = {1: 5561, 2: 5547, 3: 5548, 4: 5549, 5: 5562, 6: 5564}[difficulty];
  const passives = [6168].concat(difficulty >= 2 && difficulty <= 4 ? [5980] : []).concat(difficultyPassive ? [difficultyPassive] : []);
  const starters = [1, 2, 3, 4, 5, 6, 7, 52], starterPassives = [2571, 2786];
  const startStates = [995].concat(difficulty >= 2 && difficulty <= 4 ? [1691] : []).concat({1: [1629], 2: [1630], 3: [1631]}[difficulty] || []);
  const out = {sourceIdentity:identity, difficulty, difficultyName: w.$gameSystem.difficultyName(), passives, starters, starterPassives, startStates, actors: {}, enemies: {}, damage: []};
  for (const id of ACTORS) {
    const a = w.$gameActors.actor(id);
    passives.concat(starters.includes(id) ? starterPassives : []).forEach(s => a.learnSkill(s));
    battleRefresh(a);
    const row = {name: a.name(), classId: a._classId, equips: a.equips().map(e => e ? {id: e.id, base: e.baseItemId || e.id, name: e.name} : null), skills: a.skills().map(s => s.id)};
    row.lv1 = snap(a);
    startStates.forEach(s => a.addState(s));
    // krz_state_re 在 addState 之后才置刷新标记，状态缓存要等下一次 refresh() 才更新（实战里随时会刷新）；只加一个开战状态时不补这一下会读到旧缓存
    a.refresh();
    battleRefresh(a);
    row.lv1Battle = snap(a);
    a.changeLevel(10, false); battleRefresh(a);
    row.lv10Battle = snap(a);
    a.changeLevel(1, false); battleRefresh(a);
    out.actors[id] = row;
  }
  w.eval('$gameParty._actors = []; [1, 8, 9, 10].forEach(function(id){ $gameParty.addActor(id); });');
  for (const tid of TROOPS) {
    w.Math.random = () => 0.99;
    w.$gameTroop.setup(tid);
    w.Math.random = () => 0.5;
    const members = w.$gameTroop.members();
    members.forEach(e => e.refreshPassiveCache && e.refreshPassiveCache());
    out.enemies[tid] = members.map(e => ({id: e.enemyId(), name: e.name(), level: e.level, ...snap(e)}));
    const target = members[0];
    if (!target) continue;
    for (const id of ACTORS) {
      const a = w.$gameActors.actor(id);
      const skills = [1].concat(w.$dataClasses[a._classId].learnings.filter(l => l.level <= 20).map(l => l.skillId));
      for (const sid of skills) {
        const item = w.$dataSkills[sid];
        if (!item || !item.damage.type) continue;
        out.damage.push(measure(w, a, target, sid, {troop: tid, actor: id}));
      }
    }
    for (const act0 of w.$dataEnemies[target.enemyId()].actions) {
      if (w.$dataSkills[act0.skillId].damage.type) out.damage.push(measure(w, target, w.$gameActors.actor(9), act0.skillId, {troop: tid, enemy: target.enemyId(), target: 9}));
    }
  }
  if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
  return out;
}

function measure(w, user, target, sid, tag) {
  const item = w.$dataSkills[sid], saved = item.damage.variance;
  item.damage.variance = 0;
  const act = new w.Game_Action(user); act.setSkill(sid);
  act.itemCri = () => 0;
  const row = {...tag, skill: sid, skillName: item.name, type: item.damage.type, element: item.damage.elementId, physical: act.isPhysical(), magical: act.isMagical()};
  try {
    row.value = act.makeDamageValue(target, false);
    row.breakdown = brief(act._codexDamageBreakdown);
    row.final = act.onPreDamageStateEffects ? act.onPreDamageStateEffects(target, row.value) : row.value;
  } catch (e) { row.error = String(e.message || e); }
  item.damage.variance = saved;
  return row;
}

const ids = process.argv.slice(2).map(Number);
const measured = (ids.length ? ids : [1, 2, 3, 4, 5, 6]).map(run);
fs.mkdirSync(OUT, {recursive: true});
for (const data of measured) {
  const d = data.difficulty;
  fs.writeFileSync(path.join(OUT, 'slice_d' + d + '.json'), JSON.stringify(data, null, 1));
  console.log('difficulty', d, data.difficultyName, 'actors', Object.keys(data.actors).length, 'damage rows', data.damage.length,
    'errors', data.damage.filter(x => x.error).length);
}
process.exit(0);
