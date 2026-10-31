'use strict';
// 异化词条效果参照（installAlienationAffixes／Advanced 的战斗侧）。期一：逆骨、归墟；期二①：疫囊、囚厄、绝缘、舍身（状态类）；期二②：空壳、连命、嫁祸（生命池类）。
// ① config：templates.inversebone（逆骨适用技能）与 templates.attack 的长度、头尾，Godot alienation.json 照抄，专项核对。
// ② battle.<词条>：角色 1（99 级，石中剑要 99 级才穿得上）穿本体 1044 的异化武器（none 为不带标记的本体），角色 8 同队，敌群 2（敌人生命加 1e12、攻击加 300）；
//    A.lockParty 冻结词条后，真实 BattleManager 跑行动（同 alien_battle_probe 的 act），每步记双方生命、敌人状态，
//    以及战斗帧外读到的角色 1 物攻／物防（逆骨只在公式与伤害帧里换读，帧外不变）。
//    - inversebone：普攻（1，逆骨技能）、连续攻击（3）、十字军打击（109，元素 8）、火球术（114，不在逆骨技能里）打敌人；敌人普攻打角色 1／8。
//    - void：同一组行动；归墟的攻击无元素结算、不附加状态与增减益（敌人状态应为空）。
// ③ 期二① battle.<词条>.*：同样的队伍与敌群，按步骤跑：行动可用合成技能（空白技能 13 填入 def 的 scope／hitType／效果，
//    两边按同一份定义合成）；set 设生命／法力比例；roundEnd 照 Affixes endTurn 包装调 A.spreadPest；expire 照自然移除
//    （A.naturalRemoval）去掉一个状态。疫囊穿本体 1013 尼伯龙根指环（饰品栏）；舍身的绑定队友直接写进标记的 config。
// ④ 第④批 battle.swallow／offer：装备类；另记双方装备栏、能力值、命中／回避／暴击与背包件数，步骤 end 照 endBattle（还原装备栏）。
// 新游戏（Math.random 0.5），只在内存；产物 .sandbox/alien_affix.json。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const A = w.CodexAlienation, C = A && A.config;
if (!A || !C || !A.advanced) throw new Error('异化词条模块未安装');
const r = v => round(v);
function party(ids) { w.$gameParty.members().map(x => x.actorId()).forEach(id => { if (ids.indexOf(id) < 0) w.$gameParty.removeActor(id); }); ids.forEach(id => w.$gameParty.addActor(id)); }
function uncap() { w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });'); }
const cases = [];
const T = C.templates;
const config = {inversebone: {size: T.inversebone.length, head: T.inversebone.slice(0, 5), tail: T.inversebone.slice(-5)},
  attack: {size: T.attack.length, head: T.attack.slice(0, 5), tail: T.attack.slice(-5)}};

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
w.eval('CodexZones.ENABLED=false;');
const BIG_HP = 1e12;
// 在原对象上改（YEP 技能熟练度等插件载入时给技能对象挂了字段，整个替换会让行动结束时报错并 SceneManager.terminate）
function synth(def) { Object.assign(w.$dataSkills[13], {scope: def.scope, hitType: def.hitType,
  effects: def.effects.map(e => ({code: e[0], dataId: e[1], value1: e[2], value2: 0}))}); return 13; }
// 投影用 A.clone（JSON 克隆）复制技能，丢了 YEP_SkillMasteryLevels 挂在技能对象上的 masteryMpCost／TpCost 函数：付费算 skillMpCost 时
// 报错，SkillMasteryLevelsError 先 alert 再 SceneManager.terminate（正式游戏里直接退出，O-109）。这里把两者换成计数，记进 view.terminated，
// 让行动照「报错被吞、费用取熟练度公式之前的值」走完（默认公式就是 cost，数值上没有差别）
let terminated = 0;
w.SceneManager.terminate = () => { terminated++; };
w.alert = () => {};
// 普通独立装备（YEP gainItem 新建的实例），放进背包
function independent(kind, id) { const bag = kind === 'w' ? '_weapons' : '_armors', data = kind === 'w' ? w.$dataWeapons : w.$dataArmors;
  const before = Object.keys(w.$gameParty[bag]).map(Number); w.$gameParty.gainItem(data[id], 1);
  return data[Object.keys(w.$gameParty[bag]).map(Number).filter(x => before.indexOf(x) < 0)[0]]; }
