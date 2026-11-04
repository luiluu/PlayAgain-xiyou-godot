'use strict';
// 【cc·悟空·未经审查】YEP_TargetCore <Custom Target Eval> 三种写法＋YEP_X_SkillCostItems <Item n Cost: m>。
// 产物 .sandbox/target_eval.json，拷成 tests/fixtures/target_eval_oracle.json（不进同步），专项 xiyou_target_eval。
// 目标：真敌人走真 Game_Action.makeTargets，Math.random 按写好的带子给值、记调用次数；sort 的比较次数与次序靠这个量（node 的 V8 TimSort，短数组＝找连续段＋二分插入）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const TAPES = [];
{ let x = 12345; for (let t = 0; t < 12; t++) { const a = []; for (let i = 0; i < 40; i++) { x = (x * 1103515245 + 12345) % 2147483648; a.push(+(x / 2147483648).toFixed(6)); } TAPES.push(a); } }
TAPES.push(new Array(40).fill(0), new Array(40).fill(0.5), new Array(40).fill(0.9));
const ACTORS = [1, 8, 9, 10, 11, 12, 13, 14];
function setup(n) {
  newGame();
  const party = ACTORS.slice(0, n);
  w.eval(`$gameParty._actors=[${party}]; $gameParty._battleMembers=[${party}];`);
  w.$gameParty.battleMembers = () => party.map(i => w.$gameActors.actor(i));
  w.BattleManager.setup(3, false, false);
  for (const b of w.$gameParty.battleMembers()) b.recoverAll();
  return w.$gameTroop.members()[0];
}
function roll(subject, skillId, tape, forcing) {
  let calls = 0;
  const old = w.Math.random;
  w.Math.random = () => tape[calls++];
  const a = new w.Game_Action(subject, !!forcing);
  a.setSkill(skillId);
  let out;
  try { out = a.makeTargets(); } finally { w.Math.random = old; }
  const tag = b => b == null ? null : b.isActor() ? b.actorId() : -1 - w.$gameTroop.members().indexOf(b);
  return {targets: out.map(tag), calls};
}
const cases = [];
// 一、两种随机写法：人数 1～8、每条带子
for (const [skill, label] of [[965, 'gt2'], [1303, 'gt3']]) {
  for (let n = 1; n <= 8; n++) {
    cases.push(makeCase(`${label}.n${n}`, {skill, n}, () => {
      const e = setup(n), rows = [];
      TAPES.forEach((tape, t) => rows.push({t, ...roll(e, skill, tape)}));
      return {rows};
    }));
  }
}
// 二、倒下的不算（活人序号照 aliveMembers）；强制行动同样走 eval；scope 不看
cases.push(makeCase('gt2.dead_excluded', {skill: 965}, () => {
  const e = setup(4); { const d = w.$gameActors.actor(8); d.addNewState(1); d.need_refresh = true; d.refresh(); }
  return {rows: TAPES.slice(0, 4).map((tape, t) => ({t, ...roll(e, 965, tape)}))};
}));
cases.push(makeCase('gt2.forcing', {skill: 1083}, () => {
  const e = setup(4);
  return {rows: TAPES.slice(0, 4).map((tape, t) => ({t, ...roll(e, 1083, tape, true)}))};
}));
// 三、回春术 1172：友方受伤的，按原文的「最前／最后」排，不足 3 个用第一个补，再 sort
const HEAL = [[], [0], [1], [0, 1], [1, 0], [2, 0, 1], [0, 1, 2], [0, 1, 2, 3], [3, 2, 1, 0], [1, 3, 0, 2]];
for (const hurt of HEAL) {
  cases.push(makeCase(`heal.${hurt.join('_') || 'none'}`, {skill: 1172, hurt}, () => {
    const e = setup(1);
    const foes = w.$gameTroop.members();
    const alive = [...foes];
    while (alive.length < 4) { const n = new w.Game_Enemy(foes[0].enemyId(), 0, 0); w.$gameTroop._enemies.push(n); alive.push(n); }
    alive.forEach(b => b.recoverAll());
    hurt.forEach((idx, k) => { alive[idx]._hp = Math.max(1, alive[idx].mhp - (k + 1) * 10); });
    return {order: alive.map(b => b.mhp - b.hp), rows: TAPES.slice(0, 6).map((tape, t) => ({t, ...roll(e, 1172, tape)}))};
  }));
}
// 四、混乱：不走 eval（WeaponUnleash makeTargets 在最外层，makeConfusionTargets）。addNewState 后要 refresh，states() 有缓存
cases.push(makeCase('gt2.confused', {skill: 965, state: 8}, () => {
  const e = setup(4); e.addNewState(8); e.need_refresh = true; e.refresh();
  return {confused: e.isConfused(), level: e.confusionLevel(), restrictedStates: w.$dataStates.filter(x => x && x.restriction >= 1 && x.restriction <= 3).map(x => x.id), rows: TAPES.slice(0, 4).map((tape, t) => ({t, ...roll(e, 965, tape)}))};
}));
// 五、消耗物品：原版解析结果、够／不够、付费
const COSTS = [2610, 3760, 3761, 3762, 4715, 4719, 4752, 4753, 4754, 4759, 5110, 5111, 5112, 5113, 5765, 5766, 5908, 9921, 9922, 9923];
cases.push(makeCase('cost.parsed', {}, () => ({rows: COSTS.map(id => ({id, item: w.$dataSkills[id].useItemCost, weapon: w.$dataSkills[id].useWeaponCost.length, armor: w.$dataSkills[id].useArmorCost.length}))})));
cases.push(makeCase('cost.other_notes', {}, () => {
  const out = [];
  for (const g of ['$dataActors', '$dataClasses', '$dataEnemies', '$dataWeapons', '$dataArmors', '$dataStates']) for (const o of w.eval(g)) {
    if (o && (Object.keys(o.useItemCostSet || {}).length || Object.keys(o.useItemCostRate || {}).length || Object.keys(o.replaceItemCost || {}).length)) out.push([g, o.id]);
  }
  return {out};
}));
for (const [id, item, need] of [[2610, 514, 10], [3761, 1722, 1], [5765, 2893, 3]]) {
  cases.push(makeCase(`cost.pay.${id}`, {id, item, need}, () => {
    newGame();
    const a = w.$gameActors.actor(1), sk = w.$dataSkills[id], it = w.$dataItems[item];
    a._mp = a.mmp; a._tp = a.maxTp();
    const num = v => { w.$gameParty.loseItem(it, w.$gameParty.numItems(it)); w.$gameParty.gainItem(it, v); };
    num(need - 1); const less = !!a.canPaySkillItemCost(sk), lessList = a.skillItemCost(sk).map(x => [x[0].id, x[1]]);
    num(need); const eq = !!a.canPaySkillItemCost(sk);
    num(need + 2); a.paySkillCost(sk); const left = w.$gameParty.numItems(it);
    const e = (w.BattleManager.setup(3, false, false), w.$gameTroop.members()[0]);
    num(0); const foe = !!e.canPaySkillItemCost(sk); e.paySkillItemCost(sk);
    return {less, lessList, eq, left, foe, foeList: e.skillItemCost(sk).length};
  }));
}
// 六、回春术没人受伤时走完整行动：makeTargets 是三个 undefined，原版后面怎么样
cases.push(makeCase('heal.none.run', {skill: 1172}, () => {
  newGame();
  const stub = new Proxy(function () {}, {get: (_, k) => k === '_waitCount' ? 0 : (() => false), set: () => true});
  const sprites = new Map();
  w.Game_Battler.prototype.battler = function () {
    if (!sprites.has(this)) sprites.set(this, new Proxy({x: 0, y: 0, _homeX: 0, _homeY: 0, width: 64, height: 64, scale: {x: 1, y: 1}, anchor: {x: 0.5, y: 1}, opacity: 255},
      {get: (t, k) => k in t ? t[k] : (() => false), set: (t, k, v) => {t[k] = v; return true;}}));
    return sprites.get(this);
  };
  w.BattleManager.actionBattleHud = () => true;
  w.BattleManager.otbDisplayWindow = () => stub;
  if (!w.$) w.$ = {};
  w.$.toaster = () => {};
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(3, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.SceneManager._scene = {_otbDisplayWindow: stub};
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) b.recoverAll();
  bm.startBattle(); bm.startTurn(); bm._phase = 'turn';
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) b.recoverAll();
  const e = w.$gameTroop.members()[0], a = new w.Game_Action(e); a.setSkill(1172);
  e._actions = [a]; bm._subject = e; bm._action = null;
  let threw = null, steps = 0;
  const mp0 = e.mp;
  try {
    bm.startAction();
    for (; steps < 20000; steps++) {
      const ph = bm._phase;
      if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
      else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
    }
  } catch (err) { threw = String(err && err.message || err).slice(0, 200); }
  return {threw, steps, phase: bm._phase, mpPaid: mp0 - e.mp, canUse: e.canUse(w.$dataSkills[1172]), isValid: a.isValid(), hp: w.$gameTroop.members().map(x => x.hp)};
}));
process.exit(finish(host, 'target_eval.json', {tapes: TAPES, cases}) ? 0 : 1);
