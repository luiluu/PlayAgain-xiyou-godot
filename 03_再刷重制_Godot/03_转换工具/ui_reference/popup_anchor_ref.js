/* 只在独立参照服务器追加；不修改冻结源。内存四人夹具上用真实 startDamagePopup/setupDamagePopup 生成普通伤害与回复，
   逐例记弹数子精灵的锚点（LGP drawDefaultNumber：anchor.y = 1 + 当前存活回复弹数 − 1）、根位置与边界。
   页面内 JS：await __popupAnchor.run()，结果 __refJson('popup_anchor_oracle')。 */
(function () {
    if (!/[?&]popup_anchor=1(?:&|$)/.test(location.search)) return;
    var CASES = [
        ['damage', [9876]], ['heal', [-500]], ['damage_damage', [9876, 1234]], ['heal_heal', [-500, -300]],
        ['heal_damage', [-500, 9876]], ['damage_heal', [9876, -500]], ['heal_heal_damage', [-500, -300, 9876]],
    ];
    var GAP = 5;   // 相邻两次弹出之间推进的帧数（前一个仍存活）
    var AFTER = 5; // 最后一次弹出后推进的帧数（与沙僧51 的 5 帧一致）
    function wait(cond, ms) { return __dhRef.pump({until: cond, ms: ms}); }
    function clear(sprite, scene) {
        sprite._damages.forEach(function (d) { if (d.parent) d.parent.removeChild(d); });
        sprite._damages = [];
    }
    function read(d) {
        var b = d.getBounds();
        return {root: [d.x, d.y], bounds: [b.x, b.y, b.width, b.height], duration: d._duration,
            value: d._result.hpDamage, children: d.children.map(function (s) {
                return {xy: [s.x, s.y], scale: [s.scale.x, s.scale.y], anchor: [s.anchor.x, s.anchor.y],
                    bitmap: s.bitmap && [s.bitmap.width, s.bitmap.height]};
            })};
    }
    window.__popupAnchor = {run: async function () {
        var out = {fixture: '四人内存夹具；敌群2；敌人0与角色0；无存档', gap: GAP, after: AFTER, cases: {}, errors: []};
        try {
            if (!await wait(function () { return window.DataManager && DataManager.isDatabaseLoaded() && SceneManager._scene instanceof Scene_Title; }, 60000)) throw new Error('标题未就绪');
            Array.from(document.querySelectorAll('button')).filter(function (b) { return b.textContent === '战斗夹具 4 人'; })[0].click();
            if (!await wait(function () { var s = SceneManager._scene; return s instanceof Scene_Battle && s._actorCommandWindow && s._actorCommandWindow.active; }, 60000)) throw new Error('战斗输入未就绪');
            var scene = SceneManager._scene;
            ConfigManager.CombatDamageShow = true;
            var targets = {enemy: scene._spriteset._enemySprites.filter(function (s) { return s._battler.index() === 0; })[0],
                actor: scene._spriteset._actorSprites.filter(function (s) { return s._battler && s._battler.index() === 0; })[0]};
            for (var side in targets) {
                var sp = targets[side], bt = sp._battler;
                for (var c = 0; c < CASES.length; c++) {
                    clear(sp, scene);
                    var made = [];
                    for (var i = 0; i < CASES[c][1].length; i++) {
                        if (i > 0) for (var f = 0; f < GAP; f++) scene.update();
                        bt.clearResult(); bt.result().hpAffected = true; bt.result().hpDamage = CASES[c][1][i];
                        bt.startDamagePopup(); sp.setupDamagePopup();
                        made.push(sp._damages[sp._damages.length - 1]);
                    }
                    for (var f2 = 0; f2 < AFTER; f2++) scene.update();
                    out.cases[side + '_' + CASES[c][0]] = made.map(read);
                }
                clear(sp, scene);
            }
            out.errors = __refErrors.slice(); out.done = true;
        } catch (e) { out.errors.push(String(e.stack || e)); out.done = false; }
        __refJson('popup_anchor_oracle', out);
        return out;
    }};
})();
