'use strict';
// 【cc·悟空·未经审查】璇与屠苏的美术（Codex_XuanTusuExtraArt、Codex_XuanTusuArtPack）：启动后的专属图标 iconIndex、未竟环换图阶段、
// SuperSV 标签（平时逐帧图、绑定形态）、星魂 projectionFor、持武 weaponOfHost、专属技能的动作。画面坐标 jsdom 量不了，不比。
// 产物 .sandbox/xuan_tusu_art.json，拷成 tests/fixtures/xuan_tusu_art_oracle.json（不进同步），专项 xiyou_xuan_tusu_art。
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

const A = w.CodexXuanTusuArt, T = w.CodexTusu;
if (!A) throw new Error('美术模块未装');
A.install();
const cases = [];
const META = m => ({sv: m.sv, speed: m.SVspeed, shadow: m.YCyy, zs0: m.SVzs0, zs1: m.SVzs1, zs7: m.SVzs7});
const provide = a => META(w.Mx.SuperSVMetaProvider(a, {...a.actor().meta}));
const proj = id => { const p = A.projectionFor(who(id)); return p ? p.role : null; };
cases.push(makeCase('icons', {}, () => {
  const out = {};
  for (const [name, list] of [['Skills', w.$dataSkills], ['States', w.$dataStates], ['Items', w.$dataItems], ['Armors', w.$dataArmors]])
    for (const it of list) if (it && /<Codex(Tusu|Xuan):/i.test(it.note || '')) out[name + ':' + it.id] = it.iconIndex;
  return {out, stages: [0, 1, 2, 3, 4, 5, 6].map(n => A.relicStage(n))};
}));
cases.push(makeCase('bound', {party: [XUAN, 1, 8, 176]}, () => {
  const bm = battle({party: [XUAN, 1, 8, 176]}), ts = who(176), a = who(XUAN), out = [];
  ts.changeLevel(60, false);
  const row = tag => out.push({tag, xuan: provide(a), tusu: provide(ts), proj: [1, 8, 2 === 0 ? 0 : 176, XUAN].map(proj), host: [1, 8].map(id => T.weaponOfHost(who(id)) || null), bound: [a, ts].map(x => w.CodexBinding.isBound(x))});
  row('start');
  const tuse = key => { const u = ts, id = T.ids().skill[key]; u.setMp(u.mmp); begin(bm, u, id, w.$gameParty.members().indexOf(who(1))); run(bm); };
  tuse('huawu.sword'); row('sword');
  for (const wp of ['bow', 'shield', 'book', 'hammer']) { begin(bm, ts, T.ids().skill['yiwu.' + wp], 0); run(bm); row(wp); bm._enteredEndPhase = false; bm._phase = 'turn'; bm.endTurn(); bm.startTurn(); bm._phase = 'turn'; }
  begin(bm, a, K('jixing'), w.$gameParty.members().indexOf(who(8))); run(bm); row('jixing8');
  bm._enteredEndPhase = false; bm._phase = 'turn'; bm.endTurn(); bm.startTurn(); bm._phase = 'turn';
  const d = a._codexXuan; d.liexingUntil = w.CodexBinding.round() + 1; d.shadows = [1]; row('shadow');
  d.shadows = []; d.liexingUntil = -1; row('noshadow');
  who(8).addState(1); w.CodexBinding.validate(); row('hostdead');
  return out;
}));
// 动作：performAction 包装按技能键 requestMotion；performAttack
const motionOf = (u, skillId) => { const last = []; const old = u.requestMotion; u.requestMotion = function (m) { last.push(m); return old.apply(this, arguments); };
  const act = new w.Game_Action(u); if (skillId === 1) act.setAttack(); else act.setSkill(skillId); try { if (skillId === 1 || act.isAttack()) { u.performAttack(); } else u.performAction(act); } finally { u.requestMotion = old; } return last[last.length - 1] || null; };
cases.push(makeCase('motions', {}, () => {
  battle({party: [XUAN, 1, 8, 176]});
  const out = {}, ts = who(176), a = who(XUAN), X = w.CodexXuan;
  for (const [k, id] of Object.entries(X.ids().skill)) if (id && w.$dataSkills[id] && !/^mark\.|menu\./.test(k)) out['x.' + k] = motionOf(a, id);
  for (const [k, id] of Object.entries(T.ids().skill)) if (id && w.$dataSkills[id] && !/^mark\.|menu\./.test(k)) out['t.' + k] = motionOf(ts, id);
  out.attackX = motionOf(a, 1); out.attackT = motionOf(ts, 1);
  return out;
}));
process.exit(finish(host, 'xuan_tusu_art.json', {hostScope: '启动后的图标与绑定状态下的美术读数', cases}) ? 0 : 1);
