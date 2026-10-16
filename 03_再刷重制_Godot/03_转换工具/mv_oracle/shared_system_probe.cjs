'use strict';
const {start,finish}=require('./shared/host.cjs');
const host=start();
let ok=true;
const selected=process.argv.slice(2);
for(const [name,module] of [['shop_stock.json','stock'],['battle_messages.json','messages'],['challenge_passives.json','challenge']])
  if(!selected.length||selected.includes(module))ok=finish(host,name,require('./shared/'+module+'.cjs')(host))&&ok;
process.exit(ok?0:1);
