'use strict';
// 【cc·八戒·未经审查】成长装备期二：利维坦锻造（installNativeLeviathanForge）与杰作无我锻造（installNativeHubrisRuntime 的 forge 段）。
// ① 锻造锤 H.awardCore（Map176、来源 108／165、敌群 570～575、20%、每场一次；没记来源按变量 107）；
// ② 解锁 H／U.unlockForge：第一次拥有心钢／狂妄实例时设标记、学配方 457／458；失去后仍在；重置配方后补学；旧档读档补设；
// ③ canForge 各条件、配方的 getMaterialCount／craftable／amountCraftable；④ forge：同一实例改成杰作（底子、属性差、名字、图标、说明、元数据），
// 层数／盛名保留，材料扣 200 碎片＋5 锻造锤，穿着的角色刷新（最大生命、技能）。
// 参照引擎没有自动建配方（hc.js 用 XMLHttpRequest 读 Recipes.txt），这里照它读一次 data/Recipes.txt 再建。
// 产物 .sandbox/growth_forge.json，拷成 tests/fixtures/growth_forge_oracle.json（不进同步），专项 xiyou_growth_forge。
const fs = require('fs'), path = require('path');
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame} = host;
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const H = w.CodexHeartsteel, U = w.CodexHubris;
if (!H || !U || !H.awardCore || !U.forge) throw new Error('利维坦锻造／杰作无我锻造模块未安装');
if (!w.$) w.$ = {};
const toasts = [];
w.$.toaster = o => toasts.push(o && o.message);
w.DataManager.createRecipes(fs.readFileSync(path.join(APP, 'data/Recipes.txt'), 'utf8'));
const R = id => w.$gameRecipes[id];
const fresh = () => { newGame(); w.$gameParty.resetKnownRecipes(); toasts.length = 0; };
const count = id => w.$gameParty.armors().filter(x => x.baseItemId === id).length;
const gear = (base, fields) => {
  w.$gameParty.gainItem(w.$dataArmors[base], 1, false);
  const list = w.$gameParty.armors().filter(x => x.baseItemId === base);
  return Object.assign(list[list.length - 1], fields || {});
};
const equip = (a, it) => { a.changeEquip(a.equipSlots().indexOf(it.etypeId), it); a.need_refresh = true; a.refresh(); };
const flags = () => ({unlocked: [!!w.$gameParty._codexLeviathanUnlocked, !!w.$gameParty._codexAtaraxiaUnlocked],
  recipes: [!!w.$gameParty.recipeKnown(457), !!w.$gameParty.recipeKnown(458)]});
const pos = note => (String(note).match(/<pos=APs text=\\c\[1\][^>]*?size=/g) || []);
const snap = it => ({base: it.baseItemId, orig: it.originalBaseItemId, name: it.name, baseName: it.baseItemName, icon: it.iconIndex,
  description: it.description, params: it.params.slice(), metaKeys: Object.keys(it.meta).filter(k => /^Codex/.test(k)).sort(),
  tags: ['<CodexHeartsteel>', '<CodexLeviathan>', '<CodexHubris>', '<CodexAtaraxia>'].filter(t => it.note.includes(t)), pos: pos(it.note),
  stacks: it._codexHeartsteelStacks, hp: it._codexHeartsteelHp, fame: it._codexHubrisFame});
const SKILLS = [10227, 10228];
const cases = [];

// ① 锻造锤：结果、地图、来源（null 时按变量 107）、敌群、随机数
const CORE = [[0, 176, 165, 0, 570, 0.1], [0, 176, 165, 0, 575, 0.1999], [0, 176, 165, 0, 573, 0.2], [0, 176, 108, 0, 572, 0.1],
  [0, 176, 164, 0, 570, 0.1], [0, 176, null, 1, 570, 0.1], [0, 176, null, 2, 571, 0.1], [0, 176, null, 3, 574, 0.1], [0, 176, null, 0, 570, 0.1],
  [0, 152, 165, 0, 570, 0.1], [0, 176, 165, 0, 569, 0.1], [0, 176, 165, 0, 576, 0.1], [1, 176, 165, 0, 570, 0.1], [2, 176, 165, 0, 570, 0.1]];
