'use strict';
// 临时假来源与假存档；不打开正式应用或真实玩家文件。
const assert = require('assert/strict');
const fs = require('fs'), os = require('os'), path = require('path');
const {spawnSync} = require('child_process');
if (!process.argv[2]) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'xiyou-guard-'));
  try {
    for (const d of ['source/data', 'source/save', 'sandbox', 'outside']) fs.mkdirSync(path.join(tmp,d), {recursive:true});
    fs.writeFileSync(path.join(tmp,'source/data/ok.json'), '{}');
    fs.writeFileSync(path.join(tmp,'source/save/slot.rpgsave'), 'fake-save');
    fs.writeFileSync(path.join(tmp,'sandbox/from'), 'fake');
    fs.symlinkSync(path.join(tmp,'outside'), path.join(tmp,'sandbox/escape'));
    fs.symlinkSync(path.join(tmp,'source/save'), path.join(tmp,'source/alias'));
    const r = spawnSync(process.execPath, [__filename,tmp], {encoding:'utf8'});
    process.stdout.write(r.stdout); process.stderr.write(r.stderr);
    process.exitCode = r.status || 0;
  } finally { fs.rmSync(tmp, {recursive:true,force:true}); }
} else {
  const tmp = process.argv[2], at = p => path.join(tmp,p);
  require('./fs_guard.cjs').installGuard(at('source'),at('sandbox'),[]);
  let passed=0,total=0;
  function check(name,f) {
    total++; try { f(); passed++; } catch(e) { console.error('FAIL',name,e.message); }
  }
  const denies = f => assert.throws(f,/oracle guard/);
  check('read source',()=>assert.equal(fs.readFileSync(at('source/data/ok.json'),'utf8'),'{}'));
  check('write sandbox',()=>fs.writeFileSync(at('sandbox/ok'),'ok'));
  check('read saves blocked',()=>denies(()=>fs.readFileSync(at('source/save/slot.rpgsave'))));
  check('copy destination blocked',()=>denies(()=>fs.copyFileSync(at('sandbox/from'),at('outside/copied'))));
  check('rename destination blocked',()=>denies(()=>fs.renameSync(at('sandbox/from'),at('outside/moved'))));
  check('numeric write-open blocked',()=>denies(()=>fs.openSync(at('outside/numeric'),fs.constants.O_WRONLY|fs.constants.O_CREAT)));
  check('write symlink escape blocked',()=>denies(()=>fs.writeFileSync(at('sandbox/escape/escaped'),'no')));
  check('read symlink save blocked',()=>denies(()=>fs.readFileSync(at('source/alias/slot.rpgsave'))));
  check('copy real-save source blocked',()=>denies(()=>fs.copyFileSync(at('source/save/slot.rpgsave'),at('sandbox/copied'))));
  check('write stream blocked',()=>denies(()=>fs.createWriteStream(at('outside/stream'))));
  check('async open blocked',()=>denies(()=>fs.open(at('outside/async'),'w',()=>{})));
  check('promise write blocked',()=>denies(()=>fs.promises.writeFile(at('outside/promise'),'no')));
  check('delete outside blocked',()=>denies(()=>fs.unlinkSync(at('source/data/ok.json'))));
  check('hardlink source blocked',()=>denies(()=>fs.linkSync(at('source/data/ok.json'),at('sandbox/hardlink'))));
  check('sandbox copy allowed',()=>fs.copyFileSync(at('sandbox/ok'),at('sandbox/copied')));
  check('sandbox numeric open allowed',()=>{ const fd=fs.openSync(at('sandbox/numeric'),fs.constants.O_WRONLY|fs.constants.O_CREAT); fs.writeSync(fd,'ok'); fs.closeSync(fd); });
  console.log('TEST_RESULT='+JSON.stringify({passed,total}));
  process.exitCode = passed===total ? 0 : 1;
}
