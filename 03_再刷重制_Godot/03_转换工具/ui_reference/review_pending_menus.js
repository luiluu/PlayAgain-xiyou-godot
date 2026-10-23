/* 只在独立只读参照页运行，所有状态来自内存新局，不加载或保存玩家存档。 */
(function () {
    if (!/[?&]pending_review=1(?:&|$)/.test(location.search)) return;
    addEventListener('load', function () {
        var panel = document.createElement('div');
        panel.style.cssText = 'position:fixed;right:0;bottom:0;z-index:100000;background:white;color:black;font:14px sans-serif';
        ['mousedown', 'mouseup', 'touchstart', 'touchend'].forEach(function (t) { panel.addEventListener(t, function (e) { e.stopPropagation(); }); });
        var button = document.createElement('button'), status = document.createElement('span');
        button.textContent = '重放待审菜单'; status.textContent = '等标题就绪后重放';
        panel.append(button, status); document.body.appendChild(panel);
        button.onclick = async function (e) {
            e.stopPropagation(); button.disabled = true;
            var result = {fixture: '冻结v0.28，独立端口内存新局，无存档', screens: {}, errors: []};
            function assert(ok, msg) { if (!ok) throw new Error(msg); }
            async function wait(until) { assert(await __dhRef.pump({until: until, ms: 60000}), '等待场景失败'); }
            async function frames(n) { var i = 0; await wait(function () { return ++i > n && ImageManager.isReady(); }); }
            function rect(w) { return [w.x, w.y, w.width, w.height]; }
            async function shot(name) {
                await frames(20); await document.fonts.ready;
                SceneManager.renderScene();
                var s = SceneManager._scene, ws = s._windowLayer ? s._windowLayer.children : [];
                result.screens[name] = {scene: s.constructor.name, windows: ws.filter(function(w){return w.contents;}).map(function(w){return {type:w.constructor.name,rect:rect(w),lineHeight:w.lineHeight(),fontSize:w.contents.fontSize,visible:w.visible,openness:w.openness};})};
                assert(__refShot(name) === 200, '截图失败 ' + name);
                status.textContent = name;
            }
            async function fresh() {
                await wait(function () { return DataManager.isDatabaseLoaded() && window.Scene_Title && SceneManager._scene; });
                if (window.CodexAlienation) CodexAlienation.closeWorkshop();
                if (SceneManager._scene) { SceneManager._scene.isBusy = function(){return false;}; }
                ConfigManager.applyData({}); DataManager.setupNewGame(); Math.random = function(){return 0.75;};
                $gameParty._actors = [1,8,9,10]; $gameParty._battleMembers = [1,8,9,10];
                Game_Map.prototype.updateInterpreter = function(){};
                if(window.CodexGuide) CodexGuide.MILESTONE_ENABLED = false;
                $gameMessage.clear(); $gameScreen.clear(); $gamePlayer.clearTransferInfo();
                DataManager.loadMapData(5); await wait(function(){return DataManager.isMapLoaded();});
                $gameMap.setup(5); $gamePlayer.locate(10,10); $gamePlayer.refresh();
                SceneManager._stack = []; SceneManager.goto(Scene_Map);
                await wait(function(){return SceneManager._scene instanceof Scene_Map && SceneManager._sceneStarted && ImageManager.isReady() && !SceneManager._scene._fadeDuration;});
                SceneManager.snapForBackground();
            }
            async function go(K) { SceneManager.push(K); await wait(function(){return SceneManager._scene instanceof K && SceneManager._sceneStarted && ImageManager.isReady();}); await frames(12); return SceneManager._scene; }
            function pets(data) {
                $gameParty.GTWar = null;
                $gameParty.Pets = data.map(function(f){var p=new Game_Enemy(f.id,0,0); p._elite=!!f.elite; p._paramPush=f.paramPush.slice(); p._skills=f.skills.map(function(id){return $dataSkills[id];}); p._Levelskills=f.lvSkills; p.Exp=f.exp; p.extraLS=f.ls[0]; p.extraLSMax=f.ls[1]; Star.PetSystem.ensurePetExpTable(p); return p;});
            }
            try {
                await fresh();
                var cfg=__reviewMenuConfig.crafting.setup;
                cfg.learn.forEach(function(id){$gameParty.learnRecipe(id);});
                $gameParty._items={};$gameParty._weapons={};$gameParty._armors={};$gameParty._gold=cfg.gold;$gameParty._craftingExp=cfg.craftExp.slice();
                await wait(function(){return window.$gameRecipes && $gameRecipes.length>458;});
                $gameRecipes[1]._materials.forEach(function(m){$gameParty.gainItem(m._item,m._amount*3);});
                var m=$gameRecipes[2]._materials[0];$gameParty.gainItem(m._item,m._amount);
                var s=await go(Scene_Crafting);s._commandWindow.select(2);s.update();s.commandOk();s._listWindow.select(0);s.update();
                await shot('craft_1_list');s.listSuccess();s._confirmWindow._amount=3;await shot('craft_3_confirm_x3');s.craftSuccess();await shot('craft_4_popup');
                await fresh();pets(__reviewMenuConfig.pet.pets);s=await go(Scene_PetSystem);s._indexWindow.select(1);s._windowIdx=-1;s.update();
                await shot('pet_0');s.onRangeOk();s.onLookSkOK();await shot('pet_1_skills');
                await fresh();pets(__reviewMenuConfig.pet.pets);$gameParty.gainItem($dataItems[426],5);s=await go(Scene_PetSystem);s._indexWindow.select(1);s._windowIdx=-1;s.update();s.onRangeOk();s.onEatUpOk();await shot('pet_feed');
                s.onUpLeveListCancel();s.onRangeOk();s.onSynthesisOk();await shot('pet_synthesis');
                await fresh();CodexRaces.openMenu();await frames(40);await shot('race_defaults');
                await fresh();CodexRaces.setDefault(3);CodexRaces.openMenu();await frames(40);await shot('race_members');
            } catch (error) { result.errors.push(String(error.stack||error)); }
            try {
                await fresh();SceneManager.push(Scene_Shop);SceneManager.prepareNextScene([[2,13,0,0],[1,73,0,0],[2,52,0,0]],false);
                await wait(function(){return SceneManager._scene instanceof Scene_Shop && SceneManager._sceneStarted && ImageManager.isReady();});
                var shop=SceneManager._scene;shop.commandBuy();shop._buyWindow.select(-1);await shot('magic_shop');
                await fresh();var A=CodexAlienation;
                $gameParty.gainItem($dataItems[A.config.ids.energy],45);$gameParty.gainItem(A.create('w',1042,'mob','inversebone'),1);$gameParty.gainItem(A.create('a',1013,'boss','pest'),1);A.openWorkshop();
                var host=document.getElementById('alien-workshop');
                result.alien={rect:host.getBoundingClientRect().toJSON(),buttons:Array.from(host.querySelectorAll('button')).map(function(b){return {text:b.textContent,rect:b.getBoundingClientRect().toJSON(),disabled:b.disabled};})};
            } catch(error) { result.errors.push(String(error.stack||error)); }
            result.engineErrors=__refErrors.slice();result.done=true;
            __refJson('pending_menus_replay',result);
            status.textContent='重放已保存：'+Object.keys(result.screens).length+' 页；异常 '+result.errors.length;
            button.textContent='待审菜单重放完成';button.disabled=false;
        };
    });
})();
