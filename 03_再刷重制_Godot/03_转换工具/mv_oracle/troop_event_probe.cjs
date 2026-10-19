'use strict';
// 敌群事件参照（扩楼层：一至三、五至九、十一至十二层守层者 4/5/8/28/39/52/53/67/109/110 、十层守层者 69（另有 333 给自己加状态 44）与十三至十九层守层者 111／118／138／172／173／174／333（变量 842 为 0 时先调公共事件 1398：334 完全回复、313 全队加状态、333 加状态，再强制 6069／6105／8111）、二十层守层者 456（842 为 0 时公共事件 1399 天道领域＋强制 6070／8111，否则 1400 天道领域*伪＋强制 6071；第 3 回合起每 3 回合随机 844 强制 6101～6104 与 8111）、二十一层守层者 457 与二十二层守层者 458（同 456；第 3 页生命≤20% 且变量 853＝1 的 101 对话与专属强制 3559／3560 首两回合参照不覆盖）、二十三层守层者 459（只有两页，不交礼开场比 456 多强制 6105／6107，没有第 3 页）、二十四层守层者 460（同 459）、二十五层守层者 461（同 459）、二十六层守层者 462（金角、银角两名守层者，同 459；另加玩家集火敌人 1 的两例）、二十七层守层者 463、二十八层守层者 464（同 459）与二十四层副本熊族桃园首领 526 雄霸（第 2 页第 1 回合 333 给自己状态 44、339 强制技能 3813）第 1 回合的强制行动 339 → 技能 8111「轮回模式·平衡伤害」→ 状态 1460「轮回困难v1」）。
// 二十九层太白金星 465 同 459；三十层玉皇大帝 466 不交礼开场另加强制 6101，另加 HP≤25% 的两例（hpRate：第 3 页 101 对话、336 变身 538、1399、强制 6070／6105）。
// 三十一至三十三层守层者 467 女娲／468 伏羲／469 鸿蒙老祖（四页：第 3 回合起每 3 回合随机强制、第 1 回合变量 842＝0 时公共事件 1397 霸者领域＋强制 6068／6055／6057／6051／8111、
// HP≤30% 第 3 页 101 对话＋1397、HP≤10% 第 4 页 101 对话＋336 变身 929／929／930＋1399）与三十层求道者门后 Map055 引路人 794（HP≤20% 第 4 页变身 922）：
// 各加 HP≤30%（hpRate 0.3）一例；HP≤10% 一例另预置第 3 页已执行（flags：第 3 页先回满会让第 4 页条件不再成立，实战是先过 30% 再过 10%）。
// 十三至十九层补已交见面礼（变量 842＝1）分支，确认不触发开场领域与强制行动。
// 十五层副本敌群 160（控尸者 HP≤1% 时两只丧尸附加状态 1）：开战前控尸者 HP 设 1（守层者那套两回合检查以 e0 为首领，不适用这个敌群）（preset，只到第 1 回合输入前）。
// 真实 BattleManager 跑前两回合（日志窗/精灵组用空代理，同 sequence_probe）：普通难度、开局队伍 1/8/9/10（1 级，开局被动），
// 角色输入一律普通攻击敌人 0；Math.random 敌群生成时 0.99（不出神话），之后 0.5（分散度为 0、不会心）。
// 记录：每次开始行动（回合数、行动者、技能、是否强制）、每次 invokeAction 的目标血量变化与伤害弹字（startDamagePopup 时的 hpDamage）、
// 行动者攻击/魔攻，以及战斗中的状态。只写 .sandbox/troop_events.json。
const fs = require('fs'), path = require('path');
const {boot} = require('./hboot.cjs'), {sourceIdentity} = require('./source_identity.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity = sourceIdentity(APP), r = boot(APP, {tolerant: true, log: false}), w = r.window;
if (r.errors.length || !w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败');
const PARTY = [1, 8, 9, 10], TROOPS = [4, 5, 8, 28, 39, 52, 53, 67, 69, 109, 110, 111, 118, 138, 172, 173, 174, 333, 456, 457, 458, 459, 460, 461, 462, 463, 464, 465, 466, 467, 468, 469, 794, 526,
  // 二十七层副本墓池的二十八宿石像首领与四圣兽（607 角开场强制 8111；614／622／630／638 同 526：第 2 页第 1 回合给状态 44、强制 3813）
  607, 614, 622, 630, 638,
  // 二十九层副本太上老君藏身处的五位首领 733～737 与两位「太上老君」731／732（同 526）
  731, 732, 733, 734, 735, 736, 737,
  // 二十六层副本兜率宫·丹房的三位天尊投影 603／604／605（同 526）
  603, 604, 605,
  // 二十八层副本众分天的首领：Map208 恶·如来 695 与随机头目 696～704，Map209 善·无天 706 与随机头目 707～715（同 526）
  695, 696, 697, 698, 699, 700, 701, 702, 703, 704, 706, 707, 708, 709, 710, 711, 712, 713, 714, 715,
  // 深渊图的被封印者战斗（204～215、223～238、344～351、370／371、379～386、401～404、413～418：开场强制行动 339、状态 313／333、达摩变形条件）
  204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238,
  344, 345, 346, 347, 348, 349, 350, 351, 370, 371, 379, 380, 381, 382, 383, 384, 385, 386, 401, 402, 403, 404, 413, 414, 415, 416, 417, 418];
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
// 插件指令 battleback … scroll speed（三十一层起守层者第 2 页）：只改战斗背景画面；无场景时原函数读 SceneManager._scene._spriteset 报错，
// 按「没有 spriteset 就返回」处理（同原函数在 spriteset 缺失时的分支）。
const alterBattleback = w.BattleManager.alterBattleback;
w.BattleManager.alterBattleback = function (line) { return w.SceneManager._scene ? alterBattleback.call(this, line) : undefined; };

// hpRate：开战前把敌人 0 的 HP 设为上限的这个比例（向下取整），照常跑两回合；消息忙时直接关掉（模拟玩家读完），
// 记录 messages（每条的回合与文字）与回合结束时各敌人的 enemyId（三十层敌群 466：HP≤25% 第 3 页 101 对话、336 变身 538、1399、强制 6070／6105）。
// flags：开战前把这些敌群页标为已执行（$gameTroop._eventFlags），旧例不写字段。
function run(troopId, paid = false, preset = null, target = 0, hpRate = 0, flags = null) {
  w.eval('ConfigManager.applyData({});DataManager.setupNewGame();$gameSystem.setDifficultyId(3);for(var i=1;i<5000;i++)if($gameVariables._data[i]===undefined)$gameVariables._data[i]=0;');
  w.eval('$gameParty._actors=[];' + JSON.stringify(PARTY) + '.forEach(function(id){$gameParty.addActor(id);});');
  w.$gameVariables.setValue(842, paid ? 1 : 0);
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
  const out = {troop: troopId, paid, actions: [], invokes: [], errors: [], battlers: {}};
  if (target !== 0) out.target = target;   // 玩家普通攻击的敌人序号（默认 0 不写字段，旧例逐字节不变）
  if (flags) { out.flags = flags; for (const i of flags) w.$gameTroop._eventFlags[i] = true; }
  if (hpRate) {
    out.hpRate = hpRate; out.messages = [];
    const e0 = w.$gameTroop.members()[0];
    e0.setHp(Math.floor(e0.mhp * hpRate));
    out.hpPreset = e0.hp;
  }
  // preset：开战前把敌人 HP 设成定值（{敌人序号: hp}），只跑到第 1 回合输入前，记开场敌群事件的结果
  if (preset) {
    out.preset = preset;
    for (const i of Object.keys(preset)) w.$gameTroop.members()[Number(i)].setHp(preset[i]);
  }
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
      if (preset && BM._phase === 'input') break;
      if (hpRate && w.$gameMessage.isBusy()) {
        out.messages.push({turn: w.$gameTroop._turnCount, texts: w.$gameMessage._texts.slice(), faceName: w.$gameMessage.faceName()});
        w.$gameMessage.clear();
        continue;
      }
      if (BM._phase === 'input') {
        const act = BM.inputtingAction();
        if (act) { act.setAttack(); act.setTarget(target); }
        BM.selectNextCommand();
        continue;
      }
      BM.update();
    }
  } catch (e) { out.errors.push(String(e && e.stack || e).slice(0, 800)); }
  BM.invokeAction = inv; BM.startAction = sa;
  for (const b of w.$gameParty.battleMembers().concat(w.$gameTroop.members()))
    out.battlers[key(b)] = {hp: b.hp, mhp: b.mhp, atk: b.atk, mat: b.mat, agi: b.agi, states: b._states.slice()};
  if (hpRate) out.enemyIds = w.$gameTroop.members().map(e => e.enemyId());
  out.turnCount = w.$gameTroop._turnCount;
  out.phase = BM._phase;
  return out;
}

