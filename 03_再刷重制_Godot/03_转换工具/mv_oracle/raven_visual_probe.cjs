'use strict';
// 【cc·ravenfx·未经审查】渡鸦表现余项（installNativeRavenRuntime 第 570～598 行）：
// ① Sprite_Actor.startMotion 包装：167 的 damage→evade、dying→wait（普通与神话形态都量：这层包在 Codex_MiraRavenMultiFrame 外面，
//   多帧插件给神话留的原生受击／濒死在实际装载次序下用不上）；别的角色不换。
// ② Game_CharacterBase.animationWait 包装：玩家（取队长）或跟随者是 167 时 ×1.35 四舍五入；事件、别的角色不变。各移动速度都量。
// 产物 .sandbox/raven_visual.json（generated/oracle/raven_visual.json），专项 xiyou_raven_visual。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const MOTIONS = ['walk', 'wait', 'chant', 'guard', 'damage', 'evade', 'thrust', 'swing', 'missile', 'skill', 'spell', 'item', 'escape', 'victory', 'dying', 'abnormal', 'sleep', 'dead'];
// 无场景：YEP_X_VisualStateFX 的状态动画要挂到战斗场景层，量动作时不需要
w.Sprite_Battler.prototype.startStateAnimation = function () {};
const name = m => Object.keys(w.Sprite_Actor.MOTIONS).find(k => w.Sprite_Actor.MOTIONS[k] === m);
const cases = [];
for (const [id, myth] of [[167, false], [167, true], [168, false], [1, false]]) {
  cases.push(makeCase(`motion.${id}.${myth ? 'myth' : 'normal'}`, {actor: id, myth}, () => {
    newGame();
    w.$gameParty.addActor(id);
    const a = w.$gameActors.actor(id);
    if (myth) { w.$gameParty._inBattle = true; a._codexRavenMythTurns = 3; }
    const sp = new w.Sprite_Actor(a), out = {};
    for (const m of MOTIONS) { sp.startMotion(m); out[m] = name(sp._motion); }
    const battler = a.battlerName();
    w.$gameParty._inBattle = false;
    return {battler, motions: out};
  }));
}
for (const lead of [167, 1]) for (const second of [167, 8]) {
  if (lead === second) continue;
  cases.push(makeCase(`walk.${lead}.${second}`, {party: [lead, second, 9, 10]}, () => {
    newGame();
    w.$gameSwitches.setValue(2494, true);  // 超强者可出战（167 才进得了出战栏）
    w.eval('$gameParty._actors=[' + [lead, second, 9, 10] + '];$gameParty._battleMembers=[' + [lead, second, 9, 10, 0] + '];');
    w.$gamePlayer.refresh();
    const rows = [];
    for (const speed of [1, 2, 3, 4, 5, 6]) {
      w.$gamePlayer.setMoveSpeed(speed);
      const f = w.$gamePlayer.followers().follower(0), f2 = w.$gamePlayer.followers().follower(1);
      f.setMoveSpeed(speed); f2.setMoveSpeed(speed);
      const ev = new w.Game_Character(); ev.setMoveSpeed(speed);
      rows.push({speed, player: w.$gamePlayer.animationWait(), follower1: f.animationWait(), follower2: f2.animationWait(), character: ev.animationWait()});
    }
    return {members: w.$gameParty.battleMembers().map(b => b.actorId()), rows};
  }));
}
process.exit(finish(host, 'raven_visual.json', {hostScope: '正式 Sprite_Actor.startMotion、Game_CharacterBase.animationWait（渡鸦包装）', cases}) ? 0 : 1);
