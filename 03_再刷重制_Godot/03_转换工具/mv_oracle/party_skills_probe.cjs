'use strict';
// 技能共享（Star_SkilsShare）、羁绊（Star_JiBanSiklls）、领袖技能（Star_LeadActor），冻结 v0.28：
// 三个插件都包住 Scene_Party.commandFinish 与 Star_Scene_ActorWarehouse.cancelNowScene，调用顺序（后载入的在外层）：
// 共享 refreshAllSkills → 羁绊（出战成员变了才 GetActors）→ 领袖 LearnSkill → 原函数。
// 开战（BattleManager.startBattle）：共享只在装备学技能（<ShareLearnSkill>）有变化时刷新，羁绊在成员变化时刷新，领袖不刷新。
// 读档（Star_LeadActor 的 DataManager.loadGame 包装，本会话第一次读档时）：领袖 → 羁绊 → 共享。
// 三者的「上次」记录都只在内存（不进存档）；读档用例先清内存记录，再 JsonEx 往返恢复，再照包装体依次调用（外层还有挂机、自动存档等
// loadGame 包装，读文件，这里不走）。
// 宿主把 $.toaster 换成记录器：记录的是插件原样发出的提示；codex installV019UsabilityRuntime 包装的 refreshAllSkills 在最外层刷新期间
// 吞掉逐条「技能共享：X 激活！」（那段过滤写在 $.toaster 包装里，宿主启动时被换掉），结束时把新激活的合成一条「技能共享激活：a、b」，
// 这条记录器能收到。Godot 侧比较时照这条规则去掉逐条提示。
// 每步记录相关角色的 _skills 原样（羁绊技能 ID 是字符串，原版就这样推进 _skills）。产物 .sandbox/party_skills.json，
// 复制进 01_Godot工程/tests/fixtures/party_skills_oracle.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame, encode, restore} = host;
let toasts = [];
w.$.toaster = o => toasts.push(String(o && o.message));
const SS = w.Star.SkillsShare, JB = w.Star.ActorsRanksSkill_Jiban, LA = w.Star.LeadActor;
function resetMemory() {
  SS.cachedBattleMembers = []; SS.lastSharedSkillIds = []; SS.lastEquipLearnSkills = {};
  JB.lastBattleMemberIds = null; JB.lastActiveJiBans = new w.Set(); JB.RanksActors = [];
  LA.RanksActors = []; LA.LearnSkillActors = [];
}
// 三霄 100～102 等是 installBossDifficultyRuntime 的「超强角色」：没开挑战开关时 battleMembers() 把他们清出出战栏（D.enforceParty）。
// Godot 尚无这条限制，这里开开关 2494，只测三套系统本身
function fresh(actors, battle) {
  newGame(); resetMemory();
  w.$gameSwitches.setValue(2494, true);
  setParty(actors, battle);
}
function setParty(actors, battle) {
  w.$gameParty._actors = actors.slice();
  // YEP：_battleMembers 长度不等于 maxBattleMembers（5）时 battleMembers() 会按 _actors 重建，所以补 0 到 5 格（同 Godot battle_slots）
  w.$gameParty._battleMembers = battle.concat([0, 0, 0, 0, 0]).slice(0, 5);
  actors.forEach(id => w.$gameActors.actor(id));
}
function equip(actorId, kind, id) {
  const a = w.$gameActors.actor(actorId), base = kind === 'weapon' ? w.$dataWeapons[id] : w.$dataArmors[id];
  const list = () => kind === 'weapon' ? w.$gameParty.weapons() : w.$gameParty.armors();
  const before = list().slice();
  w.$gameParty.gainItem(base, 1);
  const it = list().find(x => before.indexOf(x) < 0) || base;
  const slot = a.equipSlots().indexOf(base.etypeId);
  if (slot < 0) throw new Error('角色 ' + actorId + ' 没有装备类型 ' + base.etypeId + ' 的槽');
  a._equips[slot].setObject(it);
  w.$gameParty.loseItem(it, 1, false);
  return slot;
}
function unequip(actorId, slot) { w.$gameActors.actor(actorId)._equips[slot].setObject(null); }
const scene = {popScene() {}};
const ACTIONS = {
  finish: () => w.Scene_Party.prototype.commandFinish.call(scene),
  warehouse: () => w.Star_Scene_ActorWarehouse.prototype.cancelNowScene.call(scene),
  battle: () => {
    if (SS.hasEquipLearnSkillsChanged()) SS.refreshAllSkills();
    if (JB.hasBattleMembersChanged()) JB.GetActors();
  },
  load: () => {
    const json = encode();
    resetMemory();
    restore(json);
    if (LA.RanksActors == '') {
      LA.LearnSkill();
      if (JB.lastBattleMemberIds == null) JB.GetActors();
      if (SS.lastSharedSkillIds == '') SS.refreshAllSkills();
    }
  },
};
// steps：[{do: 'party', actors, battle} | {do: 'equip', actor, kind, id, as} | {do: 'unequip', actor, ref} | {do: finish/warehouse/battle/load}]
function scenario(id, actors, battle, steps, watch) {
  cases.push(makeCase(id, {actors, battle, steps}, () => {
    fresh(actors, battle);
    const slots = {}, rows = [];
    for (const st of steps) {
      toasts = [];
      if (st.do === 'party') setParty(st.actors, st.battle);
      else if (st.do === 'equip') slots[st.as] = [st.actor, equip(st.actor, st.kind, st.id)];
      else if (st.do === 'unequip') unequip(...slots[st.ref]);
      else ACTIONS[st.do]();
      const skills = {};
      for (const aid of watch) skills[aid] = w.$gameActors.actor(aid)._skills.map(v => typeof v === 'string' ? 's' + v : v);
      rows.push({do: st.do, toasts, skills, shared: SS.lastSharedSkillIds.slice(), bonds: [...JB.lastActiveJiBans].sort((a, b) => a - b),
        lead: LA.RanksActors.slice(), leadLearners: LA.LearnSkillActors.slice()});
    }
    return {rows};
  }));
}
const cases = [];
// 共享：护甲 1583 <ShareSkill:1000><ShareLearnSkill:1000>（学习光环，备注 <Share:ShareSkill>）——穿戴者学会、全队共享；脱下后下次刷新全队忘掉
scenario('share.armor1583', [1, 8, 9, 10, 11], [1, 8, 9, 10], [
  {do: 'equip', actor: 1, kind: 'armor', id: 1583, as: 'a'}, {do: 'finish'},
  {do: 'party', actors: [1, 8, 9, 10, 11], battle: [1, 8, 9, 11]}, {do: 'warehouse'},
  {do: 'unequip', actor: 1, ref: 'a'}, {do: 'battle'},
  {do: 'equip', actor: 8, kind: 'armor', id: 1583, as: 'b'}, {do: 'battle'}, {do: 'finish'},
  {do: 'load'}, {do: 'unequip', actor: 8, ref: 'b'}, {do: 'finish'}], [1, 8, 9, 10, 11]);
