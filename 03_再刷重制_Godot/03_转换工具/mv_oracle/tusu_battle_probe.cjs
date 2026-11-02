'use strict';
// 【cc·白龙_14·未经审查】176 屠苏第三期（js/codex/runtime/installNativeTusuRuntime.js）：武具数据（武相、预约、持武状态、上次武相）、
// 绑定登记（种类 tusu，manual：不转充能）、化武／易武／归形（Game_Action.apply 包装）、技能条件（meetsSkillConditions 包装）、
// 「攻击」换归形（attackSkillId）、噬主（skillMpCost／canPaySkillCost／paySkillCost 包装、payer、canMaintain、回合开始维持不了就回人形）、
// 属性基准 base 与伤害公式 damage（系数随屠苏等级）、盾相双防补底（param 包装）、战斗结束清理。
// 招募屠苏（送止戈环）后队伍 [1, 8, 176, 10]，真实 BattleManager 打 3 号敌群（敌人生命加 1e9），Math.random 0.5；去掉 O-050 两个伤害钩子。
// 支援的施放与效果、统一伤害钩子、挫势、开刃、自动战斗是四期，这里不量。
// 每步后记：屠苏的本场数据、上次武相、绑定数据、武具／预约状态，宿主的持武状态，两人生命魔法双防，攻击技能号，
// 一组技能的 meets／canPay／面板 MP，各键的 payer、canMaintain。产物 .sandbox/tusu_battle.json，拷成 tests/fixtures/tusu_battle_oracle.json（不进同步），专项 xiyou_tusu_battle。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const B = w.CodexBinding, T = w.CodexTusu;
if (!T || !T.payer) throw new Error('屠苏模块未安装');
if (!B || typeof B.register !== 'function') throw new Error('绑定框架未安装');
// 同 guyu_battle_probe：用户 10-12 定不移植五乘区与超强者路线压制（O-050），去掉这两个伤害钩子，命中的伤害才对得上重制
const hooks = w.CodexDamageHooks || [];
for (const name of ['route-suppress', 'zones-correction']) {
  const i = hooks.findIndex(h => h.name === name);
  if (i < 0) throw new Error('伤害钩子 ' + name + ' 不在');
  hooks.splice(i, 1);
}
if (!w.CodexRouteSuppress || typeof w.CodexRouteSuppress.otherScale !== 'function') throw new Error('路线压制模块不在');
w.CodexRouteSuppress.otherScale = () => 1;
// 同一条 O-050：路线压制还把锁定、和鸣、护阵倍率按超强者往 1 收（屠苏是超强者，地狱路线 toward(r, 0.5)：和鸣 1.5→1.25、护阵 0.7→0.85），
// 包装里每次读 R.isSuper，改成恒假（tusu5 查明 tusu4 记的「和鸣只 ×1.25」就是它）
w.CodexRouteSuppress.isSuper = () => false;
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
// 战斗日志：只记 addText 的台词（tusu5）
const lines = [];
const logWin = new Proxy(function () {}, {get: (_, k) => k === '_waitCount' ? 0 : k === 'push' ? ((m, t) => { if (m === 'addText') lines.push(t); }) : (() => false), set: () => true});
const key = b => !b ? null : b.isActor() ? 'a' + b.actorId() : 'e' + b.index();
const TUSU = 176, PARTY = [1, 8, TUSU, 10], BIG_HP = 1e9, TROOP = 3;
// 三法宝原件（4047／4048／7912）：R.syncItem 会改写 $dataArmors 原件（名字、进化标记、特效倍率），同一进程里前一例会带进后一例
// （devour 60 级进化后 low 5 级也按进化算）。每例开局还原原件，再像读档（extractSaveContents）一样先同步一次原件：
// 之后登记的实例照原件复制，不会多出旧版倍率去重剩下的那条魔攻×1.2（O-待定-2 法宝倍率，events3c）。
const RELICS = [4047, 4048, 7912], pristine = RELICS.map(id => JSON.parse(JSON.stringify(w.$dataArmors[id])));
function battle(levels) {
  newGame();
  RELICS.forEach((id, i) => { w.$dataArmors[id] = JSON.parse(JSON.stringify(pristine[i])); });
  w.CodexThreeGrowth.sync();
  w.eval('$gameSystem.setDifficultyId(2); $gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.$gameSwitches.setValue(2494, true);  // 超强者可出战（同 tusu_growth 专项的开关）
  T.recruit();
  w.eval('$gameParty._actors=[' + PARTY + ']; $gameParty._battleMembers=[' + PARTY + ',0];');
  for (const [id, lv] of Object.entries(levels || {})) w.$gameActors.actor(+id).changeLevel(lv, false);
  for (const id of PARTY) w.$gameActors.actor(id).recoverAll();
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  w.Math.random = () => 0.99;
  const bm = w.BattleManager; bm.setup(TROOP, false, false);
  w.Math.random = () => 0.5;
  bm._logWindow = logWin; bm._spriteset = stub; bm._statusWindow = stub;
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
const I = T.ids(), K = k => I.skill[k];
const W5 = T.WEAPONS;
const TUSU_KEYS = ['return', 'menu.forge', 'body.phys', 'body.mag', 'body.guard'].concat(W5.map(x => 'yiwu.' + x), W5.map(x => 'huawu.' + x),
  ['support.jianqi', 'support.suoding', 'support.jintang', 'support.heming', 'support.zhenhun']);
const ARM_KEYS = ['arm.zhanfeng', 'arm.hengsao', 'arm.dianshe', 'arm.guanri', 'arm.huzhen', 'arm.chiling', 'arm.zhenji'];
const PAY_KEYS = ARM_KEYS.concat(['support.jianqi', 'support.suoding', 'support.jintang', 'support.heming', 'support.zhenhun']);
function skillRow(a, key) {
  const s = w.$dataSkills[K(key)];
  return [a.meetsSkillConditions(s), a.canPaySkillCost(s), a.skillMpCost(s)];
}
function snap() {
  const t = who(TUSU), d = t._codexTusu, bd = B.data(t), h = B.host(t);
  const states = a => a._states.filter(id => w.$dataStates[id] && /<Codex(?:Tusu|Bind):/.test(w.$dataStates[id].note)).sort((x, y) => x - y);
  const out = {round: B.round(), tusu: {data: d ? {weapon: d.weapon || null, reserve: d.reserve || null, pending: d.pendingWeapon || null, hostActions: d.hostActions || 0,
      trigger: d.trigger || 0, growth: d.growthSupportRound || 0} : null,
    last: t._codexTusuLast || null, bind: bd ? {charges: bd.charges, hostId: bd.hostId || 0, returnedRound: bd.returnedRound || 0} : null,
    states: states(t), hp: t.hp, mp: t.mp, mmp: t.mmp, atk: t.atk, mat: t.mat, def: t.def, mdf: t.mdf, attack: t.attackSkillId(), canMove: t.canMove(),
    skills: Object.fromEntries(TUSU_KEYS.map(k => [k, skillRow(t, k)])), guard: t.meetsSkillConditions(w.$dataSkills[2]), atk1: t.meetsSkillConditions(w.$dataSkills[1])},
    party: {}};
  for (const id of [1, 8, 10]) {
    const a = who(id);
    out.party['a' + id] = {states: states(a), hp: a.hp, mp: a.mp, mmp: a.mmp, def: a.def, mdf: a.mdf, shield: w.CodexShieldLedger.amount(a),
      arm: Object.fromEntries(ARM_KEYS.map(k => [k, skillRow(a, k)]))};
  }
  out.payer = Object.fromEntries(PAY_KEYS.map(k => [k, T.payer(k)]));
  out.maintain = Object.fromEntries(W5.map(x => [x, T.canMaintain(x)]));
  out.host = h ? 'a' + h.actorId() : null;
  out.locks = Object.fromEntries([1, 8, 10].filter(id => who(id)._codexTusuLock).map(id => ['a' + id, key(who(id)._codexTusuLock.target)]));
  out.cooldown = Object.fromEntries(['support.jianqi', 'support.suoding', 'support.jintang', 'support.heming', 'support.zhenhun'].map(k => [k, t.cooldown(K(k))]));
  const e0 = who('e0'), c = e0._codexTusuCuoshi;  // 挫势（敌人）与眩晕
  out.e0 = {cuoshi: c ? {rate: c.rate, stack: c.stack, until: c.until} : null, states: e0._states.filter(id => id === T.config.stunState || /<CodexTusu:/.test((w.$dataStates[id] || {}).note || '')).sort((x, y) => x - y)};
  out.members = w.$gameParty.battleMembers().map(key);
  return out;
}
const hits = [];
const oldExec = w.Game_Action.prototype.executeHpDamage;
w.Game_Action.prototype.executeHpDamage = function (t, v) { hits.push(['hp', key(this.subject()), key(t), v]); return oldExec.apply(this, arguments); };
// 步骤：use 人 键 目标角色（屠苏的指令：走真实 startAction～endAction；目标角色给角色号）｜act 人 技能号 敌序号｜turn｜mp 人 值｜pay 人 键（直接 paySkillCost）｜
// state 人 状态键｜hit 敌 技能号 角色｜arm 人 键 敌序号（武装技能走真实行动，记熟练度使用次数）｜kill 人｜revive 人｜cost 人 技能号（skillMpCost）｜formula 人 键（T.damage(人, 敌0, 键)、T.base 剑／书、系数）｜end
function step(bm, st) {
  const [op, x, y, z] = st;
  let ret = null;
  if (op === 'use') {
    const a = who(x), s = K(y);
    const tgt = z ? w.$gameParty.members().indexOf(who(z)) : -1;
    begin(bm, a, s, tgt); run(bm);
  } else if (op === 'act') { begin(bm, who(x), y, z); run(bm); }
  else if (op === 'arm') { const a = who(x); begin(bm, a, K(y), z); run(bm); ret = {uses: a.skillMasteryUses(K(y))}; }  // 持武者走真实行动用武装技能：熟练度计次（审查第 24 期 P2-1）
  else if (op === 'turn') { bm._enteredEndPhase = false; bm._phase = 'turn'; bm.endTurn(); bm.startTurn(); bm._phase = 'turn'; }
  else if (op === 'mp') who(x).setMp(y);
  else if (op === 'state') who(x).addState(I.state[y]);  // 直接挂屠苏的状态（和鸣、护阵；支援施放是四期剩余）
  else if (op === 'hit') { begin(bm, who(x), y, w.$gameParty.members().indexOf(who(z))); run(bm); }  // 敌人用技能打角色 z
  else if (op === 'pay') { const a = who(x); a._actionMastery = []; a.paySkillCost(w.$dataSkills[K(y)]); ret = {tusu: who(TUSU).mp, self: a.mp, mastery: a._actionMastery.slice()}; }
  else if (op === 'sup') { begin(bm, who(x), K(y), z); run(bm); }  // 屠苏自己用支援（指令窗「武相支援」）：z 敌序号（锁定选敌人），−1 不指定
  else if (op === 'gain') B.gain(who(x), y);  // 给屠苏兵势（原版屠苏 manual，兵势恒 0，内部施放的支援实际放不出来；这里补兵势量内部施放）
  else if (op === 'sethp') who(x).setHp(y);
  else if (op === 'zq') {  // 真气道法（同 zhenqi_probe withDaofa）：x 角色、y 境界、z 道法键
    const a = who(x), Z = w.CodexZhenqi;
    a._codexZhenqi = {qi: Z.REALMS[y].need, firsts: {}, realm: y, pending: [], daofa: Object.fromEntries(z.map(k => [k, 1])), spec: {}};
    for (const k of z) a.learnSkill(Z.skillKey('daofa:' + k));
    Z.refreshRewards(a);
  } else if (op === 'atkst') {  // 武装技能 y 临时加「普攻附加状态」效果（武装技能本身没有效果；用来量破甲·真气附加时读谁的道法），x＝1 加、0 去
    const s = w.$dataSkills[K(x)];
    s.effects = y ? [{code: 21, dataId: 0, value1: 1, value2: 0}] : [];
  } else if (op === 'pq') {  // 敌人 0 号的破甲·真气：有没有、附加时记的双防倍率；unpq 去掉
    const e = who('e0'); ret = {affected: e.isStateAffected(2705), rate: e._codexZqPojiaRate === undefined ? null : e._codexZqPojiaRate};
  } else if (op === 'unpq') { const e = who('e0'); e.removeState(2705); e.clearResult(); }
  else if (op === 'smart') w.ConfigManager.codexSmartAI = !!x;  // 智能战斗 AI 开关（关了持武者按挂机表、否则普通攻击，再由屠苏包装比武装技能）
  else if (op === 'auto') {  // 自动战斗选的行动（makeAutoBattleActions，原选择＋屠苏包装）：技能（屠苏的记键）与目标序号
    const a = who(x); a._actions = [new w.Game_Action(a)]; a.makeAutoBattleActions();
    const act = a._actions[0], it = act && act.item();
    ret = {skill: it ? (T.ids().key[it.id] || it.id) : null, target: act ? act._targetIndex : null};
  }
  else if (op === 'kairen') { const a = who(x); a._AdvancedNum = 3; a._codexTusuKairen = y.slice(); T.syncKairenSkills(a); }  // 进阶 3 次、器谱开刃这几相
  else if (op === 'heal') { begin(bm, who(x), y, w.$gameParty.members().indexOf(who(z))); run(bm); }  // 角色 x 对队友 z 用技能 y
  else if (op === 'kill') { const a = who(x); a.setHp(0); a.refresh(); }
  else if (op === 'revive') { const a = who(x); a.removeState(a.deathStateId()); a.setHp(a.mhp); }
  else if (op === 'formula') {
    const a = who(x), e = who('e0');
    ret = {damage: T.damage(a, e, y), sword: T.base(a, 'sword'), book: T.base(a, 'book'), coef: T.coefficient(y)};
  } else if (op === 'cost') ret = {mp: who(x).skillMpCost(w.$dataSkills[y])};  // 持武者原生技能的 MP（书相魔法技能 ×0.7）
  else if (op === 'end') bm.endBattle(0);
  else throw new Error('未知步骤 ' + op);
  return ret;
}
function play(levels, steps) {
  const bm = battle(levels), out = [{step: ['start'], snap: snap()}];
  for (const st of steps) {
    hits.length = 0; lines.length = 0;
    const ret = step(bm, st);
    out.push({step: st, ret, hits: hits.slice(), lines: lines.slice(), snap: snap()});
  }
  return out;
}
const SCRIPTS = {
  // 人形：化武剑给 1 号（宿主持剑、屠苏武具态、攻击换归形）；易武弓预约；下一回合换弓；归形（manual 没有充能：条件不过）；
  // 宿主能用的武装技能按武相；公式与基准
  basic: [{176: 30}, [['formula', 176, 'body_phys'], ['use', 176, 'huawu.sword', 1], ['cost', 1, 49], ['formula', 1, 'zhanfeng'], ['formula', 1, 'chiling'],
    ['use', 176, 'yiwu.bow'], ['use', 176, 'yiwu.bow'], ['turn'], ['use', 176, 'yiwu.book'], ['turn'], ['use', 176, 'return'], ['turn'], ['end']]],
  // 化武盾：宿主双防补底到屠苏；换宿主不能（武具态不能化武）；宿主阵亡解除（回人形，上次武相记着）；再化武用上次武相
  shield: [{176: 40, 8: 1}, [['use', 176, 'huawu.shield', 8], ['act', 8, 1, 0], ['kill', 8], ['act', 1, 1, 0], ['revive', 8], ['use', 176, 'huawu.sword', 10],
    ['turn'], ['end']]],
  // 噬主：屠苏自付 → 屠苏魔法 0 后持武者付三倍 → 两人都 0 回合开始维持不了回人形
  devour: [{176: 60}, [['use', 176, 'huawu.sword', 1], ['pay', 1, 'arm.zhanfeng'], ['mp', 176, 0], ['pay', 1, 'arm.zhanfeng'], ['mp', 1, 0], ['turn'],
    ['use', 176, 'huawu.book', 1], ['cost', 1, 49], ['cost', 1, 1], ['mp', 176, 99999], ['pay', 176, 'support.heming'], ['mp', 176, 0], ['mp', 1, 99999], ['pay', 176, 'support.heming'], ['end']]],
  // 熟练度：持武者走真实行动用武装技能，YEP paySkillCost 包装在噬主包装里层，照常记次；屠苏自付、持武者代付各一次（审查第 24 期 P2-1）
  mastery: [{176: 60}, [['use', 176, 'huawu.sword', 1], ['arm', 1, 'arm.zhanfeng', 0], ['mp', 176, 0], ['arm', 1, 'arm.zhanfeng', 0], ['end']]],
  // 武装技能伤害（伤害钩子 tusu）：书相敕令魔法、和鸣 ×hemingRate 后消费；锤相震击；护阵中的角色受伤 ×huzhenRate
  armdmg: [{176: 60}, [['use', 176, 'huawu.book', 1], ['arm', 1, 'arm.chiling', 0], ['state', 1, 'heming'], ['arm', 1, 'arm.chiling', 0],
    ['use', 176, 'yiwu.hammer'], ['turn'], ['arm', 1, 'arm.zhenji', 0], ['hit', 'e0', 1, 8], ['state', 8, 'huzhen'], ['hit', 'e0', 1, 8], ['end']]],
  // 止戈环 60 级（tusu5）：横扫第二个目标起 ×curve；点射 2 段、贯日 3 段；护阵挂护阵、首次敌方伤害给护阵队友护盾（屠苏双防和 ×18）；
  // 震击打有挫势的敌人 → 它下一次直接伤害 ×0.9（连同挫势 ×0.8）；挫势回合末到期
  arm60: [{176: 60}, [['use', 176, 'huawu.sword', 1], ['arm', 1, 'arm.hengsao', 0], ['use', 176, 'yiwu.bow'], ['turn'], ['arm', 1, 'arm.dianshe', 0], ['arm', 1, 'arm.guanri', 1],
    ['use', 176, 'yiwu.shield'], ['turn'], ['arm', 1, 'arm.huzhen', 0], ['hit', 'e0', 1, 8], ['hit', 'e1', 1, 8], ['use', 176, 'yiwu.hammer'], ['turn'],
    ['arm', 1, 'arm.zhenji', 0], ['arm', 1, 'arm.zhenji', 0], ['hit', 'e0', 1, 10], ['hit', 'e0', 1, 10], ['turn'], ['end']]],
  // 屠苏自己用支援（tusu5）：剑气（按自身基式、40 级起成长加成 ×curve，本回合成功一次后不再加）、锁定敌人给持武者、贯日 ×lockRate 并消费、
  // 金汤（护盾进账本）、和鸣给持武者、敕令 ×hemingRate、镇魂重击挂挫势
  support: [{176: 60}, [['use', 176, 'huawu.sword', 1], ['arm', 1, 'arm.zhanfeng', 0], ['sup', 176, 'support.jianqi', -1], ['sup', 176, 'support.jianqi', -1],
    ['use', 176, 'yiwu.bow'], ['turn'], ['sup', 176, 'support.suoding', 1], ['arm', 1, 'arm.guanri', 1], ['use', 176, 'yiwu.shield'], ['turn'],
    ['sup', 176, 'support.jintang', -1], ['use', 176, 'yiwu.book'], ['turn'], ['sup', 176, 'support.heming', -1], ['arm', 1, 'arm.chiling', 0],
    ['use', 176, 'yiwu.hammer'], ['turn'], ['sup', 176, 'support.zhenhun', 0], ['turn'], ['end']]],
  // 内部施放（B.cast，补兵势才放得出）：敕令前自动和鸣、斩锋后剑气纵横（按持武者这次的伤害定上下限）、回合末余下兵势释放、震击后镇魂打最危险的敌人、
  // 盾相敌人出手前有人半血以下放金汤、贯日前自动锁定；横扫打三个敌人后的剑气被下限（持武者伤害 ×0.5）抬高（上限 ×2.7 这里够不着）
  cast: [{176: 60}, [['use', 176, 'huawu.book', 1], ['gain', 176, 3], ['arm', 1, 'arm.chiling', 0], ['use', 176, 'yiwu.sword'], ['turn'], ['gain', 176, 3],
    ['arm', 1, 'arm.zhanfeng', 0], ['turn'], ['gain', 176, 2], ['arm', 1, 'arm.hengsao', 0], ['use', 176, 'yiwu.hammer'], ['turn'], ['gain', 176, 2], ['arm', 1, 'arm.zhenji', 0],
    ['use', 176, 'yiwu.shield'], ['turn'], ['gain', 176, 1], ['sethp', 8, 100], ['hit', 'e0', 1, 8], ['use', 176, 'yiwu.bow'], ['turn'], ['gain', 176, 1],
    ['arm', 1, 'arm.guanri', 1], ['end']]],
  // 开刃（tusu5）：弓——贯日击杀锁定目标后锁定下一个最危险的敌人；锤——挫势叠 2 层（×0.8²）；书——持武者对队友的魔法治疗先自动和鸣、
  // 治疗 ×hemingRate 后消费（4442 悦耳）
  kairen: [{176: 60}, [['kairen', 176, ['bow', 'hammer', 'book']], ['use', 176, 'huawu.bow', 1], ['gain', 176, 1], ['sethp', 'e1', 1],
    ['arm', 1, 'arm.guanri', 1], ['use', 176, 'yiwu.hammer'], ['turn'], ['arm', 1, 'arm.zhenji', 0], ['arm', 1, 'arm.zhenji', 0], ['hit', 'e0', 1, 10],
    ['use', 176, 'yiwu.book'], ['turn'], ['gain', 176, 1], ['sethp', 8, 100], ['heal', 1, 4442, 8], ['heal', 1, 4442, 8], ['end']]],
  // 自动战斗（tusu5）：人形化武给默认宿主（上次武相）；武具态敌人 3 个持剑放剑气；两人低于 40% 易武盾；持武者比武装技能（预览 ×1.1）
  ai: [{176: 60}, [['auto', 176], ['use', 176, 'huawu.sword', 1], ['auto', 176], ['auto', 1], ['sethp', 8, 100], ['sethp', 10, 100], ['auto', 176],
    ['use', 176, 'yiwu.hammer'], ['turn'], ['auto', 1], ['smart', 0], ['auto', 1], ['auto', 8], ['smart', 1], ['end']]],
  // 审查第 25 期 P3-2：真气 apply 包装装在屠苏外面，破甲·真气附加时读的是持武者（不是换上来的屠苏）。屠苏有破甲（炼气，倍率 0.875）、持武者没有 → 0.5；
  // 持武者也有破甲（结丹，0.75）→ 0.75。斩锋临时加普攻附加状态（屠苏的 passiveATKST2705 才附加得上）
  pojia: [{176: 60}, [['zq', 176, 0, ['pojia']], ['atkst', 'arm.zhanfeng', 1], ['use', 176, 'huawu.sword', 1], ['arm', 1, 'arm.zhanfeng', 0], ['pq'],
    ['unpq'], ['zq', 1, 3, ['pojia']], ['arm', 1, 'arm.zhanfeng', 0], ['pq'], ['atkst', 'arm.zhanfeng', 0], ['end']]],
  // 等级低：没解锁的武装技能、支援不能用
  low: [{176: 5}, [['use', 176, 'huawu.bow', 1], ['turn'], ['use', 176, 'yiwu.sword'], ['turn'], ['end']]],
};
const cases = Object.entries(SCRIPTS).map(([id, [lv, steps]]) => makeCase(id, {levels: lv, steps}, () => play(lv, steps)));
process.exit(finish(host, 'tusu_battle.json', {hostScope: '真实 CodexTusu（三期部分）＋CodexBinding，真实 BattleManager', cases}) ? 0 : 1);
