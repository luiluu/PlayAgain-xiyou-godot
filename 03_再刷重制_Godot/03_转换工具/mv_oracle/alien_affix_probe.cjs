'use strict';
// 异化词条效果参照（installAlienationAffixes／Advanced 的战斗侧，期一：只靠伤害钩子与行动接点就能接上的词条）。
// ① config：templates.inversebone（逆骨适用技能）与 templates.attack 的长度、头尾，Godot alienation.json 照抄，专项核对。
// ② battle.<词条>：角色 1（99 级，石中剑要 99 级才穿得上）穿本体 1044 的异化武器（none 为不带标记的本体），角色 8 同队，敌群 2（敌人生命加 1e12、攻击加 300）；
//    A.lockParty 冻结词条后，真实 BattleManager 跑行动（同 alien_battle_probe 的 act），每步记双方生命、敌人状态，
//    以及战斗帧外读到的角色 1 物攻／物防（逆骨只在公式与伤害帧里换读，帧外不变）。
//    - inversebone：普攻（1，逆骨技能）、连续攻击（3）、十字军打击（109，元素 8）、火球术（114，不在逆骨技能里）打敌人；敌人普攻打角色 1／8。
//    - void：同一组行动；归墟的攻击无元素结算、不附加状态与增减益（敌人状态应为空）。
// 新游戏（Math.random 0.5），只在内存；产物 .sandbox/alien_affix.json。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const A = w.CodexAlienation, C = A && A.config;
if (!A || !C || !A.advanced) throw new Error('异化词条模块未安装');
const r = v => round(v);
function party(ids) { w.$gameParty.members().map(x => x.actorId()).forEach(id => { if (ids.indexOf(id) < 0) w.$gameParty.removeActor(id); }); ids.forEach(id => w.$gameParty.addActor(id)); }
function uncap() { w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });'); }
const cases = [];
const T = C.templates;
const config = {inversebone: {size: T.inversebone.length, head: T.inversebone.slice(0, 5), tail: T.inversebone.slice(-5)},
  attack: {size: T.attack.length, head: T.attack.slice(0, 5), tail: T.attack.slice(-5)}};

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
w.eval('CodexZones.ENABLED=false;');
const BIG_HP = 1e12;
function battle(spec) {
  newGame(); uncap();
  const a = w.$gameActors.actor(1), b = w.$gameActors.actor(8);
  a.changeLevel(99, false); b.changeLevel(30, false);
  party([1, 8]);
  // 直接放进武器栏（穿戴限制属工坊侧）；none 为不带标记的同一本体
  const item = spec.affix ? A.create('w', 1044, 'boss', spec.affix) : w.$dataWeapons[1044];
  a._equips[0].setObject(item);
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(spec.troop || 2, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  const enemies = w.$gameTroop.members();
  enemies.forEach(e => { e._paramPlus[0] = BIG_HP; e._paramPlus[2] = 300; });
  for (const x of [...w.$gameParty.members(), ...enemies]) { x.need_refresh = true; x.refresh(); x.recoverAll(); }
  A.lockParty();
  w.$gameParty._inBattle = true;
  w.CodexYunshang._acted = [];
  return {bm, a, b, enemies};
}
function act(bm, user, skillId, targetIndex) {
  const action = new w.Game_Action(user);
  action.setSkill(skillId);
  action.setTarget(targetIndex);
  user._actions = [action]; bm._subject = user; bm._action = null;
  bm.startAction();
  for (let i = 0; i < 20000; i++) {
    const ph = bm._phase;
    if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
    else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
  }
  if (bm._phase === 'action' || bm._phase === 'actionList' || bm._phase === 'actionTargetList') bm.endAction();
}
const unit = x => ({hp: r(x.hp), mp: r(x.mp), shield: r(x._shield || 0), states: x._states.slice().sort((p, q) => p - q),
  buffs: x._buffs.slice(2, 8)});
const reading = ctx => ({enemies: ctx.enemies.map(unit), a: Object.assign(unit(ctx.a), {atk: ctx.a.atk, def: ctx.a.def}), b: unit(ctx.b)});
const STEPS = [{skill: 1}, {skill: 3}, {skill: 109}, {skill: 114}, {user: 'e0', skill: 1, target: 0}, {user: 'e1', skill: 1, target: 1},
  {user: 'b', skill: 1}];
function battleCase(name, spec) {
  cases.push(makeCase('battle.' + name, Object.assign({actor: 1, ally: 8, troop: 2, weapon: 1044}, spec, {steps: STEPS}), () => {
    const ctx = battle(spec), rows = [];
    const locked = [ctx.a, ctx.b].map(x => x._alienBattle ? {affix: x._alienBattle.affix} : null);
    const start = reading(ctx);
    for (const st of STEPS) {
      w.$gameTroop._turnCount = 1;
      const user = st.user === 'b' ? ctx.b : st.user && st.user[0] === 'e' ? ctx.enemies[Number(st.user.slice(1))] : ctx.a;
      user.setTp(100); user._mp = user.mmp;
      act(ctx.bm, user, st.skill, st.target || 0);
      rows.push(Object.assign({step: st}, reading(ctx)));
    }
    return {locked, start, rows};
  }));
}
battleCase('none', {});
battleCase('inversebone', {affix: 'inversebone'});
battleCase('void', {affix: 'void'});
process.exit(finish(host, 'alien_affix.json', {hostScope: '新游戏（Math.random 0.5）；异化词条效果期一（逆骨、归墟）', config, cases}) ? 0 : 1);
