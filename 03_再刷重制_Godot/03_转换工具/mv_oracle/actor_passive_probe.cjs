'use strict';
// 进度审查 35%（2026-10-20）补的冻结 v0.28 参照：切片角色升级后由被动决定、此前没有逐项对照的两条规则。
// 1) dsPassiveSkill Game_Actor.actionPlusSet：每个 <passiveAPLUS:N%> 追加一项 N×0.01（codex 分神道法另由 zhenqi.json 测）；
// 2) dsPassiveSkill <DamageElements: N> 写进 _passiveCache.damageElement，installDamageElementRuntime 用它覆盖技能属性。
// 每个切片角色新开一局，等级上限放到 99，同一实例依次 changeLevel 1／10／35／65／99（升级学会职业技能），读已学技能、追加行动几率、属性覆盖。
// 只在内存里跑：新局与 changeLevel；不渲染、不写存档。
const fs = require('fs'), path = require('path');
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const SLICE = JSON.parse(fs.readFileSync(path.join(__dirname, '../xiyou_slice.json'), 'utf8'));
const host = start(), {w, newGame} = host;
const cases = [];
for (const id of SLICE.actors) {
  newGame();
  w.eval('$gameParty.ActorMaxLevel=99;$dataActors.forEach(function(x){if(x)x.maxLevel=99;});');
  const a = w.$gameActors.actor(id);
  for (const lv of [1, 10, 35, 65, 99])
    cases.push(makeCase('actor' + id + '.lv' + lv, {actor: id, level: lv}, () => {
      a.changeLevel(lv, false); a.refresh();
      if (a.initPassiveCache) { a.initPassiveCache(); a.refreshPassiveCache(); }
      return {level: a.level, skills: a.skills().map(s => s.id).sort((x, y) => x - y),
        actionPlus: a.actionPlusSet().map(round), damageElement: Number((a._passiveCache || {}).damageElement) || 0};
    }));
}
process.exit(finish(host, 'actor_passive.json', {hostScope: '真实 Game_Actor.changeLevel／actionPlusSet 与 dsPassiveSkill 被动缓存；等级上限临时放到 99', cases}) ? 0 : 1);
