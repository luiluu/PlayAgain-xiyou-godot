'use strict';
// 战斗现场帮手：在 host.cjs 的内存新局上走原版 BattleManager.setup＋startBattle（敌群、inBattle、onBattleStart、云裳等运行时的现场），
// 让探针能跑整条 Game_Action.apply。单独成文件而不写进 host.cjs：增量同步按 require 图记依赖，改 host.cjs 会让所有探针重跑。
function battleHost(host, opt = {}) {
  const {w, newGame} = host;
  newGame();
  w.BattleManager.setup(opt.troopId || 2, true, false);
  w.BattleManager.startBattle();
  const party = w.$gameParty.members(), troop = w.$gameTroop.members();
  // 整条 apply；命中、回避、暴击可固定（默认必中、不回避、不暴击），BattleManager 的当前行动者照原版行动时设好
  const apply = (subject, skillId, target, fix = {hit:1, eva:0, cri:0}) => {
    const act = new w.Game_Action(subject); act.setSkill(skillId);
    if (fix.hit !== undefined) act.itemHit = () => fix.hit;
    if (fix.eva !== undefined) act.itemEva = () => fix.eva;
    if (fix.cri !== undefined) act.itemCri = () => fix.cri;
    const saved = [w.BattleManager._subject, w.BattleManager._action];
    w.BattleManager._subject = subject; w.BattleManager._action = act;
    try { act.apply(target); } finally { [w.BattleManager._subject, w.BattleManager._action] = saved; }
    return target.result();
  };
  return {w, party, troop, actor: i => party[i || 0], enemy: i => troop[i || 0], apply};
}
module.exports = {battleHost};
