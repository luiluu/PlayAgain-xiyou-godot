'use strict';
// 增量同步的分片合并（incremental_sync.SHARDS）：本次只跑了部分单元（敌群／地图）的探针产物，
// 与上次的完整产物按全量运行时的顺序拼回一份。只读 generated/oracle 与 .sandbox，不碰正式源和存档。
// 用 Node 合并、按探针原样 JSON.stringify，保证与全量产物逐字节一致。
// 用法：node oracle_shard_merge.cjs <spec.json>
//   spec = {kind: 'troops'|'events', order: [单元…], ran: [本次跑了的单元…],
//           files: [{old: 上次产物, fresh: 本次产物或 null, out: 写到哪, indent: 1|null}]}
const fs = require('fs');
const spec = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const ran = new Set(spec.ran), order = spec.order;
const unitOf = {
  troops: r => String(r.troop),
  events: r => r.kind === 'common' ? 'ce' + r.common : 'm' + r.map,
}[spec.kind];
if (!unitOf) throw new Error('未知分片类型：' + spec.kind);
// 各类产物里按单元分组的列表／字典
const LISTS = {troops: ['cases', 'damage'], events: ['cases']}[spec.kind];
const DICTS = {troops: ['enemies'], events: []}[spec.kind];

function group(list) {
  const out = new Map();
  for (const r of list) {
    const u = unitOf(r);
    if (!out.has(u)) out.set(u, []);
    out.get(u).push(r);
  }
  return out;
}

for (const f of spec.files) {
  const old = JSON.parse(fs.readFileSync(f.old, 'utf8'));
  const fresh = f.fresh ? JSON.parse(fs.readFileSync(f.fresh, 'utf8')) : null;
  // 非分片部分（来源身份、开局设定、行动序列等）取本次运行；没跑探针时沿用上次
  const merged = Object.assign({}, fresh || old);
  for (const name of LISTS) {
    if (!Array.isArray(old[name]) && !(fresh && Array.isArray(fresh[name]))) continue;
    const a = group(old[name] || []), b = group(fresh ? fresh[name] || [] : []);
    merged[name] = [];
    // 单元在列表里可以没有记录（如无事件的地图），所以这里不查缺失；字典每个单元必有一项，下面查
    for (const u of order) merged[name].push(...((ran.has(u) ? b : a).get(u) || []));
  }
  for (const name of DICTS) {
    if (!old[name] && !(fresh && fresh[name])) continue;
    merged[name] = {};
    for (const u of order) {
      const src = ran.has(u) ? (fresh[name] || {}) : old[name];
      if (Object.prototype.hasOwnProperty.call(src, u)) merged[name][u] = src[u];
      else if (!ran.has(u)) throw new Error('上次产物缺单元 ' + u + '（' + name + '）');
    }
  }
  fs.writeFileSync(f.out, f.indent ? JSON.stringify(merged, null, f.indent) : JSON.stringify(merged));
}
