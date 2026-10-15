/* 参照用浏览器垫片：替代需要 Node 的 mac-preload.js。不读写任何文件；存档只会进浏览器自己的 localStorage。 */
/* 难度提示专用：记录原插件的三个计时器；按工具栏按钮时才停止并逐次调用原回调。 */
(function () {
    if (!/[?&]difficulty_ref=1(?:&|$)/.test(location.search)) return;
    var original = window.setInterval;
    window.__difficultyRefClocks = {};
    window.setInterval = function (fn, ms) {
        var id = original.apply(this, arguments), code = String(fn);
        var key = ms===60 && /diffId = getDiff/.test(code) ? 'read' :
            ms===30 && /tipTime/.test(code) ? 'tick' : ms===32 && /_tipSpr/.test(code) ? 'paint' : '';
        if (key) window.__difficultyRefClocks[key] = {id:id, call:fn};
        return id;
    };
})();
(function () {
    var x = new XMLHttpRequest(); x.open('GET', 'package.json', false); x.send();
    var manifest = JSON.parse(x.responseText);
    var win = { title: '', menu: null, on: function () {}, enterFullscreen: function () {}, leaveFullscreen: function () {}, toggleFullscreen: function () {}, isFullscreen: false, showDevTools: function () {}, focus: function () {}, resizeTo: function () {}, moveTo: function () {} };
    window.nw = { App: { manifest: manifest, startPath: '', argv: [], fullArgv: [], dataPath: '', quit: function () {} }, Window: { get: function () { return win; } }, Menu: function () { return { createMacBuiltin: function () {} }; }, Shell: { openExternal: function () {} } };
    window.MacPort = { root: '', save: '', bundle: '', qa: '', log: function () {} };
})();
/* ?difficulty_ref=1：真实插件定帧参照。只操作内存新游戏；不创建、不加载任何存档。 */
(function () {
    if (!/[?&]difficulty_ref=1(?:&|$)/.test(location.search)) return;
    addEventListener('load', function () {
        var panel=document.createElement('div');
        panel.style.cssText='position:fixed;left:0;top:100px;z-index:99999;background:white;color:black;font:12px monospace;max-width:900px;max-height:180px;overflow:auto';
        ['mousedown','mouseup','click','touchstart','touchend'].forEach(function(t){panel.addEventListener(t,function(e){e.stopPropagation();});});
        var readout=document.createElement('pre'), draws=[], remaining=0, manual=false;
        function info() {
            var s=window.SceneManager&&SceneManager._scene, sp=s&&s._tipSpr;
            readout.textContent=JSON.stringify({version:window.nw&&nw.App.manifest.releaseVersion,scene:s&&s.constructor.name,
                difficulty:window.$gameSystem&&($gameSystem._difficultyId||2),manual:manual,remaining:remaining,
                tip:sp&&{x:sp.x,y:sp.y,width:sp.bitmap.width,height:sp.bitmap.height,visible:sp.visible,opacity:sp.opacity,
                    font:sp.bitmap.fontFace,fontSize:sp.bitmap.fontSize,bold:sp.bitmap.fontBold,color:sp.bitmap.textColor},
                drawCount:draws.length,draws:draws.slice(-1),errors:window.__refErrors});
        }
        function button(text,fn) {var b=document.createElement('button');b.textContent=text;b.onclick=function(){fn();b.blur();info();};panel.appendChild(b);}
        function clocks() {
            var c=window.__difficultyRefClocks;
            if (!c.read||!c.tick||!c.paint) throw new Error('难度提示的三个原插件计时器未就绪');
            if (!manual) {Object.keys(c).forEach(function(k){clearInterval(c[k].id);});manual=true;}
            return c;
        }
        function paint() {
            var s=SceneManager._scene, sp=s&&s._tipSpr;
            if (sp&&!sp.bitmap.__difficultyRefHook) {
                var draw=sp.bitmap.drawText;
                sp.bitmap.drawText=function(){draws.push({args:Array.prototype.slice.call(arguments),color:this.textColor});return draw.apply(this,arguments);};
                sp.bitmap.__difficultyRefHook=true;
            }
            draws=[];clocks().paint.call();info();
        }
        function setDifficulty(id) {
            if (!window.$gameSystem||!SceneManager._scene._tipSpr) return;
            var c=clocks(), changed=($gameSystem._difficultyId||2)!==id;
            $gameSystem.setDifficultyId(id);c.read.call();c.tick.call();
            remaining=changed?239:Math.max(0,remaining-1);paint();
        }
        button('难度地图夹具',function(){
            if(!window.DataManager||!DataManager.isDatabaseLoaded())return;
            clocks();
            if(SceneManager._scene)SceneManager._scene.update=function(){};SceneManager._scene.isBusy=function(){return false;};
            SceneManager.goto(Scene_Base);ConfigManager.applyData({});DataManager.setupNewGame();
            clocks().read.call();clocks().tick.call();remaining=0;
            Game_Map.prototype.updateInterpreter=function(){};
            if(window.CodexGuide)CodexGuide.MILESTONE_ENABLED=false;
            $gameParty._actors=[1,8,9,10];$gameParty._battleMembers=$gameParty._actors.slice();
            $gamePlayer.clearTransferInfo();$gameScreen.clear();$gameMessage.clear();
            DataManager.loadMapData(5);
            var t=setInterval(function(){
                if(!DataManager.isMapLoaded())return;clearInterval(t);$gameMap.setup(5);$gamePlayer.locate(10,10);$gamePlayer.refresh();
                SceneManager.goto(Scene_Map);
                var ready=setInterval(function(){if(!SceneManager._scene._tipSpr)return;clearInterval(ready);setDifficulty(3);},20);
            },20);
        });
        for(var i=1;i<=9;i++)(function(id){button('难度 '+id,function(){setDifficulty(id);});})(i);
        button('推进 30 格',function(){var c=clocks();for(var n=0;n<30;n++)c.tick.call();remaining=Math.max(0,remaining-30);paint();});
        button('推进至消失',function(){var c=clocks();for(var n=0;n<240;n++)c.tick.call();remaining=0;paint();});
        button('快照进入战斗',function(){
            if(!(SceneManager._scene instanceof Scene_Map))return;
            Math.random=function(){return 0.5;};$gameMessage.clear();BattleManager.setup(2,true,false);SceneManager.push(Scene_Battle);
        });
        button('难度截图',function(){__refShot('dev019_difficulty_d'+($gameSystem._difficultyId||2)+'_'+remaining+'_'+SceneManager._scene.constructor.name);});
        button('隐藏难度工具栏',function(){panel.style.display='none';});
        panel.appendChild(readout);document.body.appendChild(panel);setInterval(info,200);
    });
})();
(function () {
    window.__refErrors = [];
    var t = setInterval(function () {
        if (window.SceneManager && SceneManager.catchException && !SceneManager.__refWrapped) {
            var c = SceneManager.catchException;
            SceneManager.catchException = function (e) { window.__refErrors.push(String(e && e.stack || e)); return c.apply(this, arguments); };
            SceneManager.__refWrapped = true;
        }
    }, 1);
    setTimeout(function () { clearInterval(t); }, 60000);
})();
window.__refShot = function (name) {
    var b = SceneManager.snap();
    var x = new XMLHttpRequest(); x.open('POST', '/__ref_shot/' + name, false); x.send(b._canvas.toDataURL('image/png'));
    return x.status;
};
/* ?map_ref=1：地图 HUD 内存夹具。只修改此浏览器的内存与配置，不加载任何存档。 */
(function () {
    if (!/[?&]map_ref=1(?:&|$)/.test(location.search)) return;
    addEventListener('load', function () {
        var panel = document.createElement('div');
        panel.style.cssText = 'position:fixed;left:0;top:80px;z-index:99999;background:#fff;color:#111;font:12px monospace;max-width:600px;max-height:300px;overflow:auto';
        ['mousedown','mouseup','click','touchstart','touchend'].forEach(function(type){panel.addEventListener(type,function(e){e.stopPropagation();});});
        function button(text, fn) { var b=document.createElement('button'); b.textContent=text; b.onclick=function(){fn();b.blur();}; panel.appendChild(b); }
        function fixture(mid, x, y, coords) {
            if (!window.DataManager || !DataManager.isDatabaseLoaded()) return;
            if (SceneManager._scene instanceof Scene_Map) { SceneManager._scene.update=function(){};SceneManager._scene.isBusy=function(){return false;}; }
            SceneManager.goto(Scene_Base);
            ConfigManager.applyData({}); DataManager.setupNewGame();
            ConfigManager.MapXy=coords;
            $gameSystem.setDifficultyId(3); $gameParty.DCultyL3=true;
            $gameParty._actors=[1,8,10,9]; $gameParty._battleMembers=$gameParty._actors.slice();
            Game_Map.prototype.updateInterpreter=function(){};
            $gameScreen.clear(); $gameMessage.clear(); $gamePlayer.clearTransferInfo(); $gamePlayer.refresh();
            DataManager.loadMapData(mid);
            var wait=setInterval(function(){
                if (!DataManager.isMapLoaded()) return;
                clearInterval(wait); $gameMap.setup(mid); $gameSystem.unlockMap(mid);
                $gamePlayer.locate(x,y); $gamePlayer.setDirection(2); $gamePlayer.followers().synchronize(x,y,2);
                SceneManager.goto(Scene_Map);
            },20);
        }
        button('教派地图夹具',function(){fixture(221,13,11,false);});
        button('大厅地图夹具',function(){fixture(4,14,23,true);});
        button('一层地图夹具',function(){fixture(5,11,13,true);});
        button('截图',function(){var s=SceneManager._scene;__refShot('v013_map_'+$gameMap.mapId()+'_'+s.constructor.name);});
        button('隐藏工具栏',function(){panel.style.display='none';});
        var details=document.createElement('details'), summary=document.createElement('summary'), readout=document.createElement('pre');
        summary.textContent='地图运行时读数'; details.appendChild(summary); details.appendChild(readout); panel.appendChild(details); document.body.appendChild(panel);
        var hooked=false;
        setInterval(function(){
            if (!window.SceneManager || !SceneManager._scene) return;
            if (!hooked && window.Bitmap) {
                var draw=Bitmap.prototype.drawText;
                Bitmap.prototype.drawText=function(){(this.__refText||(this.__refText=[])).push(Array.prototype.slice.call(arguments));return draw.apply(this,arguments);};
                hooked=true;
            }
            var s=SceneManager._scene,windows=[];
            function info(x) {return x&&{type:x.constructor.name,x:x.x,y:x.y,w:x.width,h:x.height,font:x.bitmap&&x.bitmap.fontSize,text:x.bitmap&&x.bitmap.__refText};}
            function walk(x){if (x instanceof Window_Base) windows.push({type:x.constructor.name,x:x.x,y:x.y,w:x.width,h:x.height,padding:x.padding,font:x.contents&&x.contents.fontSize,text:x.contents&&x.contents.__refText,index:x.index?x.index():null});(x.children||[]).forEach(walk);}
            walk(s);
            readout.textContent=JSON.stringify({scene:s.constructor.name,map:window.$gameMap&&$gameMap.mapId(),windows:windows,backup:info(s._backupBtn),transfer:info(s._mapTransferButton),leaf:info(s._huicheng_Sprite),coords:s._StarInter&&info(s._StarInter._cont),errors:__refErrors});
        },500);
    });
})();
/* ?battle_ref=1：独立内存战斗夹具；按钮只驱动此浏览器，不读取存档。 */
(function () {
    if (!/[?&]battle_ref=1(?:&|$)/.test(location.search)) return;
    addEventListener('load', function () {
        var panel = document.createElement('div');
        panel.style.cssText = 'position:fixed;left:0;top:0;z-index:99999;background:#fff;color:#111;font:12px monospace;max-height:150px;overflow:auto';
        var readout = document.createElement('pre');
        // 工具栏点击不能同时落进 MV TouchInput（否则「截图」会确认/关闭游戏窗口）。
        ['mousedown','mouseup','click','touchstart','touchend'].forEach(function(type){panel.addEventListener(type,function(e){e.stopPropagation();});});
        function button(text, fn) { var b = document.createElement('button'); b.textContent = text; b.onclick = function(){fn();b.blur();}; panel.appendChild(b); }
        function fixture(n, dropRecord) {
            if (!window.DataManager || !DataManager.isDatabaseLoaded()) return;
            if (SceneManager._scene instanceof Scene_Map) { SceneManager._scene.update=function(){};SceneManager._scene.isBusy=function(){return false;}; }
            SceneManager.goto(Scene_Base);
            ConfigManager.applyData({}); DataManager.setupNewGame();
            if(dropRecord){ConfigManager.MOG_TrPopUpBattle_Key=true;ConfigManager.CombatDamageRecordKey=true;}
            $gameSystem.setDifficultyId(3);
            for (var i=1;i<5000;i++) $gameVariables._data[i]=0;
            $gameParty._actors = n===5 ? [1,8,9,10,2] : [1,8,9,10];
            $gameParty._battleMembers = $gameParty._actors.slice();
            // 夹具只观察地图与战斗绘制，不推进地图/公共事件剧情。
            Game_Map.prototype.updateInterpreter = function(){};
            $gameScreen.clear(); $gameMessage.clear(); $gamePlayer.clearTransferInfo(); $gamePlayer.refresh();
            $gameParty.members().forEach(function(a){
                [6168,5980,5548].concat([1,2,3,4,5,6,7,52].indexOf(a.actorId())>=0 ? [2571,2786] : []).forEach(function(id){a.learnSkill(id);});
                a.initPassiveCache(); a.refreshPassiveCache(); a.recoverAll();
            });
            $gameParty.gainItem($dataItems[1], 5);
            DataManager.loadMapData(5);
            var wait = setInterval(function(){
                if (!DataManager.isMapLoaded()) return;
                clearInterval(wait); $gameMap.setup(5); $gamePlayer.locate(10,10); $gamePlayer.setDirection(2);
                SceneManager.goto(Scene_Map);
                var ready=setInterval(function(){
                    // 地图的首次修行指引会令 isBusy 一直为真；本夹具只观察画面，先清内存消息再等待场景就绪。
                    if(SceneManager._scene instanceof Scene_Map)$gameMessage.clear();
                    if (!(SceneManager._scene instanceof Scene_Map) || !ImageManager.isReady()) return;
                    SceneManager._scene.isBusy=function(){return false;}; // 仅此内存布局夹具，忽略原生指引等待。
                    $gameMessage.clear();
                    clearInterval(ready);
                    // 避开随机神话并稳定 OTB 同速顺序；不影响正式应用。
                    Math.random = function(){return dropRecord ? 0.01 : 0.5;};
                    BattleManager.setup(2,true,false);
                    if(dropRecord)$gameTroop.members()[0].setHp(1);
                    SceneManager.push(Scene_Battle);
                }, 100);
            }, 20);
        }
        button('战斗夹具 4 人', function(){fixture(4);});
        button('战斗夹具 5 人', function(){fixture(5);});
        button('掉落与记录对照截图', function(){
            fixture(4,true);
            var attacked=false,tries=0;
            var sample=setInterval(function(){
                var s=SceneManager._scene;
                if(++tries>2000){clearInterval(sample);return;}
                if(!(s instanceof Scene_Battle))return;
                if(!attacked&&s._actorCommandWindow&&s._actorCommandWindow.active){
                    // 布局夹具：只触发第一只敌人的真实倒下／掉落动画；伤害统计规则另由 drop_record_probe 严格对照。
                    attacked=true;$gameTroop.members()[0].setHp(0);$gameTroop.members()[0].performCollapse();
                }
                var field=s._spriteset&&s._spriteset._battleField;
                var popup=field&&(field.children||[]).some(function(x){return x instanceof SpriteEnemyTrP&&x.visible;});
                if(popup){
                    clearInterval(sample);s.update=function(){};
                    setTimeout(function(){__refShot('codex_drop_record_reference');},150);
                }
            },16);
        });
        // 三项偏好仅在本浏览器内存切换，不调用 ConfigManager.save。
        button('伤害数字 开/关', function(){ConfigManager.CombatDamageShow=!ConfigManager.CombatDamageShow;});
        button('技能动画 开/关', function(){ConfigManager.CombatSkillAnimation=!ConfigManager.CombatSkillAnimation;});
        button('战斗变速 下一档', function(){ConfigManager.battleAniSpeed=ConfigManager.battleAniSpeed%4+1;});
        var actionTrace=null;
        button('测量普通攻击', function(){
            var s=SceneManager._scene;
            if (!(s instanceof Scene_Battle)||!s._actorCommandWindow.active||actionTrace&&actionTrace.running) return;
            var actor=BattleManager.actor(), enemy=$gameTroop.members().filter(function(e){return e.isAlive();})[0];
            if(!actor||!enemy)return;
            actionTrace={running:true,speed:ConfigManager.battleAniSpeed,animation:ConfigManager.CombatSkillAnimation,damage:ConfigManager.CombatDamageShow,actor:actor.actorId(),frames:0,hit:null,logClear:null,nextInput:null};
            var original=s.update, apply=Game_Action.prototype.apply;
            Game_Action.prototype.apply=function(target){
                apply.apply(this,arguments);
                if(actionTrace.hit===null&&this.subject()===actor)actionTrace.hit=actionTrace.frames;
            };
            s._actorCommandWindow.deactivate();s.commandAttack();s._enemyWindow.select($gameTroop.members().indexOf(enemy));s._enemyWindow.deactivate();s.onEnemyOk();
            s.update=function(){
                original.apply(this,arguments);actionTrace.frames++;
                if(actionTrace.hit!==null&&actionTrace.logClear===null&&this._logWindow._lines.length===0)actionTrace.logClear=actionTrace.frames;
                if(actionTrace.hit!==null&&this._actorCommandWindow.active){
                    actionTrace.nextInput=actionTrace.frames;actionTrace.running=false;this.update=original;Game_Action.prototype.apply=apply;
                }
                if(actionTrace.frames>1200){actionTrace.running=false;this.update=original;Game_Action.prototype.apply=apply;}
            };
        });
        button('胜利结算夹具', function(){
            if (!(SceneManager._scene instanceof Scene_Battle)) return;
            $gameTroop.members().forEach(function(e){e.setHp(0);});
            BattleManager.processVictory();
        });
        button('截图', function(){
            var s=SceneManager._scene;
            var state = s._victoryWindow ? 'victory' : s._enemyWindow && s._enemyWindow.active ? 'target' : s._skillWindow && s._skillWindow.active ? 'skill' : s._itemWindow && s._itemWindow.active ? 'item' : 'command';
            __refShot('v008_battle_'+$gameParty.battleMembers().length+'_'+state);
        });
        button('隐藏工具栏', function(){panel.style.display='none';});
        var details=document.createElement('details'); var summary=document.createElement('summary'); summary.textContent='运行时读数'; details.appendChild(summary); details.appendChild(readout); panel.appendChild(details); document.body.appendChild(panel);
        setInterval(function(){
            var s=window.SceneManager && SceneManager._scene;
            if (!s) return;
            var windows=[];
            function walk(x){
                if (x instanceof Window_Base) windows.push({type:x.constructor.name,x:x.x,y:x.y,w:x.width,h:x.height,padding:x.padding,font:x.contents&&x.contents.fontSize,visible:x.visible,active:x.active,index:x.index?x.index():null});
                (x.children||[]).forEach(walk);
            }
            walk(s);
            var sp=s._spriteset;
            var actors=sp&&sp._actorSprites ? sp._actorSprites.map(function(x){return {id:x._actor&&x._actor.actorId(),x:x.x,y:x.y,home:[x._homeX,x._homeY]};}) : [];
            var enemies=sp&&sp._enemySprites ? sp._enemySprites.map(function(x){return {id:x._enemy&&x._enemy.enemyId(),name:x._enemy&&x._enemy.name(),x:x.x,y:x.y,cursor:x._battleSelectCursorSprite&&[x._battleSelectCursorSprite.x,x._battleSelectCursorSprite.y]};}) : [];
            readout.textContent=JSON.stringify({version:nw.App.manifest.releaseVersion,scene:s.constructor.name,phase:window.BattleManager&&BattleManager._phase,display:{damage:ConfigManager.CombatDamageShow,animation:ConfigManager.CombatSkillAnimation,speed:ConfigManager.battleAniSpeed},actionTrace:actionTrace,windows:windows,actors:actors,enemies:enemies,victory:window.Olivia&&Olivia.OctoBattle.VictoryUI,errors:__refErrors});
        }, 500);
    });
})();
/* ?item_marks_ref=1：dev.039 一键出售窗口参照。只创建内存新游戏，不读玩家存档。 */
(function () {
    if (!/[?&]item_marks_ref=1(?:&|$)/.test(location.search)) return;
    addEventListener('load', function () {
        var panel=document.createElement('div'), readout=document.createElement('pre');
        panel.style.cssText='position:fixed;left:0;top:0;z-index:99999;background:white;color:black;font:12px monospace;max-width:900px;max-height:110px;overflow:auto';
        ['mousedown','mouseup','click','touchstart','touchend'].forEach(function(t){panel.addEventListener(t,function(e){e.stopPropagation();});});
        function button(text, fn) {var b=document.createElement('button');b.textContent=text;b.onclick=function(){fn();b.blur();};panel.appendChild(b);}
        button('一键出售夹具',function(){
            if(!window.DataManager||!DataManager.isDatabaseLoaded())return;
            ConfigManager.applyData({});DataManager.setupNewGame();$gameParty.gainGold(1000);
            $gameParty.gainItem($dataItems[1],3);$gameParty.gainItem($dataWeapons[1],1);
            $gameMessage.clear();SceneManager.goto(Scene_Shop);SceneManager.prepareNextScene([[0,1,0,0]],false);
            var timer=setInterval(function(){var s=SceneManager._scene;if(!(s instanceof Scene_Shop)||!s._ShopOnekeySellWindow)return;
                clearInterval(timer);s._commandWindow.deactivate();s._commandWindow.selectSymbol('Onekeysell');s.commandOnekeySell();
                var win=s._ShopOnekeySellWindow;readout.textContent=JSON.stringify({rect:[win.x,win.y,win.width,win.height],lineHeight:win.lineHeight(),padding:win.padding,commands:win._list.map(function(c){return c.name;}),errors:window.__refErrors});
            },20);
        });
        button('一键出售截图',function(){__refShot('codex_onekey_reference');});
        button('多货币买入夹具',function(){
            if(!window.DataManager||!DataManager.isDatabaseLoaded())return;
            ConfigManager.applyData({});DataManager.setupNewGame();$gameParty._actors=[1,8,9,10];
            $gameParty.gainGold(12345);$gameVariables.setValue(206,5000);
            $gameParty.gainItem($dataItems[182],400);$gameParty.gainItem($dataItems[2201],50);$gameMessage.clear();
            SceneManager.goto(Scene_Shop);SceneManager.prepareNextScene([[0,2230,0,0],[2,4375,0,0],[0,732,0,0]],false);
            var timer=setInterval(function(){var s=SceneManager._scene;if(!(s instanceof Scene_Shop)||!s._buyWindow)return;
                clearInterval(timer);s._commandWindow.deactivate();s.commandBuy();s._buyWindow.select(0);s._buyWindow.updateHelp();
                readout.textContent=JSON.stringify({goods:s._goods,buy:[s._buyWindow.x,s._buyWindow.y,s._buyWindow.width,s._buyWindow.height],gold:[s._goldWindow.x,s._goldWindow.y,s._goldWindow.width,s._goldWindow.height],errors:window.__refErrors});
            },20);
        });
        button('买入数量窗',function(){var s=SceneManager._scene;if(s instanceof Scene_Shop&&s._buyWindow.active){s.onBuyOk();
            readout.textContent=JSON.stringify({number:s._numberWindow._number,max:s._numberWindow._max,rect:[s._numberWindow.x,s._numberWindow.y,s._numberWindow.width,s._numberWindow.height],errors:window.__refErrors});}});
        button('买入复核截图',function(){__refShot('codex_shop_buy_reference');});
        button('隐藏一键工具栏',function(){panel.style.display='none';});
        panel.appendChild(readout);document.body.appendChild(panel);
    });
})();
