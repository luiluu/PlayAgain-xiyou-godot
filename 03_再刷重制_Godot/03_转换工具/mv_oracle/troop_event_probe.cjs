'use strict';
// 敌群事件参照（扩楼层：一至三、五至九、十一至十二层守层者 4/5/8/28/39/52/53/67/109/110 与十层守层者 69（另有 333 给自己加状态 44）第 1 回合的强制行动 339 → 技能 8111「轮回模式·平衡伤害」→ 状态 1460「轮回困难v1」）。
// 真实 BattleManager 跑前两回合（日志窗/精灵组用空代理，同 sequence_probe）：普通难度、开局队伍 1/8/9/10（1 级，开局被动），
// 角色输入一律普通攻击敌人 0；Math.random 敌群生成时 0.99（不出神话），之后 0.5（分散度为 0、不会心）。
// 记录：每次开始行动（回合数、行动者、技能、是否强制）、每次 invokeAction 的目标血量变化与伤害弹字（startDamagePopup 时的 hpDamage）、
// 行动者攻击/魔攻，以及战斗中的状态。只写 .sandbox/troop_events.json。
const fs = require('fs'), path = require('path');
const {boot} = require('./hboot.cjs'), {sourceIdentity} = require('./source_identity.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Applications/再刷一把：西游（mod_KYO）.app/Contents/Resources/app.nw';
const identity = sourceIdentity(APP), r = boot(APP, {tolerant: true, log: false}), w = r.window;
if (r.errors.length || !w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败');
const PARTY = [1, 8, 9, 10], TROOPS = [4, 5, 8, 28, 39, 52, 53, 67, 69, 109, 110];
const stub = new Proxy(function () {}, {get: (t, k) => k === '_waitCount' ? 0 : (() => false), set: () => true});
const sprite = () => {
  const store = {x: 0, y: 0, _homeX: 0, _homeY: 0, width: 64, height: 64, scale: {x: 1, y: 1}, anchor: {x: 0.5, y: 1}, opacity: 255};
  return new Proxy(store, {get: (t, k) => k in t ? t[k] : (() => false), set: (t, k, v) => { t[k] = v; return true; }});
};
const sprites = new Map();
w.BattleManager.actionBattleHud = function () { return true; };
w.BattleManager.otbDisplayWindow = function () { return stub; };
w.Game_Battler.prototype.battler = function () { if (!sprites.has(this)) sprites.set(this, sprite()); return sprites.get(this); };
const key = b => b.isActor() ? 'a' + b.actorId() : 'e' + b.index();
let popups = null;
w.Game_Battler.prototype.startDamagePopup = function () {
  if (popups) popups.push({target: key(this), hpDamage: this._result.hpDamage, hpAffected: this._result.hpAffected});
};

function run(troopId) {
  w.eval('ConfigManager.applyData({});DataManager.setupNewGame();$gameSystem.setDifficultyId(3);for(var i=1;i<5000;i++)if($gameVariables._data[i]===undefined)$gameVariables._data[i]=0;');
  w.eval('$gameParty._actors=[];' + JSON.stringify(PARTY) + '.forEach(function(id){$gameParty.addActor(id);});');
  for (const id of PARTY) {
    const a = w.$gameActors.actor(id);
    [6168, 5980, 5548].concat([1, 2, 3, 4, 5, 6, 7, 52].includes(id) ? [2571, 2786] : []).forEach(k => a.learnSkill(k));
    a.refresh(); a.recoverAll();
  }
  if (!w.$dataMap) w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const BM = w.BattleManager;
  w.Math.random = () => 0.99;
  BM.setup(troopId, false, false);
  BM._logWindow = stub; BM._spriteset = stub; BM._statusWindow = stub;
  w.Math.random = () => 0.5;
  const out = {troop: troopId, actions: [], invokes: [], errors: [], battlers: {}};
  const inv = BM.invokeAction, sa = BM.startAction;
  BM.startAction = function () {
    const s = this._subject, act = s && s.currentAction();
    out.actions.push({turn: w.$gameTroop._turnCount, subject: s && key(s), skill: act && act.item() ? act.item().id : null,
      forced: !!(act && act._forcing), processingForced: !!this._processingForcedAction});
    return sa.call(this);
  };
  BM.invokeAction = function (su, t) {
    const hp0 = t.hp; popups = [];
    const res = inv.call(this, su, t);
    out.invokes.push({turn: w.$gameTroop._turnCount, subject: key(su), skill: this._action && this._action.item() ? this._action.item().id : null,
      target: key(t), hpBefore: hp0, hpAfter: t.hp, popups, userAtk: su.atk, userMat: su.mat,
      userStates: su._states.slice(), targetStates: t._states.slice()});
    popups = null;
    return res;
  };
  try {
    BM.startBattle();
    for (let i = 0; i < 20000; i++) {
      if (BM._phase === 'battleEnd' || w.$gameTroop._turnCount > 2 || BM.isBattleEnd && BM._phase === null) break;
      if (BM._phase === 'input') {
        const act = BM.inputtingAction();
        if (act) { act.setAttack(); act.setTarget(0); }
        BM.selectNextCommand();
        continue;
      }
      BM.update();
    }
  } catch (e) { out.errors.push(String(e && e.stack || e).slice(0, 800)); }
  BM.invokeAction = inv; BM.startAction = sa;
  for (const b of w.$gameParty.battleMembers().concat(w.$gameTroop.members()))
    out.battlers[key(b)] = {hp: b.hp, mhp: b.mhp, atk: b.atk, mat: b.mat, agi: b.agi, states: b._states.slice()};
  out.turnCount = w.$gameTroop._turnCount;
  out.phase = BM._phase;
  return out;
}

const result = {sourceIdentity: identity, party: PARTY, difficulty: 3, cases: TROOPS.map(run)};
if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname, '.sandbox'), {recursive: true});
fs.writeFileSync(path.join(__dirname, '.sandbox/troop_events.json'), JSON.stringify(result, null, 1));
process.stdout.write(JSON.stringify(result.cases.map(c => ({troop: c.troop, actions: c.actions.length, invokes: c.invokes.length, errors: c.errors.length, turn: c.turnCount, phase: c.phase}))) + '\n');
process.exit(0);
