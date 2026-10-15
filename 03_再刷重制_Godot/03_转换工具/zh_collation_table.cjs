'use strict';
// 中文拼音排序表：正式版装备排序用 String.localeCompare(…, 'zh-Hans')（Chromium ICU 的 pinyin 排序），
// Godot 没有 ICU 排序，这里用 Node 的 Intl.Collator('zh-Hans') 把字符排成「一级权重」名次表，
// 写到 01_Godot工程/modes/xiyou/zh_collation.json，由 XZhCollation 逐字比较名次。
// 字符集：CJK 基本区 U+4E00～9FFF、ASCII 可见字符、冻结正式源 data/*.json 里出现过的全部字符。
// 只读冻结正式源；输出只写上述一个文件。用法：node zh_collation_table.cjs [--check]（--check 只核对不写）。
// 生成后自检：正式源全部物品/武器/防具名字（Codex text() 清理后）按本表排序须与 Intl.Collator 完全一致。
const fs = require('fs'), path = require('path');
const APP = process.env.XIYOU_APP || path.resolve(__dirname, '../02_内容与素材/冻结正式源/app.nw');
const OUT = path.resolve(__dirname, '../01_Godot工程/modes/xiyou/zh_collation.json');
const check = process.argv.includes('--check');

const full = new Intl.Collator('zh-Hans');
const base = new Intl.Collator('zh-Hans', {sensitivity: 'base'});
if (full.resolvedOptions().collation !== 'pinyin') throw new Error('Node 的 ICU 没有 zh-Hans pinyin 排序（需要 full-icu）');

const chars = new Set();
for (let c = 0x20; c < 0x7f; c++) chars.add(String.fromCharCode(c));
for (let c = 0x4e00; c <= 0x9fff; c++) chars.add(String.fromCharCode(c));
const dataDir = path.join(APP, 'data');
const names = [];
function walk(v, inName) {
  if (typeof v === 'string') { for (const ch of v) chars.add(ch); if (inName) names.push(v); }
  else if (Array.isArray(v)) v.forEach(x => walk(x, false));
  else if (v && typeof v === 'object') for (const k of Object.keys(v)) walk(v[k], k === 'name');
}
for (const f of fs.readdirSync(dataDir).filter(f => f.endsWith('.json')).sort()) {
  const data = JSON.parse(fs.readFileSync(path.join(dataDir, f), 'utf8'));
  if (['Items.json', 'Weapons.json', 'Armors.json'].includes(f)) data.forEach(r => { if (r) { walk(r, false); if (r.name) names.push(r.name); } });
  else walk(data, false);
}
// 按码位排（Godot 字符串按码位取字；表情等代理对也是一个字）
const list = [...chars].filter(ch => [...ch].length === 1 && ch !== '\n');
const ignorable = list.filter(ch => base.compare(ch, '') === 0).sort();
const ordered = list.filter(ch => base.compare(ch, '') !== 0).sort((a, b) => full.compare(a, b) || (a < b ? -1 : a > b ? 1 : 0));
const groups = [];
for (const ch of ordered) {
  const g = groups[groups.length - 1];
  if (g && base.compare(g[0], ch) === 0) g.push(ch); else groups.push([ch]);
}
const table = {
  note: '中文拼音排序表（zh_collation_table.cjs 生成，勿手改）：order 按换行分组，组号即一级权重名次；ignorable 为排序时跳过的字符。',
  icu: process.versions.icu, cldr: process.versions.cldr, unicode: process.versions.unicode,
  ignorable: ignorable.join(''),
  order: groups.map(g => g.join('')).join('\n'),
};

// 自检：照 XZhCollation.compare 的算法排序，与 Intl.Collator 比较
const rank = new Map();
groups.forEach((g, i) => g.forEach(ch => rank.set(ch, i + 1)));
const skip = new Set(ignorable);
function key(s) { const out = []; for (const ch of s) { if (skip.has(ch)) continue; out.push(rank.get(ch) || groups.length + 1 + ch.codePointAt(0)); } return out; }
function cmp(a, b) {
  const ka = key(a), kb = key(b);
  for (let i = 0; i < Math.min(ka.length, kb.length); i++) if (ka[i] !== kb[i]) return ka[i] - kb[i];
  if (ka.length !== kb.length) return ka.length - kb.length;
  return a < b ? -1 : a > b ? 1 : 0;
}
// Codex installEquipmentStatusRuntime 的 text()：全伤→全属性伤害，去掉转义码与 <…>
function text(s) { return String(s == null ? '' : s).replace(/全伤(?:害)?/g, '全属性伤害').replace(/\\[a-z]+\[[^\]]*\]/gi, '').replace(/\x1b[a-z]+\[[^\]]*\]/gi, '').replace(/<[^>]*>/g, '').replace(/\\[{}.!|><^]/g, '').trim(); }
const uniq = [...new Set(names.map(text))];
const byIcu = uniq.slice().sort((a, b) => full.compare(a, b) || (a < b ? -1 : a > b ? 1 : 0));
const byKey = uniq.slice().sort(cmp);
// 名次相同（只差大小写/全半角）时 ICU 按二三级权重、本表按码位，这类并列不算差异
const bad = byIcu.filter((n, i) => n !== byKey[i] && full.compare(n, byKey[i]) !== 0 && base.compare(n, byKey[i]) !== 0);
console.log(JSON.stringify({chars: list.length, groups: groups.length, ignorable: ignorable.length, names: uniq.length, mismatches: bad.length, sample: bad.slice(0, 5)}));
if (bad.length) process.exit(1);
if (!check) fs.writeFileSync(OUT, JSON.stringify(table, null, 1) + '\n');
else if (!fs.existsSync(OUT) || fs.readFileSync(OUT, 'utf8') !== JSON.stringify(table, null, 1) + '\n') { console.log('排序表与当前 ICU 生成结果不同'); process.exit(2); }
