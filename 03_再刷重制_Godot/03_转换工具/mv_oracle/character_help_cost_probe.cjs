'use strict';
// character_help_cost 量具（tools CR，2026-11-06 补；原夹具是手搭量具测的，库里没有探针）：角色 167／168 升到 10 级，学不学被动 9951（ConsumeReduce），
// 记技能实际 MP／TP 消耗、帮助卡（CodexDisplay.characterHelpView）里的「消耗」行、被动缓存 consumeReduce。用例与 tests/xiyou_character_help_cost.gd 一一对应。
// 只写 .sandbox/character_help_cost.json，拷成 tests/fixtures/character_help_cost_oracle.json（不接入全量同步）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const cases = [];
for (const [actor, skill] of [[167, 10122], [168, 10140]]) for (const discount of [false, true]) {
  cases.push(makeCase('help_cost.' + actor + '.' + discount, {actor, skill, discount, level: 10}, () => {
    newGame();
    const a = w.$gameActors.actor(actor), item = w.$dataSkills[skill];
    a.changeLevel(10, false);
    if (discount) a.learnSkill(9951);
    a.refresh(); a.recoverAll();
    const view = w.CodexDisplay.characterHelpView(item, {actor: a});
    return {mp: a.skillMpCost(item), tp: a.skillTpCost(item), mmp: a.mmp, maxTp: a.maxTp(),
            rows: view.descParams.filter(r => String(r[0]).includes('消耗')).map(r => r[0]),
            consume: JSON.parse(JSON.stringify(a._passiveCache.consumeReduce))};
  }));
}
process.exit(finish(host, 'character_help_cost.json', {scope: 'native currentHelpText actual MP/TP cost with and without learned ConsumeReduce passive; new minimal numeric cases only', cases}) ? 0 : 1);