const result = {sourceIdentity: identity, party: PARTY, difficulty: 3,
  cases: TROOPS.map(id => run(id)).concat([111,118,138,172,173,174,333,456,457,458,459,460,461,462,463,464,465,466].map(id => run(id, true)))
    // 敌群 462 有金角、银角两名守层者：玩家集火银角（敌人 1），看第二名守层者受击与行动
    .concat([run(462, false, null, 1), run(462, true, null, 1)])
    // 十五层副本废墟深处：敌群 160 控尸者（第 3 名）HP≤1% 时两只丧尸附加战斗不能（只记开场敌群事件）
    .concat([run(160, false, {2: 1})])
    // 三十层敌群 466 玉皇大帝 HP≤25%：第 3 页对话、变身 538 与之后的强制行动（交礼／未交礼各一例）
    .concat([run(466, false, null, 0, 0.25), run(466, true, null, 0, 0.25)])
    // 三十一至三十三层守层者 HP≤30%（第 3 页）与 HP≤10%（第 3 页已执行，第 4 页变身）；Map055 引路人 794 HP≤20%（第 4 页变身 922）
    .concat([467, 468, 469].flatMap(id => [run(id, false, null, 0, 0.3), run(id, false, null, 0, 0.1, [2])]))
    .concat([run(794, false, null, 0, 0.2)])};
if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
fs.mkdirSync(path.join(__dirname, '.sandbox'), {recursive: true});
fs.writeFileSync(path.join(__dirname, '.sandbox/troop_events.json'), JSON.stringify(result, null, 1));
process.stdout.write(JSON.stringify(result.cases.map(c => ({troop: c.troop, actions: c.actions.length, invokes: c.invokes.length, errors: c.errors.length, turn: c.turnCount, phase: c.phase}))) + '\n');
process.exit(0);
