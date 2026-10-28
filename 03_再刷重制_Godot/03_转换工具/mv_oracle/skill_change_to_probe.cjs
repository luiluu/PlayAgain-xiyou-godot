'use strict';
// 技能替换参照（TorigoyaMZ_SkillChangeTo torigoyaSkillChangeToApply）：BattleManager.startAction 里，行动技能备注的
// <ChangeTo[id]: 条件> 按备注顺序逐条 eval（a＝行动者），第一条为真就 setSkill(id)，不看 canUse、不递归。
// 正式数据 67 个技能，条件只有 Math.random() < x、Math.random() <= x（2004）、a.hp < (a.mhp * x)（4938）三种写法。
// 每例新局，BattleManager.setup 敌群 1，摆好行动者与行动后走真实 startAction 链
// （MOG 连击 → SkillChangeTo → OTB → BuffsStatesCore 行动开始 → WUL → BEC startAction），只把最后的 BEC startAction 换成记录。
// 只有 doEval 里的 Math.random 吃磁带（见 tape）。记：行动前后的技能、ChangeTo 取数次数、行动者 hp／mhp／mp／tp。
// 只在内存；产物 .sandbox/skill_change_to.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const cases = [];

// 只有 doEval（ChangeTo 条件）里的取数吃磁带（用完报错）；别的包装回 0.5，另计次数
function tape(values) {
  const used = [], other = [];
  w.Math.random = function() {
    if (!/doEval/.test(new Error().stack)) { other.push(1); return 0.5; }
    if (used.length >= values.length) throw new Error('随机磁带用完');
    used.push(values[used.length]); return values[used.length - 1];
  };
  return {used, other};
}
function battle(actorId) {
  newGame();
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  w.eval('$gameParty._actors=[];');
  w.$gameParty.addActor(actorId);
  const bm = w.BattleManager; bm.setup(1, false, false);
  const stub = new Proxy(function() {}, {get: (o, k) => k === 'then' ? undefined : (() => stub), apply: () => stub});
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  if (w.CodexYunshang) w.CodexYunshang._acted = [];
  return bm;
}
const conditions = id => w.BattleManager.torigoyaSkillChangeTo_getConditions(w.$dataSkills[id]);
// spec: {skill, rolls:[...], hp?(占 mhp 的比例，取整见 hpOf), hpAbs?, tp?, mp?, enemy?:true, item?:id}
function changeCase(name, spec) {
  cases.push(makeCase(name, spec, () => {
    const bm = battle(1);
    const a = spec.enemy ? w.$gameTroop.members()[0] : w.$gameActors.actor(1);
    a.recoverAll();
    if (spec.hpAbs !== undefined) a.setHp(spec.hpAbs);
    else if (spec.hp !== undefined) a.setHp(Math.floor(a.mhp * spec.hp));
    a.setTp(spec.tp === undefined ? 100 : spec.tp);
    if (spec.mp !== undefined) a.setMp(spec.mp);
    const act = new w.Game_Action(a);
    if (spec.item) act.setItem(spec.item); else act.setSkill(spec.skill);
    act.setTarget(0);
    a._actions = [act];
    const before = act.item().id, isItem = act.isItem();
    const started = [], real = w.Yanfly.WUL.BattleManager_startAction;
    w.Yanfly.WUL.BattleManager_startAction = function() {
      const c = this._subject.currentAction(), it = c && c.item();
      started.push(it ? (c.isItem() ? -it.id : it.id) : 0);
    };
    const hp = a.hp, mhp = a.mhp, mp = a.mp, tp = a.tp;
    bm._subject = a; bm._action = null;
    const t = tape(spec.rolls || []);
    try { bm.startAction(); } finally { w.Yanfly.WUL.BattleManager_startAction = real; w.Math.random = function() { return 0.5; }; }
    return {enemy: spec.enemy ? a.enemyId() : 0, before, isItem, hp, mhp, mp, tp,
      conditions: isItem ? [] : conditions(before).map(c => ({id: c.id, condition: c.condition.trim()})),
      started, rolls: t.used.length, otherRolls: t.other.length};
  }));
}

const SKILLS = w.$dataSkills.filter(s => s && conditions(s.id).length).map(s => s.id);
const RANDOM = SKILLS.filter(id => conditions(id).every(c => /^\s*Math\.random\(\)/.test(c.condition)));
const MISS = 0.999999;
// 纯几率：全掷 0 换第一条；全不中不换（< 1 仍中）；多条时只有最后一条中
for (const id of RANDOM) {
  const n = conditions(id).length;
  changeCase(`s${id}.first`, {skill: id, rolls: Array(n).fill(0)});
  changeCase(`s${id}.miss`, {skill: id, rolls: Array(n).fill(MISS)});
  if (n > 1) changeCase(`s${id}.last`, {skill: id, rolls: Array(n - 1).fill(MISS).concat([0])});
}
// 边界：< 掷数等于几率不中；<=（2004）等于算中；第二条中
changeCase('s188.edge-eq', {skill: 188, rolls: [0.5, 0.35]});
changeCase('s188.second', {skill: 188, rolls: [0.5, 0.349999]});
changeCase('s2004.edge-eq', {skill: 2004, rolls: [0.35]});
changeCase('s2004.edge-over', {skill: 2004, rolls: [0.35 + 1e-9]});
changeCase('s223.third', {skill: 223, rolls: [0.7, 0.6, 0.49]});
// 不看 canUse：TP／MP 都是 0 仍换成要 TP 的技能（379 自身要 55 TP）
changeCase('s379.no-tp', {skill: 379, rolls: [0], tp: 0, mp: 0});
// 血量条件（4938，不掷）：按顺序 25%→4941、50%→4940、75%→4939，严格小于
for (const f of [1, 0.9, 0.75, 0.74, 0.5, 0.49, 0.3, 0.25, 0.2, 0.01]) changeCase(`s4938.hp${f}`, {skill: 4938, hp: f, rolls: []});
// 角色 1 的 mhp 485：25%／50%／75% 是 121.25／242.5／363.75，各取紧挨的整数两侧
for (const v of [121, 122, 242, 243, 363, 364]) changeCase(`s4938.hpAbs${v}`, {skill: 4938, hpAbs: v, rolls: []});
// 敌人也换（敌群 1 第一只）
changeCase('enemy.s188.second', {skill: 188, enemy: true, rolls: [MISS, 0.2]});
changeCase('enemy.s188.miss', {skill: 188, enemy: true, rolls: [MISS, MISS]});  // 敌人行动先过 isValid（重制 execute 开头），用敌人用得起的 188
// 没有 ChangeTo：普攻、物品不掷
changeCase('attack.none', {skill: 1, rolls: []});
changeCase('item1.none', {item: 1, rolls: []});

process.exit(finish(host, 'skill_change_to.json', {cases, skills: SKILLS, random: RANDOM}) ? 0 : 1);
