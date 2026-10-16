/* 开发夹具：只在专用回环服务、common_ref查询下启用。按钮驱动真实原版窗口，只修改内存。 */
(function(){
  if(!/[?&]common_ref=1(?:&|$)/.test(location.search))return;
  addEventListener('load',function(){
    StorageManager.load=function(){return null;};StorageManager.save=function(){return true;};StorageManager.exists=function(){return false;};
    ConfigManager.save=function(){};DataManager.saveGame=function(){return false;};
    var fixture={},panel=document.createElement('div');panel.id='common-fixture';
    panel.style.cssText='position:fixed;left:4px;bottom:4px;z-index:99999;background:white;color:black;font:12px monospace;max-width:1250px';
    ['mousedown','mouseup','click','touchstart','touchend'].forEach(function(t){panel.addEventListener(t,function(e){e.stopPropagation();});});
    var pre=document.createElement('pre');pre.id='common-readout';pre.style.cssText='max-height:110px;overflow:auto;max-width:1240px';
    function button(label,fn){var b=document.createElement('button');b.textContent=label;b.onclick=function(){try{fn();b.blur();}catch(e){pre.textContent=JSON.stringify({error:String(e.stack||e)});}};panel.appendChild(b);}
    function fresh(){if(!DataManager.isDatabaseLoaded())throw new Error('数据库尚未就绪');ConfigManager.applyData({});DataManager.setupNewGame();Math.random=function(){return 0.5;};
      $gameSystem._codexOrbRng={seed:20261016,n:{}};$gameParty._actors=[1,8,9,10];$gameMessage.clear();}
    function awaitScene(klass,fn){var count=0,timer=setInterval(function(){if(++count>250){clearInterval(timer);pre.textContent=JSON.stringify({error:'场景未就绪'});return;}
      var s=SceneManager._scene;if(s instanceof klass&&s.isActive()&&s._windowLayer&&s._itemWindow){clearInterval(timer);try{fn(s);}catch(e){fixture.error=String(e.stack||e);}}},20);}
    function openGear(s,eq){var category=DataManager.isWeapon(eq)?'weapon':'armor';s._categoryWindow.selectSymbol(category);s._categoryWindow.deactivate();s._itemWindow.setCategory(category);s._itemWindow.refresh();
      var index=s._itemWindow._data.indexOf(eq);if(index<0)throw new Error('装备不在物品页列表');s._itemWindow.select(index);s._itemWindow.updateHelp();s.onItemOk();}
    button('建立宝珠夹具',function(){fresh();
      for(var i=0;i<24;i++){$gameParty.gainItem($dataWeapons[1],1);$gameParty.gainItem($dataArmors[10],1);}
      var off=$dataArmors.filter(function(x){return x&&x.etypeId===2&&x.params.some(function(v){return v>0;});})[0],god=$dataArmors.filter(function(x){return x&&x.etypeId===17&&x.params.some(function(v){return v>0;});})[0];
      if(off)$gameParty.gainItem(off,1);if(god)$gameParty.gainItem(god,1);
      var families=$dataCodexOrbs.families,weapon=families.filter(function(f){return f.slot==='武器宝珠';})[0],armor=families.filter(function(f){return f.slot==='防具宝珠';})[0];
      [weapon,armor].forEach(function(f){if(f)$gameParty.gainItem($dataItems[f.ids[0]],3);});
      fixture={kind:'orbs',seed:20261016,equipment:$gameParty.weapons().concat($gameParty.armors()).map(function(eq){return {id:eq.id,base:eq.originalBaseItemId||eq.baseItemId,name:eq.name,etype:eq.etypeId,type:CodexOrbs.socketType(eq),slots:eq.augmentSlots,stored:eq.augmentSlotItems};})};
      SceneManager.goto(Scene_Item);awaitScene(Scene_Item,function(s){var eq=$gameParty.weapons().filter(function(x){return x.augmentSlots&&x.augmentSlots.length===3;})[0]||$gameParty.weapons()[0];openGear(s,eq);});
    });
    button('打开宝珠候选',function(){var s=SceneManager._scene;if(!(s instanceof Scene_Item))throw new Error('先建立宝珠夹具');
      var i=s._itemActionWindow._list.findIndex(function(c){return c.symbol==='augment';});if(i<0)throw new Error('当前装备没有孔');s._itemActionWindow.select(i);s.onActionAugment();});
    button('镶入首颗可用宝珠',function(){var s=SceneManager._scene,win=s._augmentListWindow;
      var i=win._data.findIndex(function(item){return item&&CodexOrbs.spec(item.id)&&win.isEnabled(item);});if(i<0)throw new Error('没有可用宝珠');win.select(i);s.onAugmentListOk();});
    button('切换防具宝珠夹具',function(){var s=SceneManager._scene,eq=$gameParty.armors().filter(function(x){return x.etypeId!==2&&x.etypeId!==17&&x.augmentSlots&&x.augmentSlots.length===2;})[0];if(!eq)throw new Error('没有2孔防具');
      if(s._augmentListWindow){s._augmentListWindow.hide();s._augmentListWindow.deactivate();}openGear(s,eq);});
    button('建立战斗物品夹具',function(){fresh();[1,2,137,77].forEach(function(id){$gameParty.gainItem($dataItems[id],3);});
      fixture={kind:'battle-items',party:$gameParty._actors.slice(),items:[1,2,137,77]};
      // 画面夹具暂停流程调度；真实Window_BattleItem的列表、可用性、标记与绘制保持原实现。
      Scene_Battle.prototype.updateBattleProcess=function(){};
      BattleManager.setup(4,false,false);SceneManager.goto(Scene_Battle);awaitScene(Scene_Battle,function(s){s._partyCommandWindow.deactivate();s._actorCommandWindow.deactivate();s.commandItem();s._itemWindow.select(0);s._itemWindow.updateHelp();});
    });
    button('取消战斗物品窗口',function(){var s=SceneManager._scene;if(!(s instanceof Scene_Battle))throw new Error('先建立战斗物品夹具');s.onItemCancel();});
    button('重新打开战斗物品',function(){var s=SceneManager._scene;s.commandItem();s._itemWindow.select(0);s._itemWindow.updateHelp();});
    button('隐藏夹具工具栏',function(){panel.style.visibility='hidden';});
    panel.appendChild(pre);document.body.appendChild(panel);
    var oldDraw=Bitmap.prototype.drawText;Bitmap.prototype.drawText=function(){(this._commonDraw||(this._commonDraw=[])).push(Array.prototype.slice.call(arguments));if(this._commonDraw.length>180)this._commonDraw.shift();return oldDraw.apply(this,arguments);};
    setInterval(function(){if(!SceneManager._scene)return;var s=SceneManager._scene,windows=[];
      function walk(n){if(n instanceof Window_Base)windows.push({type:n.constructor.name,rect:[n.x,n.y,n.width,n.height],visible:n.visible,active:n.active,index:n.index?n.index():null,padding:n.padding,lineHeight:n.lineHeight(),maxCols:n.maxCols?n.maxCols():null,
        commands:n._list||null,items:(n._data||[]).filter(function(x){return x&&x.id;}).map(function(x){return {id:x.id,name:x.name,occasion:x.occasion,enabled:n.isEnabled?!!n.isEnabled(x):null,newItem:!!x._new,owned:$gameParty.numItems(x)};}),draws:n.contents&&n.contents._commonDraw||[]});(n.children||[]).forEach(walk);}
      walk(s);pre.textContent=JSON.stringify({version:nw.App.manifest.releaseVersion,fixture:fixture,scene:s.constructor.name,windows:windows,currentItem:s.item&&s.item()?{id:s.item().id,slots:s.item().augmentSlots,stored:s.item().augmentSlotItems}:null,errors:window.__refErrors||[]});
    },300);
  });
})();
