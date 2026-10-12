'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const digest = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
function sourceIdentity(APP) {
  const inputs = {};
  for (const name of fs.readdirSync(path.join(APP, 'data')).filter(n => n.endsWith('.json')).sort()) {
    inputs['data/' + name] = digest(path.join(APP, 'data', name));
  }
  inputs['package.json'] = digest(path.join(APP, 'package.json'));
  const runtimeInputs = {};
  function walk(dir) {
    for (const entry of fs.readdirSync(dir, {withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))) {
      const file = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(file);
      else if (entry.name.endsWith('.js')) runtimeInputs[path.relative(APP,file)] = digest(file);
    }
  }
  walk(path.join(APP,'js'));
  return {releaseVersion:JSON.parse(fs.readFileSync(path.join(APP,'package.json'),'utf8')).releaseVersion, inputs, runtimeInputs};
}
module.exports={sourceIdentity};
