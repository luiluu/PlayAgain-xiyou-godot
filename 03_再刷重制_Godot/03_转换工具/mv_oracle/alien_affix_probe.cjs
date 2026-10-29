'use strict';
// 异化词条效果参照（installAlienationAffixes／Advanced 的战斗侧）。期一：逆骨、归墟；期二①：疫囊、囚厄、绝缘、舍身（状态类）；期二②：空壳、连命、嫁祸（生命池类）。
// ① config：templates.inversebone（逆骨适用技能）与 templates.attack 的长度、头尾，Godot alienation.json 照抄，专项核对。
// ② battle.<词条>：角色 1（99 级，石中剑要 99 级才穿得上）穿本体 1044 的异化武器（none 为不带标记的本体），角色 8 同队，敌群 2（敌人生命加 1e12、攻击加 300）；
//    A.lockParty 冻结词条后，真实 BattleManager 跑行动（同 alien_battle_probe 的 act），每步记双方生命、敌人状态，
//    以及战斗帧外读到的角色 1 物攻／物防（逆骨只在公式与伤害帧里换读，帧外不变）。
//    - inversebone：普攻（1，逆骨技能）、连续攻击（3）、十字军打击（109，元素 8）、火球术（114，不在逆骨技能里）打敌人；敌人普攻打角色 1／8。
//    - void：同一组行动；归墟的攻击无元素结算、不附加状态与增减益（敌人状态应为空）。
// ③ 期二① battle.<词条>.*：同样的队伍与敌群，按步骤跑：行动可用合成技能（空白技能 13 填入 def 的 scope／hitType／效果，
//    两边按同一份定义合成）；set 设生命／法力比例；roundEnd 照 Affixes endTurn 包装调 A.spreadPest；expire 照自然移除
//    （A.naturalRemoval）去掉一个状态。疫囊穿本体 1013 尼伯龙根指环（饰品栏）；舍身的绑定队友直接写进标记的 config。
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
// 在原对象上改（YEP 技能熟练度等插件载入时给技能对象挂了字段，整个替换会让行动结束时报错并 SceneManager.terminate）
function synth(def) { Object.assign(w.$dataSkills[13], {scope: def.scope, hitType: def.hitType,
  effects: def.effects.map(e => ({code: e[0], dataId: e[1], value1: e[2], value2: 0}))}); return 13; }
