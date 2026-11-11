// 苍龙破晓重做（XCanglong，O-待定）在原版无画面引擎上的五回合木桩复核：把重制的五招公式、习得、逐道冷却打到原版引擎的内存数据上，
// 并从停用／隐藏名单拿掉 146、开地狱开关 2494（超强者门槛），再用 dmg5.cjs 的同一套木桩条件跑。原版文件一个不改。
// 用法（cwd 在 dmg5.cjs 所在的 sim 目录，<S> 下要有 game/ 指向冻结 v0.62.12 的 app.nw；路径别带中文，hboot 的 file:// 读不了）：
//   FULL_CRIT=1 RUNS=1 node <本文件> $PWD <S> 146        苍龙（智能挂机出招，没有随机项，1 次即可）
//   FULL_CRIT=1 RUNS=20 node <本文件> $PWD <S> 122       狂刀基准（种子与 dmg5.cjs 相同，20 次平均 1066.63 万亿）
//   POLICY=10093 TURNS=1 …                              只放某一招，量单次
// 环境变量同 dmg5.cjs（RUNS、FULL_CRIT、LEVEL、MASTERY、POLICY、TURNS），RATES=玉玺,血浪,飞霄,诛灭,逐道 改倍率试算
'use strict';
const path = require('path');
const sim = process.argv[2], S = process.argv[3];
const ids = process.argv.slice(4).map(Number);
const D = require(path.join(sim, 'dmg5.cjs'));
const {boot} = require(path.join(sim, 'hboot.cjs'));
const {stubScene} = require(path.join(sim, 'sim.cjs'));
const rates = (process.env.RATES || '5000,5000,3200,85000,1000').split(',').map(Number);
const Z = '*(1+a.level*a.level*0.02)';
const F = {
  10093: `(a.atk+a.mat)*(1+user.skillMasteryLevel(item.id))*${rates[0]}${Z}`,
  10094: `(a.atk+a.mat)*(1+user.skillMasteryLevel(item.id))*${rates[1]}${Z}`,
  10095: `(a.atk+a.mat+a.luk)*(1+user.skillMasteryLevel(item.id))*${rates[2]}${Z}`,
  10092: `(a.mmp+a.mhp+a.atk+a.mat+a.def+a.mdf+a.agi+a.luk)*${rates[3]}${Z}`,
  10096: `(a.atk+a.mat+a.luk)*a.tp*${rates[4]}${Z}`,
};
const r = boot(S + '/game', {tolerant: true, log: false});
const w = r.window;
stubScene(w);
function patch() {
  const sk = w.$dataSkills;
  for (const id in F) sk[id].damage.formula = F[id];
  sk[10093].requiredWtypeId1 = 0;
  sk[10096].cooldown = {10096: 3};
  if (sk[10092].cooldown === undefined) throw new Error('10092 没有 cooldown 字段，YEP 读法不对');
  w.$dataClasses[144].learnings = [[2, 10089], [10, 10093], [20, 10094], [30, 10095], [33, 10090], [50, 10091], [50, 10092], [60, 10096]]
    .map(([level, skillId]) => ({level, skillId, note: ''}));
  const IB = w.CodexImportedBalance;
  if (IB && IB.disabledActorIds) { const i = IB.disabledActorIds.indexOf(146); if (i >= 0) IB.disabledActorIds.splice(i, 1); }
  if (w.CodexV029) { const i = w.CodexV029.hiddenActors.indexOf(146); if (i >= 0) w.CodexV029.hiddenActors.splice(i, 1); }
}
patch();
D.ACTORS[146] = {name: '苍龙破晓', artifact: 137};
const newGame = D.newGame;
const results = [];
for (const id of ids) {
  const runs = [];
  for (let k = 0; k < D.CFG.runs; k++) {
    D.seedRandom(w, (1000003 + id * 7919 + k) >>> 0);
    newGame(w); w.$gameSwitches.setValue(2494, true); D.typeOnlyWeapons(w); D.prepareDummy(w);
    const {actor, artifact} = D.setupActor(w, id);
    const info = k === 0 ? D.describe(w, actor, artifact) : null;
    const out = D.runBattle(w, actor, D.CFG.turns, process.env.POLICY ? process.env.POLICY.split(',').map(Number) : null);
    runs.push({total: out.total, byTurn: out.byTurn, bySkill: out.bySkill, chosen: out.chosen, info, crit: out.crit, hits: out.hits});
  }
  const tot = runs.map(x => x.total), mean = tot.reduce((a, b) => a + b, 0) / tot.length;
  results.push({id, mean, min: Math.min(...tot), max: Math.max(...tot), first: runs[0]});
  console.error(`${id} mean=${(mean / 1e12).toFixed(2)}万亿 min=${(Math.min(...tot) / 1e12).toFixed(2)} max=${(Math.max(...tot) / 1e12).toFixed(2)}`);
}
console.log(JSON.stringify(results, null, 1));
process.exit(0);