for (const [result, map, origin, v107, troop, r] of CORE) {
  cases.push(makeCase(`core.${result}.${map}.${origin}.${v107}.${troop}.${r}`, {result, map, origin, v107, troop, r}, () => {
    fresh();
    w.$gameMap._mapId = map;
    if (origin == null) delete w.$gameMap._codexLeviathanUnknownOrigin; else w.$gameMap._codexLeviathanUnknownOrigin = origin;
    w.$gameVariables.setValue(107, v107);
    w.$gameTroop._troopId = troop;
    w.BattleManager._codexLeviathanCoreRolled = false;
    let draws = 0;
    w.Math.random = () => { draws++; return r; };
    const got = H.awardCore(result), again = H.awardCore(result);
    w.Math.random = () => 0.5;
    return {origin: H.unknownCoreOrigin(), got, again, draws, hammers: w.$gameParty.numItems(w.$dataItems[2867]), toasts: toasts.slice()};
  }));
}

// ② 解锁
cases.push(makeCase('unlock.flow', {}, () => {
  fresh();
  const steps = [['new', flags()]];
  w.$gameParty.gainItem(w.$dataItems[2867], 3, false);
  steps.push(['hammer', flags()]);
  const heart = gear(7900);
  steps.push(['heart', flags(), toasts.slice()]);
  gear(7900);
  steps.push(['heart2', flags(), toasts.slice()]);
  const hub = gear(7902);
  steps.push(['hubris', flags(), toasts.slice()]);
  w.$gameParty.loseItem(heart, 1, false); w.$gameParty.loseItem(hub, 1, false);
  w.$gameParty.armors().filter(x => H.isGear(x) || U.isGear(x)).forEach(x => w.$gameParty.loseItem(x, 1, false));
  steps.push(['lost', flags(), count(7900) + count(7902)]);
  w.$gameParty.resetKnownRecipes();
  steps.push(['reset', flags()]);
  w.$gameParty.forgetRecipe(457); w.$gameParty.forgetRecipe(458);
  steps.push(['forget', flags()]);
  w.$gameParty.resetKnownRecipes();
  steps.push(['reset2', flags()]);
  return {steps};
}));
// 直接得到杰作（7901／7903）也算拥有
for (const base of [7901, 7903]) cases.push(makeCase(`unlock.master.${base}`, {base}, () => { fresh(); gear(base); return {flags: flags(), toasts: toasts.slice()}; }));
// 旧档：背包或穿着有实例、没有标记与配方，读档后（Leviathan 靠 createRecipes 时的 bindRecipe，狂妄靠 extractSaveContents）
for (const where of ['bag', 'worn']) for (const base of [7900, 7902]) cases.push(makeCase(`unlock.load.${where}.${base}`, {where, base}, () => {
  fresh();
  const it = gear(base);
  if (where === 'worn') equip(w.$gameActors.actor(1), it);
  delete w.$gameParty._codexLeviathanUnlocked; delete w.$gameParty._codexAtaraxiaUnlocked;
  w.$gameParty.forgetRecipe(457); w.$gameParty.forgetRecipe(458);
  const before = flags(), json = host.encode();
  host.restore(json);
  const afterLoad = flags();
  // hc.js 每次 createGameObjects 都重读 Recipes.txt 建新配方（新对象未绑定，bindRecipe 会再跑一次）
  w.DataManager.createRecipes(fs.readFileSync(path.join(APP, 'data/Recipes.txt'), 'utf8'));
  return {before, afterLoad, afterRecipes: flags(), bound: [!!R(457)._codexLeviathanBound, !!R(458)._codexAtaraxiaBound]};
}));

// ③ canForge 与配方：kind 0＝心钢（457）、1＝狂妄（458）
const KINDS = [{H, base: 7900, master: 7901, recipe: 457, unlock: '_codexLeviathanUnlocked', grow: '_codexHeartsteelStacks'},
  {H: U, base: 7902, master: 7903, recipe: 458, unlock: '_codexAtaraxiaUnlocked', grow: '_codexHubrisFame'}];