function battle(spec) {
  newGame(); uncap();
  const a = w.$gameActors.actor(1), b = w.$gameActors.actor(8);
  a.changeLevel(99, false); b.changeLevel(30, false);
  party([1, 8]);
  // 直接放进武器栏（穿戴限制属工坊侧）；none 为不带标记的同一本体
  const kind = spec.armor ? 'a' : 'w', base = spec.armor || 1044;
  const item = spec.affix ? A.create(kind, base, 'boss', spec.affix) : w.$dataWeapons[1044];
  if (spec.config) A.mark(item).config = JSON.parse(JSON.stringify(spec.config));
  if (spec.armor) { a._equips[0].setObject(w.$dataWeapons[1044]); a._equips[a.equipSlots().indexOf(item.etypeId)].setObject(item); }
  else a._equips[0].setObject(item);
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
// 帧外物攻／物防只在期一（逆骨）读：角色身上有状态时挨减益，原版参数缓存不刷新（无词条也一样），重制另有差异，不归异化
const reading = (ctx, atk) => ({enemies: ctx.enemies.map(unit), a: Object.assign(unit(ctx.a), atk ? {atk: ctx.a.atk, def: ctx.a.def} : {}), b: unit(ctx.b)});
const STEPS = [{skill: 1}, {skill: 3}, {skill: 109}, {skill: 114}, {user: 'e0', skill: 1, target: 0}, {user: 'e1', skill: 1, target: 1},
  {user: 'b', skill: 1}];
function battleCase(name, spec, steps) {
  steps = steps || STEPS;
  cases.push(makeCase('battle.' + name, Object.assign({actor: 1, ally: 8, troop: 2, weapon: 1044}, spec, {steps}), () => {
    const ctx = battle(spec), rows = [];
    const locked = [ctx.a, ctx.b].map(x => x._alienBattle ? {affix: x._alienBattle.affix} : null);
    const atk = steps === STEPS, start = reading(ctx, atk);
    const who = k => k === 'b' ? ctx.b : k && k[0] === 'e' ? ctx.enemies[Number(k.slice(1))] : ctx.a;
    for (const st of steps) {
      w.$gameTroop._turnCount = st.round || 1;
      if (st.set) {
        for (const k of ['a', 'b']) {
          if (st.set[k + 'Hp'] != null) who(k)._hp = Math.floor(who(k).mhp * st.set[k + 'Hp']);
          if (st.set[k + 'Mp'] != null) who(k)._mp = Math.floor(who(k).mmp * st.set[k + 'Mp']);
        }
      } else if (st.roundEnd) {
        w.$gameTroop._turnCount = st.roundEnd; A.spreadPest(A.round());
      } else if (st.regen) {
        who(st.regen).onTurnEnd();
      } else if (st.revive) {
        who(st.revive).removeState(who(st.revive).deathStateId());
      } else if (st.expire) {
        const x = who(st.expire.who); A.naturalRemoval = true; try { x.removeState(st.expire.id); } finally { A.naturalRemoval = false; }
      } else {
        const user = who(st.user);
        user.setTp(100); user._mp = user.mmp;
        act(ctx.bm, user, st.def ? synth(st.def) : st.skill, st.target || 0);
      }
      rows.push(Object.assign({step: st}, reading(ctx, atk)));
    }
    return {locked, start, rows};
  }));
}
battleCase('none', {});
battleCase('inversebone', {affix: 'inversebone'});
battleCase('void', {affix: 'void'});
// 期二①：def 为合成技能 [code, dataId, value1]；scope 1 敌方单体、7 友方单体；目标序号按 scope 取对方或己方
const S = (scope, hitType, ...effects) => ({scope, hitType, effects});
// 疫囊：pestStates（灼伤 17、致盲 37）与减益必中、不可驱散；回合末传给全体敌人；自然到期照常去掉
battleCase('pest', {affix: 'pest', armor: 1013}, [
  {user: 'e0', def: S(1, 1, [21, 17, 1])}, {user: 'e0', def: S(1, 1, [21, 37, 1])}, {user: 'e0', def: S(1, 1, [32, 2, 3])},
  {user: 'b', def: S(7, 0, [22, 17, 1])}, {user: 'b', def: S(7, 0, [34, 2, 0])}, {roundEnd: 1},
  {expire: {who: 'a', id: 17}}, {user: 'b', def: S(7, 0, [22, 37, 1])}, {user: 'e1', def: S(1, 1, [32, 3, 2])}, {roundEnd: 2}, {roundEnd: 2}]);
// 囚厄：队友实际获得的 jailStates（沉默 6）与减益转给囚厄者，回合取较长；接收的不可驱散，自然到期后照常
battleCase('jail', {affix: 'jail'}, [
  {user: 'e0', target: 1, def: S(1, 1, [21, 6, 1])}, {user: 'e0', target: 1, def: S(1, 1, [32, 3, 3])},
  {user: 'b', def: S(7, 0, [22, 6, 1])}, {user: 'b', def: S(7, 0, [34, 3, 0])}, {expire: {who: 'a', id: 6}},
  {user: 'e0', def: S(1, 1, [21, 6, 1])}, {user: 'b', def: S(7, 0, [22, 6, 1])}, {user: 'e0', target: 1, def: S(1, 1, [21, 17, 1])}]);
// 绝缘：外来治疗、回蓝、登记增益（野性印记 116）、增益、减益、jailStates、驱散都拒收；自己给自己照常；非登记减益状态照常
battleCase('insulation', {affix: 'insulation'}, [
  {set: {aHp: 0.5, aMp: 0.5, bHp: 0.5}}, {user: 'b', skill: 8}, {user: 'a', skill: 8}, {user: 'b', def: S(7, 0, [21, 116, 1])},
  {user: 'a', def: S(7, 0, [21, 116, 1])}, {user: 'e0', def: S(1, 0, [22, 116, 1])}, {user: 'b', def: S(7, 0, [31, 2, 3])},
  {user: 'e0', def: S(1, 1, [32, 2, 3])}, {user: 'e0', def: S(1, 1, [21, 6, 1])}, {user: 'e0', def: S(1, 1, [21, 17, 1])},
  {set: {aMp: 0.5}}, {user: 'b', def: S(7, 0, [12, 0, 0.1])}, {user: 'b', def: S(7, 0, [11, 0, 0.1])}, {user: 'a', def: S(7, 0, [11, 0, 0.1])}]);
// 舍身：自己得到的治疗、登记增益状态、增益转给绑定队友（角色 8）；减益与普通状态不转
battleCase('sacrifice', {affix: 'sacrifice', config: {actorId: 1, partnerId: 8}}, [
  {set: {aHp: 0.5, bHp: 0.5}}, {user: 'b', skill: 8}, {user: 'a', skill: 8}, {user: 'b', def: S(7, 0, [31, 2, 3])},
  {user: 'a', def: S(7, 0, [21, 116, 1])}, {user: 'e0', def: S(1, 1, [32, 2, 3])}, {user: 'b', def: S(7, 0, [11, 0, 0.1])},
  {user: 'e0', def: S(1, 1, [21, 17, 1])}, {user: 'b', target: 1, skill: 8}]);
// 期二②（生命池类）：空壳、连命、嫁祸都绑定角色 8（空壳不绑定）；regen 照回合末 onTurnEnd（再生、护盾衰减）；revive 照 removeState(阵亡)
// 空壳：生命上限 1，开场剩余生命变护盾；治疗无效，回蓝变护盾（按开场生命／法力比例，护盾不超过原生命上限）；护盾打穿后倒下
battleCase('hollow', {affix: 'hollow'}, [
  {user: 'e0', skill: 1}, {user: 'b', skill: 8}, {set: {aMp: 0.5}}, {user: 'b', def: S(7, 0, [12, 0, 0.1])},
  {user: 'a', def: S(7, 0, [12, 0, 0.2])}, {regen: 'a'}, {user: 'e0', def: S(1, 0, [11, 0, -0.5])}, {user: 'e0', skill: 1}]);
// 连命：两人合并生命池（开场按剩余生命相加），各自按自己的上限比例显示；伤害与治疗都结算到池；池归零两人倒下；复活回池 10%
battleCase('lifelink', {affix: 'lifelink', config: {actorId: 1, partnerId: 8}}, [
  {user: 'e0', skill: 1}, {user: 'e1', skill: 1, target: 1}, {user: 'b', skill: 8}, {user: 'e0', def: S(1, 0, [11, 0, -0.1])},
  {user: 'b', target: 1, skill: 8}, {regen: 'a'}, {user: 'e0', def: S(1, 0, [11, 0, -1])}, {user: 'e0', def: S(1, 0, [11, 0, -1])},
  {revive: 'a'}]);
// 嫁祸：敌人对自己的生命伤害改由保护者（角色 8）按保护者的防御、护盾承受；自己的生命按保护者比例显示，治疗无效；保护者倒下自己也倒下
battleCase('scapegoat', {affix: 'scapegoat', config: {actorId: 1, partnerId: 8}}, [
  {user: 'e0', skill: 1}, {user: 'e0', def: S(1, 0, [11, 0, -0.1])}, {user: 'b', skill: 8}, {user: 'b', target: 1, skill: 8},
  {user: 'e1', skill: 1, target: 1}, {regen: 'a'}, {set: {bHp: 0.01}}, {user: 'e0', skill: 1}, {revive: 'a'}]);
process.exit(finish(host, 'alien_affix.json', {hostScope: '新游戏（Math.random 0.5）；异化词条效果期一（逆骨、归墟）、期二①（疫囊、囚厄、绝缘、舍身）、期二②（空壳、连命、嫁祸）', config, cases}) ? 0 : 1);
