'use strict';
// 【cc·悟空·未经审查】璇第三期（installNativeXuanRuntime）：星契自律。50 级、进阶 3、星谱选「自动」开战后附身，充能（星契）按行动次数给。
// 内部施放 cast（保留最后 1 点、先照预支与债务）；敌人行动前璃壁（并轨 2 级副宿主）；行动后救援回光（并轨 1 级）、列星、宿主攻击后棱光
// （分光按目标数分摊、同调跟元素）；同轨协同；回合末释放顺序；自动战斗选的行动（autoAction）。
// 真实 BattleManager.startAction～endAction、startTurn／endTurn，队伍 [177, 1, 8, 2]，3 号敌群（敌人生命加 1e9），Math.random 0.5；
// 五乘区、路线压制三处（otherScale、isSuper、support）关（O-050）。产物 .sandbox/xuan_auto.json，手工复制为 tests/fixtures/xuan_auto_oracle.json
// （tests/xiyou_xuan_auto 对照，不进同步）。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const X = w.CodexXuan, B = w.CodexBinding, L = w.CodexShieldLedger;
if (!X || !B || !L) throw new Error('璇模块未安装');
w.eval('CodexZones.ENABLED=false;');
w.CodexRouteSuppress.otherScale = () => 1;
w.CodexRouteSuppress.isSuper = () => false;
w.CodexRouteSuppress.support = () => 1;
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
const lines = [];
const logWin = new Proxy(function () {}, {get: (_, k) => k === '_waitCount' ? 0 : k === 'push' ? ((m, t) => { if (m === 'addText') lines.push(t); }) : (() => false), set: () => true});
const XUAN = 177, PARTY = [XUAN, 1, 8, 2], TROOP = 3;
let current = PARTY;
const I = X.ids(), K = k => I.skill[k], ST = k => I.state[k];
const key = b => !b ? null : b.isActor() ? 'a' + b.actorId() : 'e' + b.index();
const who = x => typeof x === 'number' ? w.$gameActors.actor(x) : w.$gameTroop.members()[+String(x).slice(1)];
function battle(o) {
  B.clearAll();  // 真实游戏战斗结束时清绑定模块的回合记号（startedRound／endedRound）；各例不结束战斗，不清会把上一例的回合号带进来、跳过回合收尾
  newGame();
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.$gameSwitches.setValue(2494, true);
  current = o.party || PARTY;
  w.eval(`$gameParty._actors=[${current}]; $gameParty._battleMembers=[${current},0];`);
  const a = who(XUAN);
  a.changeLevel(o.level || 60, false);
  a._AdvancedNum = o.stage == null ? 3 : o.stage;
  const c = X.chart(a);
  for (const [m, lv] of Object.entries(o.marks || {})) { c.level[m] = lv; c.slots[X.MARKS.indexOf(m) < 3 ? 0 : X.MARKS.indexOf(m) < 6 ? 1 : 2] = m; }
  if (o.partner) c.partner = o.partner;
  if (o.roster) c.roster = o.roster.slice();
  if (o.element) c.element = o.element;
  X.syncMarkSkills(a);
  if (o.relic != null) {  // 周天命星仪：relic true 装上、false 卸下（列星法宝特效看 X.relicOn）
    const slot = a.equipSlots().indexOf(w.$dataArmors[I.relic].etypeId);
    if (o.relic) { w.$gameParty.gainItem(w.$dataArmors[I.relic], 1); a.forceChangeEquip(slot, w.$dataArmors[I.relic]); }
    else a.forceChangeEquip(slot, null);
  }
  a._codexXuanControl = o.manual ? 'manual' : 'auto';
  for (const id of current) { const x = who(id); x.refresh(); x.recoverAll(); }
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  w.Math.random = () => 0.5;
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = logWin; bm._spriteset = stub; bm._statusWindow = stub;
  w.SceneManager._scene = {_otbDisplayWindow: stub};
  for (const t of w.$gameTroop.members()) { t._paramPlus[0] = 1e9; t._paramPlus[2] += o.enemyAtk || 0; }
  for (const b of [...w.$gameParty.members(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  bm.startBattle();
  bm.startTurn();
  bm._phase = 'turn';
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
function begin(bm, user, skillId, targetIndex) {
  const action = new w.Game_Action(user); action.setSkill(skillId); action.setTarget(targetIndex);
  user._actions = [action]; bm._subject = user; bm._action = null;
  bm.startAction();
}
const hits = [];
const oldExec = w.Game_Action.prototype.executeHpDamage;
w.Game_Action.prototype.executeHpDamage = function (t, v) { hits.push(['hp', key(this.subject()), key(t), Math.round(v)]); return oldExec.apply(this, arguments); };
const casts = [];
const oldCast = B.cast;
B.cast = function (owner, id, targets) { const out = oldCast.apply(this, arguments); casts.push([I.key[id] || id, (targets || []).map(key), !!out]); return out; };
const xs = b => L.rows(b).filter(r => /^xuan\./.test(r.source)).map(r => [r.source, Math.round(r.amount), r.until]);
function snap() {
  const a = who(XUAN), d = a._codexXuan || null, bd = B.data(a), h = B.host(a);
  const party = {};
  for (const id of current.slice(1)) {
    const x = who(id);
    party['a' + id] = {hp: x.hp, shield: xs(x), states: x._states.filter(s => s === 10 || s === 35 || s === ST('shadow') || s === ST('hostmark') || s === ST('dingxing')).sort((p, q) => p - q),
      home: x._codex60Home ? x._codex60Home.until : null, mist: x._codex60StarMist ? x._codex60StarMist.until : null};
  }
  const enemies = {};
  for (const e of w.$gameTroop.members()) enemies[key(e)] = {hp: e.hp, buffs: [e._buffs[3], e._buffs[5]]};
  return {round: B.round(), host: h ? 'a' + h.actorId() : null, charges: bd ? bd.charges : null, auto: X.autoEnabled(a),
    xuan: {hp: a.hp, mp: a.mp, shield: xs(a), cd: ['huiguang', 'libi', 'lengguang', 'liexing'].map(k => a.cooldown(K(k))),
      states: a._states.filter(s => [ST('possess'), ST('tonggui'), ST('debt'), ST('liexing'), 10].includes(s)).sort((p, q) => p - q),
      data: d ? {tacit: d.tacit, tonggui: d.tonggui, debt: d.debt, xianzhaoRound: d.xianzhaoRound, liexingUntil: d.liexingUntil, shadows: d.shadows.slice(), used: Object.keys(d.used).sort(), homeUsed: !!d.homeUsed, relicHealUsed: !!d.relicHealUsed, relicWallUsed: !!d.relicWallUsed} : null,
      relic: X.relicOn(a)},
    party, enemies};
}
// 步骤：use 人 键 目标（璇的指令，目标给角色号或 e序号）｜act 人 技能号 目标（e序号或角色号）｜hit 敌序号 技能号 角色号｜turn｜hp 人 比例｜state 人 状态号｜
// gain 人 n｜spend 人 n｜tacit 值｜auto 人（makeAutoBattleActions 选的行动）｜libi 人 量（重给一份璃壁）｜end
function step(bm, st) {
  const [op, x, y, z] = st;
  let ret = null;
  const tix = t => typeof t === 'string' ? +t.slice(1) : w.$gameParty.members().indexOf(who(t));
  if (op === 'use') { begin(bm, who(x), K(y), tix(z)); run(bm); }
  else if (op === 'act') { const u = who(x); u.setMp(u.mmp); begin(bm, u, y, tix(z)); run(bm); }
  else if (op === 'hit') { begin(bm, who(x), y, tix(z)); run(bm); }
  else if (op === 'turn') { bm._enteredEndPhase = false; bm._phase = 'turn'; bm.endTurn(); bm.startTurn(); bm._phase = 'turn'; }
  else if (op === 'hp') { const u = who(x); u.setHp(Math.max(1, Math.floor(u.mhp * y))); }
  else if (op === 'state') { who(x).addState(y); who(x).refresh(); }
  else if (op === 'gain') B.gain(who(x), y);
  else if (op === 'spend') B.spend(who(x), y);
  else if (op === 'tacit') { const d = who(XUAN)._codexXuan; d.tacit = x; d.tonggui = x >= 100 && B.isBound(who(XUAN)); }
  else if (op === 'auto') {
    const a = who(x); a._actions = [new w.Game_Action(a)]; a.makeAutoBattleActions();
    const act = a._actions[0], it = act && act.item();
    ret = {skill: it ? (I.key[it.id] || it.id) : null, target: act ? act._targetIndex : null};
  }
  else if (op === 'libi') { L.revoke(who(x), 'xuan.libi'); L.grant(who(x), 'xuan.libi', y, 2, XUAN, {noBonus: true}); }
  else if (op === 'skip') { const u = who(x); u._actions = []; bm._subject = u; bm._action = null; bm._phase = 'turn'; bm.processTurn(); bm._phase = 'turn'; }  // 没有行动或不能行动：真实 processTurn，不 startAction／endAction
  else if (op === 'invalid') { const u = who(x), a2 = new w.Game_Action(u); u.setMp(0); a2.setSkill(y); a2.setTarget(tix(z)); u._actions = [a2]; bm._subject = u; bm._action = null; bm._phase = 'turn'; bm.processTurn(); run(bm); }  // isValid 假：processTurn 整次跳过
  else if (op === 'force') {  // 事件强制行动：照走 startAction～endAction（同 guyu_battle_probe）
    const u = who(x); u.forceAction(y, tix(z)); bm.forceAction(u); bm._subject = null;
    for (let i = 0; i < 20000 && (bm._actionForcedBattler || bm._subject || ['action', 'actionList', 'actionTargetList', 'phaseChange'].includes(bm._phase)); i++) {
      if (bm._actionForcedBattler && !bm._subject) { bm.processForcedAction(); continue; }
      const ph = bm._phase;
      if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
      else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
    }
    bm._phase = 'turn';
  }
  else if (op === 'learn') who(x).learnSkill(y);
  else if (op === 'lv') who(x).changeLevel(y, false);
  else if (op === 'tuse') { const u = who(x), id = w.CodexTusu.ids().skill[y]; u.setMp(u.mmp); begin(bm, u, id, tix(z)); run(bm); }
  else if (op === 'end') bm.endBattle(0);
  else throw new Error('未知步骤 ' + op);
  return ret;
}
// 每例：setup（等级、星纹、副宿主、名册、手动）与步骤
const SCRIPTS = {
  // 没到 60 级：不给归宿、星幕、额外净化。排最前：法宝一旦被 60 级的璇同步过就留着进化标记（$dataArmors 跨例共用），放后面量到的是进化后的属性
  home_59: [{level: 59, manual: true, relic: true}, [['use', XUAN, 'jixing', 1], ['turn'], ['use', XUAN, 'liexing', XUAN], ['use', XUAN, 'libi', 1], ['hit', 'e0', 1, 1], ['state', 1, 35], ['use', XUAN, 'huiguang', 1]]],
  // 附身 1 号后下一回合有星契；1 号半血以下，8 号行动结束时救援回光（保留最后 1 点也能护主）；列星就绪也放（护主）；回合末剩的星契按顺序放
  rescue: [{}, [['use', XUAN, 'jixing', 1], ['turn'], ['hp', 1, 0.3], ['act', 8, 1, 'e0'], ['turn'], ['act', 8, 1, 'e0'], ['turn']]],
  // 宿主攻击后棱光：星契 2 点以上才放（保留最后 1 点），列星先放
  followup: [{}, [['use', XUAN, 'jixing', 1], ['turn'], ['gain', XUAN, 3], ['act', 1, 1, 'e1'], ['act', 1, 1, 'e1'], ['turn']]],
  // 只剩 1 点：宿主攻击后不放棱光
  keep_last: [{}, [['use', XUAN, 'jixing', 1], ['turn'], ['act', 1, 1, 'e1'], ['act', 1, 1, 'e0']]],
  // 分光 3 级＋同调 2 级：全体魔法闪电（元素 5）后棱光分给三名敌人、跟元素
  fenguang: [{marks: {fenguang: 3}}, [['use', XUAN, 'jixing', 1], ['turn'], ['gain', XUAN, 3], ['act', 1, 10, 'e0']]],
  tongdiao2: [{marks: {tongdiao: 2}}, [['use', XUAN, 'jixing', 1], ['turn'], ['gain', XUAN, 3], ['act', 1, 10, 'e0']]],
  tongdiao1: [{marks: {tongdiao: 1}, element: 3}, [['use', XUAN, 'jixing', 1], ['turn'], ['gain', XUAN, 3], ['act', 1, 1, 'e0']]],
  // 敌人打宿主前璃壁（一回合一次）；并轨 2 级：打副宿主也给
  libi: [{}, [['use', XUAN, 'jixing', 1], ['turn'], ['hit', 'e0', 1, 1], ['hit', 'e1', 1, 1], ['hit', 'e2', 1, 8]]],
  binggui2: [{marks: {binggui: 2}, partner: 8}, [['use', XUAN, 'jixing', 1], ['turn'], ['hit', 'e0', 1, 8], ['turn'], ['hp', 8, 0.3], ['act', 2, 1, 'e0']]],
  binggui1: [{marks: {binggui: 1}, partner: 8}, [['use', XUAN, 'jixing', 1], ['turn'], ['hp', 8, 0.3], ['act', 2, 1, 'e0'], ['hit', 'e0', 1, 8]]],
  // 先照：星契 0 时护主预支 1 点（债务），下回合开始还；3 回合一次
  xianzhao: [{marks: {xianzhao: 1}}, [['use', XUAN, 'jixing', 1], ['turn'], ['spend', XUAN, 1], ['hp', 1, 0.3], ['act', 8, 1, 'e0'], ['turn'], ['spend', XUAN, 1], ['hp', 1, 0.3], ['act', 8, 1, 'e0'], ['turn'], ['turn'], ['spend', XUAN, 1], ['hp', 1, 0.3], ['act', 8, 1, 'e0']]],
  // 同轨：默契 100 时回光／璃壁带一次棱光式协同（打第一个活着的敌人）
  tonggui: [{}, [['use', XUAN, 'jixing', 1], ['turn'], ['tacit', 100], ['hp', 1, 0.3], ['act', 8, 1, 'e0'], ['hit', 'e0', 1, 1]]],
  // 宿主中硬控：救援回光净化（定星 2 级给定星）
  cleanse: [{marks: {dingxing: 2}}, [['use', XUAN, 'jixing', 1], ['turn'], ['state', 1, 10], ['act', 8, 1, 'e0']]],
  // 回合末释放：没人缺血时打棱光、再璃壁
  roundend: [{}, [['use', XUAN, 'jixing', 1], ['turn'], ['gain', XUAN, 3], ['turn'], ['gain', XUAN, 1], ['turn']]],
  // 手动模式：没有星契，什么都不自动放；自动战斗本体时救人、寄星（名册优先）（附身时 autoAction 返回 null，留给原选择，那是通用自动战斗，不比）
  manual: [{manual: true, roster: [8]}, [['auto', XUAN], ['hp', 2, 0.2], ['auto', XUAN], ['use', XUAN, 'jixing', 1], ['turn'], ['hp', 1, 0.3], ['act', 8, 1, 'e0']]],
  // 定轨（10 级，手动）：敌人攻击打破璃壁给一次定星，同回合同人只一次；下一回合以后再破再给
  dinggui: [{manual: true}, [['use', XUAN, 'jixing', 1], ['libi', 1, 10], ['hit', 'e0', 1, 1], ['libi', 1, 10], ['hit', 'e1', 1, 1], ['turn'], ['turn'], ['libi', 1, 10], ['hit', 'e0', 1, 1]]],
  // 定轨只认敌方直接伤害行动：诸神黄昏（8048，不带伤害，真实动作序列 Hp -10%: actors）打破璃壁，不给定星
  dinggui_seq: [{manual: true}, [['use', XUAN, 'jixing', 1], ['libi', 1, 10], ['hit', 'e0', 8048, 'e0']]],
  // 60 级列星·归宿（不看法宝）：列星后第一次回光或璃壁给目标归宿，下一次敌方直接伤害 −10%；当回合有效；再放列星重置
  home: [{manual: true, relic: false}, [['use', XUAN, 'jixing', 1], ['turn'], ['use', XUAN, 'liexing', XUAN], ['hit', 'e0', 1, 1], ['use', XUAN, 'libi', 1], ['hit', 'e0', 1, 1], ['hit', 'e1', 1, 1],
    ['use', XUAN, 'huiguang', 1], ['hit', 'e0', 1, 1], ['turn'], ['use', XUAN, 'liexing', XUAN], ['use', XUAN, 'huiguang', 1], ['turn'], ['hit', 'e0', 1, 1]]],
  // 法宝：首次璃壁给星幕（和归宿同一次时 ×0.81）；被不带伤害的序列扣血不消费
  mist: [{manual: true, relic: true, enemyAtk: 5000}, [['use', XUAN, 'jixing', 1], ['turn'], ['use', XUAN, 'liexing', XUAN], ['use', XUAN, 'libi', 1], ['hit', 'e0', 8048, 'e0'], ['hit', 'e0', 1, 1], ['hit', 'e1', 1, 1], ['use', XUAN, 'libi', 1], ['hit', 'e0', 1, 1]]],
  // 法宝：回光后再璃壁：归宿给了回光目标，星幕给璃壁目标；两次都不重复
  mist_after_heal: [{manual: true, relic: true}, [['use', XUAN, 'jixing', 1], ['turn'], ['use', XUAN, 'liexing', XUAN], ['use', XUAN, 'huiguang', 1], ['use', XUAN, 'libi', 8], ['hit', 'e0', 1, 8], ['hit', 'e1', 1, 1], ['hit', 'e2', 1, 1]]],
  // 法宝：首次回光额外净化一个（含软状态）；第二次回光不额外；没戴法宝只净化硬控
  cleanse2: [{manual: true, relic: true}, [['use', XUAN, 'jixing', 1], ['turn'], ['use', XUAN, 'liexing', XUAN], ['state', 1, 10], ['state', 1, 35], ['use', XUAN, 'huiguang', 1], ['state', 1, 35], ['use', XUAN, 'huiguang', 1]]],
  cleanse_norelic: [{manual: true, relic: false}, [['use', XUAN, 'jixing', 1], ['turn'], ['use', XUAN, 'liexing', XUAN], ['state', 1, 10], ['state', 1, 35], ['use', XUAN, 'huiguang', 1]]],
  // 列星期间一次璃壁打到所有受益者：一次行动里每个目标都拿到归宿、星幕
  shadow_all: [{manual: true, relic: true}, [['use', XUAN, 'jixing', 1], ['turn'], ['use', XUAN, 'liexing', XUAN], ['use', XUAN, 'libi', 1], ['hit', 'e0', 1, 8], ['hit', 'e1', 1, 2]]],
  // 列星期外不给；战斗结束清
  outside: [{manual: true, relic: true}, [['use', XUAN, 'jixing', 1], ['turn'], ['use', XUAN, 'libi', 1], ['hit', 'e0', 1, 1]]],
  // 自律：敌人出手前内部璃壁也算首次（这一下就减）
  auto_mist: [{relic: true}, [['use', XUAN, 'jixing', 1], ['turn'], ['gain', XUAN, 3], ['hp', 1, 0.3], ['act', 8, 1, 'e0'], ['hp', 1, 1], ['hit', 'e0', 1, 1], ['hit', 'e1', 1, 1]]],
  // 审查 35b P2-1：敌人跳过的回合（没有行动、不能行动、行动无效）不走 endAction，不救援；同样残血，事件强制行动走 endAction 才救援
  skip_turn: [{}, [['use', XUAN, 'jixing', 1], ['turn'], ['hp', 1, 0.3], ['skip', 'e0'], ['state', 'e1', 10], ['skip', 'e1'], ['invalid', 'e2', 8, 'e2'], ['force', 'e0', 1, 8]]],
  // 角色不一样：OTB processTurn 对角色走 startOTBInput，不能输入也 makeActions＋startAction，照走 endAction 救援；只是没有行动，宿主被控也不放棱光
  skip_actor: [{}, [['use', XUAN, 'jixing', 1], ['turn'], ['hp', 1, 0.3], ['state', 2, 10], ['skip', 2]]],
  skip_host: [{}, [['use', XUAN, 'jixing', 1], ['turn'], ['gain', XUAN, 3], ['state', 1, 10], ['skip', 1]]],
  // 被控角色的回合：外层 startAction 包装没有行动就直接 endAction，走不到绑定的 startAction，回归当回合不扣充能
  skip_return: [{}, [['use', XUAN, 'jixing', 1], ['turn'], ['gain', XUAN, 3], ['use', XUAN, 'return', XUAN], ['state', XUAN, 10], ['skip', XUAN], ['skip', XUAN]]],
  // endAction 的绑定包装照跑 validate：宿主倒下，被控队友这一回合结束就解绑
  skip_validate: [{}, [['use', XUAN, 'jixing', 1], ['turn'], ['state', 8, 10], ['state', 1, 1], ['skip', 8]]],
  // 审查 36 P3：60 级列星后回合末连放：每次内部施放单独判「首次」（B.cast 清 _grants60），归宿只给第一次回光的目标（8 号），接着的璃壁给 1 号不再带
  liexing60_roundend: [{}, [['use', XUAN, 'jixing', 1], ['turn'], ['gain', XUAN, 5], ['act', 8, 1, 'e0'], ['hp', 8, 0.3], ['turn']]],
  // 审查 35b P3-1：棱光打主行动最后的目标（Game_Action.apply 包装记在这个行动上）。甚尔万里锁溅射是子行动；黄泉扩散、镜流补段 oldApply 绕过璇的包装；都不改
  last_toji: [{party: [XUAN, 171, 8, 2]}, [['use', XUAN, 'jixing', 171], ['turn'], ['gain', XUAN, 3], ['learn', 171, 10217], ['act', 171, 10217, 'e1']]],
  last_jingliu: [{party: [XUAN, 170, 8, 2]}, [['use', XUAN, 'jixing', 170], ['turn'], ['gain', XUAN, 3], ['learn', 170, 10190], ['state', 'e1', 2629], ['act', 170, 10190, 'e1']]],
  last_sukuna: [{party: [XUAN, 172, 8, 2]}, [['use', XUAN, 'jixing', 172], ['turn'], ['gain', XUAN, 3], ['learn', 172, 10230], ['act', 172, 10230, 'e1']]],
  last_sukuna_all: [{party: [XUAN, 172, 8, 2]}, [['use', XUAN, 'jixing', 172], ['turn'], ['gain', XUAN, 3], ['learn', 172, 10233], ['act', 172, 10233, 'e1']]],
  last_tusu: [{party: [XUAN, 1, 8, 176]}, [['lv', 176, 60], ['tuse', 176, 'huawu.sword', 1], ['use', XUAN, 'jixing', 1], ['turn'], ['gain', XUAN, 3], ['act', 1, 1, 'e1']]],
  last_yomi: [{party: [XUAN, 169, 8, 2]}, [['use', XUAN, 'jixing', 169], ['turn'], ['gain', XUAN, 3], ['learn', 169, 10172], ['act', 169, 10172, 'e1']]],
  autoact: [{roster: [8]}, [['auto', XUAN], ['hp', 2, 0.2], ['auto', XUAN], ['use', XUAN, 'jixing', 1], ['auto', XUAN], ['end']]]
};
const cases = [];
for (const [id, [setup, steps]] of Object.entries(SCRIPTS)) cases.push(makeCase(id, setup, () => {
  const bm = battle(setup), out = [{step: ['start'], snap: snap()}];
  for (const st of steps) {
    hits.length = 0; lines.length = 0; casts.length = 0;
    const ret = step(bm, st);
    out.push({step: st, ret, hits: hits.slice(), casts: casts.slice(), lines: lines.slice(), snap: snap()});
  }
  return out;
}));
// 先照「手动璃壁先制」：Game_Action.speed ＋100000，只有 makeSpeed 时行动里已经是璃壁才生效。真实流程量：makeActionOrders 在回合开始跑，
// 这时行动列表是空的／空白行动（出手后 removeCurrentAction），所以 OTB 排序不受影响。control 例把璃壁硬塞进 _actions 再排，证明包装本身是生效的。
const inSpeed = [];
const oldMake = w.Game_Battler.prototype.makeSpeed, oldSpeed = w.Game_Action.prototype.speed;
let making = false;
w.Game_Battler.prototype.makeSpeed = function () { making = true; try { return oldMake.apply(this, arguments); } finally { making = false; } };
w.Game_Action.prototype.speed = function () { const v = oldSpeed.apply(this, arguments), it = this.item(); if (making && this.subject() === who(XUAN)) inSpeed.push(it ? (I.key[it.id] || it.id) : null); return v; };
const orderOf = list => list.map(key);
function speedCase(o) {
  const bm = battle({manual: !o.auto, marks: o.mark ? {xianzhao: 1} : {}});
  const a = who(XUAN);
  a._paramPlus[6] -= a.agi - 1; a.refresh();  // 璇敏捷压到 1：本来排最后，才看得出先制有没有用
  const raw = new w.Game_Action(a); raw.setSkill(K('libi'));
  const speed = raw.speed() - a.agi;  // 随机 0.5 下的浮动＋包装加的
  begin(bm, a, K('jixing'), w.$gameParty.members().indexOf(who(1))); run(bm);
  bm._enteredEndPhase = false; bm._phase = 'turn'; bm.endTurn(); bm.startInput(); bm._phase = 'turn';
  const out = {speedOffset: Math.round(speed), current: orderOf(bm._actionBattlers), next: orderOf(bm._nextTurnActionBattlers)};
  out.canMove = a.canMove(); out.canInput = a.canInput();
  a.makeActions();
  a.currentAction().setSkill(K('libi')); a.currentAction().setTarget(w.$gameParty.members().indexOf(who(1)));
  bm._subject = a; bm.startAction(); run(bm);
  a.removeCurrentAction();  // endOTBAction
  out.actionsLeft = a._actions.length;
  inSpeed.length = 0;
  bm._enteredEndPhase = false; bm._phase = 'turn'; bm.endTurn(); bm.startInput(); bm._phase = 'turn';  // 真实 endTurn→startInput（makeActions 清行动）→startTurn→makeActionOrders
  out.seenInMakeSpeed = inSpeed.slice();
  out.afterCurrent = orderOf(bm._actionBattlers); out.afterNext = orderOf(bm._nextTurnActionBattlers);
  // 对照：硬塞璃壁再排，才会排到最前
  const act = new w.Game_Action(a); act.setSkill(K('libi')); a._actions = [act];
  bm.makeActionOrdersOTB();
  out.forcedNext = orderOf(bm._nextTurnActionBattlers);
  return out;
}
for (const [id, o] of Object.entries({speed_manual: {mark: true}, speed_nomark: {mark: false}, speed_auto: {mark: true, auto: true}})) cases.push(makeCase(id, o, () => speedCase(o)));
process.exit(finish(host, 'xuan_auto.json', {hostScope: '真实 BattleManager.startAction～endAction、startTurn／endTurn；星契自律；随机 0.5；五乘区、路线压制三处关', cases}) ? 0 : 1);
