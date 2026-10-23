'use strict';
// 种族祝福菜单严格级参照：执行正式引擎 installNativeRaceRuntime 的 openMenu／setDefault／change／upgrade／migrate／claimInbox，
// 记录各页行文（CodexYunshang.choose 收到的行与说明，换行后）、提示、结束时每名队员的 _codexRace、种族技能、开关 281～287 与背包。只写 .sandbox。
const fs=require('fs'),path=require('path');
const {boot}=require('./hboot.cjs'),{sourceIdentity}=require('./source_identity.cjs');
const APP=process.env.XIYOU_APP||'/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw';
const identity=sourceIdentity(APP),r=boot(APP,{tolerant:true,log:false}),w=r.window;
if(r.errors.length||!w.DataManager.isDatabaseLoaded()||!w.CodexRaces)throw new Error('参照引擎启动失败');
w.Star.Achievement.Manager.init();
const R=w.CodexRaces,C=w.$dataCodexRaces,toasts=[];
w.$.toaster=o=>toasts.push(String(o&&o.message));
const J=x=>JSON.parse(JSON.stringify(x));
const item=id=>w.$dataItems[id];
const RACE_SKILLS=new Set([].concat(...C.skills));
function setup(prep){
  w.eval('SceneManager.initInput();ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};');
  w.$gameParty._items={};[1,8,9].forEach(id=>w.$gameParty.addActor(id));toasts.length=0;if(prep)prep();
}
const bag=()=>{const o={};Object.keys(w.$gameParty._items).forEach(k=>{if(w.$gameParty._items[k])o[k]=w.$gameParty._items[k];});return o;};
const members=()=>w.$gameParty.allMembers().map(a=>({id:a.actorId(),race:J(a._codexRace||null),raceSkills:a._skills.filter(id=>RACE_SKILLS.has(id)),label:R.label(a),hp:a.hp,mp:a.mp}));
const switches=()=>[281,282,283,284,285,286,287].map(id=>w.$gameSwitches.value(id));
const after=()=>({members:members(),switches:switches(),default:w.$gameSystem._codexRaceDefault==null?null:w.$gameSystem._codexRaceDefault,bag:bag(),supply:J(w.$gameSystem._codexRaceSupply||null)});

// 新局（系统表的初始队伍是空的）后依次入队 1、8、9
// 1. 新局初值
setup();
const fresh={party:w.$gameParty.allMembers().map(a=>a.actorId()),...after(),migration:J(w.$gameSystem._codexRaceMigration)};

// 2. 直接调用：setDefault、change、upgrade 的各种返回
const calls=[];
{setup();const a=w.$gameParty.allMembers()[0],b=w.$gameParty.allMembers()[1];
  calls.push({step:'change-before-default',result:J(R.change(a,3)),...after()});
  calls.push({step:'setDefault-9',result:R.setDefault(9)});
  calls.push({step:'setDefault-2',result:R.setDefault(2),toasts:toasts.slice(),...after()});toasts.length=0;
  calls.push({step:'change-same',result:J(R.change(b,2))});
  calls.push({step:'change-free',result:J(R.change(b,4)),...after()});
  calls.push({step:'change-no-water',result:J(R.change(b,5))});
  w.$gameParty.gainItem(item(C.water),2);
  calls.push({step:'change-water',result:J(R.change(b,5)),...after()});
  calls.push({step:'upgrade-rank3',result:J(R.upgrade(b,3))});
  calls.push({step:'upgrade-no-stone',result:J(R.upgrade(b,2))});
  w.$gameParty.gainItem(item(C.stones[0]),1);w.$gameParty.gainItem(item(C.stones[1]),1);
  calls.push({step:'upgrade-2',result:J(R.upgrade(b,2)),...after()});
  calls.push({step:'upgrade-3',result:J(R.upgrade(b,3)),...after()});
  calls.push({step:'upgrade-8',result:J(R.upgrade(b,8))});
  const out=w.$gameActors.actor(2);calls.push({step:'change-not-member',inParty:w.$gameParty.allMembers().indexOf(out)>=0,result:J(R.change(out,1))});}

// 3. 旧技能推断（migrate）：一族、多族、无
const migrate=[];
for(const [name,skills] of [['one',[3656,3210]],['multi',[3210,3657]],['none',[]]]){
  setup();const a=w.$gameParty.allMembers()[0];delete a._codexRace;a._skills=a._skills.filter(id=>!RACE_SKILLS.has(id)).concat(skills);
  w.$gameSystem._codexRaceDefault=null;R.migrate();migrate.push({name,skills,...after()});}
