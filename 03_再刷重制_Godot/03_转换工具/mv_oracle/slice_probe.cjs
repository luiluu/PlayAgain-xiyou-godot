// 首期切片探针：在正式 v0.04 引擎里按真实开局状态新开一局，输出能力值与伤害明细，作为 Godot 实现的对照基准。
// 开局被动（技能学会后按战斗开始的方式刷新被动缓存）：暴爽(2747)、天道诅咒(6168)、难度适应(5980，简单~困难)；战斗开始状态 995/1691 直接附加。
// 伤害：分散度清零、不会心；value=CodexDamage 结算值，final=再经 YEP 状态 Confirm/React 脚本后的值。
// 敌群生成时 Math.random 固定为 0.99（避开精英/神话随机），之后固定 0.5。
// 用法：node slice_probe.cjs [难度ID...] → 只写 .sandbox/slice/slice_d<N>.json；验收后由资料库侧复制到 generated/oracle。
'use strict';
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const {boot} = require('./hboot.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Applications/再刷一把：西游（mod_KYO）.app/Contents/Resources/app.nw';
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

const digest = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
function sourceIdentity() {
  const inputs = {};
  for (const name of fs.readdirSync(path.join(APP, 'data')).filter(n => n.endsWith('.json')).sort()) {
    inputs['data/' + name] = digest(path.join(APP, 'data', name));
  }
  inputs['package.json'] = digest(path.join(APP, 'package.json'));
  const runtimeInputs = {};
  function walk(dir) {
    for (const entry of fs.readdirSync(dir, {withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))) {
      const file = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(file);
      else if (entry.name.endsWith('.js')) runtimeInputs[path.relative(APP,file)] = digest(file);
    }
  }
  walk(path.join(APP,'js'));
  return {releaseVersion:JSON.parse(fs.readFileSync(path.join(APP,'package.json'),'utf8')).releaseVersion, inputs, runtimeInputs};
}
function run(difficulty) {
  const identity = sourceIdentity();
  const r = boot(APP, {tolerant: true, log: false});
  const w = r.window;
  const failed = w.CodexRuntime.status().filter(m => m.state !== 'installed');
  if (r.errors.length || failed.length || !w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败');
  w.eval('ConfigManager.applyData({}); DataManager.setupNewGame(); $gameSystem.setDifficultyId(' + difficulty + ');');
  // 开局公共事件「初始化」(812) 会把公式用到的变量置 0；这里不跑事件，统一把未定义变量当 0（Godot 版同样处理）
  w.eval('for (var i = 1; i < 5000; i++) if ($gameVariables._data[i] === undefined) $gameVariables._data[i] = 0;');
  const passives = [2747, 6168].concat(difficulty >= 2 && difficulty <= 4 ? [5980] : []);
  const startStates = [995].concat(difficulty >= 2 && difficulty <= 4 ? [1691] : []);
  const out = {sourceIdentity:identity, difficulty, difficultyName: w.$gameSystem.difficultyName(), passives, startStates, actors: {}, enemies: {}, damage: []};
  for (const id of ACTORS) {
    const a = w.$gameActors.actor(id);
    passives.forEach(s => a.learnSkill(s));
    battleRefresh(a);
    const row = {name: a.name(), classId: a._classId, equips: a.equips().map(e => e ? {id: e.id, base: e.baseItemId || e.id, name: e.name} : null), skills: a.skills().map(s => s.id)};
    row.lv1 = snap(a);
    startStates.forEach(s => a.addState(s));
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
    out.enemies[tid] = members.map(e => ({id: e.enemyId(), name: e.name(), ...snap(e)}));
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
  if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity())) throw new Error('测量期间来源改变');
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
const measured = (ids.length ? ids : [2, 3, 4]).map(run);
fs.mkdirSync(OUT, {recursive: true});
for (const data of measured) {
  const d = data.difficulty;
  fs.writeFileSync(path.join(OUT, 'slice_d' + d + '.json'), JSON.stringify(data, null, 1));
  console.log('difficulty', d, data.difficultyName, 'actors', Object.keys(data.actors).length, 'damage rows', data.damage.length,
    'errors', data.damage.filter(x => x.error).length);
}
process.exit(0);
