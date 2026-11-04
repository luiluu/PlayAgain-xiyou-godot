'use strict';
// YEP_X_AnimatedSVEnemies 画面规则参照（bailong-visual1）：影子、呼吸、倒下、武器图／攻击动作。
// 用真实 Game_Enemy／Sprite_Enemy 量：census＝每个敌人的有效字段；breath＝Sprite_Enemy.update 的缩放时序；
// collapse＝倒下后 sprite 的透明度时序（MOG_CollapseEffects 默认死亡效果 0 会接管 updateCollapse）；weapon＝performAttack 的武器图／动作／动画。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
w.eval('CodexZones.ENABLED=false;');
function battle() {
  if (w.$gameParty) w.$gameParty._inBattle = false;
  newGame(); w.eval('$gameParty._actors=[];'); w.$gameParty.addActor(1);
  w.$dataMap = {displayName: '', events: [], data: [], width: 1, height: 1, note: '', meta: {}, encounterList: [], tilesetId: 1};
  w.BattleManager.setup(2, true, true);
}
function spriteOf(id) {
  const en = new w.Game_Enemy(id, 300, 300);
  const a = new w.Sprite(), b = new w.Sprite(), sp = new w.Sprite_Enemy(en);
  a.addChild(b); b.addChild(sp);
  return {en, sp};
}
const cases = [];
const hasSV = e => !!(e && e.sideviewBattler && e.sideviewBattler.length);
cases.push(makeCase('census', {}, () => {
  battle();
  const P = w.Yanfly.Param;
  const params = {collapse: P.SVECollapse, shadow: P.SVEShowShadow, breathing: P.SVEBreathing, speed: P.SVEBreathSpeed, rx: P.SVEBreathXRate, ry: P.SVEBreathYRate,
    link: P.SVELinkBreathing, attackMotion: P.SVEAttackMotion, weaponIndex: P.SVEWeaponIndex, mogDefault: w.Moghunter.collDefaultCollapse};
  const rows = [];
  let total = 0;
  for (const e of w.$dataEnemies) {
    if (!e) continue;
    total++;
    rows.push({id: e.id, sv: hasSV(e) ? 1 : 0, shadow: e.sideviewShadowShow ? 1 : 0, breath: e.sideviewBreathing ? 1 : 0, speed: e.sideviewBreathSpeed,
      rx: e.sideviewBreathXRate, ry: e.sideviewBreathYRate, link: e.sideviewLinkBreathing ? 1 : 0, collapse: e.sideviewCollapse ? 1 : 0,
      weapons: e.sideviewWeaponImage, attackMotion: e.sideviewAttackMotion, swx: e.spriteScaleX, swy: e.spriteScaleY,
      shW: e.sideviewShadowScaleX, shH: e.sideviewShadowScaleY, svw: e.sideviewWidth, svh: e.sideviewHeight, frameSpeed: e.sideviewFrameSpeed,
      name: e.sideviewBattler, idle: e.sideviewIdleMotion});
  }
  return {total, params, rows};
}));
// 呼吸：Sprite_Enemy.update 的 scale 时序（svRand 固定为 0，Graphics.frameCount 手动推进）
cases.push(makeCase('breath', {}, () => {
  battle();
  const pick = f => w.$dataEnemies.find(e => e && f(e));
  const picks = {sv: pick(e => hasSV(e)), nonSvDefault: pick(e => !hasSV(e) && e.sideviewBreathSpeed === 20), nonSvTag: pick(e => !hasSV(e) && e.sideviewBreathSpeed !== 20)};
  const out = {};
  for (const [k, e] of Object.entries(picks)) {
    if (!e) { out[k] = null; continue; }
    const {en, sp} = spriteOf(e.id);
    sp._svRand = 0;
    const frames = [];
    for (let f = 0; f < 150; f++) {
      w.Graphics.frameCount = f; sp.update();
      if (f % 5 === 0) frames.push([f, +sp.scale.x.toFixed(5), +sp.scale.y.toFixed(5)]);
    }
    out[k] = {id: e.id, isBreathing: en.isBreathing(), speed: en.breathingSpeed(), rx: en.breathXRate(), ry: en.breathYRate(), link: en.linkBreathing(), spriteScaleX: en.spriteScaleX(), spriteScaleY: en.spriteScaleY(), frames};
  }
  return out;
}));
// 倒下：SV 无 collapse 标签的敌人与普通敌人的透明度时序（MOG_CollapseEffects 接管后两者一样）
cases.push(makeCase('collapse', {}, () => {
  battle();
  const svId = w.$dataEnemies.find(e => e && hasSV(e) && !e.sideviewCollapse).id, plainId = w.$dataEnemies.find(e => e && !hasSV(e)).id;
  const out = {};
  for (const [k, id] of [['sv', svId], ['plain', plainId]]) {
    const {en, sp} = spriteOf(id);
    for (let i = 0; i < 30; i++) sp.update();
    en.setHp(0); en.performCollapse();
    const line = [];
    for (let i = 0; i < 200; i++) { sp.update(); if (i % 10 === 0 || i === 199) line.push([i, Math.round(sp.opacity), sp._effectType, sp._effectDuration]); }
    out[k] = {id, svEnabled: !!sp._svBattlerEnabled, collapseData: en._collpaseData.slice(), isSideviewCollapse: sp.isSideviewCollapse(), line};
  }
  out.svCollapseTrueCount = w.$dataEnemies.filter(e => e && hasSV(e) && e.sideviewCollapse).length;
  return out;
}));
// 武器图／攻击动作：performAttack 之后的读数（每个 SV 敌人；多条武器标签时随机，列出全部候选）
cases.push(makeCase('weapon', {}, () => {
  battle();
  const out = [];
  for (const e of w.$dataEnemies) {
    if (!hasSV(e)) continue;
    const en = new w.Game_Enemy(e.id, 0, 0);
    en.performAttack();
    out.push({id: e.id, weaponImageId: en.weaponImageId(), motion: en.attackMotion(), anim: en.attackAnimationId(), entries: e.sideviewWeaponImage.length});
  }
  return out;
}));
process.exit(finish(host, 'sve.json', {scope: 'YEP_X_AnimatedSVEnemies shadow/breathing/collapse/weapon visuals on frozen source', cases}) ? 0 : 1);
