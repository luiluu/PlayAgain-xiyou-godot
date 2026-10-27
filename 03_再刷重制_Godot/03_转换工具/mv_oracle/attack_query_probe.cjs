'use strict';
// 普攻技能查询参照（YEP_WeaponUnleash attackSkillId／replaceAttackSkillId，甚尔、宿傩运行时包装）：
// 角色按 状态 → 装备 → 技能 → 职业 → 角色 找第一个 <Replace Attack: x>，敌人按 状态 → 敌人；都没有是技能 1。
// 每例在新局里摆好（卸下全部装备、forceChangeEquip、addState、learnSkill，最后 refresh），记：
// attackSkillId、canAttack、指令窗「攻击」那一项（Window_ActorCommand.addAttackCommand 全链，含 WUL 改名与甚尔／合契改名）、
// 拿替换后的技能与技能 1 各建一个 Game_Action 问 isAttack 与 numRepeats（另记 attackTimesAdd 与 MV 本体部分 item.repeats＋isAttack×attackTimesAdd），
// 异化祈祷／逆骨的 A.ready。只在内存；产物 .sandbox/attack_query.json。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const A = w.CodexAlienation;
if (!A) throw new Error('异化模块未安装');
const cases = [];

function bare(a) { a._equips.forEach((e, n) => { if (e.object()) a.forceChangeEquip(n, null); }); }
function slotOf(a, kind, id) {
  if (kind === 'w') return 0;
  return a.equipSlots().indexOf(w.$dataArmors[id].etypeId);
}
function action(b, skillId) {
  const act = new w.Game_Action(b); act.setSkill(skillId);
  const add = b.attackTimesAdd(), item = act.item();
  return {skill: skillId, isAttack: act.isAttack(), numRepeats: act.numRepeats(), mvRepeats: Math.floor(item.repeats + (act.isAttack() ? add : 0))};
}
function command(a) {
  const win = Object.create(w.Window_ActorCommand.prototype);
  win._list = []; win._actor = a;
  win.addAttackCommand();
  const c = win._list[0];
  return c ? {name: c.name, symbol: c.symbol, enabled: !!c.enabled} : null;
}
function measure(b, actor) {
  const id = b.attackSkillId();
  const out = {attackSkillId: id, canAttack: b.canAttack(), attackTimesAdd: round(b.attackTimesAdd()),
    actions: [action(b, id)].concat(id === 1 ? [] : [action(b, 1)])};
  if (actor) {
    out.command = command(b);
    out.ready = {};
    ['prayer', 'inversebone'].forEach(k => { out.ready[k] = A.ready(b, A.create('w', 1044, 'boss', k)); });
  }
  return out;
}

// spec: {actor, equips:[['w'|'a', id]], states:[id], skills:[id]}
function actorCase(name, spec) {
  cases.push(makeCase('actor.' + name, spec, () => {
    newGame(); w.$gameParty._inBattle = true;   // canAttack 看技能场合（战斗中）
    w.$gameParty.addActor(spec.actor);
    const a = w.$gameActors.actor(spec.actor);
    bare(a);
    (spec.skills || []).forEach(id => a.learnSkill(id));
    (spec.equips || []).forEach(([k, id]) => a.forceChangeEquip(slotOf(a, k, id), k === 'w' ? w.$dataWeapons[id] : w.$dataArmors[id]));
    (spec.states || []).forEach(id => a.addState(id));
    a.refresh();
    return Object.assign({states: a.states().map(s => s.id), equips: a.equips().map(e => e ? e.id : 0)}, measure(a, true));
  }));
}
// spec: {enemy, states:[id]}
function enemyCase(name, spec) {
  cases.push(makeCase('enemy.' + name, spec, () => {
    newGame(); w.$gameParty._inBattle = true;
    const e = new w.Game_Enemy(spec.enemy, 0, 0);
    w.$gameTroop.clear(); w.$gameTroop._enemies = [e];   // Game_Action.subject 按敌群下标找
    (spec.states || []).forEach(id => e.addState(id));
    e.refresh();
    return Object.assign({states: e.states().map(s => s.id)}, measure(e, false));
  }));
}

actorCase('154-bare', {actor: 154});
actorCase('154-weapon77', {actor: 154, equips: [['w', 77]]});          // 沙僧 P2-1：攻击 5769，逆骨未就绪
actorCase('154-weapon83', {actor: 154, equips: [['w', 83]]});
actorCase('102-weapon12', {actor: 102, equips: [['w', 12]]});          // 替换成 12（157 能装但被导入平衡禁用，canMove 为假）
actorCase('161-weapon79', {actor: 161, equips: [['w', 79]]});
actorCase('167-armor4541', {actor: 167, equips: [['a', 4541]]});
actorCase('167-armor4541-skill2071', {actor: 167, equips: [['a', 4541]], skills: [2071]});   // 防具也先于技能（武器＋4541 原版装不上，refresh 卸下）
actorCase('154-weapon78-unequippable', {actor: 154, equips: [['w', 78]]});   // 不能装备的武器被 refresh 卸下
actorCase('154-state66', {actor: 154, states: [66]});
actorCase('154-state125', {actor: 154, states: [125]});                 // 替换 562 且普攻追加 +1
actorCase('154-state120', {actor: 154, states: [120]});
actorCase('154-state66-weapon77', {actor: 154, equips: [['w', 77]], states: [66]});   // 状态盖过装备
actorCase('154-state41', {actor: 154, states: [41]});                   // 只加普攻次数，技能 1
actorCase('154-state41-weapon77', {actor: 154, equips: [['w', 77]], states: [41]});
actorCase('154-states66-120', {actor: 154, states: [66, 120]});         // 两个状态按排序取第一个
actorCase('154-states120-66', {actor: 154, states: [120, 66]});
actorCase('154-skill2071', {actor: 154, skills: [2071]});
actorCase('154-skill2071-weapon77', {actor: 154, skills: [2071], equips: [['w', 77]]});   // 装备先于技能
actorCase('154-skills2071-2419', {actor: 154, skills: [2419, 2071]});   // 技能按学会后排序取第一个
actorCase('1-bare', {actor: 1});
actorCase('171-bare', {actor: 171});                                    // 甚尔：MAIN[形态]
actorCase('171-shape2631', {actor: 171, states: [2631]});
actorCase('171-shape2633-weapon77', {actor: 171, states: [2633], equips: [['w', 77]]});
actorCase('172-bare', {actor: 172});                                    // 宿傩：10238
actorCase('172-state66-weapon77', {actor: 172, states: [66], equips: [['w', 77]]});
enemyCase('1-bare', {enemy: 1});
enemyCase('1-state120', {enemy: 1, states: [120]});
enemyCase('1-state125', {enemy: 1, states: [125]});
enemyCase('1-state41', {enemy: 1, states: [41]});

process.exit(finish(host, 'attack_query.json', {cases}) ? 0 : 1);
