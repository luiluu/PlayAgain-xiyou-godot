'use strict';
// YEP_X_VisualStateFX 状态循环动画参照（bailong-visual1）：census＝带 <State Animation: N> 的状态与参数；
// loop＝给角色／敌人加该状态后 Sprite_StateAnimation 的播放时序（重播间隔、动画号、换状态／去状态后的变化、闪光开关）。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');
function battle() {
  if (w.$gameParty) w.$gameParty._inBattle = false;
  newGame(); w.eval('$gameParty._actors=[];'); w.$gameParty.addActor(1);
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  w.BattleManager.setup(2, true, true);
  w.$gameTroop.clear(); w.$gameTroop.setup(2);
}
function spriteOf(b, kind) {
  const p0 = new w.Sprite(), p1 = new w.Sprite(), sp = kind === 'actor' ? new w.Sprite_Actor(b) : new w.Sprite_Enemy(b);
  p0.addChild(p1); p1.addChild(sp);
  b.battler = () => sp;
  return sp;
}
const cases = [];
cases.push(makeCase('census', {}, () => {
  newGame();
  const P = w.Yanfly.Param;
  const states = w.$dataStates.filter(s => s && (s.stateAnimationId || s.stateMotion)).map(s => ({id: s.id, name: s.name, ani: s.stateAnimationId, motion: s.stateMotion || null, priority: s.priority}));
  const anims = {};
  for (const s of states) if (s.ani) { const a = w.$dataAnimations[s.ani]; anims[s.ani] = a ? {name: a.name, frames: a.frames.length, rate: 4, position: a.position, timings: a.timings.map(t => ({frame: t.frame, flashScope: t.flashScope, flashDuration: t.flashDuration, se: !!(t.se && t.se.name)}))} : null; }
  return {states, anims, params: {actorOver: P.VSFXActorOver, actorIcons: P.VSFXActorIcons, actorAni: P.VSFXActorAni, enemyOver: P.VSFXEnemyOver, enemyIcons: P.VSFXEnemyIcons, enemyAni: P.VSFXEnemyAni, target: P.VSFXAniTarget, screen: P.VSFXAniScreen, hide: P.VSFXAniHide, sound: P.VSFXAniSound}};
}));
function loopRun(kind, stateId) {
  battle();
  const b = kind === 'actor' ? w.$gameActors.actor(1) : w.$gameTroop.members()[0];
  const sp = spriteOf(b, kind);
  const frames = [];
  const upd = n => { for (let i = 0; i < n; i++) { sp.update(); if (sp._stateAniSprite) sp._stateAniSprite.update(); } };
  upd(3);
  const rec = tag => { const s = sp._stateAniSprite; return {tag, current: sp._currentStateAni, id: b.stateAnimationId(), has: !!s, anim: s && s._animation ? s._animation.id : 0, duration: s ? s._duration : null, opacity: s ? s.opacity : null, playing: s ? s.isPlaying() : null}; };
  const out = {kind, stateId, before: rec('before')};
  b.addState(stateId); b.refresh(); upd(1);
  out.after = rec('after add');
  // 记录播放过程：每帧 duration 和 setup 次数
  const s = sp._stateAniSprite; let setups = 0, starts = [];
  if (s) { const orig = s.setup.bind(s); s.setup = function () { setups++; starts.push(frames.length); return orig.apply(this, arguments); }; }
  for (let i = 0; i < 400; i++) { upd(1); frames.push(s ? s._duration : null); }
  out.setups = setups; out.restartAt = starts; out.durationSample = frames.slice(0, 40); out.parent = s && s.parent ? s.parent === sp.parent : null;
  out.rate = s ? s._rate : null; out.mirror = s ? s._mirror : null; out.targetIsMain = s && s._target ? (s._target === sp._mainSprite ? 'main' : (s._target === sp ? 'root' : 'other')) : null;
  b.removeState(stateId); b.refresh(); upd(2);
  out.afterRemove = rec('after remove');
  return out;
}
cases.push(makeCase('loop', {}, () => {
  newGame();
  const ids = w.$dataStates.filter(s => s && s.stateAnimationId).map(s => s.id);
  const out = [];
  for (const id of ids) for (const kind of ['actor', 'enemy']) { try { out.push(loopRun(kind, id)); } catch (e) { out.push({kind, stateId: id, error: String(e.stack).slice(0, 400)}); } }
  return out;
}));
// 优先级：多个状态同时有动画时取 states() 顺序里第一个
cases.push(makeCase('order', {}, () => {
  battle();
  const withAni = w.$dataStates.filter(s => s && s.stateAnimationId);
  const b = w.$gameActors.actor(1);
  const out = {states: withAni.map(s => s.id)};
  if (withAni.length >= 2) { for (const s of withAni) b.addState(s.id); out.picked = b.stateAnimationId(); out.order = b.states().map(s => s.id); }
  return out;
}));
process.exit(finish(host, 'vsfx.json', {scope: 'YEP_X_VisualStateFX state animation loop on frozen source', cases}) ? 0 : 1);
