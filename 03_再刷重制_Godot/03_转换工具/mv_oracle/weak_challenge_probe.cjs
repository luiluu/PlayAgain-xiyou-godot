'use strict';
// 【cc·weak1·未经审查】弱者挑战一期（js/codex/runtime/installWeakChallengeRuntime.js，CodexWeakChallenge）：
// ① 弱者分类 W.isWeak（全部有名字的角色）；② 新局：全局配置 codexWeakFiveClearV2 关／开时，各角色是否带 10357「你才是真正的强者」、
//   八项属性、物理／魔法承伤率（sparam 6／7）、HP／MP 是否回满，learnSkill(10357) 能否学；③ 存读档：本局标记 _codexWeakClearV2 决定读档后学／忘；
// ④ 伤害：弱者 2 号普攻敌群 3、敌人普攻 2 号（开关两支）；⑤ 最终战：Map157 敌群 469、混沌（难度 9）、五名弱者胜利后
//   全局与本局标记、成就 142、全员学 10357，以及难度不对、四人、混入强者、强者中途入队又离队、逃跑等不给的情形；之后新局弱者自动带技能。
// 五乘区（CodexZones）不移植，照 actor1_damage 探针关掉。ConfigManager.save 换成计数（只在内存）。
// 产物 .sandbox/weak_challenge.json（generated/oracle/weak_challenge.json），专项 xiyou_weak_challenge。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w} = host;
const W = w.CodexWeakChallenge;
if (!W || W.skillId !== 10357) throw new Error('弱者挑战模块未安装');
w.eval('CodexZones.ENABLED=false;');
let saves = 0;
w.ConfigManager.save = () => { saves++; };
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
const SK = W.skillId;
// 同 host.newGame，只是全局配置带上弱者通关标记
function newGame(clear) {
  w.eval('ConfigManager.applyData({codexWeakFiveClearV2:' + (clear ? 'true' : 'false') + '});DataManager.setupNewGame();Math.random=function(){return 0.5;};Graphics.frameCount=0;for(var i=1;i<5000;i++)if($gameVariables._data[i]===undefined)$gameVariables._data[i]=0;');
  w.Input.clear();
  w.DataManager.loadMapData(4); w.$gameMap.setup(4); w.$gamePlayer.clearTransferInfo();
  w.eval('$gameParty._actors=[];[1,8,9,10].forEach(function(id){$gameParty.addActor(id);});');
  saves = 0;
}
const params = b => [0, 1, 2, 3, 4, 5, 6, 7].map(i => round(b.param(i)));
const snap = a => ({id: a.actorId(), learned: a.isLearnedSkill(SK), param: params(a), pdr: round(a.sparam(6)), mdr: round(a.sparam(7)),
  hp: round(a.hp), mhp: round(a.mhp), mp: round(a.mp), mmp: round(a.mmp)});
const flags = () => ({config: w.ConfigManager._codexWeakFiveClearV2 === true, system: w.$gameSystem._codexWeakClearV2 === true,
  acGlobal: !!(w.ConfigManager.SAchievementS || {})[142], acParty: !!(w.$gameParty.SAchievementS || {})[142], saves});
const cases = [];

cases.push(makeCase('classify', {}, () => {
  newGame(false);
  const weak = [], strong = [];
  for (let id = 1; id < w.$dataActors.length; id++) {
    const d = w.$dataActors[id];
    if (!d || !d.name) continue;
    (W.isWeak(w.$gameActors.actor(id)) ? weak : strong).push(id);
  }
  return {weak, strong};
}));

// 新局：已在队的 1／8／9／10，再入队 2、3、103（弱者）、167（渡鸦，167～174 不算）、170（强者名单）；之后试学 10357
const JOIN = [2, 3, 103, 167, 170];
for (const clear of [false, true]) {
  cases.push(makeCase('newgame.' + (clear ? 'on' : 'off'), {clear, join: JOIN}, () => {
    newGame(clear);
    for (const id of JOIN) w.$gameParty.addActor(id);
    const rows = [1, 8, 9, 10].concat(JOIN).map(id => snap(w.$gameActors.actor(id)));
    const learn = {};
    for (const id of [1, 2, 167]) { const a = w.$gameActors.actor(id); a.forgetSkill(SK); a.learnSkill(SK); learn[id] = a.isLearnedSkill(SK); }
    return {flags: flags(), rows, learn};
  }));
}

// 存读档：本局标记决定读档后的学／忘（读档不回满）
for (const [id, clear, system, config] of [['keep', true, true, false], ['forget', true, false, true], ['grant', false, true, false], ['none', false, false, true]]) {
  cases.push(makeCase('load.' + id, {clear, system, config}, () => {
    newGame(clear);
    w.$gameParty.addActor(2);
    const a = w.$gameActors.actor(2);
    a.setHp(1);
    w.$gameSystem._codexWeakClearV2 = system;
    const json = host.encode();
    w.ConfigManager._codexWeakFiveClearV2 = config;
    host.restore(json);
    return {flags: flags(), rows: [1, 2].map(i => snap(w.$gameActors.actor(i)))};
  }));
}

