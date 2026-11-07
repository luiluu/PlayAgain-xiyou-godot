'use strict';
// 【cc·哪吒·未经审查】newsrc6 DC②：krz_state_re 的 Game_Actor.prototype.gainHp 是角色自己的方法（装载时抓的是当时的 Game_Battler.gainHp），
// 之后装到 Game_Battler.prototype.gainHp 上的包装对角色不生效、对敌人生效。量两处原版结果给规则车道：
//   ① 璇·余辉（installNativeXuanRuntime：回光溢出按 20／35／50% 转璇同源护盾）：回光真实 apply 给队友（溢出）、给璇自己；
//      同一个 BattleManager._action 下对照直接调 Game_Battler.prototype.gainHp（包装本该跑的路径）和敌人 gainHp。
//   ② 绑定（installNativeBindingChargeRuntime：敌方行动期间不可选中者脚本扣血整份排除）：登记一个参照种类 probe（同 binding_probe），
//      附身后在敌人行动里对附身者 gainHp(-50)、setHp、addState，再对照 Game_Battler.prototype.gainHp 直调；璇种类另有 Game_Actor 包装（xuan_bind owner.hp_loss）。
// 随机 0.5，五乘区、路线压制关（O-050）。产物 .sandbox/gainhp_shadow.json，拷成 tests/fixtures/gainhp_shadow_oracle.json（只给规则车道作参照，暂无专项）。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const X = w.CodexXuan, B = w.CodexBinding, L = w.CodexShieldLedger;
if (!X || !B || !L) throw new Error('璇／绑定模块未安装');
w.eval('CodexZones.ENABLED=false;');
w.CodexRouteSuppress.otherScale = () => 1;
w.CodexRouteSuppress.isSuper = () => false;
w.CodexRouteSuppress.support = () => 1;
const stub = new Proxy(function () {}, {get: (_, k) => k === '_waitCount' ? 0 : (() => false), set: () => true});
w.BattleManager.actionBattleHud = () => true;
w.BattleManager.otbDisplayWindow = () => stub;
if (!w.$) w.$ = {};
w.$.toaster = () => {};
const XUAN = 177, ALLY = 1;
const KEY = k => X.ids().skill[k];
const shields = b => L.rows(b).map(r => ({...r, value: round(r.value)}));
const cases = [];
cases.push(makeCase('shape', {}, () => ({
  actorOwnGainHp: Object.prototype.hasOwnProperty.call(w.Game_Actor.prototype, 'gainHp'),
  enemyOwnGainHp: Object.prototype.hasOwnProperty.call(w.Game_Enemy.prototype, 'gainHp'),
  actorOwnSetHp: Object.prototype.hasOwnProperty.call(w.Game_Actor.prototype, 'setHp'),
  actorOwnAddState: Object.prototype.hasOwnProperty.call(w.Game_Actor.prototype, 'addState'),
})));

