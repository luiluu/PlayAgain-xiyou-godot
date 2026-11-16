'use strict';
// 被动再释放／攻击次数参照（T046）：dsPassiveSkill 的 Game_Action.numRepeats 包装——MV 本体＋被动 atkk，
// 再把 AgainUseAll＋AgainUseZj（stypeId 1）／AgainUseMf（stypeId 2）＋AgainUse<技能号> 合计，Math.random×100 < 合计时 +1。
// 每例在新局里摆好角色 1（卸下全部装备、learnSkill、addState、refresh，再把装备直接放进槽、refreshPassiveCache），
// 对普攻（技能 1）、战技 9、魔法 51、物品 1 各建 Game_Action，在一串固定的 Math.random 值下问 numRepeats，另记 MV 本体次数。
// 只在内存；产物 .sandbox/again_use.json，拷成 tests/fixtures/again_use_oracle.json（不进同步），专项 xiyou_again_use。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');
const cases = [];
const ROLLS = [0, 0.0099, 0.01, 0.0499, 0.05, 0.0999, 0.1, 0.1499, 0.15, 0.1999, 0.2, 0.2499, 0.25, 0.3499, 0.35, 0.4999, 0.5, 0.6999, 0.7, 0.9999];
const ACTIONS = [['skill', 1], ['skill', 9], ['skill', 51], ['item', 1]];

function bare(a) { a._equips.forEach((e, n) => { if (e.object()) a.forceChangeEquip(n, null); }); }
function slotOf(a, kind, id) { return kind === 'w' ? 0 : a.equipSlots().indexOf(w.$dataArmors[id].etypeId); }
function measure(a) {
  return ACTIONS.map(([kind, id]) => {
    const act = new w.Game_Action(a);
    if (kind === 'skill') act.setSkill(id); else act.setItem(id);
    const item = act.item(), M = w.Math, keep = M.random, got = [];
    try {
      for (const r of ROLLS) { M.random = () => r; got.push(act.numRepeats()); }
    } finally { M.random = keep; }
    return {kind, id, mvRepeats: Math.floor(item.repeats + (act.isAttack() ? a.attackTimesAdd() : 0)), numRepeats: got};
  });
}
// spec: {actor, equips:[['w'|'a', id]], states:[id], skills:[id]}
function actorCase(name, spec) {
  cases.push(makeCase(name, spec, () => {
    newGame(); w.$gameParty.addActor(spec.actor);
    w.$gameParty._inBattle = true;
    const a = w.$gameActors.actor(spec.actor);
    bare(a);
    (spec.skills || []).forEach(id => a.learnSkill(id));
    (spec.states || []).forEach(id => a.addState(id));
    a.refresh();
    // 装备在 refresh 之后直接放进槽（不管能不能装：只量备注标签，不让 releaseUnequippableItems 卸掉）
    (spec.equips || []).forEach(([k, id]) => a._equips[slotOf(a, k, id)].setObject(k === 'w' ? w.$dataWeapons[id] : w.$dataArmors[id]));
    if (a.refreshPassiveCache) a.refreshPassiveCache();
    const c = a._passiveCache || {};
    return {states: a.states().map(s => s.id), equips: a.equips().map(e => e ? e.id : 0),
      cache: {atkk: c.atkk || 0, againUse: c.againUse || null}, actions: measure(a)};
  }));
}

actorCase('none', {actor: 1});
actorCase('state1384-all50', {actor: 1, states: [1384]});
actorCase('state1730-zj100', {actor: 1, states: [1730]});
actorCase('skill1817-atkk', {actor: 1, skills: [1817]});
actorCase('skill10137-mf15-nopct', {actor: 1, skills: [10137]});
actorCase('skills198-826-state1395', {actor: 1, skills: [198, 826], states: [1395]});
actorCase('atkk-and-all', {actor: 1, skills: [1817], states: [1384]});
actorCase('rune-armor3852-zjmf25', {actor: 1, equips: [['a', 3852]]});
actorCase('rune-armor3872-all25', {actor: 1, equips: [['a', 3872]]});
actorCase('armor3852-and-state1384', {actor: 1, equips: [['a', 3852]], states: [1384]});
actorCase('rune-weapon1235', {actor: 1, equips: [['w', 1235]]});
actorCase('weapon1588-mf15', {actor: 1, equips: [['w', 1588]]});
actorCase('skill7008-all100', {actor: 1, skills: [7008]});

process.exit(finish(host, 'again_use.json', {hostScope: '真实 Game_Action.numRepeats（dsPassiveSkill 包装及之后装的 Codex 运行时）；Math.random 按 ROLLS 逐个固定', rolls: ROLLS, cases}) ? 0 : 1);