// 开关推断开局默认：只开一个时
{setup();w.$gameSwitches.setValue(283,true);R.migrate();migrate.push({name:'switch-283',default:w.$gameSystem._codexRaceDefault});}

// 4. 暂存箱
const inbox=[];
{setup();w.$gameSystem._codexRaceSupply={counts:{},first:{},inbox:{[C.stones[2]]:3,[C.stones[0]]:2}};w.$gameParty.gainItem(item(C.stones[2]),9998);
  R.claimInbox();inbox.push({...after()});}

// 5. 各页（stub CodexBinding.openMenu／CodexYunshang.choose，按行文点选）
let screens=[],cur=null;
w.CodexYunshang.choose=function(scene,rows,ok,cancel,info){cur={rows,ok,cancel,info};screens.push({info:J(info||[]),rows:rows.map(x=>({label:x.label,enabled:x.enabled!==false}))});};
let home=null;w.CodexBinding.openMenu=function(b){home=b;return true;};
const scene={popScene(){screens.push({popped:true});}};
function pick(label){const r=label[0]==='@'?cur.rows[Number(label.slice(1))]:cur.rows.find(x=>x.label===label);if(!r)throw new Error('找不到行 '+label+' 现有 '+cur.rows.map(x=>x.label).join('|'));cur.ok(r);}
function back(){cur.cancel();}
function flow(name,prep,options,steps){screens=[];setup(prep);toasts.length=0;if(!R.openMenu(options))throw new Error('打不开种族祝福');home(scene);
  for(const s of steps){if(s==='<')back();else pick(s);}
  return {name,options:options||null,steps,screens,toasts:toasts.slice(),...after()};}
const pages=[];
// 没选开局默认：默认页 → 确认 → 队员页 → 角色页 → 换族（免费）→ 魔族血契开关 → 返回
pages.push(flow('default-first',null,null,['妖族','返回','人族','确定开局默认','@0','调整种族','魔族','确定选择','血契：关闭','血契：开启','<','<']));
pages.push(flow('default-cancel',null,null,['<']));
pages.push(flow('default-confirm-cancel',null,null,['神族','<']));
// 已选默认：换族要忘情水（缺／有），进阶缺石头与成功
pages.push(flow('change-water',()=>{R.setDefault(0);w.$gameParty.allMembers()[0]._codexRace.free=false;},null,['@0','调整种族','鬼族','确定选择','调整种族','神族（当前）','<','<','<']));
pages.push(flow('change-water-ok',()=>{R.setDefault(0);w.$gameParty.allMembers()[0]._codexRace.free=false;w.$gameParty.gainItem(item(C.water),1);},null,['@0','调整种族','灵族','返回','蛮族','确定选择','<','<']));
pages.push(flow('upgrade',()=>{R.setDefault(5);w.$gameParty.gainItem(item(C.stones[0]),1);},null,['@0','进阶至第2阶','确定进阶','进阶至第3阶','确定进阶','进阶至第3阶','返回','<','<']));
// 进阶石公共事件：openMenu({rank:3})
pages.push(flow('rank3',()=>{R.setDefault(6);w.$gameParty.gainItem(item(C.stones[1]),1);},{rank:3},['@0','进阶至第3阶','确定进阶','<','@1','进阶至第3阶','<','<','<']));
// 旧档多族
pages.push(flow('legacy-multi',()=>{R.setDefault(1);const a=w.$gameParty.allMembers()[0];delete a._codexRace;a._skills=a._skills.filter(id=>!RACE_SKILLS.has(id)).concat([3210,3657]);},null,['@0','调整种族','<','<']));
// 打开时领暂存箱
pages.push(flow('inbox',()=>{R.setDefault(3);w.$gameSystem._codexRaceSupply={counts:{},first:{},inbox:{[C.stones[0]]:2}};},null,['<']));
// '@n'：点第 n 行（队员行文带名字与祝福）

if(JSON.stringify(identity)!==JSON.stringify(sourceIdentity(APP)))throw new Error('测量期间来源改变');
const out={sourceIdentity:identity,config:{names:C.names,water:C.water,stones:C.stones},fresh,calls,migrate,inbox,pages};
fs.writeFileSync(path.join(__dirname,'.sandbox/race_menu.json'),JSON.stringify(out,null,1));
console.log(JSON.stringify({calls:calls.length,migrate:migrate.length,pages:pages.map(p=>p.name+':'+p.screens.length)}));process.exit(0);
