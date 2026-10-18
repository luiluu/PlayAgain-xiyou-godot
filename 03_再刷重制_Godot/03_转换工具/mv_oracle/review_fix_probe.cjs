'use strict';
// 2026-10-18 核查第二批修复的冻结 v0.28 参照（沙僧复现脚本改成常驻探针）：
// 1) 回春：installDamageElementRuntime.healing 在浮动与取整前乘治疗被动（passiveHEUP）。固定恢复 100、rec=1、无元素、无浮动；
//    HP／MP 回复、三个境界、无道法基线、敌人施法基线。
// 2) 可败战斗全灭：BattleManager.endBattle(2)＋updateBattleEnd；_canLose 时 reviveBattleMembers 把倒下的出战者 setHp(1)。
//    敌群 770（瓶颈之战）、903（神兵试炼）全灭、770 部分阵亡；不可败时不复活。
// 只在内存里跑：新局与 BattleManager.setup；不渲染、不写存档。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const cases = [];
const clean = a => { a._skills.length = 0; a._equips.length = 0; a.clearStates(); a.refresh(); a.recoverAll(); };
const heal = (type) => ({id: 0, name: '核查固定恢复', stypeId: 1, hitType: 0, scope: 7, note: '', meta: {}, effects: [],
  damage: {type, formula: '100', elementId: 0, variance: 0, critical: false}});
const calc = (user, target, item) => { const act = new w.Game_Action(user); act.item = () => item; w.$gameSystem.healRate = () => 1;
  return w.CodexDamage.calculate(act, target, {preview: true}).value; };
const withHuichun = (a, realm) => { a._codexZhenqi = {qi: 0, realm, firsts: {}, pending: [], daofa: {huichun: 1}, spec: {}};
  a.learnSkill(w.CodexZhenqi.skillKey('daofa:huichun')); w.CodexZhenqi.refreshRewards(a); };

for (const [id, realm, type] of [['hp.r0', 0, 3], ['hp.r3', 3, 3], ['hp.r5', 5, 3], ['mp.r3', 3, 4]])
  cases.push(makeCase('heal.' + id, {realm, type}, () => { newGame(); const a = w.$gameActors.actor(1), b = w.$gameActors.actor(8); clean(a); clean(b);
    withHuichun(a, realm); return {passive: a.skills().map(s => s.meta && s.meta.passiveHEUP).filter(Boolean), value: calc(a, b, heal(type))}; }));
// 实战：真实治疗技能 166「治疗术」Game_Action.apply 后的 hpDamage 与预览值（dsPassiveSkill 的 executeDamage 是否再乘一次）
cases.push(makeCase('heal.apply.r3', {realm: 3, skill: 166}, () => { newGame(); const a = w.$gameActors.actor(1), b = w.$gameActors.actor(8); clean(a); clean(b);
  withHuichun(a, 3); w.CodexYunshang._acted = []; w.BattleManager.setup(770, false, true); w.$gameParty._inBattle = true; b.setHp(1);
  const act = new w.Game_Action(a); act.setSkill(166); w.$gameSystem.healRate = () => 1;
  const preview = w.CodexDamage.calculate(act, b, {preview: true}).value; act.apply(b); w.$gameParty._inBattle = false;
  return {preview, hpDamage: b.result().hpDamage, hit: b.result().isHit()}; }));
cases.push(makeCase('heal.none', {type: 3}, () => { newGame(); const a = w.$gameActors.actor(1), b = w.$gameActors.actor(8); clean(a); clean(b);
  return {value: calc(a, b, heal(3))}; }));
cases.push(makeCase('heal.enemy', {troop: 770, type: 3}, () => { newGame(); w.$gameTroop.setup(770); const e = w.$gameTroop.members()[0];
  const b = w.$gameActors.actor(8); clean(b); return {value: calc(e, b, heal(3))}; }));

const lose = (troop, canLose, dead) => { newGame(); w.BattleManager.setup(troop, false, canLose); w.$gameParty._inBattle = true;
  const members = w.$gameParty.battleMembers();
  members.forEach((a, i) => { if (dead.includes(i)) a.addState(1); else a.setHp(Math.floor(a.mhp / 2)); });
  const scene = w.SceneManager.goto; w.SceneManager.goto = () => {};
  try { w.BattleManager.endBattle(2); w.BattleManager.updateBattleEnd(); } finally { w.SceneManager.goto = scene; }
  return {canLose: !!w.BattleManager._canLose, hp: members.map(a => a.hp), mhp: members.map(a => a.mhp), dead: members.map(a => a.isDead())}; };
for (const [id, troop, canLose, dead] of [['770.all', 770, true, [0, 1, 2, 3]], ['903.all', 903, true, [0, 1, 2, 3]],
  ['770.partial', 770, true, [0, 2]], ['770.cannot', 770, false, [0, 1, 2, 3]]])
  cases.push(makeCase('lose.' + id, {troop, canLose, dead}, () => lose(troop, canLose, dead)));

process.exit(finish(host, 'review_fix.json', {hostScope: '真实 CodexDamage.calculate（preview）与 BattleManager.endBattle／updateBattleEnd；SceneManager.goto 置空', cases}) ? 0 : 1);
