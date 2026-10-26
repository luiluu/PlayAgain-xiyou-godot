/* Real item target -> native apply/refund -> map CE1317 -> native toast. */
(function(){
 if(!/[?&]sys_review=1(?:&|$)/.test(location.search))return;
 var P=window.__capacityRef={};
 function wait(f){return __ilr.wait(f,60000);}
 async function frames(n){var f=Graphics.frameCount+(n||10);await wait(function(){return Graphics.frameCount>=f;});}
 async function settle(){await frames(24);await wait(function(){return ImageManager.isReady();});if(document.fonts)await document.fonts.ready;}
 P.ready=function(){return window.__ilr&&DataManager.isDatabaseLoaded()&&SceneManager._scene instanceof Scene_Title&&SceneManager._sceneStarted;};
 P.setup=async function(){
  var nativeUpdate=Game_Map.prototype.updateInterpreter;
  Math.random=function(){return .5;};__ilr.newGame();Game_Map.prototype.updateInterpreter=nativeUpdate;
  if(window.CodexGuide)CodexGuide.MILESTONE_ENABLED=false;
  $gameParty._actors=[2];$gameParty._battleMembers=[2,0,0,0,0];$gameVariables.setValue(9,1);
  $gameActors.actor(2).learnSkill(6301);$gameParty.gainItem($dataItems[1461],3);
  $gamePlayer.clearTransferInfo();$gameScreen.clear();$gamePlayer.reserveTransfer(5,10,10,2,0);SceneManager.goto(Scene_Map);
  await wait(function(){return SceneManager._scene instanceof Scene_Map&&SceneManager._sceneStarted&&$gameMap.mapId()===5&&!$gameMap.isEventRunning();});await settle();
  SceneManager.push(Scene_Item);
  await wait(function(){return SceneManager._scene instanceof Scene_Item&&SceneManager._sceneStarted;});await settle();
  var s=SceneManager._scene;s._categoryWindow.selectSymbol('item');s._categoryWindow.deactivate();s._itemWindow.setCategory('item');s._itemWindow.refresh();
  s._itemWindow.select(s._itemWindow._data.indexOf($dataItems[1461]));s._itemWindow.activate();s._itemWindow.processOk();await settle();s.onActionUse();await settle();
  if(!s._actorWindow.active)throw Error('native actor window inactive');return true;
 };
 P.pick=async function(){
  var s=SceneManager._scene;s._actorWindow.select(0);P.prePick={item:s.item().id,actorIndex:s._actorWindow.index(),target:s.itemTargetActors().map(function(a){return a&&a.actorId();}),allowed:s.canUse(),user:s.user().actorId(),handler:String(s._actorWindow._handlers.ok),skills:$gameActors.actor(2)._skills.slice(),effects:s.item().effects};s._actorWindow.processOk();if(!$gameTemp._commonEventId&&!SceneManager.isNextScene(Scene_Map))throw Error("native no reservation: "+JSON.stringify({pre:P.prePick,state:P.read()}));
  try { await wait(function(){return SceneManager._scene instanceof Scene_Map&&SceneManager._sceneStarted&&document.querySelector('#toastMessage .message');}); } catch(e) { throw Error('capacity return: '+JSON.stringify({pre:P.prePick,state:P.read(),busy:SceneManager._scene.isBusy(),messages:$gameMessage._texts,interp:$gameMap._interpreter&&{index:$gameMap._interpreter._index,running:$gameMap._interpreter.isRunning(),event:$gameMap._interpreter._eventId,list:$gameMap._interpreter._list},update:String(Game_Map.prototype.updateInterpreter).slice(0,300)})); }
  await wait(function(){var t=document.querySelector('#toastMessage');return t&&Number(getComputedStyle(t).opacity)>=.999;});
  await settle();return true;
 };
 function rect(el){var r=el.getBoundingClientRect();return [r.x,r.y,r.width,r.height];}
 function style(el){var s=getComputedStyle(el);return {rect:rect(el),padding:s.padding,margin:s.margin,color:s.color,background:s.backgroundColor,font:s.fontFamily,fontSize:s.fontSize,lineHeight:s.lineHeight,opacity:s.opacity,text:el.textContent};}
 P.read=function(){
  var s=SceneManager._scene,w=s._actorWindow,t=document.querySelector('#toastMessage'),m=t&&t.querySelector('.message'),container=document.querySelector('#toaster');
  return {scene:s.constructor.name,map:$gameMap.mapId(),position:[$gamePlayer.x,$gamePlayer.y,$gamePlayer.direction()],book:$gameParty.numItems($dataItems[1461]),skills:$gameActors.actor(2)._skills.slice(),selected:$gameParty._targetActorId,reserved:$gameTemp._commonEventId||0,
   actor:w?{rect:[w.x,w.y,w.width,w.height],padding:w.padding,lineHeight:w.lineHeight(),itemHeight:w.itemHeight(),texts:(w.contents.__ilrText||[]).map(function(t){return [t.text,t.x,t.y,t.w,t.align,t.size,t.color];})}:null,
   toast:t?{container:style(container),box:style(t),message:style(m)}:null,errors:(window.__refErrors||[]).slice()};
 };
})();
