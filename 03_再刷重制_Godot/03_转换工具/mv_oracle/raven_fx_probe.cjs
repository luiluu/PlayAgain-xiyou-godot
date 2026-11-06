'use strict';
// 【cc·悟空·未经审查】渡鸦施放特效的屏蔽支（v0.62.12 js/codex/runtime/installRavenSkillEffectsRuntime.js，与 v0.28 同文）：
// ① Window_BattleLog.showNormalAnimation 包装：10122～10127 由渡鸦放时换成矢量施放特效 V.play（一次调用一组，目标去重），不放原动画；
// ② CodexRaven.Fx.play 包装（108～115 行）：本次行动的技能有施放特效、且是同一个施放者时，slash／ring 不画；harvest／echo 照画；
// ③ Spriteset_Battle.isAnimationPlaying（84～86 行）：施放特效没放完就算动画没放完；每组 life 帧后自己结束；同时最多 6 组。
// 真实 BattleManager 行动序列（startAction→actionList）；战斗日志窗只接显示动画几条（showActionAnimation 等走原型），其余空转。
// 场景、精灵是假的：只给 V.play 要的 _battleField、battlerSprites；R.Fx 的 ensure 换成记一笔（画出来＝走到 ensure）。
// 产物 .sandbox/raven_fx.json（拷成 tests/fixtures/raven_fx_oracle.json），专项 xiyou_raven_fx。
// 跑法：XIYOU_APP=…/冻结正式源/v0.62.12/app.nw node raven_fx_probe.cjs
const {start, makeCase, finish, superReference} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const V = w.CodexRavenEffects, R = w.CodexRaven;
if (!V || !R || !R.Fx) throw new Error('渡鸦特效模块未安装');
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
w.Math.random = () => 0.5;
w.eval('CodexZones.ENABLED=false;');
superReference(w);
// 日志窗：显示动画这几条走 Window_BattleLog 原型（含渡鸦包装），其余空转
const SHOW = ['showActionAnimation', 'showAnimation', 'showNormalAnimation', 'showAttackAnimation', 'showActorAttackAnimation', 'showEnemyAttackAnimation'];
const logWin = new Proxy({}, {get: (t, k) => SHOW.includes(k) ? w.Window_BattleLog.prototype[k].bind(logWin) : k === '_waitCount' ? 0 : (k in t ? t[k] : () => false),
  set: (t, k, v) => { t[k] = v; return true; }});
