'use strict';
// 【cc·白龙_14·未经审查】形态绑定与行动充能框架（js/codex/runtime/installNativeBindingChargeRuntime.js 1～282，W.CodexBinding）：
// 用 CodexBinding.register 登记一个只给参照用的种类 probe（本体 9 号，形态状态 367、充能耗尽状态 654，两个都是无特性的空状态），
// 回调只记事件；屠苏、璇自己的种类不在队里不起作用。真实 BattleManager（setup→startBattle→推进到第一次输入），队伍新局的 1、8、9、10。
// 量：canHost／defaultHost、bind（转移）／unbind 各原因、spend／gain、自然回合开始转充能（被控为 0、manual 为 0）、回合末 onRoundEnd／onRoundClose
// 后清零、回归当回合每次行动扣 1、行动前后 validate（本体／宿主阵亡、离场）、敌方不可命中（随机目标、指定目标、全体、apply）、
// 敌方行动期间脚本扣血与加状态、战斗结束清理。每步后记四人的绑定数据、两个状态、生命、存活、untargetable，回合数，这一步的事件与命中。
// 敌人生命加 1e9；Math.random 0.5。产物 .sandbox/binding.json，拷成 tests/fixtures/binding_oracle.json（不进同步），专项 xiyou_binding。
const {start, makeCase, finish, superReference} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');  // 五乘区（CodexZones）重制不移植（O-044），探针宿主默认开着；关掉让参照不含成长修正（tools50 确认关与不关产物一致或已更新夹具）
const B = w.CodexBinding;
if (!B || typeof B.register !== 'function') throw new Error('绑定框架未安装');
// O-050：不移植五乘区与超强者路线压制，用 shared/host.cjs 的公用开关去掉它们
superReference(w);
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
if (!w.$) w.$ = {};
w.$.toaster = () => {};
const key = b => !b ? null : b.isActor() ? 'a' + b.actorId() : 'e' + b.index();
const OWNER = 9, FORM = 367, EMPTY = 654, PARTY = [1, 8, 9, 10], BIG_HP = 1e9, TROOP = 3;
const events = [];
const opt = {manual: false, deny: 0};
B.register('probe', {
  isOwner: a => a.actorId() === OWNER, formState: FORM, emptyState: EMPTY,
  manual: () => opt.manual,
  canHost: (o, t) => t.actorId() !== opt.deny,
  onBind: (o, t, reason, prev) => events.push(['bind', key(o), key(t), reason, key(prev)]),
  onUnbind: (o, h, reason) => events.push(['unbind', key(o), key(h), reason]),
  onRoundStart: (a, n) => events.push(['roundStart', key(a), n]),
  onRoundEnd: a => events.push(['roundEnd', key(a), B.charges(a)]),
  onRoundClose: a => events.push(['roundClose', key(a), B.charges(a)]),
  onClear: a => events.push(['clear', key(a)]),
});
function battle() {
  newGame();
  w.eval('$gameSystem.setDifficultyId(2); $gameParty._actors=[' + PARTY + ']; $gameParty._battleMembers=[' + PARTY + ',0];');
  for (const id of PARTY) w.$gameActors.actor(id).recoverAll();
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  w.Math.random = () => 0.99;
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  w.Math.random = () => 0.5;
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  for (const t of w.$gameTroop.members()) t._paramPlus[0] = BIG_HP;
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  bm.startBattle();
  for (let tick = 0; tick < 5000 && bm._phase !== 'input'; tick++) {
    if (w.$gameMessage.isBusy()) { w.$gameMessage.clear(); continue; }
    bm.update();
  }
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) b.recoverAll();
  return bm;
}
function run(bm) {
  for (let i = 0; i < 20000; i++) {
    const ph = bm._phase;
    if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
    else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
  }
  bm._phase = 'turn';
}
// targetIndex −1：不指定（敌人随机）
function begin(bm, user, skillId, targetIndex) {
  const action = new w.Game_Action(user); action.setSkill(skillId); action.setTarget(targetIndex);
  user._actions = [action]; bm._subject = user; bm._action = null;
  bm.startAction();
}
const who = x => typeof x === 'number' ? w.$gameActors.actor(x) : w.$gameTroop.members()[+String(x).slice(1)];
function snap() {
  const party = {};
  for (const id of PARTY) {
    const a = w.$gameActors.actor(id), d = B.data(a);
    party['a' + id] = {data: d ? {charges: d.charges, hostId: d.hostId || 0, boundRound: d.boundRound || 0, returnedRound: d.returnedRound || 0} : null,
      form: a.isStateAffected(FORM), empty: a.isStateAffected(EMPTY), hp: a.hp, alive: a.isAlive(), untargetable: B.untargetable(a),
      host: key(B.host(a)), bound: B.isBound(a)};
  }
  return {round: B.round(), party, members: w.$gameParty.battleMembers().map(key)};
}
const hits = [];
const oldExec = w.Game_Action.prototype.executeHpDamage;
w.Game_Action.prototype.executeHpDamage = function (t, v) { hits.push(['hp', key(this.subject()), key(t), v]); return oldExec.apply(this, arguments); };
// 步骤：bind o t｜unbind o 原因｜spend o n｜gain o n｜turn（endTurn＋startTurn）｜act 人 技能 目标序号｜foe 敌序号 技能 目标序号（−1 随机）｜
// kill 人｜revive 人｜leave 人｜back 人（回到出战）｜canHost｜defaultHost｜manual 真假｜deny 角色｜
// pick 敌序号（敌人行动中 randomTarget）｜apply 敌序号 人（敌人普攻直接 apply）｜during 敌序号 [子步骤…]（敌人普攻开始后、结算前做子步骤：hurt 人 量、set 人 生命、state 人 状态）｜end（endBattle）
function step(bm, st) {
  const [op, x, y, z] = st;
  let ret = null;
  if (op === 'bind') ret = B.bind(who(x), who(y), z);
  else if (op === 'unbind') ret = B.unbind(who(x), y);
  else if (op === 'spend') ret = B.spend(who(x), y);
  else if (op === 'gain') B.gain(who(x), y);
  else if (op === 'turn') { bm._enteredEndPhase = false; bm._phase = 'turn'; bm.endTurn(); bm.startTurn(); bm._phase = 'turn'; }
  else if (op === 'act') { begin(bm, who(x), y, z); run(bm); }
  else if (op === 'foe') { begin(bm, who('e' + x), y, z); run(bm); }
  else if (op === 'kill') { const a = who(x); a.setHp(0); a.refresh(); }
  else if (op === 'revive') { const a = who(x); a.removeState(a.deathStateId()); a.setHp(a.mhp); }
  else if (op === 'leave') w.$gameParty._battleMembers = w.$gameParty._battleMembers.map(id => id === x ? 0 : id);
  else if (op === 'back') w.$gameParty._battleMembers = PARTY.concat([0]);
  else if (op === 'canHost') ret = PARTY.map(id => B.canHost(who(OWNER), who(id))).concat([B.canHost(who(OWNER), who('e0'))]);
  else if (op === 'defaultHost') ret = key(B.defaultHost(who(OWNER)));
  else if (op === 'manual') opt.manual = !!x;
  else if (op === 'deny') opt.deny = x;
  else if (op === 'during') {
    begin(bm, who('e' + x), 1, -1);
    ret = y.map(([o, p, q]) => {
      const a = who(p);
      if (o === 'hurt') a.gainHp(-q); else if (o === 'set') a.setHp(q); else if (o === 'state') a.addState(q);
      return {hp: a.hp, state: o === 'state' ? a.isStateAffected(q) : null};
    });
    run(bm);
  } else if (op === 'pick') {  // 敌人行动开始后 $gameParty.randomTarget()
    begin(bm, who('e' + x), 1, -1);
    ret = key(w.$gameParty.randomTarget());
    run(bm);
  } else if (op === 'apply') {  // 敌人普攻直接 apply 到 y（不在行动里）
    const act = new w.Game_Action(who('e' + x)); act.setAttack();
    const t = who(y); act.apply(t);
    ret = {hp: t.hp, used: !!t.result().used};
  } else if (op === 'end') bm.endBattle(0);
  else throw new Error('未知步骤 ' + op);
  return ret;
}
function play(steps) {
  const bm = battle(), out = [{step: ['start'], snap: snap()}];
  for (const st of steps) {
    events.length = 0; hits.length = 0;
    const ret = step(bm, st);
    out.push({step: st, ret, events: events.slice(), hits: hits.slice(), snap: snap()});
  }
  opt.manual = false; opt.deny = 0;
  return out;
}
// 技能 1 普攻（scope 1）；敌人普攻 1；全体用 180
const ALL = w.$dataSkills[180];  // 巨浪术：敌方全体、不耗 MP、没有附加效果
if (!ALL || ALL.scope !== 2 || ALL.mpCost) throw new Error('全体技能 180 变了');
const SCRIPTS = {
  // 宿主规则与默认宿主；绑定、重复绑定、转移；不合法（自己、敌人、拒绝的、本体死了）
  host: [['canHost'], ['defaultHost'], ['deny', 10], ['defaultHost'], ['canHost'], ['bind', 9, 9], ['bind', 9, 'e0'], ['bind', 9, 10], ['bind', 9, 1, 'test'],
    ['bind', 9, 1], ['bind', 9, 8], ['canHost'], ['kill', 1], ['canHost'], ['defaultHost']],
  // 充能：回合开始转充能（行动次数）、spend／gain、回合末 onRoundEnd（有充能、绑定中）与 onRoundClose 后清零；manual 时 0；被控（死了）
  charge: [['bind', 9, 1], ['turn'], ['spend', 9, 1], ['spend', 9, 1], ['gain', 9, 2], ['spend', 9, 3], ['turn'], ['manual', true], ['turn'],
    ['manual', false], ['unbind', 9, 'manual'], ['turn']],
  // 回归：解除当回合有充能时每次行动扣 1、0 充能时充能耗尽状态；下一回合恢复普通；manual 解除不记回归
  ret: [['bind', 9, 1], ['turn'], ['unbind', 9, 'return'], ['act', 9, 1, 0], ['act', 9, 1, 0], ['turn'], ['bind', 9, 1], ['turn'], ['manual', true],
    ['unbind', 9, 'x'], ['manual', false], ['act', 9, 1, 0], ['turn']],
  // 离场与阵亡：宿主阵亡（行动前后 validate）、宿主离场、本体阵亡（充能清零）、本体离场
  leave: [['bind', 9, 8], ['turn'], ['kill', 8], ['act', 1, 1, 0], ['revive', 8], ['bind', 9, 8], ['leave', 8], ['act', 1, 1, 0], ['back'], ['bind', 9, 8],
    ['turn'], ['kill', 9], ['act', 1, 1, 0], ['revive', 9], ['bind', 9, 8], ['leave', 9], ['act', 1, 1, 0], ['back'], ['act', 1, 1, 0]],
  // 敌方不可命中：指定打 9（第 3 位）改随机；随机目标；全体；友方照常；解绑后能打
  untarget: [['bind', 9, 1], ['foe', 0, 1, 2], ['foe', 0, 1, 2], ['foe', 1, 1, -1], ['foe', 2, ALL.id, -1], ['act', 1, 1, 0], ['unbind', 9, 'manual'],
    ['foe', 0, 1, 2]],
  // 敌方行动期间的脚本扣血、setHp、加状态
  during: [['bind', 9, 1], ['during', 0, [['hurt', 9, 50], ['set', 9, 10], ['state', 9, 4], ['state', 9, FORM], ['hurt', 1, 50]]], ['unbind', 9, 'manual'],
    ['during', 0, [['hurt', 9, 50]]]],
  // 直接调：8 号不在时 randomTarget 原生抽到 9（形态中）→ 换人；敌人 apply 直接打 9 不生效、解绑后生效
  direct: [['bind', 9, 1], ['leave', 8], ['pick', 0], ['apply', 0, 9], ['unbind', 9, 'manual'], ['apply', 0, 9], ['pick', 0]],
  // 战斗结束清理
  end: [['bind', 9, 1], ['turn'], ['end']],
};
const cases = Object.entries(SCRIPTS).map(([id, steps]) => makeCase(id, {steps, owner: OWNER, form: FORM, empty: EMPTY, all: ALL.id}, () => play(steps)));
process.exit(finish(host, 'binding.json', {hostScope: '真实 CodexBinding（登记参照种类 probe），真实 BattleManager 行动与回合', cases}) ? 0 : 1);
