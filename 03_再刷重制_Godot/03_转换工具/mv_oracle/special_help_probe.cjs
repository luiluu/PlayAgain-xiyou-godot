'use strict';
// 特殊角色说明卡探针：特殊角色（渡鸦 167～哈基米 178）的技能与专属装备（心之钢、狂妄等）在正式版里的说明卡。
// 这些技能的说明不在数据库描述里，而是 installDisplayPreferencesRuntime 的 characterHelpView 按 characterHelpCopies
// 表与角色当前状态现编；本探针在内存新游戏里、不招募这些角色（图鉴预览态：初始等级、未学会、0 阶），对每个技能与
// 专属装备调用 Sprite_ItemHelp.setItem，记录实际画出的每一行 [文字, 字号, 颜色, y, 对齐] 与卡片宽高，
// 与 help_probe.cjs 同格式。另记各角色的图鉴技能表（CodexActorBookSkills）。只写 .sandbox/special_help_cards.json。
const fs = require('fs'), path = require('path');
const {boot} = require('./hboot.cjs');
const {sourceIdentity} = require('./source_identity.cjs');
const APP = process.env.XIYOU_APP || '/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const OUT = path.resolve(__dirname, '.sandbox');
const ACTORS = [167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178];
const identity = sourceIdentity(APP);
const r = boot(APP, {tolerant: true, log: false});
const w = r.window;
if (r.errors.length || w.CodexRuntime.status().some(m => m.state !== 'installed') || !w.DataManager.isDatabaseLoaded()) throw new Error('参照引擎启动失败');
w.eval('ConfigManager.applyData({}); DataManager.setupNewGame(); $gameSystem.setDifficultyId(3);');
const SW = w.RJO.SW;
let size = 0, color = '', rows = null;
const cs = SW.changeTextSize; SW.changeTextSize = function (s) { size = s; return cs.apply(this, arguments); };
const cc = SW.changeTextColor; SW.changeTextColor = function (c) { color = c; return cc.apply(this, arguments); };
const dc = SW.drawContentText;
SW.drawContentText = function (text, x, y, width, align) {
  if (rows) rows.push([String(text), Number(size), String(color), Number(y), align === undefined || align === null || align === '' ? null : Number(align)]);
  return dc.apply(this, arguments);
};
// 有的角色模块画说明时会顺手 $gameActors.actor(id) 建出角色；每张卡前都删掉，保证张张都是预览态、互不影响
function card(item) {
  for (const id of ACTORS) delete w.$gameActors._data[id];
  rows = [];
  const h = new w.Sprite_ItemHelp(w.RJO.HE.ItemDescWidth);
  h.setItem(item);
  const out = {width: h.width, height: h.visible ? h.height : 0, quality: Number((item.meta && item.meta.quality) || 0), rows};
  rows = null;
  return out;
}
// 图鉴技能表要一个 Game_Actor；取完把这些角色全部从 $gameActors 删掉（渡鸦等新游戏时就已建好），
// 说明卡一律按未招募的预览态现编（characterHelpActor 的 _characterHelpPreview 分支：初始等级、未学会、0 阶）
const book = {};
for (const id of ACTORS) {
  if (!w.$dataActors[id] || !w.$dataActors[id].name) continue;
  const had = !!w.$gameActors._data[id];
  const a = w.$gameActors.actor(id);
  book[id] = {name: a.name(), classId: a._classId, initialLevel: w.$dataActors[id].initialLevel, existedAtNewGame: had,
    skills: w.CodexActorBookSkills(a).map(s => s.id)};
  delete w.$gameActors._data[id];
}
const out = {sourceIdentity: identity, releaseVersion: identity.releaseVersion, state: 'preview', actors: book, skills: [], weapons: [], armors: []};
const skillIds = new Set();
for (let id = 10122; id <= 10299; id++) if (w.$dataSkills[id] && String(w.$dataSkills[id].name || '').trim()) skillIds.add(id);
for (const id of ACTORS) for (const s of (book[id] || {skills: []}).skills) skillIds.add(s);
for (const id of [...skillIds].sort((a, b) => a - b)) out.skills.push({id, name: w.$dataSkills[id].name, ...card(w.$dataSkills[id])});
// 专属装备：带 Codex 专属标签（<CodexHeartsteel> 心之钢、<CodexHubris> 狂妄……）或 characterHelpTarget 认的装备号
const GEAR_IDS = new Set([4001, 4577, 4578, 4579, 4580, 4581, 7904, 7905, 7906, 7908, 7909, 7910, 7911]);
for (let id = 7920; id <= 7935; id++) GEAR_IDS.add(id);
const TAG = /<Codex(?:RavenArtifact|Tusu|Xuan|Heartsteel|Leviathan|Hubris|Ataraxia|DemonCrown|Cat)\b/;
for (const [field, table] of [['weapons', w.$dataWeapons], ['armors', w.$dataArmors]]) {
  for (const it of table) {
    if (!it || !String(it.name || '').trim()) continue;
    if (!GEAR_IDS.has(it.id) && !TAG.test(String(it.note || ''))) continue;
    out[field].push({id: it.id, name: it.name, ...card(it)});
  }
}
if (JSON.stringify(identity) !== JSON.stringify(sourceIdentity(APP))) throw new Error('测量期间来源改变');
fs.mkdirSync(OUT, {recursive: true});
fs.writeFileSync(path.join(OUT, 'special_help_cards.json'), JSON.stringify(out));
console.log(JSON.stringify({actors: Object.keys(book).length, skills: out.skills.length, weapons: out.weapons.length, armors: out.armors.length}));
process.exit(0);
