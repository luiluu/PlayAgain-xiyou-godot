/* 状态页参照（界面 DL 2026-11-06，换源重取 tests/fixtures/status_page_oracle.json，原为 v0.28 浏览器手取）：由 dom_ref.cjs 在页面里执行。
 * 新开局队伍 1/2/23/85（初始装备），Scene_Status（JAH_StatusMenuCore）各窗口矩形与每页 contents 上的绘制调用：
 * text=[文字,x,y,宽,行高,对齐,字号,颜色]；face=[文件,序号,x,y]；icon=[序号,x,y]；gauge=[x,y,宽,填充宽,色1,色2]；line=[0,y,宽]（drawHorzLine）。
 * 空文字不列。参数：{"pages": 3}（每个角色取前几页，缺省 3）。 */
async function (arg) {
    var r = {errors: []}, nPages = (arg && arg.pages) || 3, party = [1, 2, 23, 85];
    function check(ok, msg) { if (!ok) throw new Error(msg); }
    var pump = function (until, ms) { return __dhRef.pump({until: until, ms: ms || 30000}); };
    function frames(n) { var k = 0; return pump(function () { return ++k > n; }); }
    function color(c) {
        var m = /^rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,[^)]+)?\)$/.exec(String(c));
        return m ? '#' + m.slice(1, 4).map(function (n) { return Number(n).toString(16).padStart(2, '0'); }).join('') : String(c).toLowerCase();
    }
    function rect(w) { return [w.x, w.y, w.width, w.height]; }
    // 绘制调用：drawText 记在该窗 contents 上；脸图／图标／条／横线包在窗口实例上（子类覆写的也接得住）
    function capture(win, fn) {
        var ops = [], draw = Bitmap.prototype.drawText, saved = {}, pendingGauge = null;
        Bitmap.prototype.drawText = function (text, x, y, width, height, align) {
            if (this === win.contents && String(text) !== '') ops.push(['text', String(text), x, y, width, height, align || 'left', this.fontSize, color(this.textColor)]);
            return draw.apply(this, arguments);
        };
        var hooks = {
            drawFace: function (name, index, x, y) { ops.push(['face', name, index, x, y]); },
            drawIcon: function (id, x, y) { ops.push(['icon', id, x, y]); },
            // 填充宽取实际画的渐变条宽（YEP_CoreEngine 开描边时比 floor(宽×比例) 少 2）；没画渐变条记 0
            drawGauge: function (x, y, width, rate, c1, c2) {
                var op = ['gauge', x, y, width, 0, color(c1), color(c2)], bm = this.contents, g = bm.gradientFillRect;
                bm.gradientFillRect = function (gx, gy, gw) { op[4] = gw; delete bm.gradientFillRect; return g.apply(this, arguments); };
                pendingGauge = bm; ops.push(op);
            },
            drawHorzLine: function (y, width) { ops.push(['line', 0, y, width == null ? win.contentsWidth() : width]); }
        };
        Object.keys(hooks).forEach(function (k) {
            saved[k] = Object.prototype.hasOwnProperty.call(win, k) ? win[k] : undefined;
            var orig = win[k];
            win[k] = function () {
                hooks[k].apply(this, arguments);
                try { return orig.apply(this, arguments); } finally { if (pendingGauge) { delete pendingGauge.gradientFillRect; pendingGauge = null; } }
            };
        });
        try { fn(); } finally {
            Bitmap.prototype.drawText = draw;
            Object.keys(hooks).forEach(function (k) { if (saved[k] === undefined) delete win[k]; else win[k] = saved[k]; });
        }
        return ops;
    }
    ConfigManager.applyData({}); DataManager.setupNewGame();
    $gameParty._actors = party.slice(); $gameParty._battleMembers = party.slice();
    Game_Map.prototype.updateInterpreter = function () {};
    if (window.CodexGuide) CodexGuide.MILESTONE_ENABLED = false;
    $gameScreen.clear(); $gameMessage.clear(); $gamePlayer.clearTransferInfo();
    DataManager.loadMapData(5);
    check(await pump(function () { return DataManager.isMapLoaded(); }), '地图数据未就绪');
    $gameMap.setup(5); $gamePlayer.locate(10, 10); $gamePlayer.refresh();
    SceneManager.goto(Scene_Map);
    check(await pump(function () { return SceneManager._scene instanceof Scene_Map && SceneManager._sceneStarted && SceneManager._scene._fadeDuration === 0; }, 60000), '地图未就绪');
    await document.fonts.ready;
    $gameParty.setMenuActor($gameActors.actor(1));
    SceneManager.push(Scene_Status);
    check(await pump(function () { return SceneManager._scene instanceof Scene_Status && SceneManager._sceneStarted && ImageManager.isReady(); }), '状态页未就绪');
    await frames(4);
    var s = SceneManager._scene, sel = s._statusWindow, pages = s._pageWindows, p0 = pages[0];
    r.select = {rect: rect(sel), items: [], cursor: [sel._cursorRect.x, sel._cursorRect.y, sel._cursorRect.width, sel._cursorRect.height]};
    for (var i = 0; i < sel.maxItems(); i++) { var ir = sel.itemRect(i); r.select.items.push([ir.x, ir.y, ir.width, ir.height]); }
    r.select.texts = capture(sel, function () { sel.refresh(); });
    r.page = {rect: rect(p0), contents: [p0.contents.width, p0.contents.height], maxPageRows: p0.maxPageRows(),
        opacity: p0.opacity, backOpacity: p0.backOpacity, downArrow: !!p0.downArrowVisible, upArrow: !!p0.upArrowVisible};
    r.actors = [];
    for (var k = 0; k < party.length; k++) {
        var a = $gameActors.actor(party[k]), out = {actorId: a.actorId(), name: a.name(), pages: []};
        for (var p = 0; p < nPages; p++) {
            var w = pages[p]; w.setActor(a); w.resetScroll && w.resetScroll();
            out.pages.push({maxItems: w.maxItems(), maxTopRow: w.maxTopRow(), ops: capture(w, function () { w.refresh(); })});
        }
        r.actors.push(out);
    }
    // 角色 1 第 0 页滚到底
    p0.setActor($gameActors.actor(1)); p0.setTopRow(p0.maxTopRow());
    r.scrolled = {actorId: 1, page: 0, topRow: p0.topRow(), ops: capture(p0, function () { p0.refresh(); })};
    r.pageNames = s._pageNames.slice();
    var ver = 'v0.28';
    try { var x = new XMLHttpRequest(); x.open('GET', 'data/ContentVersion.json', false); x.send(); if (x.status === 200) ver = JSON.parse(x.responseText).releaseVersion || ver; } catch (e) { /* 旧源 */ }
    r.source = '正式 ' + ver + ' 冻结副本，ui_reference/dom_ref.cjs＋status_page_ref.js 无头浏览器读数（界面 DL 2026-11-06 换源重取；v0.28 原为 2026-10-16 八戒_8 浏览器手取）：新开局队伍 1/2/23/85（初始装备），Scene_Status 各窗口矩形与每页 contents 上的绘制调用。text=[文字,x,y,宽,行高,对齐,字号,颜色]；face=[文件,序号,x,y]；icon=[序号,x,y]；gauge=[x,y,宽,填充宽,色1,色2]（底条 fillRect 在 y+27、高 6）；line=drawHorzLine（白 48/255，画在 y+17）。空文字不列。能力值与加成里与成长相关的数字，浏览器开着五乘区成长修正，可能与重制版不同。';
    return r;
}