// 假场景：V.play 要 Scene_Battle、_spriteset._battleField、battlerSprites()
const field = {addChild() {}, removeChild() {}};
const spriteset = Object.create(w.Spriteset_Battle.prototype);
spriteset._battleField = field;
spriteset._animationSprites = [];
spriteset.battlerSprites = () => [...w.$gameParty.battleMembers(), ...w.$gameTroop.members()].map((b, i) => ({_battler: b, x: 100 + i * 50, y: 300, height: 96, isAnimationPlaying: () => false}));
const scene = Object.create(w.Scene_Battle.prototype);
scene._spriteset = spriteset;
w.SceneManager._scene = scene;
// 记录：V.play（施放特效）与 R.Fx.play（外层，含屏蔽支）；ensure 走到＝真的画了
const rec = [];
const vPlay = V.play;
V.play = function (subject, skillId, targets) {
  const ok = vPlay.apply(this, arguments);
  rec.push({kind: 'cast', skill: skillId, targets: (targets || []).length, played: ok});
  return ok;
};
const fxPlay = R.Fx.play;
let drawn = false;
R.Fx.ensure = function () { drawn = true; };  // pool 留空：原 play 走到这里就返回，不建 PIXI 图形
R.Fx.play = function (subject, target, type) {
  drawn = false;
  const out = fxPlay.apply(this, arguments);
  rec.push({kind: 'fx', type, drawn});
  return out;
};
const ACTOR = 167, TROOP = 3, BIG_HP = 1e12;
function battle(opts = {}) {
  newGame();
  w.eval('$gameParty._actors=[];$dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.$gameSwitches.setValue(2494, true);  // 渡鸦是超强者，开挑战才能招募
  const a = w.$gameActors.actor(ACTOR);
  a.changeLevel(99, false);
  R.recruit();
  if (!w.$gameParty.members().includes(a)) throw new Error('招募失败');
  a._codexRavenStage = a._AdvancedNum = 5;  // 神话封解、神话被动 10170、残响 10133 要等级与进阶门槛（招募后设，招募会重整）
  for (const id of [10122, 10123, 10124, 10125, 10126, 10127, 10133, 10170]) if (!a.isLearnedSkill(id)) a.learnSkill(id);
  a._paramPlus[0] = BIG_HP;
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = logWin; bm._spriteset = stub; bm._statusWindow = stub;
  w.$gameParty._inBattle = true;
  for (const e of w.$gameTroop.members()) e._paramPlus[0] = BIG_HP;
  for (const b of [...w.$gameParty.allMembers(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  for (const m of w.$gameParty.battleMembers()) m.onBattleStart();
  bm.startTurn();
  if (opts.myth) a._codexRavenMythTurns = 3;
  if (opts.hunter) a._codexRavenHunter = true;
  V.active.slice().forEach(f => f.finish());
  return {bm, a};
}
function act(bm, user, skillId, targetIndex) {
  const action = new w.Game_Action(user); action.setSkill(skillId); action.setTarget(targetIndex);
  user._actions = [action]; bm._subject = user; bm._action = null;
  user.gainMp(user.mmp); user._tp = 100;
  bm.startAction();
  for (let i = 0; i < 20000; i++) {
    const ph = bm._phase;
    if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
    else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
  }
  if (bm._phase === 'action' || bm._phase === 'actionList') bm.endAction();
}
const cases = [];
const SKILLS = [10122, 10123, 10124, 10125, 10126, 10127];
// ①② 每个技能放一次：施放特效几组、各组几个目标；R.Fx 各类型画没画；放完 isAnimationPlaying，逐帧 update 到结束的帧数
for (const id of SKILLS) for (const mode of ['normal', 'myth']) {
  cases.push(makeCase(`cast.${id}.${mode}`, {skill: id, mode}, () => {
    const {bm, a} = battle({myth: mode === 'myth', hunter: mode === 'myth'});
    rec.length = 0;
    act(bm, a, id, 0);
    const log = rec.slice();
    const playing = spriteset.isAnimationPlaying();
    const groups = V.active.length;
    let frames = 0;
    while (V.active.length && frames < 500) { V.active.slice().forEach(f => f.update()); frames++; }
    return {log, playing, groups, frames, after: spriteset.isAnimationPlaying(), myth: a._codexRavenMythTurns || 0};
  }));
}
// ③ 放完前再放一次（不 update）：两组同时在；连放 8 次封顶 6 组
cases.push(makeCase('twice', {skill: 10122}, () => {
  const {bm, a} = battle();
  act(bm, a, 10122, 0); act(bm, a, 10122, 0);
  const two = V.active.length;
  for (let i = 0; i < 6; i++) act(bm, a, 10123, 0);
  const capped = V.active.length;
  V.active.slice().forEach(f => f.finish());
  return {two, capped};
}));
// 别的角色放同一技能：不换施放特效，原 Fx 也不由它触发
cases.push(makeCase('other', {actor: 1, skill: 10122}, () => {
  const {bm} = battle();
  const b = w.$gameActors.actor(1); w.$gameParty.addActor(1); b.learnSkill(10122); b._paramPlus[0] = BIG_HP; b.recoverAll();
  rec.length = 0;
  act(bm, b, 10122, 0);
  return {log: rec.slice(), groups: V.active.length};
}));
process.exit(finish(host, 'raven_fx.json', {hostScope: '正式 BattleManager 行动序列、Window_BattleLog 显示动画、CodexRavenEffects.play、CodexRaven.Fx.play（屏蔽支）', cases}) ? 0 : 1);
