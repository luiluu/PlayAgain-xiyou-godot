'use strict';
const {host,fixture}=require('./formula_effect_probe.cjs');
const {makeCase,finish}=require('./shared/host.cjs');
const cases=[];
for(const mode of ['repeat','reflect','counter'])for(const resources of [[10000,220,123],[450,1,1]]){
 const setup={skill:857,pair:'enemy_actor',resources,mode};
 cases.push(makeCase(`${mode}.${resources.join('_')}`,setup,()=>fixture(setup)));
}
process.exit(finish(host,'formula_actions.json',{hostScope:'real-action-resource-reactions',cases})?0:1);
