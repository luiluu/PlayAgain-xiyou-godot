'use strict';
// 【cc·悟空·未经审查】CodexQualityIcons.lookup（installNativeYomiJingliuRuntime）与 Codex_GuyuSukunaIconArt、谷雨图标条：
// 全库超出 IconSet 网格（≥6400）的图标号，原版取哪张图的第几格、哪个品质色。云裳、屠苏璇、小猫、魔冠各有专项，这里略过。
// 产物 .sandbox/quality_icons.json，拷成 tests/fixtures/quality_icons_oracle.json（不进同步），专项 xiyou_quality_icons。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w} = host;
const Q = w.CodexQualityIcons, A = w.CodexGuyuSukunaIconArt;
if (!Q) throw new Error('模块未装');
if (A) A.install();
const color = i => { const it = i.item; return it ? w.RJO.IQ.QualitiesColor[Number(it.meta.quality) || 0] : undefined; };
const cases = [makeCase('lookup', {}, () => {
  const rows = {};
  for (const list of [w.$dataSkills, w.$dataItems, w.$dataWeapons, w.$dataArmors, w.$dataStates]) for (const it of list) {
    const k = it && it.iconIndex;
    if (!k || k < 6400 || rows[k] || (k >= 130270 && k <= 130287) || (k >= 210000 && k < 220000) || (k >= 240000 && k < 280009) || k === 290000) continue;
    if (k >= 220000 && k < 220016) { rows[k] = {image: 'Guyu_Icons', source: k - 220000}; continue; }
    const i = Q.lookup(k);
    if (!i) continue;
    const row = {image: i.image || 'IconSet', source: i.source === undefined ? -1 : i.source};
    if (i.item && i.source !== undefined && !i.guyuSukunaArt) row.color = color(i);
    rows[k] = row;
  }
  return {rows};
})];
process.exit(finish(host, 'quality_icons.json', {hostScope: '启动后的图标查表', cases}) ? 0 : 1);
