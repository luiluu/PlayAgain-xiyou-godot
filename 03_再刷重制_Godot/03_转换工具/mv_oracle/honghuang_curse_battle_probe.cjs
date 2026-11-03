'use strict';
// 【cc·悟空·未经审查】诅咒 7201～7215 与洪荒压制 10300 的战斗效果：队伍 1 号学一个诅咒，敌群 3；开战标签状态，量双方状态与回合、
// 八维、xparam、sparam、敌人再动，再让 1 号普攻敌人一次看伤害（固定 Math.random＝0.5，敌人血加 1e12）；7208 死而复燃另量 0.1／0.5 两种随机下把敌人打死后的血蓝 TP。
// Scene_Battle.start 需要窗口，无界面宿主跑不了；开战标签照 dsPassiveSkill 逐键解析（同 start_state_walk_probe）。
// 产物 .sandbox/honghuang_curse_battle.json，手工复制为 tests/fixtures/honghuang_curse_battle_oracle.json（tests/xiyou_honghuang_curse_battle 对照，不进同步）。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const stub = new Proxy({}, {get: () => () => {}});
function setup(curse, rnd) {
  newGame();
  w.Math.random = () => 0.5;  // 敌人的血量等开战数值也取随机，开战这段都用 0.5
  w.eval('$gameParty._actors=[1]; $gameParty._battleMembers=[1,0,0,0,0];');
  const a = w.$gameActors.actor(1);
  if (curse) a.learnSkill(curse);
  const bm = w.BattleManager;
  bm.setup(3, true, false);
  bm._logWindow = stub; bm._spriteset = stub; bm._statusWindow = stub;
  w.SceneManager._scene = {_otbDisplayWindow: stub};
  bm.startBattle();
  a.initPassiveCache();
  const enemies = w.$gameTroop.members();
  a.equips().concat(a.skills()).filter(Boolean).forEach(obj => {
    for (const key in obj.meta || {}) {
      const m = /^Start(WT|AE)?PushState(\d+)$/.exec(key);
      if (!m) continue;
      if (!(w.Math.random() * 100 < parseFloat(String(obj.meta[key]).trim().replace('%', '')))) continue;
      const to = m[1] === 'WT' ? [a] : m[1] === 'AE' ? enemies.filter(e => e.isAlive()) : [a];
      to.forEach(x => x.addState(Number(m[2])));
    }
  });
  a._passiveCache.okadd = true;
  a.refreshPassiveCache();
  // krz_state_re 的 states() 缓存在 addState 后不刷新，第一回合 onTurnStart 才 refresh（同 start_state_walk_probe）
  a.refresh(); enemies.forEach(x => x.refresh());
  w.Math.random = () => rnd;
  return {a, enemies, e: enemies[0]};
}
const nums = f => [...Array(10).keys()].map(i => round(f(i)));
const look = b => ({states: b.states().map(s => s.id).filter(id => id > 1), turns: Object.keys(b._stateTurns || {}).map(Number).sort((x, y) => x - y).map(id => [id, b._stateTurns[id]]),
  params: [0, 1, 2, 3, 4, 5, 6, 7].map(i => round(b.param(i))), x: nums(i => b.xparam(i)), s: nums(i => b.sparam(i)), plus: b.actionPlusSet().map(round), rates: {death: b.isStateResist(1)}});
const attack = (a, e) => { const act = new w.Game_Action(a); act.setSkill(1); e.clearResult(); act.apply(e); const r = e.result(); return {hit: r.isHit(), critical: r.critical, hp: round(r.hpDamage), dead: e.isDeathStateAffected()}; };
const cases = [];
for (const curse of [0, 7201, 7202, 7203, 7204, 7205, 7206, 7207, 7208, 7209, 7210, 7211, 7212, 7213, 7214, 7215, 10300]) cases.push(makeCase(`curse.${curse}`, {curse}, () => {
  const {a, e} = setup(curse, 0.5);
  const out = {actor: look(a), enemy: look(e)};
  e.setHp(e.mhp); a.setHp(a.mhp);
  out.attack = attack(a, e);
  return out;
}));
// 免死（7203）：敌人死亡状态抗性，打到 0 血不倒下
cases.push(makeCase('immortal.7203', {curse: 7203}, () => {
  const {a, e} = setup(7203, 0.5);
  e.setHp(1);
  const r = attack(a, e);
  e.refresh();
  return {...r, hpAfter: round(e.hp), resist: e.isStateResist(1), states: e.states().map(s => s.id), alive: e.isAlive()};
}));
for (const [tag, rnd] of [['revive', 0.1], ['stay', 0.5]]) cases.push(makeCase(`revive.${tag}`, {curse: 7208, rnd}, () => {
  const {a, e} = setup(7208, rnd);
  e.setHp(1); e.setMp(0); e.setTp(50);
  const r = attack(a, e);
  e.refresh();
  return {...r, hpAfter: round(e.hp), mhp: round(e.mhp), mp: round(e.mp), mmp: round(e.mmp), tp: round(e.tp), alive: e.isAlive(), states: e.states().map(s => s.id), hpDamage: round(e.result().hpDamage)};
}));
process.exit(finish(host, 'honghuang_curse_battle.json', {hostScope: '真实 Game_Action.apply 与状态包装；开战标签照 dsPassiveSkill 解析；Math.random 固定', cases}) ? 0 : 1);
