/* 装备词条检索面板参照（界面 DE 2026-11-06，换源重量 tests/fixtures/gear_search_oracle.json）：由 dom_ref.cjs 在页面里执行。
 * 参数是旧夹具（取 bag 的能力值与读数键名）。内存新局，背包按旧夹具同样的 21 件模板各得一件（得装备时 Math.random 固定 0.5：
 * 不出随机词缀），名字／描述／能力照旧夹具覆盖（消掉随机浮动），备注用新源实例自己的（模板改了的装备随之换新）；
 * 打开 CodexEquipmentQuery「装备词条检索」，位置选「仅背包」，按旧夹具的键逐项操作下拉／搜索框读列表、摘要、详情。 */
async function (old) {
    var r = {errors: []};
    function check(ok, msg) { if (!ok) throw new Error(msg); }
    var pump = function (until, ms) { return __dhRef.pump({until: until, ms: ms || 30000}); };
    ConfigManager.applyData({}); DataManager.setupNewGame();
    Game_Map.prototype.updateInterpreter = function () {};
    if (window.CodexGuide) CodexGuide.MILESTONE_ENABLED = false;
    $gameScreen.clear(); $gameMessage.clear(); $gamePlayer.clearTransferInfo();
    DataManager.loadMapData(5);
    check(await pump(function () { return DataManager.isMapLoaded(); }), '地图数据未就绪');
    $gameMap.setup(5); $gamePlayer.locate(10, 10); $gamePlayer.refresh();
    SceneManager.goto(Scene_Map);
    check(await pump(function () { return SceneManager._scene instanceof Scene_Map && SceneManager._sceneStarted && SceneManager._scene._fadeDuration === 0; }, 60000), '地图未就绪');
    var W = [1, 2, 3, 55, 102, 194, 52, 53, 76, 738, 77, 74, 75, 68, 2222], A = [2, 3, 54, 130, 4541, 13];
    var oldBag = {}; old.bag.forEach(function (b) { oldBag[b.kind + b.dbId] = b; });
    // 新源新局背包里自带的装备（v0.28 没有）先记下再拿掉，背包只留夹具的 21 件
    r.starterBag = $gameParty.weapons().concat($gameParty.armors()).map(function (i) { return [DataManager.isWeapon(i) ? 'weapon' : 'armor', i.baseItemId || i.id, i.name, $gameParty.numItems(i)]; });
    $gameParty.weapons().concat($gameParty.armors()).forEach(function (i) { $gameParty.loseItem(i, $gameParty.numItems(i)); });
    var rand = Math.random; Math.random = function () { return 0.5; };
    var made = [];
    try {
        [['weapon', W, $dataWeapons], ['armor', A, $dataArmors]].forEach(function (k) {
            k[1].forEach(function (id) {
                var before = k[2].length; $gameParty.gainItem(k[2][id], 1);
                // 带 <Prefixes> 的先生成一个「模板」实例（底装备＋词缀，baseItemId 指向底装备），背包里的是再由它生成的那件（最后一件）
                var fresh = k[2].slice(before).filter(Boolean);
                check(fresh.length >= 1 && fresh[0].baseItemId === id, '没有生成独立实例：' + k[0] + id);
                var item = fresh[fresh.length - 1], b = oldBag[k[0] + id];
                item.name = b.name; item.description = b.description; item.params = b.params.slice();
                made.push([k[0], id, item]);
            });
        });
    } finally { Math.random = rand; }
    var Q = CodexEquipmentQuery;
    r.bag = Q.collection().filter(function (x) { return !x.owner; }).map(function (x) {
        var i = x.item, m = made.filter(function (e) { return e[2] === i; })[0];
        check(m, '背包里有夹具以外的装备：' + i.name + ' ' + JSON.stringify([i.id, i.baseItemId, DataManager.isWeapon(i), Q.collection().filter(function (x) { return !x.owner; }).map(function (x) { return [x.item.id, x.item.baseItemId, x.item.name]; }), made.map(function (e) { return [e[0], e[1], e[2].id]; })]));
        var o = {kind: m[0], dbId: m[1], id: i.id, name: i.name, note: i.note, description: i.description,
            quality: i.meta && i.meta.quality != null ? String(i.meta.quality).trim() : null};
        if (m[0] === 'weapon') o.wtypeId = i.wtypeId;
        o.etypeId = i.etypeId; o.params = i.params.slice();
        return o;
    });
    check(r.bag.length === 21, '背包件数不是 21：' + r.bag.length);

    Q.open(); await pump(function () { return !!document.getElementById('cq-modal'); });
    var panel = document.getElementById('cq-modal');
    function sel(label) { return panel.querySelector('select[aria-label="' + label + '"]'); }
    function setSel(label, v) { var s = sel(label); check(s, '没有下拉：' + label); s.value = v; s.onchange(); }
    function setQuery(v) { var i = panel.querySelector('input[type=search]'); i.value = v; i.oninput(); }
    function names() { return Array.from(panel.querySelectorAll('.cq-list .cq-row strong')).map(function (e) { return e.textContent; }); }
    function opts(label) { return Array.from(sel(label).options).map(function (o) { return [o.value, o.textContent]; }); }
    function line(c) {
        var t = c.tagName;
        if (c.classList.contains('cq-effect')) {
            var sm = c.querySelector('small');
            return t + '|' + Array.from(c.childNodes).filter(function (n) { return n !== sm; }).map(function (n) { return n.textContent; }).join('') + '|' + (sm ? sm.textContent : '');
        }
        return t + '|' + c.textContent;
    }
    setSel('位置', 'bag');
    r.sorts = {}; Object.keys(old.sorts).forEach(function (k) { setSel('排序', k); check(sel('排序').value === k, '排序没有这一项：' + k); r.sorts[k] = names(); });
    setSel('排序', 'quality');
    r.small = Array.from(panel.querySelectorAll('.cq-list .cq-row small')).map(function (e) { return e.textContent; });
    r.cats = {}; Object.keys(old.cats).forEach(function (k) { setSel('分类', k); r.cats[k] = names(); }); setSel('分类', '');
    r.queries = {}; Object.keys(old.queries).forEach(function (k) { setQuery(k); r.queries[k] = names(); }); setQuery('');
    // 下拉里没有的值（如 L13）在 select 上落空为「全部品质」
    r.quality = {}; Object.keys(old.quality).forEach(function (k) { setSel('品质', k); r.quality[k] = names(); }); setSel('品质', '');
    setSel('部位', 'w2'); r.type_w2 = names(); setSel('部位', 'a4'); r.type_a4 = names(); setSel('部位', '');
    r.options = {'品质': opts('品质')};
    setSel('指定词条', '暴击率#%'); check(sel('指定词条').value === '暴击率#%', '指定词条没有「暴击率#%」');
    r.term = names(); r.sortOptions = opts('排序').map(function (o) { return o[0]; });
    setSel('排序', 'term'); r.termSorted = names();
    setSel('排序', 'quality'); setSel('指定词条', '');
    check(sel('排序').value === 'quality' && sel('位置').value === 'bag', '复位失败');
    r.count = panel.querySelector('.cq-count').textContent;
    r.detail = {};
    for (var i = 0; i < 21; i++) {
        panel.querySelectorAll('.cq-list .cq-row')[i].click();
        r.detail[i] = Array.from(panel.querySelector('.cq-detail').children).map(line);
    }
    Q.close();
    // 物品页武器列表（按保存的排序：品质）
    SceneManager.push(Scene_Item);
    check(await pump(function () { return SceneManager._scene instanceof Scene_Item && SceneManager._sceneStarted; }), '物品页未就绪');
    var s = SceneManager._scene; s._categoryWindow.selectSymbol('weapon'); s._itemWindow.setCategory('weapon'); s._itemWindow.refresh();
    r.itemList = s._itemWindow._data.filter(Boolean).map(function (i) { return i.name; });
    var ver = 'v0.28';
    try { var x = new XMLHttpRequest(); x.open('GET', 'data/ContentVersion.json', false); x.send(); if (x.status === 200) ver = JSON.parse(x.responseText).releaseVersion || ver; } catch (e) { /* 旧源 */ }
    r.source = '正式西游 ' + ver + ' 冻结副本，ui_reference/dom_ref.cjs＋gear_search_ref.js 无头浏览器读数（界面 DE 2026-11-06 换源重量；v0.28 原为浏览器手量）：内存新局（setupNewGame），背包加武器 [' + W + ']、防具 [' + A + ']（得装备时随机数固定 0.5，不出随机词缀；名字、描述、能力照 v0.28 夹具覆盖消掉随机浮动，备注为新源实例自身，模板改了的随之换新）；装备检索面板「仅背包」的读数；bag 为各实例（dbId 为数据库 ID，Godot 测试照搬）';
    return r;
}
