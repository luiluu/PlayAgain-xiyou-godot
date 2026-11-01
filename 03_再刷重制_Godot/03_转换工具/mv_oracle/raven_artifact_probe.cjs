'use strict';
// 【cc·悟空·未经审查】渡鸦 167 专属法宝冥河断罪镰 4001（js/codex/runtime/installNativeRavenRuntime.js；js/plugins/Codex_Raven.js 不在 plugins.js，没启用）：
// ① module：R.ARTIFACT_LEVEL_GROWTH、R.ARTIFACT_BASE_BONUS、R.artifactMaxLevel()，原型与招募给的独立法宝的 paramPlusPerLevel／maxLevel／
//    level／<Max Level> 备注（installArtifactMagicWeaponFields 盖掉备注里的每级成长，上限取 CP_MagicWeapon 参数）。
// ② params.*：渡鸦（等级、进阶 rank、灵魂 soul）装上法宝、法宝等级 L 时 paramPlus(0..7) 与 param(0..7)，同条件不装时的同两项；
//    Game_Actor.paramPlus 包装：装着 4001 加固定 ARTIFACT_BASE_BONUS，魔攻另加 artifactMagicAttackBonus（⌊阶×50＋魂×(0.02＋阶×0.006)⌋），
//    生命另加 artifactHpBonus（⌊阶×400＋魂×(0.04＋阶×0.008)⌋）；CP_MagicWeapon 每级成长＝等级×paramPlusPerLevel。
// 真实新局、Math.random 0.5，只在内存；产物 .sandbox/raven_artifact.json（generated/oracle/raven_artifact.json，tests/xiyou_raven_artifact.gd 读）。
const {start, makeCase, finish, round} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const R = w.CodexRaven;
if (!R || !R.ARTIFACT_LEVEL_GROWTH) throw new Error('渡鸦模块未安装');
const ACTOR = 167, ARTIFACT = 4001, SWITCH = 2494;
const J = o => w.JSON.parse(w.JSON.stringify(o));
// 量能力值前清 krz_state_re 的缓存（同 magic_weapon_level_probe）
function clearParamCache(a) {
  a._cacheBaseParam = {}; a._baseParamCache = []; a._ParamCache2 = []; a._xparamCache2 = []; a._sparamCache2 = []; a._cacheParamBuffRate = {};
  a.need_refresh_param = [1,1,1,1,1,1,1,1]; a.need_refresh_xparam = [1,1,1,1,1,1,1,1,1,1]; a.need_refresh_sparam = [1,1,1,1,1,1,1,1,1,1]; a.need_refresh = true; a.refresh();
}
// 新局、挑战开关、队伍 [167, 1]、渡鸦等级／进阶／灵魂；招募给的那件法宝（背包里的独立装备）
function setup(level, rank, soul) {
  newGame();
  w.eval('$gameParty.ActorMaxLevel = 99; $dataActors.forEach(function(x){ if (x) x.maxLevel = 99; });');
  w.$gameSwitches.setValue(SWITCH, true);
  w.eval('$gameParty._actors=[]; $gameParty._battleMembers=[0,0,0,0,0];');
  w.$gameParty.addActor(1);
  const before = w.$gameParty.equipItems().slice();
  R.recruit();
  const a = w.$gameActors.actor(ACTOR);
  a._AdvancedNum = rank; a._codexRavenStage = rank;
  a.changeLevel(level, false);
  a._codexRavenSoul = soul;
  const item = w.$gameParty.equipItems().find(x => before.indexOf(x) < 0 && (x.baseItemId === ARTIFACT || x.id === ARTIFACT));
  if (!item) throw new Error('招募没给法宝');
  return {a, item};
}
function read(a) {
  clearParamCache(a);
  const plus = [], param = [];
  for (let i = 0; i < 8; i++) { plus.push(round(a.paramPlus(i))); param.push(round(a.param(i))); }
  return {plus, param};
}
const cases = [];
cases.push(makeCase('module', {}, () => {
  const {item} = setup(1, 0, 0);
  const proto = w.$dataArmors[ARTIFACT];
  const rec = o => ({paramPlusPerLevel: J(o.paramPlusPerLevel), maxLevel: o.maxLevel, level: o.level, initLevel: o.initLevel,
    metaMaxLevel: String(o.meta['Max Level']), params: J(o.params), etypeId: o.etypeId});
  return {growth: J(R.ARTIFACT_LEVEL_GROWTH), base: J(R.ARTIFACT_BASE_BONUS), maxLevel: R.artifactMaxLevel(),
    proto: rec(proto), instance: rec(item), independent: item !== proto};
}));
for (const [level, rank, soul, lv] of [[1, 0, 0, 1], [30, 0, 500, 1], [45, 2, 20000, 10], [60, 3, 123457, 37], [99, 5, 300000, 888]]) {
  cases.push(makeCase(`params.l${level}.r${rank}.s${soul}.m${lv}`, {level, rank, soul, artifactLevel: lv}, () => {
    const {a, item} = setup(level, rank, soul);
    const bare = read(a);
    const slot = a.equipSlots().indexOf(item.etypeId);
    if (slot < 0) throw new Error('渡鸦没有法宝槽');
    item.level = lv;
    a.forceChangeEquip(slot, item);
    if (a.equips()[slot] !== item) throw new Error('没装上法宝');
    const worn = read(a);
    return {slot, itemLevel: item.level, bare, worn,
      matBonus: round(R.artifactMagicAttackBonus(a)), hpBonus: round(R.artifactHpBonus(a))};
  }));
}
process.exit(finish(host, 'raven_artifact.json', {hostScope: '正式 installNativeRavenRuntime（法宝字段、Game_Actor.paramPlus 包装）＋CP_MagicWeapon 每级成长', cases}) ? 0 : 1);