// 共享：武器 1111 <ShareSkill:1022><ShareLearnSkill:1022>；只学不共享的护甲 13 <ShareLearnSkill:34>；两件一起
scenario('share.weapon1111_armor13', [1, 8, 9, 10], [1, 8, 9, 10], [
  {do: 'equip', actor: 9, kind: 'armor', id: 13, as: 'c'}, {do: 'battle'}, {do: 'battle'},
  {do: 'equip', actor: 1, kind: 'weapon', id: 1111, as: 'w'}, {do: 'finish'},
  {do: 'unequip', actor: 9, ref: 'c'}, {do: 'finish'}], [1, 8, 9, 10]);
// 羁绊：三霄 100／101／102（2 人 5594、3 人 5595；「三霄羁绊」1 人 5593 永远不成组合），出入队与单人队
scenario('bond.sanxiao', [100, 101, 102, 8, 9], [100, 101, 8, 9], [
  {do: 'finish'}, {do: 'finish'},
  {do: 'party', actors: [100, 101, 102, 8, 9], battle: [100, 101, 102, 9]}, {do: 'warehouse'},
  {do: 'party', actors: [100, 101, 102, 8, 9], battle: [100, 8, 9]}, {do: 'battle'},
  {do: 'party', actors: [100, 101, 102, 8, 9], battle: [101, 102]}, {do: 'finish'},
  {do: 'party', actors: [100, 101, 102, 8, 9], battle: [101]}, {do: 'finish'},
  {do: 'party', actors: [100, 101, 102, 8, 9], battle: [100, 101, 102]}, {do: 'load'}], [100, 101, 102, 8, 9]);
// 羁绊：MyGO 118／119／129／130／131（2～5 人各一条）
scenario('bond.mygo', [118, 119, 129, 130, 131], [118, 119, 129, 130, 131], [
  {do: 'finish'},
  {do: 'party', actors: [118, 119, 129, 130, 131], battle: [118, 119, 129]}, {do: 'finish'}], [118, 119, 129, 130, 131]);
// 领袖：首位 1（717 天罡剑阵）→ 换首位 29（701）→ 首位 8（无领袖技能）→ 首位 2（2772）读档
scenario('lead.swap', [1, 29, 8, 9, 2], [1, 8, 9, 29], [
  {do: 'finish'},
  {do: 'party', actors: [1, 29, 8, 9, 2], battle: [29, 1, 8, 9]}, {do: 'warehouse'},
  {do: 'party', actors: [1, 29, 8, 9, 2], battle: [8, 1, 9, 29]}, {do: 'finish'}, {do: 'battle'},
  {do: 'party', actors: [1, 29, 8, 9, 2], battle: [2, 1, 9]}, {do: 'load'}, {do: 'finish'}], [1, 29, 8, 9, 2]);
// 三套一起：领袖 1＋三霄两人＋护甲 1583，看同一次刷新里的先后（共享先于羁绊与领袖，后两者学会的技能要到下次刷新才参与共享）
scenario('mixed', [1, 100, 101, 8], [1, 100, 101, 8], [
  {do: 'equip', actor: 8, kind: 'armor', id: 1583, as: 'a'}, {do: 'finish'}, {do: 'finish'},
  {do: 'party', actors: [1, 100, 101, 8], battle: [100, 1, 8]}, {do: 'finish'}], [1, 100, 101, 8]);
process.exit(finish(host, 'party_skills.json', {hostScope: '新游戏（Math.random 0.5）；技能共享、羁绊、领袖技能：整队完成、仓库退出、开战、读档', cases}) ? 0 : 1);
