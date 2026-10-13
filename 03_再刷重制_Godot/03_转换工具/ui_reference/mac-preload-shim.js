/* 参照用浏览器垫片：替代需要 Node 的 mac-preload.js。不读写任何文件；存档只会进浏览器自己的 localStorage。 */
(function () {
    var x = new XMLHttpRequest(); x.open('GET', 'package.json', false); x.send();
    var manifest = JSON.parse(x.responseText);
    var win = { title: '', menu: null, on: function () {}, enterFullscreen: function () {}, leaveFullscreen: function () {}, toggleFullscreen: function () {}, isFullscreen: false, showDevTools: function () {}, focus: function () {}, resizeTo: function () {}, moveTo: function () {} };
    window.nw = { App: { manifest: manifest, startPath: '', argv: [], fullArgv: [], dataPath: '', quit: function () {} }, Window: { get: function () { return win; } }, Menu: function () { return { createMacBuiltin: function () {} }; }, Shell: { openExternal: function () {} } };
    window.MacPort = { root: '', save: '', bundle: '', qa: '', log: function () {} };
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
        function fixture(n) {
            if (!window.DataManager || !DataManager.isDatabaseLoaded()) return;
            ConfigManager.applyData({}); DataManager.setupNewGame();
            $gameSystem.setDifficultyId(3);
            for (var i=1;i<5000;i++) $gameVariables._data[i]=0;
            $gameParty._actors = n===5 ? [1,8,9,10,2] : [1,8,9,10];
            $gameParty._battleMembers = $gameParty._actors.slice();
            // 夹具只观察地图与战斗绘制，不推进地图/公共事件剧情。
            Game_Map.prototype.updateInterpreter = function(){};
            $gameScreen.clear(); $gameMessage.clear(); $gamePlayer.clearTransferInfo(); $gamePlayer.refresh();
            $gameParty.members().forEach(function(a){ [2747,6168,5980].forEach(function(id){a.learnSkill(id);}); a.recoverAll(); });
            $gameParty.gainItem($dataItems[1], 5);
            DataManager.loadMapData(5);
            var wait = setInterval(function(){
                if (!DataManager.isMapLoaded()) return;
                clearInterval(wait); $gameMap.setup(5); $gamePlayer.locate(10,10); $gamePlayer.setDirection(2);
                SceneManager.goto(Scene_Map);
                var ready=setInterval(function(){
                    if (!(SceneManager._scene instanceof Scene_Map) || !ImageManager.isReady() || SceneManager._scene.isBusy()) return;
                    clearInterval(ready);
                    // 避开随机神话并稳定 OTB 同速顺序；不影响正式应用。
                    Math.random = function(){return 0.5;};
                    BattleManager.setup(2,true,false); SceneManager.push(Scene_Battle);
                }, 100);
            }, 20);
        }
        button('战斗夹具 4 人', function(){fixture(4);});
        button('战斗夹具 5 人', function(){fixture(5);});
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
            readout.textContent=JSON.stringify({version:nw.App.manifest.releaseVersion,scene:s.constructor.name,phase:window.BattleManager&&BattleManager._phase,windows:windows,actors:actors,enemies:enemies,victory:window.Olivia&&Olivia.OctoBattle.VictoryUI,errors:__refErrors});
        }, 500);
    });
})();
