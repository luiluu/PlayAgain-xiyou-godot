'use strict';
// 冻结正式版的副作用公式。固定资源上限，直接调用真实 evalDamageFormula；敌人必须来自当前敌群。
const crypto = require('crypto');
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), w = host.w, cases = [];
w.eval('CodexZones.ENABLED=false;');  // 五乘区（CodexZones）重制不移植（O-044），探针宿主默认开着；关掉让参照不含成长修正（tools50 确认关与不关产物一致或已更新夹具）
host.newGame();
for (const skill of [857, 858, 4013]) for (const enemy of [false, true])
  for (const resources of [[10000, 220, 123], [450, 1, 1], [3000, 0, 0], [3001, 201, 200]])
    for (const immortal of [false, true]) {
      const setup = {skill, enemy, resources, immortal, subjectParams: [10000, 101, 100, 100, 100, 100, 100, 100],
        targetParams: [10000, 1000, 100, 100, 100, 100, 100, 100], maxTp: 200};
      cases.push(makeCase(`s${skill}.${enemy ? 'enemy' : 'actor'}.${resources.join('_')}.${immortal}`, setup, () => {
        w.$gameTroop.setup(157);
        const a = enemy ? w.$gameTroop.members()[0] : w.$gameActors.actor(1), b = w.$gameActors.actor(8);
        a.param = i => setup.subjectParams[i]; b.param = i => setup.targetParams[i];
        a.maxTp = b.maxTp = () => setup.maxTp;
        b._hp = resources[0]; b._mp = resources[1]; b._tp = resources[2];
        b.clearStates(); b.removeImmortal(); if (immortal) b.addImmortal();
        const action = new w.Game_Action(a); action.setSkill(skill);
        const value = action.evalDamageFormula(b);
        return {value, resources: [b.hp, b.mp, b.tp], deathState: b.isStateAffected(1),
          formulaSHA256: crypto.createHash('sha256').update(w.$dataSkills[skill].damage.formula).digest('hex')};
      }));
    }
process.exit(finish(host, 'custom_damage.json', {cases}) ? 0 : 1);
