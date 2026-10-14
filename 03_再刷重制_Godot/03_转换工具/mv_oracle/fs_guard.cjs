'use strict';
const fs = require('fs'), path = require('path');
const {fileURLToPath} = require('url');

// 保护参照引擎常用的 fs 接口；不是运行任意不可信代码的安全隔离环境。
function installGuard(root, sandbox, allow = []) {
  if (fs.__oracleGuard) { Object.assign(fs.__oracleGuard,{root,sandbox,allow}); return; }
  const g = fs.__oracleGuard = {root,sandbox,allow};
  const realpath = fs.realpathSync, exists = fs.existsSync;
  const descriptors = new Map();
  const absolute = p => path.resolve(p instanceof URL ? fileURLToPath(p) : Buffer.isBuffer(p) ? p.toString() : String(p));
  // 新文件尚不存在时解析最近存在的祖先，不能经沙盒内的符号链接写到外面。
  function canonical(p) {
    let base=absolute(p), rest=[];
    while (!exists(base)) {
      const parent=path.dirname(base); if (parent===base) break;
      rest.unshift(path.basename(base)); base=parent;
    }
    return path.join(realpath(base),...rest);
  }
  const inside = (p,base) => {
    const r=path.relative(canonical(base),canonical(p));
    return r==='' || (r!=='..' && !r.startsWith('..'+path.sep) && !path.isAbsolute(r));
  };
  const protectedPath = p => /(?:^|\/)(?:save|saves|app_userdata|Application Support)(?:\/|$)|codex_author_key|\.(?:rpgsave|sav|save)(?:\.|$)/i.test(p);
  function blocked(p) {
    if (typeof p==='number') return descriptors.has(p) && blocked(descriptors.get(p));
    return !inside(p,g.sandbox) && (protectedPath(absolute(p)) || protectedPath(canonical(p)));
  }
  function readable(p) {
    if (blocked(p)) throw new Error('oracle guard: read blocked '+p);
  }
  function writable(p) {
    if (typeof p==='number') {
      if (p===1 || p===2) return;
      if (!descriptors.has(p)) throw new Error('oracle guard: unknown write descriptor '+p);
      p=descriptors.get(p);
    }
    if (blocked(p) || !(inside(p,g.sandbox) || g.allow.some(d=>inside(p,d))))
      throw new Error('oracle guard: write blocked '+p);
  }
  const writeFlags = flags => typeof flags==='number'
    ? !!(flags & (fs.constants.O_WRONLY|fs.constants.O_RDWR|fs.constants.O_CREAT|fs.constants.O_TRUNC|fs.constants.O_APPEND))
    : /[wa+]/.test(flags || 'r');
  function wrap(object,name,guard,after) {
    const original=object[name]; if (typeof original!=='function') return;
    object[name]=function(...args) { guard(...args); const r=original.apply(this,args); return after ? after(r,args) : r; };
  }
  for (const name of ['readFile','readdir','stat','lstat','access','realpath','readlink','opendir']) {
    wrap(fs,name,readable); wrap(fs,name+'Sync',readable); wrap(fs.promises,name,readable);
  }
  fs.existsSync=p=>!blocked(p) && exists(p);
  for (const name of ['writeFile','appendFile','mkdir','unlink','rm','rmdir','truncate','chmod','chown','utimes','lutimes','lchown','lchmod']) {
    wrap(fs,name,writable); wrap(fs,name+'Sync',writable); wrap(fs.promises,name,writable);
  }
  const renameGuard=(src,dst)=>{writable(src);writable(dst);};
  wrap(fs,'rename',renameGuard); wrap(fs,'renameSync',renameGuard); wrap(fs.promises,'rename',renameGuard);
  for (const name of ['copyFile','link','symlink']) {
    const guard=(src,dst)=>{
      readable(name==='symlink' ? path.resolve(path.dirname(absolute(dst)),String(src)) : src);
      if(name==='link')writable(src); // 硬链接不能让沙盒写入修改只读来源的同一 inode。
      writable(dst);
    };
    wrap(fs,name,guard); wrap(fs,name+'Sync',guard); wrap(fs.promises,name,guard);
  }
  // 递归复制会隐式读子目录，参照引擎不需要该接口，禁止用它绕过存档目录守卫。
  const noBulkCopy=()=>{throw new Error('oracle guard: recursive copy blocked');};
  wrap(fs,'cp',noBulkCopy); wrap(fs,'cpSync',noBulkCopy); wrap(fs.promises,'cp',noBulkCopy);
  const openGuard=(p,flags)=>{readable(p);if(writeFlags(flags))writable(p);};
  wrap(fs,'openSync',openGuard,(fd,args)=>{descriptors.set(fd,args[0]);return fd;});
  const originalOpen=fs.open;
  fs.open=function(p,flags,...rest) {
    openGuard(p,flags);const callback=rest.pop();
    return originalOpen.call(this,p,flags,...rest,(err,fd)=>{if(!err)descriptors.set(fd,p);callback(err,fd);});
  };
  wrap(fs.promises,'open',openGuard,(promise,args)=>promise.then(handle=>{descriptors.set(handle.fd,args[0]);return handle;}));
  wrap(fs,'createReadStream',readable);
  wrap(fs,'createWriteStream',writable);
  for (const name of ['write','writev','ftruncate','fchmod','fchown','futimes']) {
    wrap(fs,name,writable); wrap(fs,name+'Sync',writable);
  }
  for (const name of ['read','readv','fstat']) { wrap(fs,name,readable); wrap(fs,name+'Sync',readable); }
}

module.exports = {installGuard};
