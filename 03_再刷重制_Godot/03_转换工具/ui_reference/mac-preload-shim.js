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
/* 声音（用户 2026-10-16）：参照浏览器默认静音。WebAudio 主音量固定为 0（之后游戏再设也不生效），
   Html5Audio 与视频元素也静音；网址加 ?sound=1 时不处理。只改本浏览器内存，不碰配置与存档。 */
(function () {
    if (/[?&]sound=1(?:&|$)/.test(location.search)) return;
    window.__refMuted = true;
    addEventListener('load', function () {
        if (window.WebAudio) {
            WebAudio.setMasterVolume(0);
            var setVolume = WebAudio.setMasterVolume;
            WebAudio.setMasterVolume = function () { return setVolume.call(this, 0); };
        }
        if (window.Html5Audio && Html5Audio._audioElement) Html5Audio._audioElement.muted = true;
        if (window.Graphics && Graphics._video) Graphics._video.muted = true;
    });
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
window.__refJson = function (name, obj) {
    var x = new XMLHttpRequest(); x.open('POST', '/__ref_json/' + name, false); x.send(JSON.stringify(obj));
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
        // 图标 dh 闪光：第一只敌人倒下时掉落三件带 <dh:N> 的防具（默认 108 生命披风 dh179、130 队员死霸装 dh183、
        // 57 萌萌怪的毛布护甲 dh143），逐帧记录 SpriteEnemyTrP 的子节点（图标与 Sprite_Animation、屏幕闪光），
        // 到 shotFrame 帧定格截图 dh_drop_reference_f<帧>。页面内 JS 也可调 __dhRef.run({drops:[防具ID…],shotFrame:N,rand:[…],shot:名字})，
        // 读 __dhRef.trace。每次跑之前重载页面（夹具战斗里再开新局，离开战斗时 AB_EnemyBook.onBattleEnd 会报错）。
        // 只测画面，掉落规则另见 drop_record_probe。
        var dh=window.__dhRef={trace:null};
        dh.run=function(o){
            o=o||{};var ids=o.drops||[108,130,57],shot=o.shotFrame===undefined?3:o.shotFrame,maxFrames=o.frames||240;
            var T0=dh.trace;if(T0)T0.done=true;
            fixture(4,true);
            var T=dh.trace={target:null,drops:ids,shotFrame:shot,frames:[],samples:null,done:false,battleAniSpeed:null,enemy:null};
            if(!SpriteEnemyTrP.prototype.__dhWrapped){
                var up=SpriteEnemyTrP.prototype.update;
                SpriteEnemyTrP.prototype.update=function(){up.call(this);if(dh.hook)dh.hook(this);};
                SpriteEnemyTrP.prototype.__dhWrapped=true;
            }
            function node(c,icons){
                if(c instanceof Sprite_Animation){
                    var f=c._screenFlashSprite;
                    return {anim:c._animation&&c._animation.id,target:icons.indexOf(c._target),x:c.x,y:c.y,duration:c._duration,rate:c._rate,
                        frame:c.isPlaying()?c.currentFrameIndex():null,cells:c._cellSprites.filter(function(s){return s.visible;}).length,
                        screenFlash:f&&{opacity:f.opacity,visible:f.visible,x:f.x,y:f.y,rgb:[f._red,f._green,f._blue],duration:c._screenFlashDuration}};
                }
                return {icon:c.item&&c.item.id,x:c.x,y:c.y,sx:c.scale.x,sy:c.scale.y,opacity:c.opacity,visible:c.visible,intY:c.intY,ry:c.ry,dy:c.dy,vx:c.sx,wait:c.wait,height:c.height};
            }
            function samples(trp){
                // 色相：同一格子在原图（hue 0）与动画实际用的 hue 图上的像素，供 Godot 着色器逐点对照。
                var out=[];
                trp.children.forEach(function(c){
                    if(!(c instanceof Sprite_Animation))return;
                    var a=c._animation,raw=ImageManager.loadAnimation(a.animation1Name,0);
                    if(!raw.isReady()||!c._bitmap1.isReady())return;
                    // 只取不透明度 ≥160 的点（画布读回会把低不透明度像素的颜色量化），最多 48 个。
                    var pts=[];for(var y=5;y<c._bitmap1.height&&pts.length<48;y+=11)for(var x=3;x<c._bitmap1.width&&pts.length<48;x+=37)
                        if(raw.getAlphaPixel(x,y)>=160)pts.push([x,y,raw.getPixel(x,y),c._bitmap1.getPixel(x,y),raw.getAlphaPixel(x,y)]);
                    out.push({anim:a.id,name:a.animation1Name,hue:a.animation1Hue,points:pts});
                });
                return out;
            }
            dh.hook=function(trp){
                if(T.done||!T.target||trp._enemy!==T.target)return; // 只记本次倒下的敌人（旧场景的掉落不算）
                var icons=trp._icons||[];
                if(!T.enemy)T.enemy={x:trp._sprite.x,y:trp._sprite.y,height:trp._sprite.height,z:trp.z};
                T.battleAniSpeed=ConfigManager.battleAniSpeed;
                T.frames.push({n:T.frames.length+1,x:trp.x,y:trp.y,visible:trp.visible,children:trp.children.map(function(c){return node(c,icons);})});
                if(!T.samples){var sm=samples(trp);if(sm.length)T.samples=sm;}
                if(T.frames.length===shot){var s=SceneManager._scene;var u=s.update;s.update=function(){};
                    setTimeout(function(){__refShot(o.shot||'dh_drop_reference_f'+shot);s.update=u;},150);}
                if(T.frames.length>=maxFrames)T.done=true;
            };
            var attacked=false,tries=0,old=SceneManager._scene; // 连续再跑时，旧战斗场景要等真正换掉
            var t=setInterval(dh.tick=function(){
                var s=SceneManager._scene;
                if(++tries>3000||T.done){clearInterval(t);dh.tick=null;return;}
                if(s===old||!(s instanceof Scene_Battle)||attacked||!s._actorCommandWindow||!s._actorCommandWindow.active)return;
                attacked=true;var e=T.target=$gameTroop.members()[0];
                e.makeDropItems=function(){return ids.map(function(id){return $dataArmors[id];});};
                // rand：之后 Math.random 依次循环取这些值（改变各图标的 intY／横向速度与排序）；不给时沿用夹具的 0.01。
                if(o.rand){var k=0;Math.random=function(){return o.rand[k++%o.rand.length];};}
                e.setHp(0);e.performCollapse();
            },16);
            return T;
        };
        // 内置浏览器窗格不在前台时 requestAnimationFrame 停摆：pump 手动按 MV 主循环推进（每帧一次
        // updateInputData/changeScene/updateScene/renderScene），帧间用 MessageChannel 让出事件循环以便图片加载。
        dh.pump=function(o){
            o=o||{};var until=o.until||function(){return dh.trace&&dh.trace.done;},limit=Date.now()+(o.ms||40000);
            var ch=new MessageChannel();
            return new Promise(function(ok){
                ch.port1.onmessage=function(){
                    if(until()||Date.now()>limit){ok(!!until());return;}
                    SceneManager.updateInputData();SceneManager.changeScene();SceneManager.updateScene();SceneManager.renderScene();
                    if(dh.tick)dh.tick();
                    ch.port2.postMessage(0);
                };
                ch.port2.postMessage(0);
            });
        };
        button('dh 掉落逐帧读数',function(){dh.run();});
        // 技能动画逐帧：在战斗者精灵上 startAnimation（敌人目标是 Sprite_Enemy，角色是 _mainSprite），每帧 Spriteset_Battle.update
        // 之后记 Sprite_Animation 的位置（相对目标精灵）、剩余时长、帧序、目标混合色与显示、屏幕闪光，到移除后再 2 帧。
        // 页面内 JS：__animRef.run({anim:ID, side:'enemy'|'actor', index:0}) 后 await __animRef.pump()，读 __animRef.trace。
        // 先在战斗夹具里等到角色指令窗口；动画图事先载好（不计异步加载等待）。只测画面。
        var ar=window.__animRef={trace:null};
        ar.run=function(o){
            var T=ar.trace={anim:o.anim,side:o.side||'enemy',index:o.index||0,frames:[],samples:null,done:false,rate:null,target:null};
            var a=$dataAnimations[o.anim],b1=ImageManager.loadAnimation(a.animation1Name,a.animation1Hue),b2=ImageManager.loadAnimation(a.animation2Name,a.animation2Hue);
            var raw=ImageManager.loadAnimation(a.animation1Name,0);
            if(!Spriteset_Battle.prototype.__arWrapped){
                var up=Spriteset_Battle.prototype.update;
                Spriteset_Battle.prototype.update=function(){up.call(this);if(ar.hook)ar.hook(this);};
                Spriteset_Battle.prototype.__arWrapped=true;
            }
            var sprite=null,anim=null,removed=0;
            ar.hook=function(ss){
                if(T.done)return;
                if(!anim){
                    if(!b1.isReady()||!b2.isReady()||!raw.isReady())return;
                    var list=T.side==='actor'?ss._actorSprites:ss._enemySprites;
                    var battlers=T.side==='actor'?$gameParty.battleMembers():$gameTroop.members();
                    sprite=list.filter(function(s){return s._battler===battlers[T.index];})[0];
                    sprite.startAnimation(a,false,0);anim=sprite._animationSprites[sprite._animationSprites.length-1];
                    T.rate=anim._rate;T.target={x:sprite.x,y:sprite.y,height:sprite._effectTarget.height,effect:sprite._effectTarget===sprite?'self':'main'};
                    var pts=[];for(var y=5;y<b1.height&&pts.length<48;y+=11)for(var x=3;x<b1.width&&pts.length<48;x+=37)
                        if(raw.getAlphaPixel(x,y)>=160)pts.push([x,y,raw.getPixel(x,y),b1.getPixel(x,y),raw.getAlphaPixel(x,y)]);
                    T.samples={name:a.animation1Name,hue:a.animation1Hue,points:pts};
                    return;
                }
                var t=anim._target,f=anim._screenFlashSprite,live=!!anim.parent;
                if(!live)removed++;
                T.frames.push({n:T.frames.length+1,live:live,x:anim.x-sprite.x,y:anim.y-sprite.y,duration:anim._duration,
                    frame:anim.isPlaying()?anim.currentFrameIndex():null,cells:anim._cellSprites.filter(function(s){return s.visible;}).length,
                    blend:t.getBlendColor().slice(),targetVisible:t.visible,flashDuration:anim._flashDuration,hiding:anim._hidingDuration,
                    screen:f&&{opacity:f.opacity,visible:f.visible,duration:anim._screenFlashDuration}});
                if(removed>=2)T.done=true;
            };
            return T;
        };
        ar.pump=function(o){o=o||{};return dh.pump({until:function(){return ar.trace&&ar.trace.done;},ms:o.ms});};
        // 夹具套件：动画 3（目标闪光＋屏幕闪光，含四倍速）、14（转色相 135）、24（隐藏目标，敌人与角色），
        // 压成 frames 行后 __refJson('mv_anim_oracle') 写到截图目录，复制到 tests/fixtures/mv_anim_oracle.json。
        ar.suite=async function(){
            var cases=[['flash3',{anim:3,side:'enemy'},4],['hue14',{anim:14,side:'enemy'},4],['hide24_actor',{anim:24,side:'actor'},4],
                ['hide24_enemy',{anim:24,side:'enemy'},4],['flash3_speed1',{anim:3,side:'enemy'},1]];
            var out={note:'ui_reference __animRef.suite()：正式版 Sprite_Animation 逐帧（Spriteset_Battle.update 之后），战斗夹具 4 人、敌群 2。'+
                'frames 行：[n, 未移除, 相对目标 dx, dy, _duration, 帧序, 可见格数, 目标混合色 r, g, b, a, 目标可见, 屏幕闪光不透明度, 屏幕闪光可见]',traces:{}};
            for(var i=0;i<cases.length;i++){
                var c=cases[i];ConfigManager.battleAniSpeed=c[2];ar.run(c[1]);var ok=await ar.pump({ms:30000});var t=ar.trace;
                out.traces[c[0]]={ok:ok,anim:t.anim,side:t.side,index:t.index,speed:c[2],rate:t.rate,target:t.target,
                    samples:t.samples.hue?{name:t.samples.name,hue:t.samples.hue,points:t.samples.points.slice(0,24)}:null,
                    frames:t.frames.map(function(f){return [f.n,f.live?1:0,f.x,f.y,f.duration,f.frame,f.cells,f.blend[0],f.blend[1],f.blend[2],
                        Math.round(f.blend[3]*1000)/1000,f.targetVisible?1:0,Math.round(f.screen.opacity*1000)/1000,f.screen.visible?1:0];})};
            }
            ConfigManager.battleAniSpeed=4;
            __refJson('mv_anim_oracle',out);
            return out;
        };
        // YEP 行动序列画面逐帧：在战斗夹具等到角色指令窗口后 __seqRef.run({skill:ID, target:敌人序号, camera:true|false})，
        // 再 await __seqRef.pump()。当前行动角色学会该技能、补满 MP/TP 后照指令窗流程出招；每帧 Spriteset_Battle.update 之后记
        // 每个战斗者精灵（位置、移动偏移、朝向、不透明度、浮空/跳跃高度、动作、帧格）与镜头（场景层位置与缩放、$gameScreen 镜头点）、
        // 窗口层位置（HIDE BATTLE HUD）、日志行数，另记每条序列指令开始执行的帧。到该角色的行动结束为止。只测画面。
        var sr=window.__seqRef={trace:null};
        var r3=function(v){return Math.round(v*1000)/1000;};
        sr.run=function(o){
            o=o||{};var s=SceneManager._scene;
            if(!(s instanceof Scene_Battle)||!s._actorCommandWindow||!s._actorCommandWindow.active)throw new Error('先等到角色指令窗口');
            ConfigManager.battleCamera=o.camera!==false;ConfigManager.CombatSkillAnimation=!!o.anim;
            var actor=BattleManager.actor(),skill=$dataSkills[o.skill];
            actor.learnSkill(o.skill);actor.setMp(actor.mmp);actor.setTp(actor.maxTp());
            // 连续出招时不让战斗结束：敌人加 100 万生命、全员回满（只改这场内存战斗）。
            $gameTroop.members().forEach(function(e){if(!e.__srTough){e.addParam(0,1000000);e.__srTough=true;}e.recoverAll();});
            $gameParty.battleMembers().forEach(function(a){a.recoverAll();});
            // prep(actor, 目标敌人)：另设场景（如反击致死：行动者 1 HP、目标加反击）；只改这场内存战斗
            if(o.prep)o.prep(actor,$gameTroop.members()[o.target||0]);
            var T=sr.trace={skill:o.skill,actor:actor.actorId(),camera:ConfigManager.battleCamera,speed:ConfigManager.battleAniSpeed,
                animation:ConfigManager.CombatSkillAnimation,battlers:null,frames:[],cmds:[],done:false,started:false};
            if(!BattleManager.__srWrapped){
                var proc=BattleManager.processActionSequence;
                BattleManager.processActionSequence=function(name,args){
                    var t=sr.trace;if(t&&!t.done)t.cmds.push([t.frames.length,name,(args||[]).slice()]);
                    return proc.call(this,name,args);
                };
                BattleManager.__srWrapped=true;
                var up=Spriteset_Battle.prototype.update;
                Spriteset_Battle.prototype.update=function(){up.call(this);if(sr.hook)sr.hook(this);};
            }
            var motionName=function(sp){for(var k in Sprite_Actor.MOTIONS)if(Sprite_Actor.MOTIONS[k]===sp._motion)return k;return '';};
            var jump=function(sp){if(!(sp._jumpDur>0))return 0;var x=sp._jumpFull-sp._jumpDur,h=sp._jumpFull/2,k=sp._jumpHeight;return -k/(h*h)*(x-h)*(x-h)+k;};
            sr.hook=function(ss){
                if(T.done)return;
                var list=ss.battlerSprites().filter(function(sp){return sp._battler;});
                if(!T.battlers)T.battlers=list.map(function(sp){var b=sp._battler;
                    return {key:b.isActor()?'a'+b.actorId():'e'+b.index(),home:[sp._homeX,sp._homeY],width:b.spriteWidth(),height:b.spriteHeight()};});
                if(!T.started)return;
                var lw=SceneManager._scene._logWindow;
                T.frames.push({phase:BattleManager._phase,wait:lw._waitMode,count:lw._waitCount,lines:lw._lines.length,
                    methods:lw._methods.map(function(m){return m.name;}),
                    field:[ss.x,ss.y,r3(ss.scale.x)],zoom:[r3($gameScreen._zoomX),r3($gameScreen._zoomY),r3($gameScreen._zoomScale)],
                    hud:BattleManager._windowLayer?BattleManager._windowLayer.x:0,
                    sprites:list.map(function(sp){var b=sp._battler,main=sp._mainSprite;
                        return [r3(sp.x),r3(sp.y),r3(sp._offsetX),r3(sp._offsetY),sp.scale.x<0?1:0,r3(sp.opacity),r3(sp._floatHeight||0),r3(jump(sp)),
                            b.isActor()?motionName(sp):'',b.isActor()?sp._pattern:0,r3(main&&main.bitmap?main.anchor.y:sp.anchor.y),sp.visible?1:0];}),
                    // 敌人：[实际 HP, YEP_X_VisualHpGauge 显示值]（多段攻击血条逐段变化用）
                    hp:list.map(function(sp){var b=sp._battler,g=sp._visualHpGauge;return b.isEnemy()?[b.hp,g?g._displayedValue:null]:null;})});
                if(BattleManager._subject!==actor||BattleManager._phase==='input'||T.frames.length>=1500)T.done=true;
            };
            s._actorCommandWindow.deactivate();
            var act=actor.inputtingAction();act.setSkill(o.skill);
            T.started=true;
            if(act.isForOpponent()&&!act.isForAll()){s._enemyWindow.select(o.target||0);s._enemyWindow.deactivate();s.onEnemyOk();}
            else{act.setTarget(o.target||0);s.selectNextCommand();}
            return T;
        };
        sr.pump=function(o){o=o||{};return dh.pump({until:function(){return sr.trace&&sr.trace.done;},ms:o.ms});};
        // 套件：普通攻击、幻化龙爪 65（透明/镜头/缩放/击退）开与关镜头、104（跳跃/隐藏界面/SE）、161（浮空）、51（动画/等待/咏唱）。
        // 每条跑完刷新页面重开夹具更稳；此处按顺序在同一场战斗里接着出招（每条之后等回到角色指令窗口）。
        // name：写出的读数名（默认 action_sequence_oracle；另跑几招时另起名，免得覆盖 9 段套件）
        sr.suite=async function(list,name){
            list=list||[['attack',{skill:1}],['s65',{skill:65}],['s65_nocam',{skill:65,camera:false}],['s104',{skill:104}],['s161',{skill:161}],['s51',{skill:51}],['attack_anim',{skill:1,anim:true}],['s65_anim',{skill:65,anim:true}],['s73',{skill:73}]];
            var out=sr.out={note:'ui_reference __seqRef.suite()：正式版 YEP 行动序列逐帧（Spriteset_Battle.update 之后），战斗夹具 4 人、敌群 2。'+
                'sprites 行：[x, y, _offsetX, _offsetY, 朝向反转, 不透明度, 浮空率, 跳跃率, 动作, 帧格, 身体锚点 y, 可见]',traces:{}};
            // 先载好要用的动画图（正式版首次播放要等图片异步载入，几十帧不等，Godot 已预载，不比这一段）
            await dh.pump({until:function(){var s=SceneManager._scene;return s instanceof Scene_Battle&&s._actorCommandWindow&&s._actorCommandWindow.active;},ms:60000});
            var ids=[51,52];$gameParty.battleMembers().forEach(function(a){ids.push(a.attackAnimationId1(),a.attackAnimationId2());});
            list.forEach(function(c){var k=$dataSkills[c[1].skill];ids.push(k.animationId,k.castAnimation||0);
                [k.setupActions,k.wholeActions,k.targetActions,k.followActions,k.finishActions].forEach(function(l){(l||[]).forEach(function(x){var m=String(x[0]).match(/ANIMATION[ ](\d+)/i);if(m)ids.push(+m[1]);});});});
            var bms=[];ids.forEach(function(id){var a=id>0&&$dataAnimations[id];if(a&&a.frames){bms.push(ImageManager.loadAnimation(a.animation1Name,a.animation1Hue),ImageManager.loadAnimation(a.animation2Name,a.animation2Hue));}});
            await dh.pump({until:function(){return bms.every(function(b){return b.isReady();});},ms:30000});
            for(var i=0;i<list.length;i++){
                await dh.pump({until:function(){var s=SceneManager._scene;return s instanceof Scene_Battle&&s._actorCommandWindow&&s._actorCommandWindow.active;},ms:60000});
                sr.run(list[i][1]);var ok=await sr.pump({ms:60000});
                out.traces[list[i][0]]=Object.assign({ok:ok},sr.trace);
            }
            ConfigManager.battleCamera=true;ConfigManager.CombatSkillAnimation=false;
            __refJson(name||'action_sequence_oracle',out);
            return out;
        };
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
/* ?item_list_ref=1：物品列表一组（NEW 角标、「序号/9,999」、战斗物品窗口）参照。只建内存新游戏，不读写玩家存档；
   页面内 JS 调 __ilr.*：newGame() 建四人新局，go(场景类) 切场景并等就绪，rows(窗口) 读每行的数据、已看过状态与当前画面
   （newShown：该行此刻是否画着 newIcon；texts：该行此刻的文字），saveRoundTrip() 只在内存里做存读档序列化。 */
(function () {
    if (!/[?&]item_list_ref=1(?:&|$)/.test(location.search)) return;
    var R = window.__ilr = {};
    var hooked = false;
    function hook() {
        if (hooked || !window.Bitmap || !window.Galv) return;
        hooked = true;
        var blt = Bitmap.prototype.blt, clearRect = Bitmap.prototype.clearRect, clear = Bitmap.prototype.clear, drawText = Bitmap.prototype.drawText;
        Bitmap.prototype.blt = function (src, sx, sy, sw, sh, dx, dy) {
            if (src && src === ImageManager.loadSystem(Galv.NII.newIcon)) (this.__ilrNew || (this.__ilrNew = [])).push([dx, dy]);
            return blt.apply(this, arguments);
        };
        Bitmap.prototype.drawText = function (text, x, y, w, h, align) {
            (this.__ilrText || (this.__ilrText = [])).push({text: String(text), x: x, y: y, w: w, align: align || 'left', size: this.fontSize, color: this.textColor});
            return drawText.apply(this, arguments);
        };
        Bitmap.prototype.clearRect = function (x, y, w, h) {
            var inside = function (p) { return p.y === undefined ? !(p[1] >= y && p[1] < y + h) : !(p.y >= y && p.y < y + h); };
            if (this.__ilrNew) this.__ilrNew = this.__ilrNew.filter(inside);
            if (this.__ilrText) this.__ilrText = this.__ilrText.filter(inside);
            return clearRect.apply(this, arguments);
        };
        Bitmap.prototype.clear = function () { this.__ilrNew = []; this.__ilrText = []; return clear.apply(this, arguments); };
    }
    addEventListener('load', function () { var t = setInterval(function () { if (window.Galv && window.Bitmap) { hook(); clearInterval(t); } }, 50); });
    R.wait = function (cond, ms) {
        return new Promise(function (ok, ng) {
            var n = 0, t = setInterval(function () { var v; try { v = cond(); } catch (e) { v = false; } if (v) { clearInterval(t); ok(v); } else if (++n * 20 > (ms || 20000)) { clearInterval(t); ng(new Error('timeout')); } }, 20);
        });
    };
    R.newGame = function () {
        hook();
        if (SceneManager._scene instanceof Scene_Map) { SceneManager._scene.update = function () {}; SceneManager._scene.isBusy = function () { return false; }; }
        ConfigManager.applyData({}); DataManager.setupNewGame();
        $gameParty._actors = [1, 8, 9, 10]; $gameParty._battleMembers = $gameParty._actors.slice();
        Game_Map.prototype.updateInterpreter = function () {};
        $gameMessage.clear();
        return $gameParty.members().map(function (a) { return a.name(); });
    };
    R.go = function (cls) {
        SceneManager.goto(cls);
        return R.wait(function () { var s = SceneManager._scene; return s instanceof cls && SceneManager._sceneStarted && ImageManager.isReady() && s; });
    };
    R.type = function (item) { return !item ? null : item.itypeId ? 'items' : item.wtypeId ? 'weapons' : item.atypeId ? 'armors' : null; };
    R.seen = function (item) { var t = R.type(item); return !!(t && $gameSystem._seenItems[t][item.id]); };
    R.rows = function (w) {
        var h = w.itemHeight(), sy = w._scrollY || 0, out = [];
        var bmp = w.contents, news = bmp.__ilrNew || [], texts = bmp.__ilrText || [];
        for (var i = 0; i < w.maxItems(); i++) {
            var it = w._data[i];
            var y0 = i * h - sy;
            out.push({i: i, id: it && it.id, base: it && (it.baseItemId || it.id), type: R.type(it), name: it && it.name, seen: R.seen(it),
                enabled: !!(it && w.isEnabled(it)),
                newShown: news.some(function (p) { return p[1] >= y0 && p[1] < y0 + h; }),
                texts: texts.filter(function (t) { return t.y >= y0 && t.y < y0 + h; }).map(function (t) { return [t.text, t.x, t.y - y0, t.w, t.align, t.size]; })});
        }
        return {type: w.constructor.name, rect: [w.x, w.y, w.width, w.height], padding: w.padding, lineHeight: w.lineHeight(), itemHeight: h,
            font: w.standardFontSize(), index: w.index(), topRow: w.topRow(), maxPageRows: w.maxPageRows(), active: w.active, visible: w.visible, rows: out};
    };
    R.saveRoundTrip = function () {
        var json = JsonEx.stringify(DataManager.makeSaveContents());
        DataManager.extractSaveContents(JsonEx.parse(json));
        return json.length;
    };
})();
