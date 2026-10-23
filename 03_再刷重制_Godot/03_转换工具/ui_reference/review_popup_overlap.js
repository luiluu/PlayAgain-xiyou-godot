/* 只在独立审查服务器追加；不修改冻结源。内存四人夹具＋真实101窗口/弹数。 */
(function () {
    if (!/[?&]popup_overlap=1(?:&|$)/.test(location.search)) return;
    addEventListener('load', function () {
        var button = document.createElement('button');
        button.textContent = '捕获弹数与101重叠';
        button.style.cssText = 'position:fixed;right:0;top:0;z-index:100000';
        button.onclick = async function (event) {
            event.stopPropagation(); button.disabled = true;
            var result = {fixture: '四人内存夹具；敌群2；居中101；伤害9876；无存档', errors: []};
            function rect(r) { return [r.x, r.y, r.width, r.height]; }
            function check(ok, message) { if (!ok) throw new Error(message); }
            try {
                check(await __dhRef.pump({until: function () {
                    return window.DataManager && DataManager.isDatabaseLoaded() && SceneManager._scene instanceof Scene_Title;
                }, ms: 60000}), '标题未就绪');
                // 原工具的地图就绪条件早于贴图渲染；等地图真正启动再让它进战斗，避免黑色背景快照。
                var nativePush = SceneManager.push;
                SceneManager.push = function (sceneClass) {
                    if (sceneClass !== Scene_Battle) return nativePush.apply(this, arguments);
                    var timer = setInterval(function () {
                        if (!(SceneManager._scene instanceof Scene_Map) || !SceneManager._sceneStarted || !ImageManager.isReady() || SceneManager._scene._fadeDuration > 0) return;
                        clearInterval(timer); SceneManager.push = nativePush;
                        SceneManager._scene.update(); SceneManager.renderScene();
                        nativePush.call(SceneManager, sceneClass);
                    }, 100);
                };
                Array.from(document.querySelectorAll('button')).filter(function (b) {
                    return b.textContent === '战斗夹具 4 人';
                })[0].click();
                check(await __dhRef.pump({until: function () {
                    var s = SceneManager._scene;
                    return s instanceof Scene_Battle && s._actorCommandWindow && s._actorCommandWindow.active;
                }, ms: 60000}), '战斗输入未就绪');
                var scene = SceneManager._scene;
                check(await __dhRef.pump({until: function () {
                    return ImageManager.isReady() && scene._spriteset._actorSprites.every(function (s) {
                        return !s._battler || (s._mainSprite.bitmap && s._mainSprite.bitmap.isReady() && s._mainSprite._frame.width > 0);
                    });
                }, ms: 30000}), '战斗贴图未就绪');
                await document.fonts.ready;
                $gameMessage.setFaceImage('', 0); $gameMessage.setBackground(0); $gameMessage.setPositionType(1);
                $gameMessage.add('天空中的圣雷积攒到了极限');
                check(await __dhRef.pump({until: function () {
                    return scene._messageWindow.openness === 255 && scene._messageWindow.pause;
                }, ms: 10000}), '101消息未全显');
                var w = scene._messageWindow;
                result.message = [w.x, w.y, w.width, w.height];
                check(__refShot('popup_baseline') === 200, '基线截图失败');
                var target = scene._spriteset._enemySprites.filter(function (s) { return s._battler.index() === 0; })[0];
                var enemy = target._battler;
                ConfigManager.CombatDamageShow = true;
                enemy.clearResult(); enemy.result().hpAffected = true; enemy.result().hpDamage = 9876;
                enemy.startDamagePopup(); target.setupDamagePopup();
                var popup = target._damages[target._damages.length - 1];
                check(!!popup, '真实setupDamagePopup未生成弹数');
                // 恰好自然更新5帧；之后只冻结本夹具场景，三张图为同一帧。
                for (var i = 0; i < 5; i++) scene.update();
                SceneManager.renderScene();
                result.popup = rect(popup.getBounds()); result.duration = popup._duration;
                result.popupRoot = [popup.x, popup.y];
                result.popupChildren = popup.children.map(function (s) {
                    return {xy: [s.x, s.y], scale: [s.scale.x, s.scale.y], anchor: [s.anchor.x, s.anchor.y],
                        bitmap: s.bitmap && [s.bitmap.width, s.bitmap.height, s.bitmap.fontFace, s.bitmap.fontSize]};
                });
                result.popupParent = popup.parent.constructor.name;
                result.sceneOrder = [scene.children.indexOf(scene._spriteset), scene.children.indexOf(scene._windowLayer)];
                var p = result.popup, m = result.message;
                check(p[0] < m[0] + m[2] && p[0] + p[2] > m[0] && p[1] < m[1] + m[3] && p[1] + p[3] > m[1], '弹数没有实际重叠消息窗');
                check(result.duration > 0, '弹数已经结束');
                check(__refShot('popup_overlap') === 200, '重叠截图失败');
                w.visible = false;
                check(__refShot('popup_window_hidden') === 200, '同帧隐藏窗口截图失败');
                w.visible = true;
                scene.update = function () {};
                result.errors = __refErrors.slice(); result.done = true;
                check(__refJson('popup_overlap', result) === 200, '读数保存失败');
                button.textContent = '重叠截图已保存';
            } catch (error) {
                result.errors.push(String(error.stack || error)); result.done = false;
                __refJson('popup_overlap_failure', result);
                button.textContent = '捕获失败（已保存原文）';
            }
        };
        document.body.appendChild(button);
    });
})();
