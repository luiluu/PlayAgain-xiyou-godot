'use strict';
// 【cc·未经审查】Codex_SmartBattleAI 自带的那条 registerProfile（第 508～526 行）与五个角色的估伤分支（v0.62.12）：
// 黄泉 169（10172～10174 溅射）、流萤 179（10622 溅射）、宿傩 172（领域里神灶：开 10233 的 holdInLongFight；伏魔御厨子 10231 的
// futureActor＋ongoingSkill 10237）、渡鸦 167（神话封解 10127 的 futureActor＋duration 3）、米拉 168（解放 10146 的 futureActor＋followupSkill 10151）。
// 每个角色照各自战斗探针的搭法开一场（敌群 3，敌人生命加 1e12；Math.random 0.5），按步骤改战况，每步记：
//   能用的候选技能、各技能的档案（数值项与标志）、铺垫后的角色视图（能力值、能用的技能、估伤）、伤害技能对各敌人的 safeDamage 与
//   命中／闪避／暴击、choose 的选择与前 6 名候选分数。步骤表在 smart_ai_profile_cases.json（Godot 专项读夹具里的 setup.steps）。
// 只读：choose 不付费、不改形态。只在内存，产物 .sandbox/smart_ai_profile.json，
// 拷成 tests/fixtures/smart_ai_profile_oracle.json（不接入全量同步）。
// 跑法：XIYOU_APP=…/冻结正式源/v0.62.12/app.nw node smart_ai_profile_probe.cjs
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const AI = w.CodexSmartAI;
if (!AI || typeof AI.profile !== 'function') throw new Error('智能 AI 未安装');
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
w.eval('CodexZones.ENABLED=false;');  // 五乘区（CodexZones）重制不移植（O-044）：act 步的真实伤害不带成长修正；估伤本来就不经过它
const BIG_HP = 1e12, TROOP = 3;
const S = w.$dataSkills;

