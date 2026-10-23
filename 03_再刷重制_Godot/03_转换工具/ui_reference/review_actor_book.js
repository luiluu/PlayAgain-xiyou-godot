/* 独立只读服务器追加；原版场景/窗口真实重放，输出只进本批目录。 */
(function () {
    if (!/[?&]actor_book_review=1(?:&|$)/.test(location.search)) return;
    addEventListener('load', function () {
        var b = document.createElement('button');
        b.textContent = '重放人物图鉴';
        b.style.cssText = 'position:fixed;right:0;top:0;z-index:100000';
        ['mousedown', 'mouseup', 'touchstart', 'touchend'].forEach(function (t) {
            b.addEventListener(t, function (e) { e.stopPropagation(); });
        });
        b.onclick = async function (e) {
            e.stopPropagation(); b.disabled = true;
            var r = {fixture: '冻结v0.28；内存新局1/8/9/10；地图5；无存档', actors: {}, errors: []};
            function check(ok, msg) { if (!ok) throw new Error(msg); }
            function rect(w) { return [w.x, w.y, w.width, w.height]; }
            function color(c) {
                var m = /^rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,[^)]+)?\)$/.exec(c);
                return m ? m.slice(1, 4).map(function (n) { return Number(n).toString(16).padStart(2, '0'); }).join('') : c.replace(/^#/, '');
            }
            function round(n) { return typeof n === 'number' ? Math.round(n * 100) / 100 : n; }
            var activeCapture = null;
            function capture(w, fn) {
                var ops = [];
                activeCapture = {window: w, ops: ops};
                try { fn(); } finally { activeCapture = null; }
                return ops;
            }
            try {
                check(await __dhRef.pump({until: function () {
                    return DataManager.isDatabaseLoaded() && SceneManager._scene instanceof Scene_Title;
                }, ms: 60000}), '标题未就绪');
                ConfigManager.applyData({}); DataManager.setupNewGame();
                $gameParty._actors = [1, 8, 9, 10]; $gameParty._battleMembers = [1, 8, 9, 10];
                Game_Map.prototype.updateInterpreter = function () {};
                if (window.CodexGuide) CodexGuide.MILESTONE_ENABLED = false;
                $gameScreen.clear(); $gameMessage.clear(); $gamePlayer.clearTransferInfo();
                DataManager.loadMapData(5);
                check(await __dhRef.pump({until: function () { return DataManager.isMapLoaded(); }, ms: 30000}), '地图数据未就绪');
                $gameMap.setup(5); $gamePlayer.locate(10, 10); $gamePlayer.refresh();
                SceneManager.goto(Scene_Map);
                check(await __dhRef.pump({until: function () {
                    return SceneManager._scene instanceof Scene_Map && SceneManager._sceneStarted &&
                        ImageManager.isReady() && SceneManager._scene._fadeDuration === 0;
                }, ms: 60000}), '地图贴图未就绪');
                SceneManager.snapForBackground(); SceneManager.push(Scene_ActorBook);
                check(await __dhRef.pump({until: function () {
                    return SceneManager._scene instanceof Scene_ActorBook && SceneManager._sceneStarted && ImageManager.isReady();
                }, ms: 30000}), '人物图鉴未就绪');
                await document.fonts.ready;
                var s = SceneManager._scene, iw = s._indexWindow, sw = s._statusWindow;
                var hw = s._actorSkillHeader, lw = s._actorSkillList, help = s._actorSkillHelp;
                var draw = Bitmap.prototype.drawText, icon = Window_Base.prototype.drawIcon;
                Bitmap.prototype.drawText = function (text, x, y, width, height, align) {
                    if ((activeCapture && this === activeCapture.window.contents ? activeCapture.ops : null)) {
                        var o = [String(text), round(x), round(y), round(width), this.fontSize, color(this.textColor)];
                        if (align && align !== 'left') o.push(align);
                        (activeCapture && this === activeCapture.window.contents ? activeCapture.ops : null).push(o);
                    }
                    return draw.apply(this, arguments);
                };
                Window_Base.prototype.drawIcon = function (id, x, y) {
                    if ((activeCapture && this === activeCapture.window ? activeCapture.ops : null)) (activeCapture && this === activeCapture.window ? activeCapture.ops : null).push([id, round(x), round(y)]);
                    return icon.apply(this, arguments);
                };
                try {
                    r.geo = {index: rect(iw).concat(iw.lineHeight()), status: rect(sw), header: rect(hw),
                        list: rect(lw), help: [help.x, help.y], opacity: [iw.opacity, iw.backOpacity], padding: iw.padding};
                    r.index = iw._list.map(function (a) { return a._name; });
                    for (var id = 0; id < $dataActors.length; id++) {
                        var a = $dataActors[id] && $dataActors[id].name ? $gameActors.actor(id) : false;
                        var out = r.actors[id] = {};
                        out.status = capture(sw, function () { sw.setupWhenCheck(a); });
                        out.sprite = a ? a.battlerName() : '';
                        if (a) {
                            hw._actor = a;
                            out.header = capture(hw, function () { hw.refresh(); });
                            lw.setActor(a);
                            out.skills = lw._data.map(function (skill) { return skill.id; });
                            out.list = capture(lw, function () { lw.refresh(); });
                        }
                    }
                } finally { Bitmap.prototype.drawText = draw; Window_Base.prototype.drawIcon = icon; }
                // 全角色取数会让隐藏列表反复刷新说明卡；清理仅由夹具造成的卡片，再走真实可见流程。
                s.closeActorSkillDetails();
                s.children.filter(function (c) { return c.constructor.name === 'Window_ItemHelp'; }).forEach(function (c) { c.visible = false; });
                iw.select(0); s._windowIdx = -1; s.update(); s.openActorSkillDetails();
                r.emptySlotRejected = iw.visible && !lw.visible;
                iw.select(1); s._windowIdx = -1; s.update();
                check(await __dhRef.pump({until: function () { return ImageManager.isReady(); }, ms: 30000}), '角色图未就绪');
                SceneManager.renderScene(); check(__refShot('actor_book_1') === 200, '状态截图失败');
                s.openActorSkillDetails();
                check(await __dhRef.pump({until: function () { return ImageManager.isReady(); }, ms: 30000}), '说明卡未就绪');
                s.update(); SceneManager.renderScene();
                r.details = {actor: lw._actor.actorId(), skill: lw.item().id, help: [help.x, help.y, help.width, help.height],
                    rects: [rect(hw), rect(lw)], visible: [iw.visible, sw.visible, hw.visible, lw.visible, help.visible]};
                check(__refShot('actor_book_1_skills') === 200, '详情截图失败');
                s.closeActorSkillDetails(); s.update(); SceneManager.renderScene();
                r.back = {visible: [iw.visible, sw.visible, hw.visible, lw.visible, help.visible],
                    borders: s.children.filter(function (c) { return c.constructor.name === 'Window_ItemHelp'; }).map(function (c) {
                        return {visible: c.visible, rect: rect(c)};
                    })};
                check(__refShot('actor_book_back') === 200, '返回截图失败');
                r.errors = __refErrors.slice(); r.done = true;
                check(r.errors.length === 0, '引擎错误');
                check(__refJson('actor_book_replay', r) === 200, '读数保存失败');
                s.update = function () {};
                b.textContent = '人物图鉴重放已保存';
            } catch (error) {
                r.errors.push(String(error.stack || error)); r.done = false;
                __refJson('actor_book_failure', r); b.textContent = '人物图鉴捕获失败';
            }
        };
        document.body.appendChild(b);
    });
})();
