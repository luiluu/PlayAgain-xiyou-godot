'use strict';
// 【cc·八戒·未经审查】米拉／渡鸦数值池二期（js/codex/runtime/installMiraRavenNumberBoostRuntime.js）的 itemHit／itemEva／itemCri：
// 归属技能（168 用米拉攻击表、167 用渡鸦攻击表，打敌人、伤害类型 1）itemHit 1、itemEva 0；归属且可暴击时 itemCri 夹到 0～1；
// 渡鸦用普攻、非专属技能或打的不是敌人时，itemCri 内层读面板暴击不带魂海 +10×灵魂进度（面板 cri 本身照带）。
// 用例：行动者 168（学 10156）／167（学 10137、灵魂 0／3000／75000／150000），挂致盲 37（命中 −100%）让非归属技能命中掉下来；
// 技能为归属攻击或普攻 1；目标为敌人 1（e1）、303（e303，自带闪避与暴击闪避 +100%）或挂无光黑雾 222（闪避、暴击闪避 +50%）的 1 号角色
// （单独 new 的敌人不在敌群里，_states 记上了但 states() 取不到，所以敌人不挂状态）。
// 真实新局，只在内存；产物 .sandbox/mira_raven_hit.json（generated/oracle/mira_raven_hit.json，tests/xiyou_mira_raven_hit.gd 读）。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');
const cases = [];
const PLAN = [
  [168, 10156, 0, 10140, 'e1'],
  [168, 10156, 0, 10140, 'e303'],
  [168, 10156, 0, 10140, 'actor'],
  [168, 10156, 0, 1, 'e1'],
  [168, 10156, 0, 1, 'e303'],
  [168, 10156, 0, 1, 'actor'],
  [168, 10156, 0, 10151, 'e1'],
  [168, 10156, 0, 10151, 'e303'],
  [168, 10156, 0, 10151, 'actor'],
  [167, 10137, 0, 10122, 'e1'],
  [167, 10137, 0, 10122, 'e303'],
  [167, 10137, 0, 10122, 'actor'],
  [167, 10137, 3000, 10123, 'e1'],
  [167, 10137, 3000, 10123, 'e303'],
  [167, 10137, 3000, 10123, 'actor'],
  [167, 10137, 3000, 1, 'e1'],
  [167, 10137, 3000, 1, 'e303'],
  [167, 10137, 3000, 1, 'actor'],
  [167, 10137, 75000, 10122, 'e1'],
  [167, 10137, 75000, 10122, 'e303'],
  [167, 10137, 75000, 10122, 'actor'],
  [167, 10137, 75000, 1, 'e1'],
  [167, 10137, 75000, 1, 'e303'],
  [167, 10137, 75000, 1, 'actor'],
  [167, 10137, 150000, 10126, 'e1'],
  [167, 10137, 150000, 10126, 'e303'],
  [167, 10137, 150000, 10126, 'actor'],
  [167, 10137, 150000, 1, 'e1'],
  [167, 10137, 150000, 1, 'e303'],
  [167, 10137, 150000, 1, 'actor'],
];
for (const [user, panel, soul, skill, target] of PLAN) {
  cases.push(makeCase(`hit.u${user}.s${skill}.soul${soul}.${target}`, {user, panel, soul, skill, target, level: 60, state: 222, userState: 37}, () => {
    newGame();
    w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
    w.$gameSwitches.setValue(2494, true);
    w.$gameParty.addActor(user);
    const a = w.$gameActors.actor(user);
    a.changeLevel(60, false);
    if (!a.isLearnedSkill(panel)) a.learnSkill(panel);
    a._codexRavenSoul = soul;
    a.addState(37);
    a.need_refresh = true; a.refresh();
    const t = target === 'actor' ? w.$gameActors.actor(1) : new w.Game_Enemy(Number(target.slice(1)), 0, 0);
    if (target === 'actor') t.addState(222);
    const action = new w.Game_Action(a); action.setSkill(skill);
    return {cri: round(a.cri), uHit: round(a.hit), tEva: round(t.eva), tCev: round(t.cev), hit: round(action.itemHit(t)), eva: round(action.itemEva(t)), itemCri: round(action.itemCri(t))};
  }));
}
process.exit(finish(host, 'mira_raven_hit.json', {hostScope: '正式 Game_Action.itemHit／itemEva／itemCri（米拉渡鸦数值池及外层包装）', cases}) ? 0 : 1);