// 伤害：弱者 2 号普攻敌群 3 第 1 只、敌人 0 普攻 2 号（敌我生命 +1e12，Math.random 0.5）
const TROOP = 3, BIG_HP = 1e12;
function act(bm, user, skillId, targetIndex) {
  const action = new w.Game_Action(user); action.setSkill(skillId); action.setTarget(targetIndex);
  user._actions = [action]; bm._subject = user; bm._action = null;
  bm.startAction();
  for (let i = 0; i < 20000; i++) {
    const ph = bm._phase;
    if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
    else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
  }
}
function record(fn) {
  const log = [], old = w.Game_Action.prototype.executeHpDamage;
  w.Game_Action.prototype.executeHpDamage = function (target, value) {
    log.push({user: this.subject().isActor() ? 'a' + this.subject().actorId() : 'e' + this.subject().index(),
      target: target.isActor() ? 'a' + target.actorId() : 'e' + target.index(), value: round(value), critical: !!target.result().critical});
    return old.apply(this, arguments);
  };
  try { fn(); } finally { w.Game_Action.prototype.executeHpDamage = old; }
  return log;
}
for (const clear of [false, true]) {
  cases.push(makeCase('damage.' + (clear ? 'on' : 'off'), {clear, troop: TROOP, party: [2, 1, 8, 9, 10]}, () => {
    newGame(clear);
    w.$gameParty.addActor(2);
    w.eval('$gameParty._actors=[2,1,8,9,10];$gameParty._battleMembers=[2,1,8,9,10];');
    for (const b of w.$gameParty.allMembers()) b._paramPlus[0] = BIG_HP;
    w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
    const bm = w.BattleManager; bm.setup(TROOP, false, false);
    bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
    w.$gameParty._inBattle = true;
    for (const e of w.$gameTroop.members()) e._paramPlus[0] = BIG_HP;
    for (const b of [...w.$gameParty.allMembers(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
    bm.startTurn();
    const a = w.$gameActors.actor(2), e = w.$gameTroop.members()[0];
    const before = {members: w.$gameParty.battleMembers().map(b => b.actorId()), a: snap(a), e: params(e)};
    a.setTp(a.maxTp()); a.setMp(a.mmp);
    const log = record(() => { act(bm, a, 1, 0); act(bm, e, 1, 0); });
    w.$gameParty._inBattle = false;
    return {...before, log};
  }));
}

// 最终战：Map157 敌群 469
const WEAK5 = [2, 3, 4, 5, 6];
function final(o) {
  newGame(false);
  w.$gameSystem.setDifficultyId(o.difficulty);
  for (const id of o.party) w.$gameActors.actor(id);
  const slots = o.party.concat([0, 0, 0, 0, 0]).slice(0, 5);
  w.eval('$gameParty._actors=[' + o.party + '];$gameParty._battleMembers=[' + slots + '];');
  w.$gameMap._mapId = 157;
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(o.troop || 469, true, true);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  if (o.visit) { w.$gameParty.addActor(o.visit); w.$gameParty.removeActor(o.visit); }
  if (o.leave) w.$gameParty.removeActor(o.leave);
  if (o.back) w.$gameParty.addActor(o.back);
  if (o.dead) w.$gameActors.actor(o.dead).addState(w.$gameActors.actor(o.dead).deathStateId());
  if (o.result === 0) for (const e of w.$gameTroop.members()) e.addNewState(e.deathStateId());
  const members = w.$gameParty.battleMembers().map(b => b.actorId());
  bm.endBattle(o.result);
  w.$gameParty._inBattle = false;
  return {members, flags: flags(), learned: o.party.map(id => [id, w.$gameActors.actor(id).isLearnedSkill(SK)])};
}
const FINALS = [
  ['win', {party: WEAK5, difficulty: 9, result: 0}],
  ['win.dead', {party: WEAK5, difficulty: 9, result: 0, dead: 3}],
  ['diff8', {party: WEAK5, difficulty: 8, result: 0}],
  ['four', {party: WEAK5.slice(0, 4), difficulty: 9, result: 0}],
  ['strong', {party: [2, 3, 4, 5, 8], difficulty: 9, result: 0}],
  ['visit', {party: WEAK5, difficulty: 9, result: 0, visit: 8}],  // 满五人时 8 号只进替补，仍给
  ['leave', {party: WEAK5, difficulty: 9, result: 0, leave: 6}],
  ['leave.back', {party: WEAK5, difficulty: 9, result: 0, leave: 6, back: 6}],
  ['escape', {party: WEAK5, difficulty: 9, result: 1}],
  ['troop', {party: WEAK5, difficulty: 9, result: 0, troop: 468}],
];
for (const [id, o] of FINALS) cases.push(makeCase('final.' + id, o, () => final(o)));

// 通关后（全局标记已开）再开新局：弱者入队即带技能并回满
cases.push(makeCase('after.newgame', {}, () => {
  final(FINALS[0][1]);
  const config = w.ConfigManager._codexWeakFiveClearV2 === true;
  newGame(config);
  w.$gameParty.addActor(2);
  return {flags: flags(), rows: [1, 2].map(i => snap(w.$gameActors.actor(i)))};
}));

process.exit(finish(host, 'weak_challenge.json', {hostScope: '正式 CodexWeakChallenge（新局、存读档、BattleManager.setup／startAction／endBattle）', cases}) ? 0 : 1);
