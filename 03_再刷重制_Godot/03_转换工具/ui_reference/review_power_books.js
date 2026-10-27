/* Dedicated power-forget screenshots: real item onActionUse and native choice handlers. */
(function(){
 if(!/[?&]sys_review=1(?:&|$)/.test(location.search))return;
 var P=window.__powerRef={};
 function wait(f){return __ilr.wait(f,60000);}
 async function frames(n){var f=Graphics.frameCount+(n||10);await wait(function(){return Graphics.frameCount>=f;});}
 async function settle(){await frames(20);await wait(function(){return ImageManager.isReady();});if(document.fonts)await document.fonts.ready;await frames(4);}
 P.ready=function(){return window.__ilr&&DataManager.isDatabaseLoaded()&&SceneManager._scene instanceof Scene_Title&&SceneManager._sceneStarted;};
 P.setup=async function(){
  Math.random=function(){return .5;};__ilr.newGame();if(window.CodexGuide)CodexGuide.MILESTONE_ENABLED=false;
  $gameSwitches.setValue(2494,true);$gameVariables.setValue(9,999);$gameParty._actors=[1,106,2];$gameParty._battleMembers=[1,106,2,0,0];
  $gameActors.actor(1).learnSkill(7238);$gameActors.actor(2).learnSkill(7240);$gameParty.gainItem($dataItems[3044],1);
  $gamePlayer.clearTransferInfo();$gameScreen.clear();SceneManager.goto(Scene_Item);
  await wait(function(){return SceneManager._scene instanceof Scene_Item&&SceneManager._sceneStarted;});await settle();
  var s=SceneManager._scene;s._categoryWindow.selectSymbol('item');s._categoryWindow.deactivate();s._itemWindow.setCategory('item');s._itemWindow.refresh();
  s._itemWindow.select(s._itemWindow._data.indexOf($dataItems[3044]));s._itemWindow.activate();s._itemWindow.processOk();await settle();s.onActionUse();await settle();return true;
 };
 P.pick=async function(i){var w=SceneManager._scene._yunChoices;w.select(i);w.processOk();await settle();return true;};
 P.read=function(){var w=SceneManager._scene._yunChoices;return {rect:[w.x,w.y,w.width,w.height],padding:w.padding,lineHeight:w.lineHeight(),infoHeight:w.infoHeight(),pageRows:w.maxPageRows(),
 info:w.info.slice(),rows:w.rows.map(function(r){return {label:r.label,enabled:r.enabled!==false};}),
 texts:(w.contents.__ilrText||[]).map(function(t){return [t.text,t.x,t.y,t.w,t.align,t.size,t.color];}),tokens:$gameParty.numItems($dataItems[3044]),
 powers:$gameParty.allMembers().map(function(a){return {actor:a.actorId(),powers:CodexHonghuang.learnedPowers(a)};}),errors:(window.__refErrors||[]).slice()};};
})();
