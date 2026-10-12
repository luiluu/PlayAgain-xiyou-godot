// 首期切片探针：在正式 v0.04 引擎里新开一局，输出角色/敌人能力值与伤害（分散度清零、无会心），
// 作为 Godot 实现的对照基准。用法：node slice_probe.cjs [难度ID] > 输出.json
'use strict';
const {boot} = require('./hboot.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Applications/再刷一把：西游（mod_KYO）.app/Contents/Resources/app.nw';
const difficulty = Number(process.argv[2] || 3);
const r = boot(APP, {tolerant: true, log: false});
const w = r.window;
// 全新玩家：配置全部取默认值（无通关加成等跨存档数据）
w.eval('ConfigManager.applyData({}); DataManager.setupNewGame();');
if (w.$gameSystem.setDifficultyId) w.$gameSystem.setDifficultyId(difficulty);
else if (w.Vitsuno && w.Vitsuno.Difficulty) w.Vitsuno.Difficulty.setId(difficulty);
const P = ['mhp', 'mmp', 'atk', 'def', 'mat', 'mdf', 'agi', 'luk'];
const X = ['hit', 'eva', 'cri', 'cev', 'mev', 'mrf', 'cnt', 'hrg', 'mrg', 'trg'];
const S = ['tgr', 'grd', 'rec', 'pha', 'mcr', 'tcr', 'pdr', 'mdr', 'fdr', 'exr'];
const snap = b => ({param: P.map(k => b[k]), xparam: X.map(k => +b[k].toFixed(4)), sparam: S.map(k => +b[k].toFixed(4)),
  elementRates: [1, 2, 3, 4, 5, 6, 7, 8, 9].map(e => +b.elementRate(e).toFixed(4))});
const out = {difficulty, difficultyName: null, actors: {}, enemies: {}, damage: []};
try { out.difficultyName = w.$gameSystem.difficultyName ? w.$gameSystem.difficultyName() : null; } catch (e) {}
const ACTORS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
for (const id of ACTORS) {
  const a = w.$gameActors.actor(id);
  out.actors[id] = {name: a.name(), lv1: snap(a), equips: a.equips().map(e => e ? e.id : 0), skills: a.skills().map(s => s.id)};
  a.changeLevel(10, false);
  out.actors[id].lv10 = snap(a);
  a.changeLevel(1, false);
}
// 数组须在游戏窗口的 realm 里创建，MV 给 Array.prototype 加的 contains 等方法才可用
w.eval('$gameParty._actors = []; [1, 8, 9, 10].forEach(function(id){ $gameParty.addActor(id); });');
for (const tid of [2, 4]) {
  w.$gameTroop.setup(tid);
  w.$gameTroop.members().forEach((e, i) => { out.enemies[tid + ':' + i] = {id: e.enemyId(), name: e.name(), ...snap(e)}; });
}
// 伤害：Math.random 固定，分散度置 0，不会心
w.Math.random = () => 0.5;
for (const tid of [2, 4]) {
  w.$gameTroop.setup(tid);
  const target = w.$gameTroop.members()[0];
  for (const id of ACTORS) {
    const a = w.$gameActors.actor(id);
    const skills = [1].concat(w.$dataClasses[a._classId].learnings.filter(l => l.level <= 20).map(l => l.skillId));
    for (const sid of skills) {
      const item = w.$dataSkills[sid];
      if (!item || !item.damage.type) continue;
      const saved = item.damage.variance; item.damage.variance = 0;
      const act = new w.Game_Action(a); act.setSkill(sid);
      let value = null, err = null;
      try { value = act.makeDamageValue(target, false); } catch (e) { err = String(e.message || e); }
      item.damage.variance = saved;
      out.damage.push({troop: tid, actor: id, skill: sid, skillName: item.name, formula: item.damage.formula, type: item.damage.type,
        element: item.damage.elementId, base: (() => { try { return act.evalDamageFormula(target); } catch (e) { return null; } })(), value, err});
    }
  }
  const enemy = w.$gameTroop.members()[0];
  for (const act0 of w.$dataEnemies[enemy.enemyId()].actions) {
    const item = w.$dataSkills[act0.skillId];
    if (!item.damage.type) continue;
    const saved = item.damage.variance; item.damage.variance = 0;
    const act = new w.Game_Action(enemy); act.setSkill(act0.skillId);
    let value = null; try { value = act.makeDamageValue(w.$gameActors.actor(9), false); } catch (e) { value = 'ERR ' + e.message; }
    item.damage.variance = saved;
    out.damage.push({troop: tid, enemy: enemy.enemyId(), skill: act0.skillId, skillName: item.name, target: 9, value});
  }
}
process.stdout.write(JSON.stringify(out, null, 1));
process.exit(0);
