'use strict';
// 增量同步的运行时依赖记录（tools-probe-deps）：同步给每个探针进程 --require 预加载本文件（XIYOU_PROBE_HELPER_DEPS=0 不加载）。
// 记下这次运行读过（fs 同步／回调读、打开、读流）或 require 过的 mv_oracle 内文件，退出时写进 mv_oracle/.sandbox/probe_deps/<探针>.<pid>.json；
// incremental_sync.py 把它与静态 require 图合起来算该探针的依赖。只记不拦，不改探针行为；写也只写 .sandbox。
// 不经 fs 的读法（fs.promises、子进程）记不到：这类写法在静态扫描里多半会被认作「认不出」，没记录时保守带上全部 helper。
const fs = require('fs'), path = require('path'), {fileURLToPath} = require('url');
const name = process.env.XIYOU_PROBE_DEPS_NAME, root = process.env.XIYOU_PROBE_DEPS_ROOT;
if (name && root && !/[\\/]/.test(name)) {
  const real = fs.realpathSync, write = fs.writeFileSync, mkdir = fs.mkdirSync, seen = new Set(), outside = new Set();
  const canon = s => { try { return real(s); } catch (e) { return path.resolve(s); } };
  const base = canon(root);
  const note = p => {
    try {
      const s = p instanceof URL ? fileURLToPath(p) : Buffer.isBuffer(p) ? p.toString() : p;
      if (typeof s !== 'string') return;
      const rel = path.relative(base, canon(s));
      if (rel && !rel.startsWith('..') && !path.isAbsolute(rel)) seen.add(rel.split(path.sep).join('/'));
      else if (rel.startsWith('..' + path.sep)) {   // mv_oracle 的上一级（03_转换工具）里 mv_oracle 之外的文件：记下，同步核对它们是否登记进了键（tools-probe-deps2）
        const up = path.relative(path.dirname(base), canon(s));
        if (up && !up.startsWith('..') && !path.isAbsolute(up)) outside.add(up.split(path.sep).join('/'));
      }
    } catch (e) {}
  };
  for (const k of ['readFileSync', 'readFile', 'openSync', 'open', 'createReadStream']) {
    const f = fs[k];
    if (typeof f === 'function') fs[k] = function (p) { note(p); return f.apply(this, arguments); };
  }
  process.on('exit', () => {
    for (const k of Object.keys(require.cache)) note(k);
    const files = [...seen].filter(r => !/^(\.sandbox|node_modules|real)(\/|$)/.test(r)).sort();
    try {
      const dir = path.join(base, '.sandbox', 'probe_deps');
      mkdir(dir, {recursive: true});
      write(path.join(dir, name + '.' + process.pid + '.json'), JSON.stringify({files, outside: [...outside].filter(r => !/(^|\/)node_modules\//.test(r)).sort()}) + '\n');
    } catch (e) {}
  });
}
