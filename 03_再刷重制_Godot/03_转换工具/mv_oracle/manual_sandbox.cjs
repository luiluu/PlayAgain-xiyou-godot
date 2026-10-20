'use strict';
// 手动探针与同步探针均从相同起始种子开始；手动运行不修改公共 seed。
const fs = require('fs'), path = require('path');
const boxes = new Map();

function manualSandbox(base) {
  base = path.resolve(base);
  if (boxes.has(base)) return boxes.get(base);
  if (fs.existsSync(base) && fs.lstatSync(base).isSymbolicLink()) throw new Error('sandbox 不能是符号链接');
  const seeds = ['save', 'macport'];
  function inspect(src) {
    const stat = fs.lstatSync(src);
    if (stat.isSymbolicLink()) throw new Error('种子不能含符号链接：' + src);
    if (stat.isDirectory()) for (const name of fs.readdirSync(src)) inspect(path.join(src, name));
    else if (!stat.isFile()) throw new Error('种子只能含普通文件：' + src);
  }
  for (const name of seeds) if (fs.existsSync(path.join(base, name))) inspect(path.join(base, name));
  const manual = path.join(base, 'manual');
  try {
    if (fs.lstatSync(manual).isSymbolicLink()) throw new Error('手动副本目录不能是符号链接');
  } catch (e) { if (e.code !== 'ENOENT') throw e; }
  fs.mkdirSync(manual, {recursive:true});
  const box = fs.mkdtempSync(path.join(manual, 'probe-'));
  function copy(src, dst) {
    if (fs.lstatSync(src).isDirectory()) {
      fs.mkdirSync(dst, {recursive:true});
      for (const name of fs.readdirSync(src)) copy(path.join(src, name), path.join(dst, name));
    } else fs.copyFileSync(src, dst, fs.constants.COPYFILE_FICLONE);
  }
  for (const name of seeds) if (fs.existsSync(path.join(base, name))) copy(path.join(base, name), path.join(box, name));
  // 同一个探针进程多次 boot 仍共用本次副本，语义与同步的一探针一目录相同。
  boxes.set(base, box);
  return box;
}

module.exports = {manualSandbox};
