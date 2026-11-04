'use strict';
// scan2（插件备注覆盖扫尾）三处参照：
// ① <Max Item: 130>（物品 2933、2934）：Game_Party.maxItems 与 gainItem 实际封顶
// ② dsPassiveSkill <SvPngFd: N>：Game_Actor._passiveCache.SvPngFd（装备→技能→状态，后者盖前者）
// ③ Olivia_BattleSysOTB <SkillKillGoon>：击杀后追击是否真的发生（技能 2061 乘胜追击、2035 俱灭，敌人 3 只，其中打死第一只）
// 报错放 sourceErrors。只在内存里跑；产物 .sandbox/scan2.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');
const stub = new Proxy(function () {}, {get: (_, k) => k === '_waitCount' ? 0 : (() => false), set: () => true});
const sprites = new Map();
w.Game_Battler.prototype.battler = function () {
  if (!sprites.has(this)) sprites.set(this, new Proxy({x: 0, y: 0, _homeX: 0, _homeY: 0, width: 64, height: 64,
    scale: {x: 1, y: 1}, anchor: {x: 0.5, y: 1}, opacity: 255},
  {get: (t, k) => k in t ? t[k] : (() => false), set: (t, k, v) => {t[k] = v; return true;}}));
  return sprites.get(this);
};
w.BattleManager.actionBattleHud = () => true;
w.BattleManager.otbDisplayWindow = () => stub;
const sourceErrors = [];
w.Yanfly.Util.displayError = (error, code, message) => sourceErrors.push({text: String(error && error.message || error), message});
function battle(troop) {
  if (w.$gameParty) w.$gameParty._inBattle = false;
  newGame();
  w.eval('$gameParty._actors=[];');
  for (const id of [1, 8]) w.$gameParty.addActor(id);
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(troop || 2, true, true);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.CodexYunshang._acted = [];
  for (const id of [1, 8]) { const a = w.$gameActors.actor(id); a.need_refresh = true; a.refresh(); a.recoverAll(); a._paramPlus[0] = 1e9; a.need_refresh = true; a.refresh(); a.recoverAll(); }
  w.$gameParty._inBattle = true;
  for (const e of w.$gameTroop.members()) { e._paramPlus[0] = 1e9; e.need_refresh = true; e.refresh(); e.recoverAll(); }
  return {bm, a: w.$gameActors.actor(1), b: w.$gameActors.actor(8), troop: w.$gameTroop.members()};
}
const cases = [];
cases.push(makeCase('max_item', {items: [2933, 2934, 1, 2935]}, () => {
  newGame();
  const rows = [];
  for (const id of [2933, 2934, 1, 2935]) {
    const item = w.$dataItems[id];
    for (const n of [w.$gameParty.numItems(item)]) {
      w.$gameParty.gainItem(item, 500);
      rows.push({id, name: item.name, maxItem: item.maxItem, maxItems: w.$gameParty.maxItems(item), after500: w.$gameParty.numItems(item)});
      w.$gameParty.gainItem(item, -9999);
    }
  }
  return {rows};
}));
cases.push(makeCase('svpng', {armors: [2937, 4279, 5198, 5200, 5201, 5202, 5203], state: 1120}, () => {
  // 每行一个新角色：戴不戴 armor、带不带状态 1120，然后 refreshPassiveCache（开战时就是这样刷的）；原版缓存只会被改写、不会复位，所以不在同一角色上连续比
  const rows = [];
  const one = (armorId, withState) => {
    const {a} = battle(); sourceErrors.length = 0;
    if (armorId) { const arm = w.$dataArmors[armorId]; const slot = a.equipSlots().findIndex(t => t === arm.etypeId); w.$gameParty.gainItem(arm, 1); a.forceChangeEquip(slot, arm); }
    if (withState) a.addState(1120);
    a.need_refresh = true; a.refresh(); a.refreshPassiveCache();
    rows.push({armorId, withState, scale: a._passiveCache.SvPngFd, sourceErrors: sourceErrors.slice()});
  };
  one(0, false); one(0, true);
  for (const id of [2937, 4279, 5198, 5200, 5201, 5202, 5203]) { one(id, false); one(id, true); }
  return {rows};
}));
// ③ 击杀追击：3 只敌人，打死第一只后看有没有第二次 startAction／其它敌人受伤
cases.push(makeCase('killgoon', {skills: [2061, 2035, 2192], troop: 2}, () => {
  const out = {rows: []};
  const trials = [['plain', 1, []], ['kill_goon_2061', 2061, []], ['kill_goon_2192', 2192, []], ['passive_2035_attack', 1, [2035]]];
  for (const [tag, skillId, extraSkills] of trials) for (const kill of [true, false]) {
    const {bm, a, troop} = battle(2); sourceErrors.length = 0;
    const learn = [skillId, ...extraSkills].filter(x => x > 1); for (const id of learn) a.learnSkill(id);
    a._tp = a.maxTp(); a._mp = a.mmp; a.need_refresh = true; a.refresh();
    a._skills = a._skills.slice();
    const alive = troop.filter(e => e.isAlive());
    for (const e of troop) { e._hp = 1e9; e.need_refresh = true; }
    const target = troop[0]; if (kill) target._hp = 1;
    let starts = 0; const oldStart = bm.startAction;
    bm.startAction = function () { starts++; return oldStart.apply(this, arguments); };
    const hpBefore = troop.map(e => e.hp);
    const action = new w.Game_Action(a); action.setSkill(skillId); action.setTarget(0);
    a._actions = [action]; bm._subject = a; bm._action = null;
    bm.startAction();
    for (let i = 0; i < 20000; i++) {
      const ph = bm._phase;
      if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
      else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
    }
    const mid = {phase: bm._phase, starts, dead0: target.isDead(), hp: troop.map(e => e.hp), subjectActions: a._actions.length};
    let ended = null;
    try { bm.endAction(); ended = {phase: bm._phase, starts, hp: troop.map(e => e.hp), dead: troop.map(e => e.isDead()), actions: a._actions.length, item: a.currentAction() ? (a.currentAction().item() || {}).id : null, targetIndex: a.currentAction() ? a.currentAction()._targetIndex : null}; }
    catch (x) { sourceErrors.push({text: String(x).slice(0, 100), message: 'endAction'}); }
    // 再把可能新排的行动跑完
    for (let i = 0; i < 20000; i++) {
      const ph = bm._phase;
      if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
      else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
    }
    const final = {phase: bm._phase, starts, hpLostOthers: troop.slice(1).map((e, i) => hpBefore[i + 1] - e.hp), mp: a.mp, tp: a.tp};
    bm.startAction = oldStart;
    out.rows.push({tag, kill, skillId, hasSkill: a.hasSkill(skillId), mid, ended, final, enemies: troop.length, sourceErrors: sourceErrors.slice()});
  }
  const flags = (() => { const { a } = battle(2); const act = new w.Game_Action(a); act.setSkill(1); return {subjectActorId: act._subjectActorId, subjectEnemyIndex: act._subjectEnemyIndex}; })();
  out.actionFlags = flags;
  return out;
}));
process.exit(finish(host, 'scan2.json', {scope: 'scan2 probes on frozen source', cases}) ? 0 : 1);
