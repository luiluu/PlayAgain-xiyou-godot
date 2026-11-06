/* 角色战力面板参照（界面 DE 2026-11-06，换源重取 tests/fixtures/power_panel_oracle.json）：由 dom_ref.cjs 在页面里执行。
 * 内存新局，队伍 1/2/23/85（初始装备），状态页打开 CodexEquipmentQuery.openPower(角色)，读 #cq-modal 里带文字的元素
 * [标签, class, 自身文字, x, y, 宽, 高]（画布坐标，详情未滚动；超出详情框下沿的行照样列出），另记工具条「战力」按钮与面板／详情／底栏框。
 * 参数：{"actors": [1, 23]}（缺省同此）。 */
async function (arg) {
    var r = {errors: []}, ids = (arg && arg.actors) || [1, 23];
    function check(ok, msg) { if (!ok) throw new Error(msg); }
    var pump = function (until, ms) { return __dhRef.pump({until: until, ms: ms || 30000}); };
    function frames(n) { var k = 0; return pump(function () { return ++k > n; }); }
    function round(n) { return Math.round(n * 100) / 100; }
    ConfigManager.applyData({}); DataManager.setupNewGame();
    $gameParty._actors = [1, 2, 23, 85]; $gameParty._battleMembers = [1, 2, 23, 85];
    Game_Map.prototype.updateInterpreter = function () {};
    if (window.CodexGuide) CodexGuide.MILESTONE_ENABLED = false;
    $gameScreen.clear(); $gameMessage.clear(); $gamePlayer.clearTransferInfo();
    DataManager.loadMapData(5);
    check(await pump(function () { return DataManager.isMapLoaded(); }), '地图数据未就绪');
    $gameMap.setup(5); $gamePlayer.locate(10, 10); $gamePlayer.refresh();
    SceneManager.goto(Scene_Map);
    check(await pump(function () { return SceneManager._scene instanceof Scene_Map && SceneManager._sceneStarted && SceneManager._scene._fadeDuration === 0; }, 60000), '地图未就绪');
    await document.fonts.ready;
    var canvas = Graphics._canvas;
    function box(e) {
        var c = canvas.getBoundingClientRect(), b = e.getBoundingClientRect();
        return [round(b.left - c.left), round(b.top - c.top), round(b.width), round(b.height)];
    }
    function rows(panel) {
        return Array.from(panel.querySelectorAll('*')).filter(function (e) {
            return Array.from(e.childNodes).some(function (n) { return n.nodeType === 3 && n.nodeValue.trim(); });
        }).map(function (e) {
            // 文字只取元素自己的文字节点（「人物属性：／」里的属性名是子 span，另列一行），与 v0.28 手取一致
            var own = Array.from(e.childNodes).filter(function (n) { return n.nodeType === 3; }).map(function (n) { return n.nodeValue; }).join('');
            return [e.tagName.toLowerCase(), e.className, own].concat(box(e));
        });
    }
    r.actors = {};
    for (var k = 0; k < ids.length; k++) {
        $gameParty.setMenuActor($gameActors.actor(ids[k]));
        SceneManager.push(Scene_Status);
        check(await pump(function () { return SceneManager._scene instanceof Scene_Status && SceneManager._sceneStarted && ImageManager.isReady(); }), '状态页未就绪');
        await frames(6);
        var pb = document.querySelector('#cq-toolbar [data-power]');
        check(pb, '状态页没有战力按钮');
        if (!r.toolbar) {
            var cs = getComputedStyle(pb);
            r.toolbar = {text: pb.textContent.replace(/\d+(?:\.\d+)?(?:万亿|万|亿)?/g, 'N'), rect: box(pb), font: parseFloat(cs.fontSize),
                padding: [parseFloat(cs.paddingTop), parseFloat(cs.paddingLeft)]};
        }
        CodexEquipmentQuery.openPower(ids[k]);
        await frames(2);
        var panel = document.getElementById('cq-modal');
        check(panel, '战力面板没打开');
        if (!r.panel) { r.panel = box(panel); r.detail = box(panel.querySelector('.cq-detail')); r.footer = box(panel.querySelector('.cq-footer')); }
        r.actors[ids[k]] = rows(panel);
        CodexEquipmentQuery.close();
        SceneManager.pop();
        check(await pump(function () { return SceneManager._scene instanceof Scene_Map && SceneManager._sceneStarted; }), '回地图失败');
    }
    var ver = 'v0.28';
    try { var x = new XMLHttpRequest(); x.open('GET', 'data/ContentVersion.json', false); x.send(); if (x.status === 200) ver = JSON.parse(x.responseText).releaseVersion || ver; } catch (e) { /* 旧源 */ }
    r.source = '正式 ' + ver + ' 冻结副本，ui_reference/dom_ref.cjs＋power_panel_ref.js 无头浏览器读数（界面 DE 2026-11-06 换源重取；v0.28 原为 2026-10-16 八戒_8 浏览器手取）：状态页 CodexEquipmentQuery.openPower(角色) 打开的 #cq-modal 里带文字的元素 [标签, class, 文字, x, y, 宽, 高]（画布坐标，详情未滚动；超出详情框下沿的行照样列出）。队伍 1/2/23/85 新开局初始装备。正式版浏览器开着五乘区成长修正，战力数字与重制版不同。';
    return r;
}