function xuanSetup(level, mark) {
  newGame();
  w.Math.random = () => 0.5;
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.eval(`$gameParty._actors=[${XUAN},${ALLY}]; $gameParty._battleMembers=[${XUAN},${ALLY},0,0,0];`);
  w.$gameSwitches.setValue(2494, true);
  const a = w.$gameActors.actor(XUAN), t = w.$gameActors.actor(ALLY);
  a.changeLevel(level, false);
  const c = X.chart(a);
  if (mark) { c.level.yuhui = mark; c.slots[0] = 'yuhui'; }
  X.syncMarkSkills(a); a.refresh(); a.recoverAll();
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager;
  bm.setup(3, true, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.SceneManager._scene = {_otbDisplayWindow: stub};
  bm.startBattle(); bm.startTurn();
  a.refresh(); t.refresh(); t.recoverAll();
  return {a, t, e: w.$gameTroop.members()[0], bm};
}
// ① 余辉：hurt＝队友生命比例；via＝apply（真实回光）／battler（Game_Battler.prototype.gainHp 直调，同一行动）／enemy（敌人 gainHp，同一行动）
for (const mark of [1, 2, 3])  // 星图初始就学了余辉 1 级（CFG.chart.initial），没有「0 级」
  for (const [via, hurt] of [['apply', 0.99], ['apply', 0.2], ['self', 0.99], ['battler', 0.99], ['enemy', 0.99]]) {
  cases.push(makeCase(`yuhui.${mark}.${via}.${hurt}`, {mark, via, hurt}, () => {
    const c = xuanSetup(60, mark);
    const act = new w.Game_Action(c.a); act.setSkill(KEY('huiguang'));
    const who = via === 'self' ? c.a : via === 'enemy' ? c.e : c.t;
    who.setHp(Math.max(1, Math.floor(who.mhp * hurt)));
    const before = who.hp, heal = round(X.healAmount(c.a, who));
    c.bm._action = act; who.clearResult();
    if (via === 'apply' || via === 'self') act.apply(who);
    else if (via === 'battler') w.Game_Battler.prototype.gainHp.call(who, heal);
    else who.gainHp(heal);
    c.bm._action = null;
    return {markLevel: X.markLevel(c.a, 'yuhui'), mhp: round(who.mhp), before: round(before), after: round(who.hp), heal, hpDamage: round(who.result().hpDamage), shields: shields(who)};
  }));
}
// ② 绑定：参照种类 probe（本体 9，形态 367、耗尽 654 都是空状态），手动附身到 1 号
const OWNER = 9, HOST = 1, FORM = 367, EMPTY = 654;
B.register('probe', {isOwner: a => a.actorId() === OWNER, formState: FORM, emptyState: EMPTY, manual: () => true, canHost: () => true});
function bindSetup() {
  newGame();
  w.Math.random = () => 0.5;
  w.eval('$gameParty._actors=[1,8,9,10]; $gameParty._battleMembers=[1,8,9,10,0];');
  for (const id of [1, 8, 9, 10]) { const a = w.$gameActors.actor(id); a.refresh(); a.recoverAll(); }
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager;
  bm.setup(2, true, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.SceneManager._scene = {_otbDisplayWindow: stub};
  bm.startBattle(); bm.startTurn();
  for (const e of w.$gameTroop.members()) { e._paramPlus[0] = 1e9; e.refresh(); e.recoverAll(); }
  return {bm, o: w.$gameActors.actor(OWNER), h: w.$gameActors.actor(HOST), e: w.$gameTroop.members()[0]};
}
for (const [tag, op, during] of [['hurt', 'hurt', true], ['hurt_battler', 'hurt_battler', true], ['set', 'set', true], ['state', 'state', true], ['hurt_idle', 'hurt', false], ['host_hurt', 'host', true]]) {
  cases.push(makeCase(`bind.${tag}`, {op, during}, () => {
    const c = bindSetup();
    const bound = B.bind(c.o, c.h, 'bind');
    const untargetable = B.untargetable(c.o);
    // 敌人行动开始（startAction 包装记下行动者＝敌人），量完 endAction 收尾（同 binding_probe begin／run）
    if (during) { const act = new w.Game_Action(c.e); act.setSkill(1); act.setTarget(-1); c.e._actions = [act]; c.bm._subject = c.e; c.bm._action = null; c.bm.startAction(); }
    const before = {o: c.o.hp, h: c.h.hp};
    if (op === 'hurt') c.o.gainHp(-50);
    else if (op === 'hurt_battler') w.Game_Battler.prototype.gainHp.call(c.o, -50);
    else if (op === 'set') c.o.setHp(10);
    else if (op === 'state') c.o.addState(4);
    else if (op === 'host') c.h.gainHp(-50);
    const after = {o: c.o.hp, h: c.h.hp, state4: c.o.isStateAffected(4)};
    if (during) c.bm.endAction();
    return {bound: !!bound, untargetable, enemyActing: during, before, after};
  }));
}
process.exit(finish(host, 'gainhp_shadow.json', {hostScope: '真实 Game_Action.apply／BattleManager（startBattle→startTurn），Math.random 0.5，五乘区与路线压制关', cases}) ? 0 : 1);
