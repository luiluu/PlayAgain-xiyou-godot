'use strict';
// book_capacity_ui 夹具组装（tools CR，2026-11-06 补）：tests/fixtures/book_capacity_ui_oracle.json 原是把 review_book_capacity.cjs（隔离 Chrome 原版两页）
// 的 capacity_0_actor／capacity_1_limit 两页手工拼上来源身份与 33 个相关文件指纹。用法（同一个 XIYOU_APP）：
//   node review_book_capacity.cjs <输出目录>    然后    node book_capacity_ui_fixture.cjs <输出目录>
// 写 <输出目录>/book_capacity_ui_oracle.json，拷成 tests/fixtures/book_capacity_ui_oracle.json（不接入全量同步）。
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const {sourceIdentity} = require('../mv_oracle/source_identity.cjs');
const dir = path.resolve(process.argv[2] || '.');
const app = process.env.XIYOU_APP ? path.resolve(process.env.XIYOU_APP) : path.resolve(__dirname, '../../02_内容与素材/冻结正式源/app.nw');
const FILES = ["js/plugins/HelpExtend.js", "js/plugins/AXY_Toast.js", "fonts/FZLanTYJW_ZhongCu.TTF", "js/codex/runtime/installItemBagContinuationRuntime.js", "index.html", "js/plugins.js", "js/rpg_scenes.js", "js/rpg_windows.js", "js/rpg_\u03bfbjects.js", "js/plugins/hc.js", "js/plugins/CP_MagicWeapon.js", "js/plugins/Star_PetSystem.js", "js/plugins/Star_PetUpLevel.js", "js/plugins/Star_PetSynthesis.js", "js/codex/runtime/installNativeHonghuangRuntime.js", "js/codex/runtime/installNativeRaceRuntime.js", "js/codex/runtime/installNativeYunshangRuntime.js", "js/codex/runtime/installNativeBindingChargeRuntime.js", "js/codex/runtime/installAlienationWorkshop.js", "js/codex/runtime/installAlienationAffixes.js", "js/codex/runtime/installGamePanelTheme.js", "js/codex/runtime/installCombatPowerRuntime.js", "js/plugins/AB_EnemyBook.js", "js/plugins/Star_EquipInlayBook.js", "js/plugins/Star_EquipmentMosaic.js", "js/plugins/PH_Warehouse.js", "js/plugins/Star_ActorWarehouse.js", "js/plugins/Star_ChangeClothes.js", "js/plugins/Star_ActorAdvanced.js", "js/codex/runtime/installNativeEconomyRuntime.js", "js/codex/runtime/installUnifiedQualityRuntime.js", "js/plugins/EliteEnemy.js", "js/plugins/EnemyNameColorByDifficulty.js"];
const run = JSON.parse(fs.readFileSync(path.join(dir, 'run.json'), 'utf8'));
if (run.errors.length || Object.values(run.pages).some(p => p.errors.length)) throw new Error('取样有错误，先看 run.json');
const pages = {};
for (const name of ['capacity_0_actor', 'capacity_1_limit']) pages[name] = JSON.parse(fs.readFileSync(path.join(dir, name + '.json'), 'utf8'));
const sourceFingerprints = Object.fromEntries(FILES.map(f => [f, crypto.createHash('sha256').update(fs.readFileSync(path.join(app, f))).digest('hex')]));
const out = {schemaVersion: 1, sourceIdentity: sourceIdentity(app), sourceFingerprints, pages};
fs.writeFileSync(path.join(dir, 'book_capacity_ui_oracle.json'), JSON.stringify(out, null, 1) + '\n');
console.log(JSON.stringify({file: path.join(dir, 'book_capacity_ui_oracle.json'), pages: Object.keys(pages)}));