function open() {
  newGame();
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.$gameSwitches.setValue(2494, true);
}
function enter(a, opts = {}) {
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub; bm._enteredEndPhase = false;
  w.$gameParty._inBattle = true;
  if (w.CodexYunshang) w.CodexYunshang._acted = [];
  if (opts.before) opts.before();
  for (const e of w.$gameTroop.members()) e._paramPlus[0] = BIG_HP;
  for (const b of [...w.$gameParty.allMembers(), ...w.$gameTroop.members()]) { b.need_refresh = true; b.refresh(); b.recoverAll(); }
  if (opts.after) opts.after();
  return {bm, a, foes: w.$gameTroop.members()};
}
// 各角色的搭法照各自的战斗探针（yomi_battle／liuying2／sukuna_battle／raven_battle／mira_battle）
const BATTLES = {
  169: () => {  // 黄泉：55 级，学 10171～10174；[169, 1]，两人生命加 1e12
    open(); w.eval('$gameParty._actors=[];');
    w.$gameParty.addActor(169); w.$gameParty.addActor(1);
    for (const id of [169, 1]) { const b = w.$gameActors.actor(id); b.changeLevel(55, false); b._paramPlus[0] = BIG_HP; b.recoverAll(); }
    const a = w.$gameActors.actor(169);
    for (const id of [10171, 10172, 10173, 10174]) a.learnSkill(id);
    return enter(a);
  },
  179: () => {  // 流萤：60 级二阶，招募（专武＋法宝），再入队 1（1 号生命加 1e12）
    open(); w.eval('$gameParty._actors=[];');
    const a = w.$gameActors.actor(179); a._AdvancedNum = 2; a.changeLevel(60, false);
    if (!w.CodexLiuying.recruit()) throw new Error('招募失败');
    w.$gameParty.addActor(1);
    w.$gameActors.actor(1)._paramPlus[0] = BIG_HP;
    return enter(a, {after: () => { for (const m of w.$gameParty.battleMembers()) m.onBattleStart(); w.BattleManager.startTurn(); }});
  },
  172: () => {  // 宿傩：55 级二阶（领域）；[172, 1]，两人生命加 1e12
    open(); w.eval('$gameParty._actors=[172,1]; $gameParty._battleMembers=[172,1,0,0,0];');
    const a = w.$gameActors.actor(172), SK = w.CodexSukuna, B = w.CodexBlackFlash;
    a._AdvancedNum = 2;
    for (const id of [172, 1]) { const b = w.$gameActors.actor(id); b.changeLevel(55, false); b._paramPlus[0] = BIG_HP; b.recoverAll(); }
    SK.sync(a);
    const env = enter(a, {before: () => {
      SK.round = 0; delete a._codexSukuna; B.round = 0; B.serial = 0; B.nested = 0; B.clear(a);
      for (const t of w.$gameTroop.members()) delete t._codexSukunaTarget;
    }});
    a.setTp(100);
    return env;
  },
  167: () => {  // 渡鸦：60 级五阶，招募，再入队 1；全队生命加 1e12
    open(); w.eval('$gameParty._actors=[];');
    const a = w.$gameActors.actor(167);
    a._AdvancedNum = 5; a._codexRavenStage = 5;
    a.changeLevel(60, false);
    if (!w.CodexRaven.recruit()) throw new Error('招募失败');
    w.$gameParty.addActor(1);
    for (const b of w.$gameParty.allMembers()) b._paramPlus[0] = BIG_HP;
    return enter(a, {after: () => w.BattleManager.startTurn()});
  },
  168: () => {  // 米拉：70 级三阶，照 CodexSkillProgression.sync 学技能；[168, 1]（不加生命）
    open(); w.eval('$gameParty._actors=[]; $gameParty._battleMembers=[0,0,0,0,0];');
    w.$gameParty.addActor(168); w.$gameParty.addActor(1);
    const a = w.$gameActors.actor(168);
    a._AdvancedNum = 3;
    for (const id of [168, 1]) { const b = w.$gameActors.actor(id); b.changeLevel(70, false); b.recoverAll(); }
    w.CodexSkillProgression.sync(a);
    const env = enter(a);
    a._tp = a.maxTp();
    return env;
  },
};
function act(bm, user, skillId, targetIndex) {
  const action = new w.Game_Action(user); action.setSkill(skillId); action.setTarget(targetIndex);
  user._actions = [action]; bm._subject = user; bm._action = null;
  bm.startAction();
  for (let i = 0; i < 20000; i++) {
    const ph = bm._phase;
    if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
    else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
  }
  bm._phase = 'turn';
}
const fresh = (a, id) => { const x = new w.Game_Action(a); x.setSkill(id); return x; };
function snap(env) {
  const {a, foes} = env;
  a.need_refresh = true; a.refresh();
  const ids = [...new Set([a.attackSkillId()].concat(a.skills().filter(s => s.scope > 0).map(s => s.id)))].sort((x, y) => x - y);
  const profile = {}, damage = {}, rates = {}, future = {};
  for (const id of ids) {
    const p = AI.profile(a, S[id], fresh(a, id)), row = {};
    for (const [k, v] of Object.entries(p)) {
      if (typeof v === 'number' || typeof v === 'boolean') row[k] = v;
      else if (k === 'futureActor') {
        // 铺垫后的角色视图（Object.create 出的只读视图）：能力值、能用的技能、各伤害技能对各敌人的 safeDamage
        row.future = true;
        const f = v, dmg = {};
        for (const s of f.skills()) if (s.scope > 0 && s.damage && [1, 2, 5, 6].includes(s.damage.type)) dmg[s.id] = foes.map(t => AI.safeDamage(f, t, s, fresh(f, s.id)));
        future[id] = {params: [0, 1, 2, 3, 4, 5, 6, 7].map(i => f.param(i)), usable: f.skills().filter(s => s.scope > 0 && f.canUse(s)).map(s => s.id).sort((x, y) => x - y), damage: dmg};
      }
    }
    profile[id] = row;
    if (S[id].damage && [1, 2, 5, 6].includes(S[id].damage.type)) {
      w.Math.random = () => 0.5;
      damage[id] = foes.map(t => AI.safeDamage(a, t, S[id], fresh(a, id)));
      const x = fresh(a, id);
      rates[id] = foes.map(t => [x.itemHit(t), x.itemEva(t), S[id].damage.critical ? x.itemCri(t) : 0]);
    }
  }
  const usable = ids.filter(id => a.canUse(S[id]));
  a._codexLastAIDecision = null;
  const best = AI.choose(a), d = a._codexLastAIDecision;
  return {ids, usable, profile, future, damage, rates, selfIndex: a.index(),
    choice: best ? {id: best.item().id, target: best._targetIndex} : null, score: d ? d.score : 0, candidates: d ? d.candidates : [],
    self: {hp: a.hp, mhp: a.mhp, mp: a.mp, mmp: a.mmp, tp: a.tp, atk: a.atk, mat: a.mat, def: a.def, mdf: a.mdf, agi: a.agi, luk: a.luk, harm: a._passiveCache ? Number(a._passiveCache.globalHarmRi) || 0 : 0, mastery: ids.map(id => a.skillMasteryLevel ? a.skillMasteryLevel(id) : 0), states: a._states.slice().sort((x, y) => x - y)},
    foes: foes.map(t => ({hp: t.hp, mhp: t.mhp, pdr: t.pdr, mdr: t.mdr, def: t.def, mdf: t.mdf, power: t.atk + t.mat + t.agi * 0.3, alive: t.isAlive()}))};
}
function run(id, steps) {
  const env = BATTLES[id](), {bm, a, foes} = env, out = [];
  for (const st of steps) {
    const [kind, x, y] = st;
    if (kind === 'act') act(bm, a, x, y);
    else if (kind === 'end') { bm._enteredEndPhase = false; bm._phase = 'turn'; bm.endTurn(); bm._phase = 'turn'; }
    else if (kind === 'foehp') foes.forEach((t, i) => t.setHp(x[i]));  // 各敌人生命（0＝倒下）
    else if (kind === 'allyrate') { const b = w.$gameActors.actor(1); b.setHp(Math.max(1, Math.floor(b.mhp * x))); }  // 1 号生命比例（急需）
    else if (kind === 'tp') a.setTp(x);
    else if (kind === 'mp') a.setMp(x);
    else if (kind === 'forget') a.forgetSkill(x);
    else if (kind === 'weapon') { a._equips[0].setObject(w.$dataWeapons[x]); a.refresh(); }  // 黄泉的技能要刀（武器类型 11）
    else if (kind === 'dream') a._codexYomiDream = x;  // 黄泉残梦
    out.push({step: st, snap: kind === 'ai' ? snap(env) : null});
  }
  return out;
}
// act／end 之后把敌人生命定回原值再记（真实伤害的绝对值两边另有与本探针无关的差，不让它混进分数）。
// 步骤：ai＝记一次；act 技能 目标序号；end＝回合结束；foehp 各敌人生命（0＝倒下）；allyrate 1 号生命比例（<0.25 即急需）；tp／mp；
// weapon＝黄泉换武器（技能要刀）；dream＝黄泉残梦。写在探针里而不另放 json：mv_oracle 下非探针的 json 会进全部探针的缓存键
const BIG = [75000000015000, 75000000015000, 75000000015000];
const SCRIPTS = {
  // 黄泉：没刀只能普攻；持刀后三招的溅射；残梦 9 开 10174；敌人残血（溅射能补刀）、一大两小、急需、只剩一只
  yomi: {actor: 169, steps: [['ai'], ['weapon', 11], ['ai'], ['dream', 9], ['ai'], ['foehp', [2e8, 2e8, 2e8]], ['ai'],
    ['foehp', [3e9, 1e8, 1e8]], ['ai'], ['allyrate', 0.1], ['ai'], ['foehp', [1000, 0, 0]], ['ai']]},
  // 流萤：天火溅射对完全燃烧（全体）；敌人生命与伤害同级、残血、只剩一只、急需
  liuying: {actor: 179, steps: [['ai'], ['foehp', [5e9, 5e9, 5e9]], ['ai'], ['foehp', [1000, 1000, 1000]], ['ai'],
    ['foehp', [1000, 0, 0]], ['ai'], ['allyrate', 0.1], ['ai']]},
  // 宿傩（二阶）：伏魔御厨子的铺垫档案（长战、急需、短战）；展开后不再给；有准备层后神灶：开长战压 0、急需与短战不压；领域到期、冷却中
  sukuna: {actor: 172, steps: [['ai'], ['allyrate', 0.1], ['ai'], ['allyrate', 1], ['foehp', [1e9, 1e9, 1e9]], ['ai'],
    ['foehp', BIG], ['act', 10231, 0], ['foehp', BIG], ['ai'], ['end'], ['foehp', BIG], ['ai'], ['allyrate', 0.1], ['ai'],
    ['allyrate', 1], ['foehp', [1e9, 1e9, 1e9]], ['ai'], ['foehp', BIG],
    ['end'], ['end'], ['foehp', BIG], ['ai'], ['end'], ['foehp', BIG], ['ai'], ['end'], ['foehp', BIG], ['ai']]},
  // 宿傩 TP 不够开领域、TP 为 0
  sukuna_tp: {actor: 172, steps: [['tp', 30], ['ai'], ['tp', 0], ['ai']]},
  // 渡鸦（五阶 60 级）：神话封解的铺垫档案（长战、急需、短战、MP 不够）；神话形态中不再给；形态结束后又给
  raven: {actor: 167, steps: [['ai'], ['allyrate', 0.1], ['ai'], ['allyrate', 1], ['foehp', [1e9, 1e9, 1e9]], ['ai'],
    ['foehp', BIG], ['mp', 300], ['ai'], ['mp', 1193], ['act', 10127, 0], ['ai'], ['end'], ['ai'],
    ['end'], ['end'], ['ai']]},
  // 米拉（三阶 70 级）：解放的铺垫档案（长战、急需、短战、TP 为 0）；解放后的黑龙技
  mira: {actor: 168, steps: [['ai'], ['allyrate', 0.1], ['ai'], ['allyrate', 1], ['foehp', [1e11, 1e11, 1e11]], ['ai'],
    ['foehp', BIG], ['tp', 0], ['ai'], ['tp', 200], ['act', 10146, 0], ['foehp', BIG], ['ai'], ['end'], ['foehp', BIG], ['ai']]},
};
const cases = [];
for (const [name, c] of Object.entries(SCRIPTS)) {
  cases.push(makeCase('script.' + name, {actor: c.actor, troop: TROOP, steps: c.steps}, () => ({steps: run(c.actor, c.steps)})));
}
process.exit(finish(host, 'smart_ai_profile.json', {hostScope: '真实 BattleManager／Game_Action（Math.random 0.5）；CodexSmartAI.profile／safeDamage／choose（只读）', cases}) ? 0 : 1);
