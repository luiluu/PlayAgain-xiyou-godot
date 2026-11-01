'use strict';
// 【cc·悟空·未经审查】黄泉 169／镜流 170 的必中物理技能打甚尔 171 时的 itemEva（审查第 18 期 P3②）：
// 装入次序镜流黄泉在甚尔里面。原版甚尔 itemEva 包装：行动者有五感且是主技能／武器库 → 0；否则先拿内层（黄泉／镜流必中 → 0），
// 物理行动且目标会天与咒缚 10203 时再加影速 min(0.3, (目标敏捷／行动者敏捷 − 1)×0.15)。外层 DamageElement 夹到 0～1。
// 用例：行动者 169（10172 霆影横渡）、170（10187 落霜剑）、169 普攻 1，行动者敏捷加成 0／1500；目标 171 或 1 号；60 级；记双方敏捷、itemEva 与 itemHit。
// 真实新局，只在内存；产物 .sandbox/toji_eva.json（generated/oracle/toji_eva.json，tests/xiyou_toji_eva.gd 读）。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');
const cases = [];
for (const [user, skill, target, plus] of [[169, 10172, 171, 0], [170, 10187, 171, 0], [169, 10172, 171, 1500], [170, 10187, 171, 1500], [169, 1, 171, 0], [170, 10187, 1, 0]]) {
  cases.push(makeCase(`eva.u${user}.s${skill}.t${target}.p${plus}`, {user, skill, target, userAgiPlus: plus, level: 60}, () => {
    newGame();
    w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
    w.$gameSwitches.setValue(2494, true);
    for (const id of [169, 170, 171]) { w.$gameParty.addActor(id); w.$gameActors.actor(id).changeLevel(60, false); }
    const a = w.$gameActors.actor(user), t = w.$gameActors.actor(target);
    if (!t.isLearnedSkill(10203) && target === 171) t.learnSkill(10203);
    for (const b of [a, t]) { b.need_refresh = true; b.refresh(); }
    a._paramPlus[6] += plus;  // 行动者敏捷加成（各角色另有倍率），把速度比压到影速上限 0.3 以下
    for (const b of [a, t]) { b.need_refresh = true; b.refresh(); }
    const action = new w.Game_Action(a); action.setSkill(skill);
    return {agi: [round(a.agi), round(t.agi)], knowsNoMp: t.isLearnedSkill(10203), eva: round(action.itemEva(t)), hit: round(action.itemHit(t))};
  }));
}
process.exit(finish(host, 'toji_eva.json', {hostScope: '正式 Game_Action.itemEva／itemHit（镜流黄泉、甚尔包装）', cases}) ? 0 : 1);