function battle(spec) {
  newGame(); uncap();
  const a = w.$gameActors.actor(1), b = w.$gameActors.actor(8);
  a.changeLevel(spec.level || 99, false); b.changeLevel(spec.allyLevel || 30, false);
  if (spec.learn) spec.learn.forEach(id => a.learnSkill(id));  // 祸祝等要先学会模板技能才穿得上（canEquip 看 A.ready）
  if (spec.teach) spec.teach.forEach(id => b.learnSkill(id));  // 无面借入的技能要来源队友（角色 8）已学会
  party(spec.extra ? [1, 8, spec.extra.actor] : [1, 8]);
  // 直接放进武器栏（穿戴限制属工坊侧）；none 为不带标记的同一本体
  const kind = spec.armor ? 'a' : 'w', base = spec.armor || spec.weapon || 1044;
  const item = spec.affix ? A.create(kind, base, 'boss', spec.affix) : w.$dataWeapons[1044];
  // 吞器供体：背包里的普通独立武器；config.donorId 写 'd序号'，换成供体的编号。lockDonor 给第一件供体名字加【锁定】
  const donors = (spec.donors || []).map(id => independent('w', id));
  if (spec.lockDonor) donors[0].name += '【锁定】';
  // 队友（角色 8）自己也穿一件本体 1044 的异化武器（allyAffix；夺舍的队友照样锁队冻结）
  if (spec.allyAffix) { const own = A.create('w', 1044, 'boss', spec.allyAffix); b._equips[0].setObject(own); }
  if (spec.config) { A.mark(item).config = JSON.parse(JSON.stringify(spec.config));
    const c = A.mark(item).config; if (typeof c.donorId === 'string') c.donorId = donors[Number(c.donorId.slice(1))].id; }
  // 衣服栏（装备类型 4）穿一件普通独立防具（从背包拿出来）
  if (spec.body) { const body = independent('a', spec.body); w.$gameParty.loseItem(body, 1); a._equips[a.equipSlots().indexOf(4)].setObject(body); }
  if (spec.armor) { a._equips[0].setObject(w.$dataWeapons[spec.weapon || 1044]); a._equips[a.equipSlots().indexOf(item.etypeId)].setObject(item); }
  else a._equips[0].setObject(item);
  // 第三名队员（extra：角色、词条、配置）也穿一件本体 1044 的异化武器（锁队检查「重复绑定」用）
  let extra = null;
  if (spec.extra) { extra = A.create('w', 1044, 'boss', spec.extra.affix); A.mark(extra).config = JSON.parse(JSON.stringify(spec.extra.config));
    w.$gameActors.actor(spec.extra.actor)._equips[0].setObject(extra); }
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  const bm = w.BattleManager; bm.setup(spec.troop || 2, false, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  const enemies = w.$gameTroop.members();
  enemies.forEach(e => { e._paramPlus[0] = BIG_HP; e._paramPlus[2] = 300; });
  for (const x of [...w.$gameParty.members(), ...enemies]) { x.need_refresh = true; x.refresh(); x.recoverAll(); }
  // 开战前身上的状态与增益（饕餮锁队时吞掉）：回合直接写定，不经随机
  if (spec.pre) { (spec.pre.states || []).forEach(([id, turns]) => { a.addState(id); a._stateTurns[id] = turns; });
    (spec.pre.buffs || []).forEach(([pid, n, turns]) => { a._buffs[pid] = n; a._buffTurns[pid] = turns; }); a.refresh(); }
  // 开战前已倒下的队员（dead：'b'），锁队检查「已倒下」用
  (spec.dead || []).forEach(k => { const x = k === 'b' ? b : a; x.addState(x.deathStateId()); });
  // 镜骸（mirror）：敌人 0 直接写成镜骸变体（不经 setupEncounter 的抽签与奖励），每回合第一次被角色主动打中，行动结束反噬
  // 敌人额外特性（enemyTraits：[[代码, 编号, 值], …]）：包一层 traitObjects，只对这一局的敌人
  if (spec.enemyTraits) enemies.forEach(e => { const more = {traits: spec.enemyTraits.map(([code, dataId, value]) => ({code, dataId, value}))};
    const old = e.traitObjects; e.traitObjects = function () { return old.call(this).concat([more]); }; });
  if (spec.mirror) enemies[0]._alienEnemy = {variant: 'mirror', boss: true, shieldGranted: false, mirrorRound: -1, mirrorCharged: true,
    plagueRound: -1, drainRound: -1, visualPulse: 0};
  A.lockParty();
  w.$gameParty._inBattle = true;
  w.CodexYunshang._acted = [];
  return {bm, a, b, enemies, item, donors, extra};
}
function act(bm, user, skillId, targetIndex, choice, repeats) {
  const action = new w.Game_Action(user);
  action.setSkill(skillId);
  action.setTarget(targetIndex);
  if (choice) action._alienChoice = choice;  // 百相切换窗口选的仿形（Scene_Battle onSkillOk 包装写进输入中的行动）
  const item = action.item(), view = {name: item.name, scope: item.scope, effects: item.effects.map(e => [e.code, e.dataId, e.value1]),
    usable: user.isActor() ? user.canUse(w.$dataSkills[skillId]) : true};
  if (repeats) view.repeats = action.numRepeats();  // 逆祷投影后不算普通攻击（isAttack 比的是 item() 对象），攻击次数追加不加
  terminated = 0;
  user._actions = [action]; bm._subject = user; bm._action = null;
  bm.startAction();
  for (let i = 0; i < 20000; i++) {
    const ph = bm._phase;
    if (ph === 'phaseChange') bm.updatePhase(); else if (ph === 'actionList') bm.updateActionList();
    else if (ph === 'actionTargetList') bm.updateActionTargetList(); else break;
  }
  if (bm._phase === 'action' || bm._phase === 'actionList' || bm._phase === 'actionTargetList') bm.endAction();
  view.terminated = terminated;
  return view;
}
const unit = x => ({hp: r(x.hp), mp: r(x.mp), shield: r(x._shield || 0), states: x._states.slice().sort((p, q) => p - q),
  buffs: x._buffs.slice(2, 8)});
// 帧外物攻／物防只在期一（逆骨）读：角色身上有状态时挨减益，原版参数缓存不刷新（无词条也一样），重制另有差异，不归异化
// 缄默、饕餮另记角色 1 的生命／法力上限、已锁比例与饥饿储备
// 百相、无相另记仿形记录、当前仿形，以及 WATCH 里哪些技能在技能表、哪些能用
const WATCH = [160, 311, 502, 1924, 1926, 1928, 1930, C.ids.switch];
// 蚀术另记角色 1 与各敌人身上的异化封印（_alienSeals 的技能号），以及 ERODE_WATCH 里各自能用哪些
const ERODE_WATCH = [1, 1924, 1926, 1928];
const seals = x => Object.keys(x._alienSeals || {}).map(Number).sort((p, q) => p - q);
const extra = x => { const d = x._alienBattle; if (!d) return {};
  if (['silence', 'glutton'].indexOf(d.affix) >= 0) return {mhp: r(x.mhp), mmp: r(x.mmp), capLock: r(d.capLock), hunger: r(d.hunger)};
  // 夺舍另记出战名单、敌人等级、角色 1 技能表里有没有借来的 9（火焰）与被动 16（剑道天赋）、能不能用 9
  if (d.affix === 'possession') return {members: w.$gameParty.battleMembers().map(m => m.actorId()), lv: w.$gameTroop.members().map(e => e.level),
    has: [9, 16].filter(id => x.skills().some(s => s.id === id)), usable: [9].filter(id => x.canUse(w.$dataSkills[id]))};
  if (['mimic', 'faceless'].indexOf(d.affix) >= 0) return {observed: d.observed.slice(), selected: d.selected,
    has: WATCH.filter(id => x.skills().some(s => s.id === id)), usable: WATCH.filter(id => x.canUse(w.$dataSkills[id]))};
  if (d.affix === 'erosion') return {seals: seals(x), usable: ERODE_WATCH.filter(id => x.canUse(w.$dataSkills[id])),
    eseals: w.$gameTroop.members().map(seals), eusable: w.$gameTroop.members().map(e => ERODE_WATCH.filter(id => e.canUse(w.$dataSkills[id])))};
  return {}; };
// 吞器、献器另记双方装备栏（本体编号，空栏 0）、八项能力值、命中／回避／暴击，以及背包里供体与异化装备各几件
// 独立装备的 baseItemId 可能还指向一件独立装备（YEP 再登记），一直追到数据库本体
const rootId = o => { const data = w.DataManager.isWeapon(o) ? w.$dataWeapons : w.$dataArmors;
  while (o.baseItemId && o.baseItemId !== o.id && data[o.baseItemId]) o = data[o.baseItemId]; return o.id; };
const gearOf = x => ({equips: x.equips().map(e => e ? rootId(e) : 0), params: [0, 1, 2, 3, 4, 5, 6, 7].map(i => r(x.param(i))),
  xp: [0, 1, 2].map(i => r(x.xparam(i)))});
const bagOf = ctx => ({item: w.$gameParty.numItems(ctx.item), donors: ctx.donors.map(d => w.$gameParty.numItems(d))});
const reading = (ctx, atk) => Object.assign({enemies: ctx.enemies.map(unit),
  a: Object.assign(unit(ctx.a), atk ? {atk: ctx.a.atk, def: ctx.a.def} : {}, extra(ctx.a), ctx.gear ? {gear: gearOf(ctx.a)} : {}),
  b: Object.assign(unit(ctx.b), ctx.gear ? {gear: gearOf(ctx.b)} : {})}, ctx.gear ? {bag: bagOf(ctx)} : {});
const STEPS = [{skill: 1}, {skill: 3}, {skill: 109}, {skill: 114}, {user: 'e0', skill: 1, target: 0}, {user: 'e1', skill: 1, target: 1},
  {user: 'b', skill: 1}];
function battleCase(name, spec, steps) {
  steps = steps || STEPS;
  cases.push(makeCase('battle.' + name, Object.assign({actor: 1, ally: 8, troop: 2, weapon: 1044}, spec, {steps}), () => {
    const ctx = battle(spec), rows = [];
    ctx.gear = !!spec.gear;
    const locked = [ctx.a, ctx.b].map(x => x._alienBattle ? {affix: x._alienBattle.affix} : null);
    // 锁队检查卸下的：异化武器在背包几件、还穿着没有；第三名队员的同样记下
    const eject = spec.dead || spec.extra ? {item: w.$gameParty.numItems(ctx.item), worn: ctx.a.equips().indexOf(ctx.item) >= 0,
      extra: ctx.extra ? w.$gameParty.numItems(ctx.extra) : null, extraLocked: spec.extra ? !!w.$gameActors.actor(spec.extra.actor)._alienBattle : null} : null;
    const atk = steps === STEPS, start = reading(ctx, atk);
    const who = k => k === 'b' ? ctx.b : k && k[0] === 'e' ? ctx.enemies[Number(k.slice(1))] : ctx.a;
    for (const st of steps) {
      w.$gameTroop._turnCount = st.round || 1;
      if (st.set) {
        for (const k of ['a', 'b']) {
          if (st.set[k + 'Hp'] != null) who(k)._hp = Math.floor(who(k).mhp * st.set[k + 'Hp']);
          if (st.set[k + 'Mp'] != null) who(k)._mp = Math.floor(who(k).mmp * st.set[k + 'Mp']);
          if (st.set[k + 'Shield'] != null) who(k)._shield = st.set[k + 'Shield'];
        }
      } else if (st.roundEnd) {
        w.$gameTroop._turnCount = st.roundEnd; A.spreadPest(A.round());
      } else if (st.regen) {
        ctx.bm._subject = null; who(st.regen).onTurnEnd();  // 回合末没有行动者（BattleManager.endTurn 时 _subject 已空）
      } else if (st.tick) {
        w.$gameTroop._turnCount = st.tick;
        w.$gameParty.battleMembers().concat(w.$gameTroop.members()).forEach(t => A.tickCorrosion(t, st.tick));  // endTurn 包装里的腐蚀结算
      } else if (st.event) {
        const x = who(st.event.who);
        if (st.event.mp) { ctx.bm._subject = st.event.src ? who(st.event.src) : null; x.gainMp(st.event.value); }  // 事件「增减 MP」（command312：actor.gainMp）；src 为 BattleManager._subject
        else w.Game_Interpreter.prototype.changeHp.call(new w.Game_Interpreter(), x, st.event.value, !!st.event.death);  // 事件「增减生命」
      } else if (st.sethp) {
        // 行动外的 setHp（插件、自定义效果直接设生命）：来源取 BattleManager._subject（src，没有就是自己）
        const x = who(st.sethp.who); ctx.bm._subject = st.sethp.src ? who(st.sethp.src) : null; x.setHp(Math.floor(x.mhp * st.sethp.value));
      } else if (st.revive) {
        who(st.revive).removeState(who(st.revive).deathStateId());
      } else if (st.end != null) {
        // 战斗结束（0 胜、1 逃、2 败）：endBattle 包装还原装备栏；之后退出战斗（Scene_Battle.terminate 的 onBattleEnd）
        ctx.bm._escaped = st.end === 1; ctx.bm.endBattle(st.end); w.$gameParty._inBattle = false;
      } else if (st.shield) {
        who(st.shield.who)._shield = st.shield.value;
      } else if (st.forget) {
        who(st.forget.who).forgetSkill(st.forget.id);
      } else if (st.apply) {
        // 直接对指定目标 Game_Action.apply（不经选目标）：result.used＝testApply（isForDeadFriend() === target.isDead()），蚀术命中才封印
        // scope 给定时临时改该技能的 scope（行动后还原）
        const sk = w.$dataSkills[st.apply.skill], scope0 = sk.scope;
        if (st.apply.scope != null) sk.scope = st.apply.scope;
        const action = new w.Game_Action(who(st.apply.user)); action.setSkill(st.apply.skill); who(st.apply.target).clearResult();
        try { action.apply(who(st.apply.target)); } finally { sk.scope = scope0; }
        const res = who(st.apply.target).result();
        rows.push(Object.assign({step: st, used: res.used, hit: res.isHit()}, reading(ctx, atk))); continue;
      } else if (st.expire) {
        const x = who(st.expire.who); A.naturalRemoval = true; try { x.removeState(st.expire.id); } finally { A.naturalRemoval = false; }
      } else {
        const user = who(st.user);
        user.setTp(100); user._mp = user.mmp;
        const view = act(ctx.bm, user, st.def ? synth(st.def) : st.skill, st.target || 0, st.choice, st.repeats);
        if (st.view) { rows.push(Object.assign({step: st, view}, reading(ctx, atk))); continue; }
      }
      rows.push(Object.assign({step: st}, reading(ctx, atk)));
    }
    return eject ? {locked, start, rows, eject} : {locked, start, rows};
  }));
}
battleCase('none', {});
battleCase('inversebone', {affix: 'inversebone'});
battleCase('void', {affix: 'void'});
// 期二①：def 为合成技能 [code, dataId, value1]；scope 1 敌方单体、7 友方单体；目标序号按 scope 取对方或己方
const S = (scope, hitType, ...effects) => ({scope, hitType, effects});
// 疫囊：pestStates（灼伤 17、致盲 37）与减益必中、不可驱散；回合末传给全体敌人；自然到期照常去掉
battleCase('pest', {affix: 'pest', armor: 1013}, [
  {user: 'e0', def: S(1, 1, [21, 17, 1])}, {user: 'e0', def: S(1, 1, [21, 37, 1])}, {user: 'e0', def: S(1, 1, [32, 2, 3])},
  {user: 'b', def: S(7, 0, [22, 17, 1])}, {user: 'b', def: S(7, 0, [34, 2, 0])}, {roundEnd: 1},
  {expire: {who: 'a', id: 17}}, {user: 'b', def: S(7, 0, [22, 37, 1])}, {user: 'e1', def: S(1, 1, [32, 3, 2])}, {roundEnd: 2}, {roundEnd: 2}]);
// 疫囊传播减益照 itemEffectAddDebuff 掷骰（减益有效度 × 幸运差）：敌人物攻减益有效度 0，传不过去；物防照常传；
// 队友 b 直接对敌人放物攻减益（一般技能的效果 32）同样不中
battleCase('pest.resist', {affix: 'pest', armor: 1013, enemyTraits: [[12, 2, 0]]}, [
  {user: 'e0', def: S(1, 1, [32, 2, 3])}, {user: 'e0', def: S(1, 1, [32, 3, 3])}, {user: 'b', def: S(1, 1, [32, 2, 3])}, {roundEnd: 1}]);
// 囚厄：队友实际获得的 jailStates（沉默 6）与减益转给囚厄者，回合取较长；接收的不可驱散，自然到期后照常
battleCase('jail', {affix: 'jail'}, [
  {user: 'e0', target: 1, def: S(1, 1, [21, 6, 1])}, {user: 'e0', target: 1, def: S(1, 1, [32, 3, 3])},
  {user: 'b', def: S(7, 0, [22, 6, 1])}, {user: 'b', def: S(7, 0, [34, 3, 0])}, {expire: {who: 'a', id: 6}},
  {user: 'e0', def: S(1, 1, [21, 6, 1])}, {user: 'b', def: S(7, 0, [22, 6, 1])}, {user: 'e0', target: 1, def: S(1, 1, [21, 17, 1])}]);
// 绝缘：外来治疗、回蓝、登记增益（野性印记 116）、增益、减益、jailStates、驱散都拒收；自己给自己照常；非登记减益状态照常
battleCase('insulation', {affix: 'insulation'}, [
  {set: {aHp: 0.5, aMp: 0.5, bHp: 0.5}}, {user: 'b', skill: 8}, {user: 'a', skill: 8}, {user: 'b', def: S(7, 0, [21, 116, 1])},
  {user: 'a', def: S(7, 0, [21, 116, 1])}, {user: 'e0', def: S(1, 0, [22, 116, 1])}, {user: 'b', def: S(7, 0, [31, 2, 3])},
  {user: 'e0', def: S(1, 1, [32, 2, 3])}, {user: 'e0', def: S(1, 1, [21, 6, 1])}, {user: 'e0', def: S(1, 1, [21, 17, 1])},
  {set: {aMp: 0.5}}, {user: 'b', def: S(7, 0, [12, 0, 0.1])}, {user: 'b', def: S(7, 0, [11, 0, 0.1])}, {user: 'a', def: S(7, 0, [11, 0, 0.1])}]);
// 舍身：自己得到的治疗、登记增益状态、增益转给绑定队友（角色 8）；减益与普通状态不转
battleCase('sacrifice', {affix: 'sacrifice', config: {actorId: 1, partnerId: 8}}, [
  {set: {aHp: 0.5, bHp: 0.5}}, {user: 'b', skill: 8}, {user: 'a', skill: 8}, {user: 'b', def: S(7, 0, [31, 2, 3])},
  {user: 'a', def: S(7, 0, [21, 116, 1])}, {user: 'e0', def: S(1, 1, [32, 2, 3])}, {user: 'b', def: S(7, 0, [11, 0, 0.1])},
  {user: 'e0', def: S(1, 1, [21, 17, 1])}, {user: 'b', target: 1, skill: 8}]);
// 期二②（生命池类）：空壳、连命、嫁祸都绑定角色 8（空壳不绑定）；regen 照回合末 onTurnEnd（再生、护盾衰减）；revive 照 removeState(阵亡)
// 空壳：生命上限 1，开场剩余生命变护盾；治疗无效，回蓝变护盾（按开场生命／法力比例，护盾不超过原生命上限）；护盾打穿后倒下
battleCase('hollow', {affix: 'hollow'}, [
  {user: 'e0', skill: 1}, {user: 'b', skill: 8}, {set: {aMp: 0.5}}, {user: 'b', def: S(7, 0, [12, 0, 0.1])},
  {user: 'a', def: S(7, 0, [12, 0, 0.2])}, {regen: 'a'}, {user: 'e0', def: S(1, 0, [11, 0, -0.5])}, {user: 'e0', skill: 1}]);
// 连命：两人合并生命池（开场按剩余生命相加），各自按自己的上限比例显示；伤害与治疗都结算到池；池归零两人倒下；复活回池 10%
battleCase('lifelink', {affix: 'lifelink', config: {actorId: 1, partnerId: 8}}, [
  {user: 'e0', skill: 1}, {user: 'e1', skill: 1, target: 1}, {user: 'b', skill: 8}, {user: 'e0', def: S(1, 0, [11, 0, -0.1])},
  {user: 'b', target: 1, skill: 8}, {regen: 'a'}, {user: 'e0', def: S(1, 0, [11, 0, -1])}, {user: 'e0', def: S(1, 0, [11, 0, -1])},
  {revive: 'a'}]);
// 嫁祸：敌人对自己的生命伤害改由保护者（角色 8）按保护者的防御、护盾承受；自己的生命按保护者比例显示，治疗无效；保护者倒下自己也倒下
battleCase('scapegoat', {affix: 'scapegoat', config: {actorId: 1, partnerId: 8}}, [
  {user: 'e0', skill: 1}, {user: 'e0', def: S(1, 0, [11, 0, -0.1])}, {user: 'b', skill: 8}, {user: 'b', target: 1, skill: 8},
  {user: 'e1', skill: 1, target: 1}, {regen: 'a'}, {set: {bHp: 0.01}}, {user: 'e0', skill: 1}, {revive: 'a'}]);
// 期一顺带：舍身的回合末再生转给队友，绝缘自己的再生照常（再生生命 0.35 的普度众生 1366）
battleCase('sacrifice.regen', {affix: 'sacrifice', config: {actorId: 1, partnerId: 8}}, [
  {set: {aHp: 0.5, bHp: 0.5}}, {user: 'a', def: S(7, 0, [21, 1366, 1])}, {regen: 'a'}]);
battleCase('insulation.regen', {affix: 'insulation'}, [
  {set: {aHp: 0.5}}, {user: 'a', def: S(7, 0, [21, 1366, 1])}, {regen: 'a'}, {user: 'b', def: S(7, 0, [21, 1366, 1])}, {regen: 'a'}]);
// 生命池补漏：行动外的 gainHp（腐蚀每回合末扣 2% 生命）照 hpChange：连命扣池、嫁祸由保护者付、空壳先吃护盾
const CORRODE = {user: 'e0', def: S(1, 1, [21, C.ids.corrosion, 1])};
battleCase('lifelink.corrosion', {affix: 'lifelink', config: {actorId: 1, partnerId: 8}}, [CORRODE, {tick: 1}, {tick: 2}]);
battleCase('scapegoat.corrosion', {affix: 'scapegoat', config: {actorId: 1, partnerId: 8}}, [CORRODE, {tick: 1}, {tick: 2}]);
battleCase('hollow.corrosion', {affix: 'hollow'}, [CORRODE, {tick: 1}]);
// 事件「增减生命」（Game_Interpreter.changeHp：先按不致死夹到最多扣到 1，再 gainHp）：连命扣池、嫁祸由保护者付、空壳不吃治疗
battleCase('lifelink.event', {affix: 'lifelink', config: {actorId: 1, partnerId: 8}}, [
  {event: {who: 'a', value: -3000}}, {event: {who: 'b', value: 1000}}, {event: {who: 'a', value: -99999}}, {event: {who: 'a', value: -99999, death: true}}]);
battleCase('scapegoat.event', {affix: 'scapegoat', config: {actorId: 1, partnerId: 8}}, [{event: {who: 'a', value: -1000}}, {event: {who: 'a', value: 500}}]);
// 嫁祸保护者（角色 8）行动外扣血：gainHp 包装末尾 A.syncRelations，嫁祸者按保护者比例跟着掉、保护者倒下嫁祸者跟着倒下
// （镜骸反噬、腐蚀、事件「增减生命」，含致死）
const SCAPEGOAT = {affix: 'scapegoat', config: {actorId: 1, partnerId: 8}};
battleCase('scapegoat.mirror_protector', Object.assign({mirror: true}, SCAPEGOAT), [{user: 'b', skill: 1}, {user: 'b', skill: 1}]);
battleCase('scapegoat.corrosion_protector', SCAPEGOAT, [Object.assign({target: 1}, CORRODE), {tick: 1}]);
battleCase('scapegoat.event_protector', SCAPEGOAT, [{event: {who: 'b', value: -1000}}]);
battleCase('scapegoat.event_protector_death', SCAPEGOAT, [{event: {who: 'b', value: -99999, death: true}}]);
battleCase('hollow.event', {affix: 'hollow'}, [{event: {who: 'a', value: 500}}, {event: {who: 'a', value: -500, death: true}}]);
// 连命者的负再生（中毒 4）先吃护盾：护盾够吸收时只扣护盾；不够时击穿，余下的进生命池（沙僧第三十六期补核的现场）
battleCase('lifelink.regen_shield', {affix: 'lifelink', config: {actorId: 1, partnerId: 8}}, [{set: {aShield: 1000}}, {user: 'e0', def: S(1, 0, [21, 4, 1])}, {regen: 'a'}]);
battleCase('lifelink.regen_shield_break', {affix: 'lifelink', config: {actorId: 1, partnerId: 8}}, [{set: {aShield: 100}}, {user: 'e0', def: S(1, 0, [21, 4, 1])}, {regen: 'a'}]);
// 夺舍（Adv:11、37、72、80、86、105）：队友（角色 8，90 级）整场退出战斗（battleMembers 去掉），角色 1（35 级）借队友学会的
// possessionSkills（教 9 火焰）与安全被动（教 16 剑道天赋）；敌人等级在锁队前已按队伍最高等级定（含队友）；自己倒下时队友也倒下
const POSSESS = {affix: 'possession', config: {actorId: 1, partnerId: 8}, level: 35, allyLevel: 90, teach: [9, 16]};  // 本体 1044 要 35 级
battleCase('possession', POSSESS, [{user: 'a', skill: 9}, {user: 'e0', skill: 1}, {event: {who: 'a', value: -99999, death: true}}]);
// 被夺舍的队友自己穿饕餮：锁队照样冻结（法力归 0）
battleCase('possession.glutton', Object.assign({allyAffix: 'glutton'}, POSSESS), [{user: 'e0', skill: 1}]);
battleCase('possession.invalid', Object.assign({dead: ['b']}, POSSESS), [{user: 'e0', skill: 1}]);
// 锁队检查（Adv:62）：绑定的队友（角色 2）不在场，异化装备卸下放回背包，本场不生效
battleCase('lifelink.invalid', {affix: 'lifelink', config: {actorId: 1, partnerId: 2}}, [{user: 'e0', skill: 1}]);
// 第③批·行动道具投影：祸祝把 templates.blessing（7100 幻日虹，自身加速 2421）改为敌方单体、状态换成 statePairs 的诅咒（2668 减速）；
// 名字「祸祝·」。普攻不在模板里，不投影。view 记行动开始前 Game_Action.item() 的名字、scope、效果
battleCase('blessing', {affix: 'blessing', armor: 1020, learn: [7100]}, [{user: 'a', skill: 7100, view: true}, {user: 'a', skill: 7100, target: 1, view: true},
  {user: 'a', skill: 1, view: true}]);
battleCase('blessing.none', {learn: [7100]}, [{user: 'a', skill: 7100, view: true}]);
// 恶愿：templates.wish（7100）改为除自己外的全体友方；自己先挂上 statePairs 的诅咒（2668，回合照 2421 的最少回合），不可驱散、自然到期才去掉。
// 到期后先普攻一次：原版自然到期记进行动结果（isStateRemoved），结果清掉之前再付代价挂不上诅咒（O-110），这里让对照避开它
battleCase('wish', {affix: 'wish', learn: [7100]}, [{user: 'a', skill: 7100, view: true}, {user: 'b', def: S(7, 0, [22, 2668, 1])},
  {expire: {who: 'a', id: 2668}}, {user: 'a', skill: 1}, {user: 'a', skill: 7100, view: true}]);
// 逆祷：templates.attack 的攻击照治愈（8）改为治疗友方（原 scope 1→7，其余→8，3～6 改随机友方 n 个），治疗预算按原技能 MP 费用
// 选治疗技能（≥125 治疗术 166、≥75 次级治疗术 135、否则 8），平分给目标；模板外的伤害技能不能用（usable），硬用对敌人也没有伤害
battleCase('prayer', {affix: 'prayer'}, [{set: {aHp: 0.5, bHp: 0.5}}, {user: 'a', skill: 1, target: 1, view: true},
  {user: 'a', skill: 114, view: true}, {user: 'a', skill: 148, view: true}, {set: {aHp: 0.3, bHp: 0.3}}, {user: 'a', skill: 274, view: true},
  {user: 'a', skill: 109, view: true}, {user: 'e0', skill: 1}]);
// 第③批·MP 费用：缄默（选定 templates.silence 的盗梦 3648，MP 5000，先学会）：MP 费用 0，每次锁 面板费用／开场MP×20% 的生命上限
// （约 30.9%），生命截到新上限；锁满（累计 ≥100% 或锁后上限不到 1）就用不了、硬用整次不付费；不受魔法沉默（沉默 6）封印，别的魔法照封。
// 沉默的随机回合两边取法不同，锁满那步之前先按自然到期去掉
battleCase('silence', {affix: 'silence', learn: [3648], config: {actorId: 1, skillId: 3648}}, [
  {user: 'a', skill: 3648, view: true}, {user: 'e0', def: S(1, 0, [21, 6, 1])}, {user: 'a', skill: 3648, view: true},
  {user: 'a', skill: 114, view: true}, {user: 'a', skill: 3648, view: true}, {expire: {who: 'a', id: 6}}, {user: 'a', skill: 3648, view: true}]);
// 饕餮：实际 MP 上限 0、回蓝无效；开场身上的登记增益（野性印记 116）与增益吞成饥饿储备；队友给的登记增益、增益也吞掉；
// 吞噬（10198）吞敌人第一个登记增益状态，没有就吞增益；MP 费用从储备扣（付不起照付、储备归 0）
battleCase('glutton', {affix: 'glutton', pre: {states: [[116, 3]], buffs: [[2, 1, 3]]}}, [
  {user: 'b', def: S(7, 0, [21, 116, 1])}, {user: 'b', def: S(7, 0, [31, 3, 3])}, {user: 'b', def: S(7, 0, [12, 0, 0.5])},
  {user: 'e0', def: S(7, 0, [21, 116, 1])}, {user: 'e0', def: S(7, 0, [31, 6, 3])},
  {user: 'a', skill: C.ids.devour, view: true}, {user: 'a', skill: C.ids.devour, view: true}, {user: 'a', skill: C.ids.devour, view: true},
  {user: 'a', skill: 114, view: true}, {user: 'a', skill: 148, view: true}, {user: 'a', skill: 114, view: true}]);
// 第③批·借技能：百相（替换万剑诀 160）：敌人行动根用的可借技能（登记攻击、效果只有可传播减益或可共享增益）记进仿形，最多 3 项，
// 第一项自动成为仿形；仿形技能进技能表、替换的技能拿掉且不能用；记了两项以上多一个切换仿形（10197，作用自己、无效果），
// 没选就换成第一个不是当前仿形的记录；记录了但不是当前仿形（又不是自己本来会的）不能用。技能都挑 0 MP（重制敌人付不起不行动）、
// 方差 0、不暴击的测试技能 1924／1926／1928／1930（物理、火焰、寒冰、大地 100），伤害不受随机取整差异影响
battleCase('mimic', {affix: 'mimic', config: {actorId: 1, replace: 160}}, [
  {user: 'a', skill: 160, view: true}, {user: 'e0', skill: 1}, {user: 'e0', skill: 1924}, {user: 'a', skill: 1924, view: true},
  {user: 'e1', skill: 1926, target: 1}, {user: 'a', skill: 1926, view: true}, {user: 'a', skill: C.ids.switch, view: true},
  {user: 'a', skill: 1926, view: true}, {user: 'a', skill: 1924, view: true}, {user: 'e0', skill: 1928}, {user: 'e0', skill: 1930},
  {user: 'a', skill: C.ids.switch, view: true}, {user: 'a', skill: C.ids.switch, choice: 1928, view: true}, {user: 'a', skill: 1928, view: true}]);
// 无面：借角色 8 已学会的 1924（替换万剑诀 160）、1926（替换天剑 311）；被替换的拿掉且不能用，没被替换的剑神诀 502 照常；
// 来源队友忘掉后借来的不能用（仍在技能表）。忘掉放最后：之后角色 1 再行动，useItem 的 refresh 经 canEquip 包装（A.ready 不过）
// 把异化武器卸回背包，重制没移植这一处（见 alien_battle.gd 词条效果③百相、无面）
battleCase('faceless', {affix: 'faceless', teach: [1924, 1926], config: {actorId: 1, pairs: [{ownerId: 8, skillId: 1924, replaceId: 160}, {ownerId: 8, skillId: 1926, replaceId: 311}]}}, [
  {user: 'a', skill: 1924, view: true}, {user: 'a', skill: 160, view: true}, {user: 'a', skill: 1926, view: true}, {user: 'a', skill: 502, view: true},
  {forget: {who: 'b', id: 1924}}]);
// 第③批·蚀术（选定 templates.attack 的 1924，先学会）：这招与同一行动根里的生命伤害只扣目标护盾（护盾不够扣到 0 为止），生命不变；
// 命中后封印目标上次用的技能（startAction 记的、>2 且在 templates.attack 里；目标已有封印不再封），封印成功也封自己的 1924；
// 各自下一次技能行动（原有合法行动窗口：startAction 时能动且不看封印也合条件）结束时解封。e1 先用合成技能 13（不在模板里）不封
battleCase('erosion', {affix: 'erosion', learn: [1924], config: {actorId: 1, skillId: 1924}}, [
  {user: 'a', skill: 1924, target: 1, view: true}, {user: 'e1', def: S(11, 0)}, {user: 'a', skill: 1924, target: 1},
  {user: 'e0', skill: 1926}, {shield: {who: 'e0', value: 1000}}, {user: 'a', skill: 1924, view: true}, {user: 'a', skill: 1924, view: true},
  {user: 'e0', skill: 1928}, {user: 'a', skill: 1924, view: true}, {user: 'a', skill: 1}, {user: 'b', skill: 1}]);
// 蚀术命中判定（审查第 2 期 D2／P3）：e0 先用 1926 留下可封的上次技能，再由角色 1 直接对活着的 e0 apply 选定的 1924：
// 临时把 1924 的 scope 改成 9（对阵亡友方，复活类）时 used 为假、不算命中、不封印；scope 照旧时命中并封印
battleCase('erosion.used', {affix: 'erosion', learn: [1924], config: {actorId: 1, skillId: 1924}}, [
  {user: 'e0', skill: 1926}, {apply: {user: 'a', target: 'e0', skill: 1924, scope: 9}}, {apply: {user: 'a', target: 'e0', skill: 1924}}]);
// 技能 HP 费用（YEP_SkillCore＋Adv:126-128）：搏命 3913（3% 生命上限）。空壳按开场参照上限算、看护盾够不够（护盾 1 时不能用、硬用扣到 0）、
// 从护盾扣；连命从生命池扣；嫁祸由保护者（角色 8）的生命付
battleCase('hollow.hpcost', {affix: 'hollow', learn: [3913]}, [{user: 'a', skill: 3913, view: true}, {set: {aShield: 1}}, {user: 'a', skill: 3913, view: true}]);
battleCase('lifelink.hpcost', {affix: 'lifelink', learn: [3913], config: {actorId: 1, partnerId: 8}}, [{user: 'a', skill: 3913, view: true}]);
battleCase('scapegoat.hpcost', {affix: 'scapegoat', learn: [3913], config: {actorId: 1, partnerId: 8}}, [{user: 'a', skill: 3913, view: true}]);
// 第④批·装备类：吞器（本体 1044 武器，供体背包里的普通独立武器 6 指虎）：衣服栏（装备类型 4，穿皮甲 3）整场空出，
// 借来供体的登记效果（命中、暴击各 +1%）；不继承供体的能力值；供体留在背包。逃跑结束后装备栏还原，供体、异化武器都不多不少
battleCase('swallow', {affix: 'swallow', gear: true, donors: [6], body: 3, config: {actorId: 1, donorId: 'd0'}}, [
  {user: 'e0', skill: 1}, {user: 'a', skill: 1}, {end: 1}]);
// 供体加了【锁定】：锁队时 A.ready 不过，异化武器卸下放回背包，本场不生效
battleCase('swallow.invalid', {affix: 'swallow', gear: true, donors: [6], body: 3, lockDonor: true, config: {actorId: 1, donorId: 'd0'}}, [
  {user: 'a', skill: 1}, {end: 1}]);
// 献器（绑定角色 8）：自己的装备栏整场全空（属性、效果、套装都没了），每件装备的登记效果（异化武器本身不借）交给角色 8；全灭结束后还原
battleCase('offer', {affix: 'offer', gear: true, body: 3, config: {actorId: 1, partnerId: 8}}, [
  {user: 'e0', skill: 1}, {user: 'e0', skill: 1, target: 1}, {user: 'b', skill: 1}, {end: 2}]);
// 补漏①：绝缘的 setHp（行动外直接设生命，改走 gainHp(差值)）：外来抬高拒收、外来压低照扣、自己设照常；舍身的外来抬高转给队友
battleCase('insulation.sethp', {affix: 'insulation'}, [
  {set: {aHp: 0.5}}, {sethp: {who: 'a', value: 0.8, src: 'b'}}, {sethp: {who: 'a', value: 0.3, src: 'b'}}, {sethp: {who: 'a', value: 0.6, src: 'a'}},
  {sethp: {who: 'a', value: 0.9}}]);
battleCase('sacrifice.sethp', {affix: 'sacrifice', config: {actorId: 1, partnerId: 8}}, [
  {set: {aHp: 0.5, bHp: 0.5}}, {sethp: {who: 'a', value: 0.9, src: 'b'}}, {sethp: {who: 'a', value: 0.2, src: 'b'}}]);
// 补漏②：阵亡（die：清状态、清增减益）时，疫囊者身上的 pestStates（此刻还算活着）、囚厄接收的状态与减益、
// 绝缘者被外来行动打倒时身上的登记增益与增益都保留；之后复活（去阵亡）仍在。疫囊的减益不保留（Affixes 没包 clearBuffs）
const KILL = {user: 'e0', def: S(1, 0, [11, 0, -1])};
battleCase('pest.death', {affix: 'pest', armor: 1013}, [
  {user: 'e0', def: S(1, 1, [21, 17, 1])}, {user: 'e0', def: S(1, 1, [32, 2, 3])}, KILL, {revive: 'a'}]);
battleCase('jail.death', {affix: 'jail'}, [
  {user: 'e0', target: 1, def: S(1, 1, [21, 6, 1])}, {user: 'e0', target: 1, def: S(1, 1, [32, 3, 3])}, KILL, {revive: 'a'}]);
battleCase('insulation.death', {affix: 'insulation'}, [
  {user: 'a', def: S(7, 0, [21, 116, 1])}, {user: 'a', def: S(7, 0, [31, 2, 3])}, {user: 'a', def: S(7, 0, [21, 17, 1])}, KILL]);
// 补漏③：锁队检查（Adv:62）——绑定的队友（角色 8）开战前已倒下；两人（角色 1、2）都舍身绑定角色 8，后面的人被卸下
battleCase('lifelink.dead', {affix: 'lifelink', dead: ['b'], config: {actorId: 1, partnerId: 8}}, [{user: 'e0', skill: 1}]);
battleCase('sacrifice.twice', {affix: 'sacrifice', config: {actorId: 1, partnerId: 8}, extra: {actor: 2, affix: 'sacrifice', config: {actorId: 2, partnerId: 8}}},
  [{set: {aHp: 0.5, bHp: 0.5}}, {user: 'b', skill: 8}]);
// 补漏④：逆祷者的反击（反击率 100% 的避苍 327；敌人用物理的合成技能，普攻 1 不是物理、不会被反击）也读投影；石中剑 1044 把攻击换成
// 别的技能（不在 templates.attack），这例异化武器的本体换成同为剑类的未知的刀片 1521（没有换攻击）：反击变成治愈打在敌人身上；攻击次数 +1（勇士 41）时逆祷普攻（同样用 1521）不加次数；
// 逆祷者挂给敌人的毒鸡汤（460，自定义再生效果扣生命，来源是逆祷者）在回合末的行动帧里被阻断
battleCase('prayer.counter', {affix: 'prayer', weapon: 1521}, [
  {user: 'a', def: S(11, 0, [21, 327, 1])}, {user: 'b', skill: 1}, {user: 'e0', def: S(1, 1), target: 0}]);
battleCase('prayer.repeat', {affix: 'prayer', weapon: 1521}, [
  {user: 'a', def: S(11, 0, [21, 41, 1])}, {set: {bHp: 0.5}}, {user: 'a', skill: 1, target: 1, view: true, repeats: true}]);
battleCase('prayer.dot', {affix: 'prayer'}, [{user: 'a', def: S(1, 0, [21, 460, 1])}, {regen: 'e0'}, {regen: 'e0'}]);
// 补漏⑥：事件「增减 MP」（command312：actor.gainMp）——空壳回蓝变护盾、扣蓝照扣；饕餮一律无效；绝缘拒收外来（src 为 _subject）回蓝，自己照收
battleCase('hollow.mp', {affix: 'hollow'}, [{set: {aMp: 0.5}}, {event: {who: 'a', value: 300, mp: true}}, {event: {who: 'a', value: -100, mp: true}}]);
battleCase('glutton.mp', {affix: 'glutton'}, [{event: {who: 'a', value: 300, mp: true}}, {event: {who: 'a', value: -100, mp: true}}]);
battleCase('insulation.mp', {affix: 'insulation'}, [{set: {aMp: 0.5}}, {event: {who: 'a', value: 300, mp: true, src: 'b'}},
  {event: {who: 'a', value: 300, mp: true}}, {event: {who: 'a', value: -100, mp: true, src: 'b'}}]);
process.exit(finish(host, 'alien_affix.json', {hostScope: '新游戏（Math.random 0.5）；异化词条效果期一（逆骨、归墟）、期二①（疫囊、囚厄、绝缘、舍身）、期二②（空壳、连命、嫁祸）、生命池补漏（行动外扣血、事件增减生命）、第③批行动道具投影（祸祝、恶愿、逆祷）、MP 费用（缄默、饕餮）、借技能（百相、无相）、蚀术、第④批装备类（吞器、献器）、补漏（setHp、阵亡保留、锁队检查已倒下与重复绑定、逆祷反击与连击与持续伤害帧、事件增减 MP）', config, cases}) ? 0 : 1);
