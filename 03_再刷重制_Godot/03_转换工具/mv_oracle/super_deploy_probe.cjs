'use strict';
// 超强者出战限制（installBossDifficultyRuntime 的 D.enforceParty），冻结 v0.28：
// 没开持久挑战开关（2494／2489／2487／2483／2461～2463）且难度不是 9（混沌）时，battleMembers() 前后、
// initializeBattleMembers／addActor／swapOrderBattleMembers／rearrangeActors／changeBattleMax 前后各清一次：
// 出战栏里的超强者换成 0，再只把这些空出的格按 _actors 顺序用「不是超强者、不在出战栏、已登场」的角色补上（补不满留 0），
// _actors 不重排；有清出时记一条提示，Scene_Map／Scene_Party.start 时用 $.toaster 弹「超强者仅限地狱及以上难度出战，已移至替补。」。
// 整队名单：Window_PartyList.actorIsEnabled／isCurrentItemEnabled 对超强者为 false（名单半透明、确定蜂鸣），switchActors 也蜂鸣拦下。
// 每步记录 _battleMembers、_actors（都在取 battleMembers() 之前读）、battleMembers() 的角色、本步弹出的提示。产物 .sandbox/super_deploy.json，
// 复制进 01_Godot工程/tests/fixtures/super_deploy_oracle.json。
const {start, makeCase, finish} = require('./shared/host.cjs');
const host = start(), {w, newGame, encode, restore} = host;
let toasts = [];
w.$.toaster = o => toasts.push(String(o && o.message));
const D = w.CodexBossDifficulty, P = () => w.$gameParty;
const SW = [2494, 2489, 2487, 2483, 2461, 2462, 2463];
function setParty(actors, battle) {
  // 直接写字段，不经包装（模拟旧存档或开关关掉之前编好的队）；_battleMembers 补到 5 格
  // 用引擎那边的数组（宿主数组没有 RPG Maker 加的 contains）
  P()._actors = w.JSON.parse(JSON.stringify(actors));
  P()._battleMembers = w.JSON.parse(JSON.stringify(battle.concat([0, 0, 0, 0, 0]).slice(0, 5)));
  actors.forEach(id => w.$gameActors.actor(id));
}
const flush = () => D.flushDeploymentNotice();
const ACTIONS = {
  party: st => setParty(st.actors, st.battle),
  members: () => { P().battleMembers(); },
  flush,
  rearrange: () => P().rearrangeActors(),
  add: st => P().addActor(st.id),
  remove: st => P().removeActor(st.id),
  init: () => P().initializeBattleMembers(),
  switch: st => w.$gameSwitches.setValue(st.id, st.on),
  difficulty: st => { w.$gameSystem._difficultyId = st.id; },
  // 整队页开页（Scene_Party.start 包装：先清再开、开完弹提示）
  partyStart: () => { D.enforceParty(P()); flush(); },
  load: st => { setParty(st.actors, st.battle); const json = encode(); restore(json); P().battleMembers(); flush(); },
};
function row() {
  const list = {};
  for (const id of P()._actors) {
    const a = w.$gameActors.actor(id);
    list[id] = [D.canDeploy(a), w.Window_PartyList.prototype.actorIsEnabled.call({}, a),
      w.Window_PartyList.prototype.isCurrentItemEnabled.call({curActor: () => a})];
  }
  return {slots: P()._battleMembers.slice(), actors: P()._actors.slice(), members: P().battleMembers().map(a => a.actorId()),
    enabled: D.superStrongEnabled(), list, toasts};
}
function scenario(id, steps) {
  cases.push(makeCase(id, {steps}, () => {
    newGame();
    SW.forEach(s => w.$gameSwitches.setValue(s, false));
    toasts = [];
    D.flushDeploymentNotice();
    const rows = [];
    for (const st of steps) {
      toasts = [];
      ACTIONS[st.do](st);
      rows.push(Object.assign({do: st.do}, row()));
    }
    return {difficulty: w.$gameSystem.difficultyId(), rows};
  }));
}
const cases = [];
// 三霄 100／101／102 是超强者：清出、按 _actors 顺序补替补（102 也是超强者，不补）、留下原本的空格；再编整队、加人、重建出战栏
scenario('sanxiao', [
  {do: 'party', actors: [1, 100, 101, 102, 8, 9, 10], battle: [100, 1, 101, 0, 8]}, {do: 'members'}, {do: 'flush'},
  {do: 'rearrange'}, {do: 'add', id: 11}, {do: 'flush'},
  {do: 'party', actors: [100, 101, 1, 8, 9, 102, 10, 11], battle: [1, 8, 9, 10, 11]}, {do: 'init'}, {do: 'flush'},
  {do: 'remove', id: 10}]);
// 替补不够：空出的格留 0
scenario('shortage', [
  {do: 'party', actors: [100, 101, 102, 1], battle: [100, 101, 102, 1]}, {do: 'partyStart'}, {do: 'members'}]);
// 开关与难度：开着时不清；关掉后下一次取出战成员时清；难度 9 也放行
scenario('switches', [
  {do: 'switch', id: 2461, on: true}, {do: 'party', actors: [100, 101, 1, 8], battle: [100, 101, 1, 8]}, {do: 'members'},
  {do: 'rearrange'}, {do: 'switch', id: 2461, on: false}, {do: 'members'}, {do: 'flush'},
  {do: 'difficulty', id: 9}, {do: 'party', actors: [100, 101, 1, 8], battle: [100, 101, 1, 8]}, {do: 'members'}, {do: 'flush'}]);
// 加入超强者：已持有（开关开着时拿到的）关掉后再 addActor 不会进出战栏
scenario('add_owned', [
  {do: 'party', actors: [1, 8, 100], battle: [1, 8]}, {do: 'add', id: 100}, {do: 'flush'}, {do: 'members'}]);
// MyGO 118／119／129／130／131 与镜流 170 是「强者」，不受出战限制
scenario('mygo', [
  {do: 'party', actors: [118, 119, 129, 130, 131, 170], battle: [118, 119, 129, 130, 170]}, {do: 'members'}, {do: 'flush'},
  {do: 'rearrange'}]);
// 读档：存档里出战栏有超强者（存之前不经包装直接写），读回来第一次取出战成员时清，回地图弹提示
scenario('load', [{do: 'load', actors: [1, 8, 101, 9, 10], battle: [101, 1, 8, 0, 0]}]);
process.exit(finish(host, 'super_deploy.json', {hostScope: '新游戏（Math.random 0.5）；超强者出战限制：出战成员、整队编辑、开关与难度、读档', cases}) ? 0 : 1);
