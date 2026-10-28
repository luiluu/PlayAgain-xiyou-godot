'use strict';
// 普攻技能查询参照（YEP_WeaponUnleash attackSkillId／replaceAttackSkillId，甚尔、宿傩运行时包装）：
// 角色按 状态 → 装备 → 技能 → 职业 → 角色 找第一个 <Replace Attack: x>，敌人按 状态 → 敌人；都没有是技能 1。
// 每例在新局里摆好（卸下全部装备、forceChangeEquip、addState、learnSkill，最后 refresh），记：
// attackSkillId、canAttack、指令窗「攻击」那一项（Window_ActorCommand.addAttackCommand 全链，含 WUL 改名与甚尔／合契改名）、
// 拿替换后的技能与技能 1 各建一个 Game_Action 问 isAttack 与 numRepeats（另记 attackTimesAdd 与 MV 本体部分 item.repeats＋isAttack×attackTimesAdd），
// 异化祈祷／逆骨的 A.ready。另有 skip 组：行动无效（敌人行动列表空、行动时不能用、禁用号角）时 processTurn 跳过不退回攻击，号角的物品窗。
// 只在内存；产物 .sandbox/attack_query.json。
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
  const atk = new w.Game_Action(b); atk.setAttack();   // 反击 invokeCounterAttack、混乱、退回都走 setAttack
  out.setAttack = atk.item() ? atk.item().id : 0;
  if (actor) {
    w.$gameParty._XdRsData_hangUp_ActSkill = {};          // 挂机 makeAction 没排表：setSkill(attackSkillId)（关智能AI，只看 XdRs 本体）
    const smart = w.ConfigManager.codexSmartAI; w.ConfigManager.codexSmartAI = false;
    const made = b.makeAction();
    w.$gameParty._XdRsData_hangUp_ActSkill[b.name() + w.Star.NumToThreeNum(w.$gameTroop._turnCount)] = 1;   // 排表写攻击（1）：IsRepSkill = attackSkillId
    const sched = b.makeAction();
    w.ConfigManager.codexSmartAI = smart;
    out.hangUpScheduled = sched.item() ? sched.item().id : 0;
    out.hangUpAction = made.item() ? made.item().id : 0;
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
actorCase('157-weapon12-disabled', {actor: 157, equips: [['w', 12]]});   // 导入平衡禁用：canUse 全否（canAttack、指令窗不可用）
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

// 行动无效时：敌人走核心 BattleManager.processTurn（prepare 后 isValid 为假就不 startAction，不退回攻击）；
// 角色在 OTB 下走 startOTBInput／selectNextCommand，输入完（或不能输入时 makeActions 后）直接 startAction，不看 isValid。
// 敌人例：真实 processTurn（OTB 等包装都在），只把最外层 startAction 换成记录。
// 角色例：真实 selectNextCommand → startAction（YEP），在角色实例上记 useItem（导入平衡的 useItem 包装在其内）与付费。
function battleOf(troop) {
  newGame();
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(troop, false, false);
  const stub = new Proxy(function() {}, {get: (o, k) => k === 'then' ? undefined : (() => stub), apply: () => stub});
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  if (w.CodexYunshang) w.CodexYunshang._acted = [];
  return bm;
}
function enemyTurn(bm, e) {
  const started = [], real = bm.startAction;   // BattleManager 是普通对象，startAction 是它自己的属性：换掉再还原
  bm.startAction = function() { const it = this._subject.currentAction() && this._subject.currentAction().item(); started.push(it ? it.id : 0); };
  bm._subject = e; bm._action = null;
  const mp = e.mp, tp = e.tp;
  try { bm.processTurn(); } finally { bm.startAction = real; }
  return {otb: bm.isOTB(), started, left: e._actions.length, mp: [mp, e.mp], tp: [tp, e.tp]};
}
function actorTurn(bm, a, item) {
  const used = [], old = a.useItem;
  a.useItem = function(it) { used.push(it ? it.id : 0); return old.apply(this, arguments); };
  bm._subject = a; bm._action = null;
  const mp = a.mp, count = item ? w.$gameParty.numItems(item) : 0;
  try { bm.selectNextCommand(); } finally { delete a.useItem; }
  return {otb: bm.isOTB(), used, phase: bm._phase, mp: [mp, a.mp], count: item ? [count, w.$gameParty.numItems(item)] : null};
}
function skipCase(name, spec, fn) { cases.push(makeCase('skip.' + name, spec, fn)); }
// 木桩：敌人行动列表为空（正式数据 73～78、394～397、668、669、746），makeActions 后行动没有技能，processTurn 不行动
for (const smart of [false, true]) skipCase('enemy73-empty' + (smart ? '-smartai' : ''), {troop: 70, smartAI: smart}, () => {
  const bm = battleOf(70), e = w.$gameTroop.members()[0];
  w.ConfigManager.codexSmartAI = smart;
  e.makeActions();
  const made = e._actions.map(x => x.item() ? x.item().id : 0), valid = e._actions.map(x => x.isValid());
  return Object.assign({enemyId: e.enemyId(), actionList: e.enemy().actions.length, made, valid}, enemyTurn(bm, e));
});
// 敌人选好技能、行动时 MP 不够：isValid 假，整次跳过（不退回攻击、不扣费）；对照：普通攻击照常 startAction
const MP_SKILL = w.$dataSkills.find(s => s && s.mpCost > 0 && s.tpCost === 0 && [0, 1].includes(s.occasion) && s.scope === 1).id;
skipCase('enemy1-mp-short', {troop: 1, skill: MP_SKILL}, () => {
  const bm = battleOf(1), e = w.$gameTroop.members()[0], sk = w.$dataSkills[MP_SKILL];
  const act = new w.Game_Action(e); act.setSkill(sk.id); act.setTarget(0); e._actions = [act]; e._mp = sk.mpCost - 1;
  return Object.assign({mpCost: sk.mpCost, valid: act.isValid()}, enemyTurn(bm, e));
});
skipCase('enemy1-attack-control', {troop: 1}, () => {
  const bm = battleOf(1), e = w.$gameTroop.members()[0];
  const act = new w.Game_Action(e); act.setAttack(); act.setTarget(0); e._actions = [act];
  return Object.assign({valid: act.isValid()}, enemyTurn(bm, e));
});
// 角色：行动时已不能用（物品用完、MP 不够）也照样 startAction→useItem，不跳过也不退回攻击；对照：普通攻击
skipCase('actor1-attack-control', {troop: 1}, () => {
  const bm = battleOf(1), a = w.$gameParty.members()[0];
  const act = new w.Game_Action(a); act.setAttack(); act.setTarget(0); a._actions = [act];
  return Object.assign({valid: act.isValid()}, actorTurn(bm, a));
});
skipCase('actor1-item-gone', {troop: 1, item: 1}, () => {
  const bm = battleOf(1), a = w.$gameParty.members()[0];
  w.$gameParty.loseItem(w.$dataItems[1], 9999);
  const act = new w.Game_Action(a); act.setItem(1); act.setTarget(0); a._actions = [act];
  return Object.assign({valid: act.isValid()}, actorTurn(bm, a, w.$dataItems[1]));
});
skipCase('actor1-mp-short', {troop: 1, skill: MP_SKILL}, () => {
  const bm = battleOf(1), a = w.$gameParty.members()[0], sk = w.$dataSkills[MP_SKILL];
  const act = new w.Game_Action(a); act.setSkill(sk.id); act.setTarget(0); a._actions = [act]; a._mp = sk.mpCost - 1;
  return Object.assign({mpCost: sk.mpCost, canUse: a.canUse(sk), valid: act.isValid()}, actorTurn(bm, a));
});
// 禁用号角（occasion 2，仅菜单）：canUse／isValid（含强制）都否；菜单物品动作窗「使用」灰（YEP_ItemCore：Window_ItemActionCommand.isEnabled＝$gameParty.canUse，
// 物品场景的列表本身恒可用），战斗物品窗不列；
// 角色行动里拿着号角：startAction 照走，useItem 被导入平衡挡下（不扣物品）
for (const id of [255, 256, 257, 394, 440]) skipCase('horn' + id, {troop: 1, item: id}, () => {
  const bm = battleOf(1), a = w.$gameParty.members()[0], item = w.$dataItems[id];
  w.$gameParty._items[id] = 1;   // gainItem 对禁用号角另有拦截，这里直接摆持有
  const act = new w.Game_Action(a); act.setItem(id); act.setTarget(0); act._forcing = true; const forcedValid = act.isValid(); act._forcing = false;
  a._actions = [act];
  const menu = Object.create(w.Window_ItemActionCommand.prototype), battleWin = Object.create(w.Window_BattleItem.prototype);
  const out = {occasion: item.occasion, actorCanUse: a.canUse(item), valid: act.isValid(), forcedValid, battleListed: !!battleWin.includes(item)};
  w.$gameParty._inBattle = false; out.menuEnabled = !!menu.isEnabled(item); out.partyCanUse = w.$gameParty.canUse(item); w.$gameParty._inBattle = true;
  return Object.assign(out, actorTurn(bm, a, item));
});
// 对照：普通药（物品 1）在菜单可用
skipCase('item1-menu-control', {item: 1}, () => {
  newGame(); w.$gameParty.gainItem(w.$dataItems[1], 1);
  return {menuEnabled: !!Object.create(w.Window_ItemActionCommand.prototype).isEnabled(w.$dataItems[1]), partyCanUse: w.$gameParty.canUse(w.$dataItems[1])};
});

process.exit(finish(host, 'attack_query.json', {cases}) ? 0 : 1);