const CONDS = ['ok', 'frag199', 'hammer4', 'locked', 'battle', 'master', 'stranger', 'worn', 'none'];
for (let k = 0; k < 2; k++) for (const cond of CONDS) cases.push(makeCase(`can.${k}.${cond}`, {kind: k, cond}, () => {
  fresh();
  const K = KINDS[k], M = K.H;
  w.$gameParty.gainItem(w.$dataItems[2530], cond === 'frag199' ? 199 : 200, false);
  w.$gameParty.gainItem(w.$dataItems[2867], cond === 'hammer4' ? 4 : 5, false);
  let src = cond === 'none' ? null : gear(cond === 'master' ? K.master : K.base);
  if (cond === 'master') w.$gameParty[K.unlock] = true;
  if (cond === 'stranger') src = w.JsonEx.makeDeepCopy(src);
  if (cond === 'worn') equip(w.$gameActors.actor(1), src);
  if (cond === 'locked') { delete w.$gameParty[K.unlock]; w.$gameParty.forgetRecipe(K.recipe); }
  if (cond === 'battle') w.$gameParty._inBattle = true;
  const r = R(K.recipe);
  const out = {can: M.canForge(src), sources: M.forgeSources().length, material: r.getMaterialCount(r._materials[0]),
    hasMaterials: r.hasMaterials(), craftable: r.craftable(), amount: r.amountCraftable(), known: !!w.$gameParty.recipeKnown(K.recipe)};
  w.$gameParty._inBattle = false;
  return out;
}));

// ④ forge：背包里的／穿着的；带层数与旧版生命
for (let k = 0; k < 2; k++) for (const where of ['bag', 'worn']) cases.push(makeCase(`forge.${k}.${where}`, {kind: k, where}, () => {
  fresh();
  const K = KINDS[k], M = K.H, a = w.$gameActors.actor(1);
  w.$gameParty.gainItem(w.$dataItems[2530], 230, false);
  w.$gameParty.gainItem(w.$dataItems[2867], 7, false);
  const src = gear(K.base, k === 0 ? {_codexHeartsteelStacks: 350, _codexHeartsteelHp: 7} : {_codexHubrisFame: 420});
  const other = gear(K.base);
  if (where === 'worn') equip(a, src);
  const before = snap(src), actorBefore = {mhp: a.mhp, atk: a.atk, def: a.def, mdf: a.mdf, skills: a.skills().map(s => s.id).filter(id => SKILLS.includes(id))};
  const view = snap(M.previewForge(src)), unchanged = JSON.stringify(snap(src)) === JSON.stringify(before);
  const detail = M.forgeDetailLines(src), help = [M.forgeHelpText(src, true, false), M.forgeHelpText(src, true, true), M.forgeHelpText(src, false, false), M.forgeHelpText(null, false, false)];
  const r = R(K.recipe);
  M._forgeSource = src;
  const out = r.craft();
  return {before, view, unchanged, same: out === src, after: snap(src), detail, help, emptyDetail: M.forgeDetailLines(null),
    materials: [w.$gameParty.numItems(w.$dataItems[2530]), w.$gameParty.numItems(w.$dataItems[2867])],
    counts: [count(K.base), count(K.master)], otherBase: other.baseItemId, armorsLen: w.$gameParty.armors().length,
    actor: {mhp: a.mhp, atk: a.atk, def: a.def, mdf: a.mdf, skills: a.skills().map(s => s.id).filter(id => SKILLS.includes(id))}, actorBefore,
    canAgain: M.canForge(src), canOther: M.canForge(other), craftableAfter: r.craftable(), materialAfter: r.getMaterialCount(r._materials[0])};
}));
// 锻造失败（不能锻造时 craft 返回 null，什么都不扣）
cases.push(makeCase('forge.refuse', {}, () => {
  fresh();
  w.$gameParty.gainItem(w.$dataItems[2530], 200, false);
  w.$gameParty.gainItem(w.$dataItems[2867], 4, false);
  const src = gear(7900);
  H._forgeSource = src;
  const out = R(457).craft();
  return {out: out === null, base: src.baseItemId, materials: [w.$gameParty.numItems(w.$dataItems[2530]), w.$gameParty.numItems(w.$dataItems[2867])]};
}));

finish(host, 'growth_forge.json', {cases});
process.exit(0);
