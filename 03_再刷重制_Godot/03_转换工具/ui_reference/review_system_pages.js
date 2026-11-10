/* 系统页成对截图（八戒_63）：review_system_pages.py 只读服务追加，仅 ?sys_review=1 启用。
   每页从标题建内存新局（1/8/9/10，地图 5，不读写存档），照 tests/fixtures 对应参照的 setup 摆好状态，走真实原版场景／窗口；
   __sysRef.run(页) 摆好并返回该页的截图状态名，show(页, 状态) 推进到该状态，readout 取场景里所有窗口的矩形、开合、不透明度与本帧文字。 */
(function () {
    if (!/[?&]sys_review=1(?:&|$)/.test(location.search)) return;
    var S = window.__sysRef = {}, P = {};
    function wait(cond, ms) { return __ilr.wait(cond, ms || 30000); }
    function frames(n) { var f = Graphics.frameCount + (n || 2); return wait(function () { return Graphics.frameCount >= f; }); }
    async function settle(n) {
        await frames(n || 20);
        await wait(function () { return ImageManager.isReady(); });
        if (document.fonts) await document.fonts.ready;
        await frames(4);
    }
    function scene() { return SceneManager._scene; }
    // cls：场景类，或场景类名（插件闭包里的场景，用 open 回调按原入口打开）
    async function push(cls, prep, open) {
        SceneManager.snapForBackground();
        if (open) open(); else SceneManager.push(cls);
        if (prep) prep();
        await wait(function () {
            var s = scene();
            return (typeof cls === 'string' ? s.constructor.name === cls : s instanceof cls) && SceneManager._sceneStarted && ImageManager.isReady();
        });
        await settle();
        return scene();
    }
    function round(n) { return typeof n === 'number' ? Math.round(n * 100) / 100 : n; }
    function walk(node, out) {
        if (node instanceof Window_Base) {
            var texts = (node.contents && node.contents.__ilrText || []).map(function (t) {
                return [t.text, round(t.x), round(t.y), round(t.w), t.align, t.size, t.color];
            });
            out.push({type: node.constructor.name, rect: [round(node.x), round(node.y), round(node.width), round(node.height)],
                visible: node.visible, openness: node.openness, opacity: node.opacity, backOpacity: node.backOpacity,
                contentsOpacity: node.contentsOpacity, active: node.active, index: node.index ? node.index() : null,
                padding: node.padding, lineHeight: node.lineHeight(), texts: texts});
        } else if (node !== scene() && node.constructor && /^Sprite_(Button|ItemHelp)/.test(node.constructor.name)) {
            out.push({type: node.constructor.name, rect: [round(node.x), round(node.y), node.width, node.height], visible: node.visible});
        }
        (node.children || []).forEach(function (c) { walk(c, out); });
        return out;
    }
    async function fresh() {
        // 工坊是独立 DOM 层，SceneManager 换场景不会替它关闭。
        if (window.CodexAlienation) CodexAlienation.closeWorkshop();
        Math.random = function () { return 0.5; };  // 同 mv_oracle 各探针：新局初始装备的随机浮动、宝珠孔数固定
        __ilr.newGame();
        if (window.CodexGuide) CodexGuide.MILESTONE_ENABLED = false;
        $gameScreen.clear(); $gamePlayer.clearTransferInfo();
        DataManager.loadMapData(5);
        await wait(function () { return DataManager.isMapLoaded(); });
        $gameMap.setup(5); $gamePlayer.locate(10, 10); $gamePlayer.refresh();
        SceneManager.goto(Scene_Map);
        await wait(function () {
            var s = scene();
            return s instanceof Scene_Map && SceneManager._sceneStarted && ImageManager.isReady() && s._fadeDuration === 0;
        }, 60000);
        await settle();
    }
    S.ready = function () {
        return window.__ilr && DataManager.isDatabaseLoaded() && scene() instanceof Scene_Title && SceneManager._sceneStarted;
    };
    S.pages = function () { return Object.keys(P); };
    S.run = async function (name) { await fresh(); await P[name].setup(); return Object.keys(P[name].shots); };
    S.show = async function (name, shot) { await P[name].shots[shot](); await settle(); return true; };
    S.readout = function (name, shot) {
        var s = scene(), extra = P[name].extra ? P[name].extra(shot) : null;
        var alien = document.getElementById('alien-workshop');
        var alienVisible = !!(alien && alien.getBoundingClientRect().width > 0 && alien.getBoundingClientRect().height > 0 && getComputedStyle(alien).display !== 'none');
        return {fixture: '冻结v0.28；内存新局 1/8/9/10；地图 5；无存档', page: name, shot: shot, scene: s.constructor.name, alienOverlayVisible: alienVisible,
            windows: walk(s, []), extra: extra, errors: (window.__refErrors || []).slice()};
    };

    // 制作：crafting_oracle.json 的 setup（学会 26 条配方、金币 150000、打造经验 30、配方 1 材料 ×3、配方 2 第一种材料 ×1）
    function give(m, n) {
        var data = m._type === 'item' ? $dataItems : m._type === 'weapon' ? $dataWeapons : $dataArmors;
        $gameParty.gainItem(data[m._baseItemId], n);
    }
    P.crafting = {
        setup: async function () {
            [1, 2, 3, 4, 35, 36, 5, 6, 7, 8, 9, 10, 53, 54, 55, 56, 57, 58, 82, 83, 84, 85, 86, 87, 37, 62].forEach(function (id) { $gameParty.learnRecipe(id); });
            $gameParty._gold = 150000; $gameParty._craftingExp = [0, 30, 0, 0];
            $gameRecipes[1]._materials.forEach(function (m) { give(m, m._amount * 3); });
            give($gameRecipes[2]._materials[0], $gameRecipes[2]._materials[0]._amount);
            await push('Scene_Crafting', null, function () { Scene_Menu.prototype.commandRecipe.call({}); });
        },
        shots: {
            craft_0_category: async function () {},
            craft_1_list: async function () {
                var s = scene(); s._commandWindow.select(2); s._commandWindow.processOk(); s._listWindow.select(0);
            },
            craft_3_confirm_x3: async function () {
                var s = scene(); s._listWindow.processOk(); await settle();
                for (var i = 0; i < 3; i++) s._confirmWindow.cursorRight(false);
            },
            craft_4_popup: async function () { var s = scene(); s._confirmWindow.processOk(); }
        }
    };

    // 法宝图标等级字：magic_level_oracle.json（商店 goods 防具13／武器73／防具52；角色 1 第 13 槽强装大罗剑胎；物品页大罗剑胎详情）
    var magicArmor = null;
    P.magic_level = {
        setup: async function () {
            Game_Actor.prototype.releaseUnequippableItems = function () {};
            $gameParty.gainItem($dataArmors[13], 1);
            magicArmor = $gameParty.armors().filter(function (a) { return (a.baseItemId || a.id) === 13; })[0];
            $gameParty.loseItem(magicArmor, 1);
            $gameActors.actor(1)._equips[12].setObject(magicArmor);
            $gameActors.actor(1).refresh();
            await push(Scene_Shop, function () {
                SceneManager.prepareNextScene([[2, 13, 0, 0], [1, 73, 0, 0], [2, 52, 0, 0]], false);
            });
        },
        shots: {
            magic_shop_buy: async function () {
                var s = scene(); s._commandWindow.selectSymbol('buy'); s._commandWindow.processOk(); s._buyWindow.select(0);
            },
            magic_equip_slot: async function () {
                $gameParty.setMenuActor($gameActors.actor(1));
                SceneManager.goto(Scene_Equip);
                await wait(function () { return scene() instanceof Scene_Equip && SceneManager._sceneStarted && ImageManager.isReady(); });
                await settle();
                var s = scene(); s._commandWindow.selectSymbol('equip'); s._commandWindow.processOk(); s._slotWindow.select(12);
            },
            magic_item_info: async function () {
                $gameActors.actor(1)._equips[12].setObject(null);
                $gameParty.gainItem(magicArmor, 1);
                SceneManager.goto(Scene_Item);
                await wait(function () { return scene() instanceof Scene_Item && SceneManager._sceneStarted && ImageManager.isReady(); });
                await settle();
                var s = scene(), cw = s._categoryWindow;
                cw.selectSymbol('armor'); cw.deactivate(); s._itemWindow.setCategory('armor'); s._itemWindow.refresh();
                s._itemWindow.activate(); s._itemWindow.select(s._itemWindow._data.indexOf(magicArmor));
            }
        },
        extra: function () {
            var a = $gameActors.actor(1), P = window.CodexCombatPower, shown = P && P.actor(a), fresh = P && (P.clearCache(), P.actor(a, true));
            return {armor: magicArmor && {id: magicArmor.id, base: magicArmor.baseItemId, name: magicArmor.name,
                upgradeSlots: magicArmor.upgradeSlots, augmentSlots: magicArmor.augmentSlots},
                power: {shown: shown && shown.total, fresh: fresh && fresh.total, equipment: P && magicArmor && P.equipment(magicArmor).total,
                    noZones: P && window.CodexZones && (function () { var z = CodexZones.ENABLED; CodexZones.ENABLED = false; P.clearCache();
                        var v = P.actor(a, true).total; CodexZones.ENABLED = z; P.clearCache(); return v; })()}};
        }
    };

    // 宠物：pet_oracle.json／pet_synth_oracle.json（固定随机序列按原版 GetingPet 造敌人 1、288、10）；造出的宠物与参照逐项比对写进读数
    var SEQ = [0.5, 0.2, 0.9, 0.1, 0.7, 0.3, 0.6, 0.4, 0.8, 0.05];
    function makePets(exps) {
        var k = 0, rnd = Math.random;
        Math.random = function () { return SEQ[k++ % SEQ.length]; };
        try {
            $gameParty.Pets = [];
            [1, 288, 10].forEach(function (id, i) {
                var e = new Game_Enemy(id, 0, 0);
                Star.PetSystem.GetingPet(e);
                e.Exp = exps[i];
                $gameParty.Pets.push(e);
            });
        } finally { Math.random = rnd; }
    }
    function petsReadout() {
        return ($gameParty.Pets || []).map(function (p) {
            return {id: p.enemyId(), name: p.name(), paramPush: p._paramPush.slice(), skills: p._skills.map(function (x) { return x && x.id; }),
                exp: p.Exp, lv: p.levell};
        });
    }
    function bottomPick(symbol) {
        var s = scene(); s.onRangeOk(); s._BottomconfirmWindow.selectSymbol(symbol); s._BottomconfirmWindow.processOk();
    }
    P.pets = {
        setup: async function () { makePets([0, 500, 0]); await push(Scene_PetSystem); },
        shots: {
            pet_0: async function () { scene()._indexWindow.select(1); },
            pet_bottom: async function () { var s = scene(); s.onRangeOk(); },
            pet_1_skills: async function () { var b = scene()._BottomconfirmWindow; b.selectSymbol('LookSk'); b.processOk(); }
        },
        extra: function () { return {pets: petsReadout()}; }
    };
    P.pet_synth = {
        setup: async function () {
            makePets([131713, 131713, 0]);
            $gameParty.gainItem($dataItems[426], 3); $gameParty.gainItem($dataItems[428], 1);
            await push(Scene_PetSystem);
        },
        shots: {
            pet_feed: async function () { scene()._indexWindow.select(2); await settle(); bottomPick('EatUp'); },
            pet_synth: async function () {
                var s = scene(); s.onUpLeveListCancel(); await settle(); s.onCancel(); await settle();
                s._indexWindow.select(0); await settle(); bottomPick('Synthesis');
            }
        },
        extra: function () { return {pets: petsReadout()}; }
    };

    // 种族祝福：race_menu 探针的 default-first 路线（队伍 1/8/9、清空背包），按行文点选 Window_YunChoices
    function yunPick(label) {
        var w = scene()._yunChoices, i = label[0] === '@' ? Number(label.slice(1)) : w.rows.map(function (r) { return r.label; }).indexOf(label);
        if (i < 0) throw new Error('找不到行 ' + label + '：' + w.rows.map(function (r) { return r.label; }).join('|'));
        w.select(i); w.processOk();
    }
    P.race = {
        setup: async function () {
            $gameParty._actors = [1, 8, 9]; $gameParty._battleMembers = [1, 8, 9]; $gameParty._items = {}; $gamePlayer.refresh();
            Math.random = function () { return 0.5; };
            await push('Scene_CodexBindMenu', null, function () { if (!CodexRaces.openMenu()) throw new Error('打不开种族祝福'); });
        },
        shots: {
            race_1_default: async function () {},
            race_2_confirm: async function () { yunPick('人族'); },
            race_3_members: async function () { yunPick('确定开局默认'); },
            race_4_actor: async function () { yunPick('@0'); },
            race_5_change: async function () { yunPick('调整种族'); }
        },
        extra: function () { var w = scene()._yunChoices; return w ? {rows: w.rows.map(function (r) { return [r.label, r.enabled !== false]; }), info: w.info} : null; }
    };

    // 怪物图鉴（八戒_64）：enemy_book_oracle.json 的 setup（难度 2，全登记后去掉 3/5/40，敌人 2 出没「草原、新手村」击败 5；
    // onElite 关掉不随机神话）；走 Scene_EnemyBook 目录第 1 项与掉落第 1 行（说明卡）
    P.enemy_book = {
        setup: async function () {
            Game_Enemy.prototype.onElite = function () { return false; };
            $gameSystem._difficultyId = 2;
            $gameSystem.completeEnemyBook();
            [3, 5, 40].forEach(function (id) { $gameSystem.removeFromEnemyBook(id); });
            $gameSystem._recordEnemyMap = [];  // 地图 5 建图时登记的出没清掉，只留参照的这一条
            $gameSystem._recordEnemyMap[2] = ['草原', '新手村'];
            $gameSystem.clearDefeatNumber(); $gameSystem._defeatNumbers[2] = 5;
            Window_EnemyBookIndex.lastIndex = 0;
            await push(Scene_EnemyBook);
        },
        shots: {
            enemy_book_0: async function () {},
            enemy_book_0_drops: async function () { scene().onRangeOk(); }
        },
        // CV 2026-11-06 换源重取：enemy_book_oracle.json 原是 v0.28 浏览器手拼（item_list_ref），这里在同一场面按原格式整份重出
        // （extra.fixture；文字 [t,文字,x,y,宽,对齐,字号,颜色]、图标 [i,图标号,x,y]，记在 Bitmap.drawText／Window_Base.drawIcon 上，颜色为改色前）
        extra: function (shot) { return shot === 'enemy_book_0' ? {fixture: enemyBookFixture()} : null; }
    };
    function enemyBookFixture() {
        var sc = scene(), idx = sc._indexWindow, st = sc._statusWindow, dl = sc._statusWindow3, target = null, ops = [];
        var dt = Bitmap.prototype.drawText, di = Window_Base.prototype.drawIcon;
        Bitmap.prototype.drawText = function (text, x, y, w, lh, align) {
            if (target && this === target.contents) ops.push(['t', String(text), round(x), round(y), round(w), align === 'center' || align === 'right' ? align : 'left', this.fontSize, this.textColor]);
            return dt.apply(this, arguments);
        };
        Window_Base.prototype.drawIcon = function (icon, x, y) {
            if (target === this) ops.push(['i', icon, round(x), round(y)]);
            return di.apply(this, arguments);
        };
        function rec(win, fn) { target = win; ops = []; try { fn(); } finally { target = null; } return ops; }
        function status(e) { return rec(st, function () { st._enemy = null; st.setEnemy(e); }); }
        function drops(i) {
            var draws = rec(dl, function () { idx.select(i); dl.refresh(); });
            // 每行单独重画一次取名字（有的行除名字外还画数量等）
            return [dl._data.map(function (it, n) { var t = rec(dl, function () { dl.drawItem(n); }).filter(function (o) { return o[0] === 't'; });
                return [it.id, t.length ? t[0][1] : it.name, it.isAItem ? 'item' : DataManager.isWeapon(it) || it.wtypeId ? 'weapon' : 'armor']; }), draws];
        }
        try {
            var list = idx._list, out = {difficulty: $gameSystem._difficultyId, removed: [3, 5, 40], record: {enemy: 2, maps: ['草原', '新手村'], defeat: 5}};
            out.geo = {index: [idx.x, idx.y, idx.width, idx.height], status: [st.x, st.y, st.width, st.height],
                percent: [sc._percentWindow.x, sc._percentWindow.y, sc._percentWindow.width, sc._percentWindow.height], drops: [dl.x, dl.y, dl.width, dl.height], rows: idx.maxPageRows()};
            out.names = list.map(function (e, i) { var d = rec(idx, function () { idx.drawItem(i); }).filter(function (o) { return o[0] === 't'; }); return [e.enemyId(), d.length > 1 ? d[1][1] : '']; });
            idx.select(0); idx.setTopRow(0);
            out.index0 = rec(idx, function () { idx.refresh(); });
            list = idx._list;  // refresh 重建了目录（新的 Game_Enemy）
            out.percent = rec(sc._percentWindow, function () { sc._percentWindow.refresh(); });
            out.status = {};
            for (var i = 0; i < list.length; i += 8) out.status[i] = [list[i].enemyId(), status(list[i])];
            out.drops = {};
            for (i = 0; i < list.length; i += 41) out.drops[i] = [list[i].enemyId()].concat(drops(i));
            out.elite = {};
            var rnd = Math.random, oe = Game_Enemy.prototype.onElite;
            [0, 8, 41].forEach(function (k) {
                Math.random = function () { return 0; }; Game_Enemy.prototype.onElite = function () { return true; };
                var e = new Game_Enemy(list[k].enemyId(), 0, 0);
                Math.random = rnd; Game_Enemy.prototype.onElite = oe;
                // 掉落窗按 SceneManager._scene._indexWindow 的当前项取敌人：换成只含这只神话的替身目录
                var sd = status(e), real = sc._indexWindow;
                sc._indexWindow = {_list: [e], index: function () { return 0; }, select: function () {}};
                var d;
                try { d = drops(0); } finally { sc._indexWindow = real; }
                out.elite[k] = [e.enemyId(), e.isElite(), sd, d[0].map(function (r) { return [r[0], r[1]]; })];
            });
            idx.select(0); st._enemy = null; st.setEnemy(list[0]);
            out['说明'] = '冻结正式源（版本见同目录 source_before.json）怪物图鉴（AB_EnemyBook）参照：review_system_pages.cjs enemy_book（同 v0.28 版 item_list_ref 手拼的场面：四人新局 1/8/9/10、难度 2；completeEnemyBook 后去掉敌人 3/5/40；敌人 2 出没「草原、新手村」击败 5；onElite 关掉不随机神话）无头重出。status 每 8 项、drops 每 41 项取一只，elite 是目录 0/8/41 强制神话（Math.random 0、onElite 真）。文字 [t,文字,x,y,宽,对齐,字号,颜色(改色前)]，图标 [i,图标号,x,y]。CV 2026-11-06。';
            return out;
        } finally { Bitmap.prototype.drawText = dt; Window_Base.prototype.drawIcon = di; }
    }

    // 修炼（八戒_64）：training_ui_oracle.json 的 setup（精魂 1234567890、XiuLian=[8,9,14,15]）；目录确定后的底部「修炼」，
    // 读数另记 44 个空格与「修炼」在原版字体下的实测宽（Godot 按它定「修炼」的横坐标）
    P.training = {
        setup: async function () {
            $gameParty._gold = 1234567890;
            Star.ActorAttributePlusPoints.XiuLian = [8, 9, 14, 15];
            await push(Scene_ActorAttributePlusPoints);
        },
        shots: {
            training_bottom: async function () { var s = scene(); s._indexWindow.select(0); s._indexWindow.processOk(); }
        },
        extra: function () {
            var w = scene()._BottomconfirmWindow;
            w.resetFontSettings();
            return {spaces44: w.textWidth(new Array(45).join(' ')), word: w.textWidth('修炼'), fontFace: w.contents.fontFace, fontSize: w.contents.fontSize};
        }
    };

    // 装备镶嵌图鉴（八戒_65）：魂灯商人 Map4 EV40 p1／p3「查看图鉴」＝插件指令 StarEIBook GetAll 再 SceneManager.push(Scene_EquipInlayBook)。
    // 截图：开场（类型窗）、武器第 1 项、武器第 20 项（滚动）、防具第 1 项；__sysRef.inlayAll() 逐项读状态窗的全部 drawText 与 drawIcon
    P.inlay_book = {
        setup: async function () {
            Game_Interpreter.prototype.pluginCommand.call(new Game_Interpreter(), 'StarEIBook', ['GetAll']);
            await push(Scene_EquipInlayBook);
        },
        shots: {
            inlay_0: async function () {},
            inlay_1_weapon: async function () { scene().onRangeOk(); },
            inlay_2_weapon_20: async function () { scene()._indexWindow.select(19); },
            inlay_3_armor: async function () { var s = scene(); s.OnCancel(); s._indexTypeWindow.select(1); s.onRangeOk(); }
        }
    };
    S.inlayAll = async function () {
        await fresh(); await P.inlay_book.setup();
        var s = scene(), w = s._statusWindow, out = {geo: {}, lists: {}, status: {}};
        [['type', s._indexTypeWindow], ['index', s._indexWindow], ['status', w]].forEach(function (p) {
            out.geo[p[0]] = [p[1].x, p[1].y, p[1].width, p[1].height];
        });
        out.geo.rows = s._indexWindow.maxPageRows();
        out.geo.statusLineHeight = w.lineHeight();
        var icons = [], drawIcon = w.drawIcon;
        w.drawIcon = function (i, x, y) { icons.push([i, x, y]); return drawIcon.apply(this, arguments); };
        [['weapon', 0, s._WIdlist], ['armor', 1, s._AIdlist]].forEach(function (p) {
            s._indexTypeWindow.select(p[1]);
            out.lists[p[0]] = p[2].map(function (e) { return [e.id, e.name]; });
            out.status[p[0]] = p[2].map(function (e) {
                icons = [];
                w.setupWhenCheck(e);
                return {id: e.id, x: w.x, texts: (w.contents.__ilrText || []).map(function (t) {
                    return [t.text, round(t.x), round(t.y), round(t.w), t.align, t.size, t.color];
                }), icons: icons};
            });
        });
        s._indexTypeWindow.select(0);
        return out;
    };

    // 仓库（八戒_65）：方桌大厅仓库管理员 Map4 EV8「装备道具仓库」＝PHWarehouse create <仓库:999> 再 show <仓库>（PH_Warehouse 的 Scene_Warehouse，在插件闭包里）。
    // 摆法：药水 1×5、2×3、蘑菇 6×2、指路灯 4×1、武器 2／9 各一件、防具 2 一件；开仓库后先真按存入：物品 1 两次、钥匙 4 一次、武器第 1 件、防具第 1 件，再回选项窗
    function whCmd(args) { Game_Interpreter.prototype.pluginCommand.call(new Game_Interpreter(), 'PHWarehouse', args); }
    function whDeposit(s, cat, pick) {
        s._optionWindow.select(1); s.onOptionOk();
        s._categoryWindow.selectSymbol(cat); s._categoryWindow.update(); s._itemWindow.refresh(); s.onCategoryOk();
        var i = s._itemWindow._data.findIndex(pick); s._itemWindow.select(i); s.onItemOk();
        s.onItemCancel(); s.onCategoryCancel();
    }
    P.warehouse = {
        setup: async function () {
            [[1, 5], [2, 3], [6, 2], [4, 1]].forEach(function (p) { $gameParty.gainItem($dataItems[p[0]], p[1]); });
            $gameParty.gainItem($dataWeapons[2], 1); $gameParty.gainItem($dataWeapons[9], 1); $gameParty.gainItem($dataArmors[2], 1);
            whCmd(['create', '<仓库:999>']);
            await push('Scene_Warehouse', null, function () { whCmd(['show', '<仓库>']); });
            var s = scene();
            whDeposit(s, 'item', function (it) { return it && it.id === 1; });
            whDeposit(s, 'item', function (it) { return it && it.id === 1; });
            whDeposit(s, 'keyItem', function (it) { return it && it.id === 4; });
            whDeposit(s, 'weapon', function (it) { return it && it.baseItemId === 2; });
            whDeposit(s, 'armor', function (it) { return it && it.baseItemId === 2; });
            s._optionWindow.select(0); s._optionWindow.activate(); s._infoLocationWindow.refresh();
        },
        shots: {
            wh_0: async function () {},
            wh_1_withdraw_category: async function () { scene().onOptionOk(); },
            wh_2_withdraw_items: async function () { scene().onCategoryOk(); },
            wh_3_withdraw_weapon: async function () { var s = scene(); s.onItemCancel(); s._categoryWindow.selectSymbol('weapon'); s._categoryWindow.update(); s.onCategoryOk(); },
            wh_4_deposit_items: async function () { var s = scene(); s.onItemCancel(); s.onCategoryCancel(); s._optionWindow.select(1); s.onOptionOk(); s._categoryWindow.selectSymbol('item'); s._categoryWindow.update(); s.onCategoryOk(); },
            wh_5_deposit_weapon: async function () { var s = scene(); s.onItemCancel(); s._categoryWindow.selectSymbol('weapon'); s._categoryWindow.update(); s.onCategoryOk(); s._itemWindow.select(1); },
            wh_6_withdraw_one: async function () {
                var s = scene(); s.onItemCancel(); s.onCategoryCancel(); s._optionWindow.select(0); s.onOptionOk();
                s._categoryWindow.selectSymbol('item'); s._categoryWindow.update(); s.onCategoryOk(); s.onItemOk();
            }
        },
        extra: function () {
            var w = PHPlugins.PHWarehouse, s = scene();
            return {seen: $gameSystem._seenItems, newRows: (s._itemWindow.contents.__ilrNew || []).slice(), warehouses: JSON.parse(JSON.stringify(w._warehouses, function (k, v) { return v; })), lastOption: w._lastOption, lastCategory: w._lastCategory,
                data: s._itemWindow._data.map(function (it) { return it && [it.id, it.baseItemId || 0, it.name, DataManager.isWeapon(it) ? 'w' : DataManager.isArmor(it) ? 'a' : 'i']; }),
                party: {items: $gameParty._items, weapons: Object.keys($gameParty._weapons).map(function (id) { return [Number(id), $dataWeapons[id].baseItemId]; }),
                    armors: Object.keys($gameParty._armors).map(function (id) { return [Number(id), $dataArmors[id].baseItemId]; })},
                list: {maxCols: s._itemWindow.maxCols(), itemHeight: s._itemWindow.itemHeight(), category: {cols: s._categoryWindow.maxCols(), rows: s._categoryWindow.numVisibleRows ? s._categoryWindow.numVisibleRows() : null}}};
        }
    };

    // 角色仓库（八戒_66）：仓库管理员 Map4 EV8「角色仓库」＝SceneManager.push(Star_Scene_ActorWarehouse)。
    // 摆法：队伍 1/8/9/10 加 11、12（出战栏 1/8/9/10/11，12 候补），仓库里放 13 与停用角色 143；
    // 截图：开场、存入列表、存入出战中的 8（出战栏重建）、存入最后一行的 12（光标留在空行）、取出列表、取出 13、停用 143 确定（蜂鸣不动）
    function awState() {
        var p = $gameParty, s = scene(), l = s && s._listWindow;
        return {actors: p._actors.slice(), battleMembers: p._battleMembers.slice(), saveactors: (p._saveactors || []).slice(),
            battle: p.battleMembers().map(function (a) { return a.actorId(); }),
            list: l ? {category: l._category, data: l._data.slice(), index: l.index(), active: l.active, enabled: l.isCurrentItemEnabled(),
                itemHeight: l.itemHeight(), section: l.itemSection(), opacity: l._data.map(function (id) { var a = $gameActors.actor(id); return a ? l.actorIsEnabled(a) : null; })} : null,
            category: s && s._categoryWindow ? {index: s._categoryWindow.index(), active: s._categoryWindow.active, symbol: s._categoryWindow.currentSymbol()} : null};
    }
    P.actor_warehouse = {
        setup: async function () {
            $gameParty.addActor(11); $gameParty.addActor(12);
            $gameParty._saveactors = [13, 143];
            $gameActors.actor(13); $gameActors.actor(143);
            $gamePlayer.refresh();
            await push(Star_Scene_ActorWarehouse);
        },
        shots: {
            aw_0: async function () {},
            aw_1_save_list: async function () { scene().onCategoryOk(); },
            aw_2_save_battle: async function () { var l = scene()._listWindow; l.select(1); l.processOk(); },
            aw_3_save_last: async function () { var l = scene()._listWindow; l.select(l._data.length - 1); l.processOk(); },
            aw_4_load_list: async function () {
                var s = scene(); s._listWindow.processCancel(); s._categoryWindow.select(1); s._categoryWindow.update(); s._categoryWindow.processOk();
            },
            aw_5_load_one: async function () { var l = scene()._listWindow; l.select(0); l.processOk(); },
            aw_6_disabled: async function () { var l = scene()._listWindow; l.select(l._data.indexOf(143)); l.processOk(); }
        },
        extra: function () { return awState(); }
    };

    // 星级仓库（八戒_91）：黄金大厅通用仓库管理员 Map041 EV1「存放／取出」＝SceneManager.push(Scene_StarSaveWarehouse／Scene_StarWarehouse)。
    // 摆法：背包放武器本体 2、52（PushDct）、3，防具本体 2；宠物敌人 1／2／3，第 2 只出战；ConfigManager.GetEq／GetPet 先清空（不读写配置文件）。
    // 截图：存放开场（分类窗）、装备列表、存入第 1 件（光标不动）、宠物列表；退出后打开取出：开场、装备列表、宠物列表、取光宠物后的空列表
    // 宠物是 Game_Enemy，没有 note：列表选中宠物时 updateHelp→Sprite_ItemHelp→HelpExtend getItemExtraDescParams 读 item.note.split 抛错，
    // 正式版里这发生在场景 update 中（SceneManager.catchException 停机）。这里接住并记下，接着摆后面的状态。
    var swErrors = [];
    function swTry(fn) { try { fn(); } catch (e) { swErrors.push(String(e && e.message)); } }
    function swState() {
        var s = scene(), l = s && s._itemWindow, c = s && s._categoryWindow, h = s && s._helpWindow;
        return {GetEq: (ConfigManager.GetEq || []).map(function (i) { return [i.id, i.baseItemId, i.name]; }),
            GetPet: (ConfigManager.GetPet || []).map(function (p) { return [p._enemyId, p.name()]; }),
            pets: ($gameParty.Pets || []).map(function (p) { return [p._enemyId, p.name()]; }),
            list: l ? {category: l._category, index: l.index(), active: l.active, maxCols: l.maxCols(), spacing: l.spacing(), itemHeight: l.itemHeight(),
                data: l._data.map(function (i) { return i && (i._enemyId ? ['pet', i._enemyId, i.name()] : [i.id, i.baseItemId, i.name, i.iconIndex]); })} : null,
            category: c ? {index: c.index(), active: c.active, symbol: c.currentSymbol()} : null,
            help: h ? {rect: [h.x, h.y, h.width, h.height], text: h._text, visible: h.visible} : null, errors: swErrors.slice()};
    }
    P.star_warehouse = {
        setup: async function () {
            $gameParty._weapons = {}; $gameParty._armors = {}; $gameParty._items = {};
            [2, 52, 3].forEach(function (id) { $gameParty.gainItem($dataWeapons[id], 1); });
            $gameParty.gainItem($dataArmors[2], 1);
            ConfigManager.GetEq = []; ConfigManager.GetPet = []; swErrors = [];
            $gameParty.Pets = [1, 2, 3].map(function (id) { return Star.PetSystem.GetingPet(new Game_Enemy(id, 0, 0)); });
            $gameParty.GTWar = $gameParty.Pets[1];
            await push(Scene_StarSaveWarehouse);
        },
        shots: {
            sw_0_save_open: async function () {},
            sw_1_save_equip: async function () { scene()._categoryWindow.processOk(); },
            sw_2_save_one: async function () { scene()._itemWindow.processOk(); },
            sw_3_save_pet: async function () {
                var s = scene(); s._itemWindow.processCancel(); s._categoryWindow.select(1); s._categoryWindow.update();
                swTry(function () { s._categoryWindow.processOk(); });
            },
            sw_3b_save_pet_one: async function () { var l = scene()._itemWindow; swTry(function () { l.processOk(); }); },
            sw_4_load_open: async function () { SceneManager.pop(); await settle(); await push(Scene_StarWarehouse); },
            sw_5_load_equip: async function () { scene()._categoryWindow.processOk(); },
            sw_6_load_pet: async function () {
                var s = scene(); s._itemWindow.processCancel(); s._categoryWindow.select(1); s._categoryWindow.update();
                swTry(function () { s._categoryWindow.processOk(); });
            },
            sw_7_load_empty: async function () { var l = scene()._itemWindow; swTry(function () { l.processOk(); }); l.activate(); swTry(function () { l.processOk(); }); }
        },
        extra: function () { return swState(); }
    };

    // 更衣（八戒_67）：衣橱管理员 Map4 EV17「查看衣橱」＝SceneManager.push(Scene_ChangeClothes)。
    // 摆法：队伍 1/8/9/10，仓库 [13]；ConfigManager.ChangeClothesLite 先放 -9、-12、-20（换装表第 9／12／20 项），
    // 打开时 initialize 再补上队伍与仓库的角色。$.toaster 包一层记下提示文字。
    // 截图：开场、更换（普通档）、优秀档（光标在分类）、优秀档确定（名单第 1 行）、未解锁行、未解锁确定、已解锁确定（替换）、
    // 名单取消回分类、神话档（换装表）确定、换装表已解锁行确定、典藏档、回底部还原
    var ccToasts = [];
    function ccState() {
        var s = scene(), l = s && s._AListWindow, st = s && s._statusWindow, sp = st && st._Sprite;
        return {lite: ConfigManager.ChangeClothesLite.slice(), toasts: ccToasts.slice(),
            player: {setName: $gamePlayer.Set_OcharacterName, setIndex: $gamePlayer.Set_OcharacterIndex,
                characterName: $gamePlayer.characterName(), characterIndex: $gamePlayer.characterIndex()},
            followers: $gamePlayer.followers()._data.map(function (f) { return [f.characterName(), f.characterIndex()]; }),
            category: s && s._indexWindow ? {index: s._indexWindow.index(), active: s._indexWindow.active} : null,
            list: l ? {lid: l.Lid, ids: l._list.map(function (a) { return a.id; }), index: l.index(), active: l.active, top: l.topRow(),
                itemHeight: l.itemHeight(), maxPageRows: l.maxPageRows()} : null,
            bottom: s && s._BottomconfirmWindow ? {index: s._BottomconfirmWindow.index(), active: s._BottomconfirmWindow.active} : null,
            sprite: sp ? {bitmap: sp.bitmap ? sp.bitmap._url : null, x: round(sp.x), y: round(sp.y), scale: [sp.scale.x, sp.scale.y],
                anchor: [sp.anchor.x, sp.anchor.y], frame: sp.bitmap ? [sp._frame.x, sp._frame.y, sp._frame.width, sp._frame.height] : null,
                bitmapSize: sp.bitmap ? [sp.bitmap.width, sp.bitmap.height] : null, frameCount: st._spriteFrameCount, fref: st._spriteFRef} : null};
    }
    P.change_clothes = {
        setup: async function () {
            $gameParty._saveactors = [13]; $gameActors.actor(13);
            ConfigManager.ChangeClothesLite = [-9, -12, -20];
            ccToasts = [];
            var toaster = $.toaster;
            $.toaster = function (o) { ccToasts.push(o && o.message); return toaster.apply(this, arguments); };
            await push(Scene_ChangeClothes);
        },
        shots: {
            cc_0: async function () {},
            cc_1_change: async function () { scene()._BottomconfirmWindow.processOk(); },
            cc_2_cat1: async function () { scene()._indexWindow.select(1); },
            cc_3_cat1_ok: async function () { scene()._indexWindow.processOk(); },
            cc_4_locked: async function () { scene()._AListWindow.select(3); },
            cc_5_locked_ok: async function () { scene()._AListWindow.processOk(); },
            cc_6_apply: async function () { var l = scene()._AListWindow; l.select(0); await settle(); l.processOk(); },
            cc_7_list_cancel: async function () { scene()._AListWindow.processCancel(); },
            cc_8_myth: async function () { var c = scene()._indexWindow; c.select(6); await settle(); c.processOk(); },
            cc_9_myth_apply: async function () { var l = scene()._AListWindow; l.select(3); await settle(); l.processOk(); },
            cc_10_dian: async function () { var s = scene(); s._AListWindow.processCancel(); await settle(); s._indexWindow.select(7); },
            cc_11_restore: async function () {
                var s = scene(); s._indexWindow.processCancel(); await settle();
                s._BottomconfirmWindow.select(1); s._BottomconfirmWindow.processOk();
            }
        },
        extra: function () { return ccState(); }
    };

    // 角色进阶（八戒_68）：奉神老妪 Map132 EV6「进阶」＝SceneManager.push(Scene_ActorAdvanced)。
    // 摆法：队伍 1/8/9/10，金币 0；$.toaster 包一层记下提示文字。
    // 截图：开场、第 2 行、确定开底部「进阶」、条件不足、补齐角色 1 第 0 阶的物品与金币后再开底部、确认窗「是否进阶」、
    // 确认窗取消、再走一遍确定、进阶完成（次数 1、学会技能、扣物品金币）、角色 9 进阶次数设 4（已达最大）、已满时确定
    var advToasts = [];
    function advRow(a) {
        return $dataStarAdvancedOpt.filter(function (o) { return o && a._actorId == o.AdvancedActId && a._AdvancedNum == o.AdvancedActNum; })[0] || null;
    }
    function advState() {
        var s = scene(), st = s && s._statusWindow, sp = st && st._Sprite, a1 = $gameActors.actor(1), r1 = advRow(a1);
        return {toasts: advToasts.slice(), gold: $gameParty._gold,
            members: $gameParty.members().map(function (a) {
                var r = advRow(a);
                return {id: a._actorId, name: a._name, level: a._level, num: a._AdvancedNum, params: [0, 1, 2, 3, 4, 5, 6, 7].map(function (i) { return a.param(i); }),
                    row: r ? {id: r.id, num: r.AdvancedActNum, max: r.AdvancedActNumMaX, level: r.AdvancedActLevel, gold: r.AdvancedGold,
                        items: r.AdvancedItem, learn: r.AdvancedSkiId, forget: r.AdvancedForId} : null};
            }),
            actor1: {skills: a1._skills.slice(), has1240: a1._skills.indexOf(1240) >= 0, items: (r1 || {AdvancedItem: []}).AdvancedItem.map(function (p) { return [p[0], $gameParty.numItems($dataItems[p[0]])]; })},
            item188: $gameParty.numItems($dataItems[188]), item180: $gameParty.numItems($dataItems[180]),
            index: s && s._indexWindow ? {index: s._indexWindow.index(), active: s._indexWindow.active, windowIdx: s._windowIdx} : null,
            bottom: s && s._BottomconfirmWindow ? {index: s._BottomconfirmWindow.index(), active: s._BottomconfirmWindow.active, openness: s._BottomconfirmWindow.openness} : null,
            confirm: s && s._confirmWindow ? {index: s._confirmWindow.index(), active: s._confirmWindow.active, openness: s._confirmWindow.openness} : null,
            sprite: sp ? {bitmap: sp.bitmap ? sp.bitmap._url : null, x: round(sp.x), y: round(sp.y), scale: [sp.scale.x, sp.scale.y],
                anchor: [sp.anchor.x, sp.anchor.y], frame: sp.bitmap ? [sp._frame.x, sp._frame.y, sp._frame.width, sp._frame.height] : null,
                bitmapSize: sp.bitmap ? [sp.bitmap.width, sp.bitmap.height] : null, frameCount: st._spriteFrameCount} : null};
    }
    P.actor_advanced = {
        setup: async function () {
            $gameParty._gold = 0;
            advToasts = [];
            var toaster = $.toaster;
            $.toaster = function (o) { advToasts.push(o && o.message); return toaster.apply(this, arguments); };
            await push(Scene_ActorAdvanced);
        },
        shots: {
            adv_0: async function () {},
            adv_1_row1: async function () { scene()._indexWindow.select(1); },
            adv_2_bottom: async function () { var w = scene()._indexWindow; w.select(0); await settle(); w.processOk(); },
            adv_3_fail: async function () { scene()._BottomconfirmWindow.processOk(); },
            adv_4_ready: async function () {
                var s = scene(), r = advRow($gameActors.actor(1));
                r.AdvancedItem.forEach(function (p) { $gameParty.gainItem($dataItems[p[0]], p[1]); });
                $gameParty._gold = r.AdvancedGold;
                s._goldWindow.setupWhenCheck(); s._statusWindow.setupWhenCheck($gameActors.actor(1));
                await settle(); s._indexWindow.processOk();
            },
            adv_5_confirm: async function () { scene()._BottomconfirmWindow.processOk(); },
            adv_6_cancel: async function () { scene()._confirmWindow.processCancel(); },
            adv_7_confirm2: async function () {
                var s = scene(); s._indexWindow.processOk(); await settle(); s._BottomconfirmWindow.processOk();
            },
            adv_8_done: async function () { scene()._confirmWindow.processOk(); },
            adv_9_max: async function () { $gameActors.actor(9)._AdvancedNum = 4; scene()._indexWindow.select(2); },
            adv_10_max_ok: async function () { scene()._indexWindow.processOk(); }
        },
        extra: function () { return advState(); }
    };

    // 异化工坊：alien_workshop 探针的 list 路线、alien_config 探针的 bound 路线（DOM 叠加层，整页截图）
    function domReadout() {
        var host = document.getElementById('alien-workshop');
        if (!host) return null;
        function r(e) { var b = e.getBoundingClientRect(); return [round(b.x), round(b.y), round(b.width), round(b.height)]; }
        return {pane: r(host.querySelector('.alien-pane')), nodes: Array.prototype.map.call(host.querySelectorAll('h1,h2,h3,p,button,select,label,section,fieldset'), function (e) {
            return {tag: e.tagName.toLowerCase(), cls: e.className || undefined, text: (e.tagName === 'LABEL' ? (e.childNodes[0] && e.childNodes[0].textContent) : e.textContent).slice(0, 80),
                rect: r(e), disabled: e.disabled || undefined, font: getComputedStyle(e).fontSize};
        })};
    }
    function domClick(label) {
        var host = document.getElementById('alien-workshop');
        if (label[0] === '@') { host.querySelectorAll('.alien-list button')[Number(label.slice(1))].onclick(); return; }
        if (label.indexOf('sel:') === 0) {
            var m = /^sel:(.+)#(\d+)$/.exec(label), lab = Array.prototype.find.call(host.querySelectorAll('label'), function (l) { return l.childNodes[0].textContent === m[1]; });
            var sel = lab.querySelector('select'); sel.selectedIndex = Number(m[2]); if (sel.onchange) sel.onchange(); return;
        }
        var b = Array.prototype.find.call(host.querySelectorAll('button'), function (x) { return x.textContent === label; });
        if (!b || b.disabled) throw new Error('按钮不可点 ' + label);
        b.onclick();
    }
    function alienSetup(party) {
        CodexAlienation.closeWorkshop(); Math.random = function () { return 0.5; };
        $gameParty._actors = []; $gameParty._items = {}; $gameParty._weapons = {}; $gameParty._armors = {};
        party.forEach(function (id) { $gameParty.addActor(id); });
        $gamePlayer.refresh();
    }
    function alienMake(kind, id, origin, affix) { var i = CodexAlienation.create(kind, id, origin, affix); $gameParty.gainItem(i, 1); return i; }
    P.alien_workshop = {
        setup: async function () {
            alienSetup([1, 8]);
            var C = CodexAlienation.config; $gameParty.gainItem($dataItems[C.ids.energy], 45);
            alienMake('w', 1042, 'mob', 'inversebone'); alienMake('a', 1013, 'boss', 'pest');
            CodexAlienation.openWorkshop(); await settle();
        },
        shots: {
            alien_list: async function () {},
            alien_list_pending: async function () { ['@1', '20点能量 → 1颗异化石', '使用1颗异化石重抽'].forEach(domClick); }
        },
        extra: domReadout
    };
    P.alien_config = {
        setup: async function () {
            var A = CodexAlienation, C = A.config, T = C.templates, PARTY = [1, 8, 9, 10];
            var activeOk = function (s) { return s && s.id > 2 && s.stypeId !== 4 && s.occasion !== 3 && s.occasion !== 2 && s.id !== C.ids.switch && s.name; };
            var pick = function (ids, n, f) { return ids.map(function (id) { return $dataSkills[id]; }).filter(function (s) { return activeOk(s) && (!f || f(s)); }).slice(0, n).map(function (s) { return s.id; }); };
            var atk1 = pick(T.attack, 3), l1 = atk1.concat(pick(T.silence, 8, function (s) { return atk1.indexOf(s.id) < 0; }).slice(0, 2));
            var LEARN = {1: l1, 8: pick(T.attack, 400, function (s) { return A.borrowable(s) && l1.indexOf(s.id) < 0; }).slice(0, 2).concat(pick(T.possessionSkills, 2, function (s) { return T.attack.indexOf(s.id) < 0; })), 9: T.wish.slice(), 10: []};
            alienSetup(PARTY);
            PARTY.forEach(function (id) { var a = $gameActors.actor(id); a._equips.forEach(function (e, n) { if (e.object()) a.forceChangeEquip(n, null); }); LEARN[id].forEach(function (s) { a.learnSkill(s); }); });
            $gameParty._weapons = {}; $gameParty._armors = {};
            alienMake('w', 1044, 'boss', 'lifelink');
            A.openWorkshop(); await settle();
        },
        shots: {
            alien_config_bound: async function () { domClick('配置异化'); }
        },
        extra: domReadout
    };

    // 整队页领袖旗标（八戒_71 期三，Star_LeadActor 的 Window_PartySelect.drawActor 包装）：队伍 1/8/9/10/2/3/4，首位狗逍遥（领袖 5 号）。
    // 原版 ImageManager.loadSystem("LeaderFlag") 在绘制时才载入：打开时那一次可能还没载好（不画），重画一次才有。两态都截。
    P.party_leader = {
        setup: async function () {
            [2, 3, 4].forEach(function (id) { $gameParty.addActor(id); });
            await push(Scene_Party);
        },
        shots: {
            party_leader_open: async function () {},
            party_leader_redraw: async function () { scene()._partyWindow.refresh(); }
        },
        extra: function () {
            var w = scene()._partyWindow, flag = ImageManager.loadSystem('LeaderFlag'), r = w.itemRect(0);
            return {battleMembers: $gameParty._battleMembers.slice(), window: [w.x, w.y, w.width, w.height], padding: w.standardPadding(),
                textPadding: w.textPadding(), itemRect0: [r.x, r.y, r.width, r.height], flag: [flag.width, flag.height, flag.isReady()],
                flagAt: [r.width - w.textPadding() - flag.width + w.standardPadding() + w.x, w.y + w.standardPadding()]};
        }
    };

    // 装备页右下详情（界面 ui-gaps1，v0.62.12 installEquipmentDetailV041Runtime＋installPanelLayoutV043Runtime）：
    // 三页签「装备详情／属性对比／插槽与镶嵌」、整行分页的翻页条；物品页装备说明放右侧（v0.43）。
    // 长说明武器：角色 1 能装进槽 0 的武器里，详情排出来最高的那把（给一把，候选里选中它）。
    // 详情窗（640×431）里排出来的总高
    var probe41 = null;
    function detailRows(item) {
        if (!probe41) probe41 = new CodexEquipment41.Detail(0, 0, 640, 431);
        probe41._key41 = ''; probe41.setMode(0); probe41.setEquipment(item);
        return probe41._fullHeight41 || 0;
    }
    var longWeapon = 0, longKind = 'weapon';
    function detailState() {
        var s = scene(), d = s._detail41 || s._detail43, out = {longWeapon: longWeapon, longKind: longKind};
        if (!d) return out;
        out.detail = {rect: [d.x, d.y, d.width, d.height], visible: d.visible, mode: d._mode41, page: d._page41, pages: d._pages41,
            fullHeight: d._fullHeight41, pageTops: d._pageTops43 || null, originY: d.origin.y, contentsHeight: d.contentsHeight(), contentsWidth: d.contentsWidth(),
            item: d._item41 ? [d._item41.id, d._item41.name] : null,
            rows: d.rows41().map(function (r) { return [r[0], r[1], r[2], r[4]]; })};
        out.equipMode = s._equipMode41 !== undefined ? s._equipMode41 : s._mode43;
        return out;
    }
    // 技能页（ui-gaps4）：xiyou_skill_page 的预期值原是 v0.24 实测，这里用新源 v0.62.12 重量一遍（四人学 6168/5980/5548/2571/2786、Lv10）
    var skillPicked = {};
    async function skillType(i) {
        var s = scene();
        if (s._itemWindow.active) s.onItemCancel();
        s._skillTypeWindow.select(i); s._skillTypeWindow.processOk(); await settle();
        s._itemWindow.select(0); await settle();
    }
    P.skill_page = {
        setup: async function () {
            [1, 8, 9, 10].forEach(function (id) {
                var a = $gameActors.actor(id);
                [6168, 5980, 5548, 2571, 2786].forEach(function (k) { a.learnSkill(k); });
                a.changeLevel(10, false); a.refresh(); a.recoverAll();
            });
            // 魔法／其他／功法页要有内容：每类取 id≥2000 的前两个技能（id 记进 extra.picked）
            skillPicked = {};
            [2, 4, 5].forEach(function (st) {
                skillPicked[st] = [];
                for (var i = 2000; i < $dataSkills.length && skillPicked[st].length < 2; i++) {
                    var k = $dataSkills[i];
                    if (k && k.name && k.stypeId === st && !/^[?？]+$/.test(k.name)) skillPicked[st].push(i);
                }
                skillPicked[st].forEach(function (id) { $gameActors.actor(1).learnSkill(id); });
            });
            $gameActors.actor(1).refresh();
            await push(Scene_Skill);
        },
        shots: {
            skill_0_type: async function () {},
            skill_1_list: async function () { var s = scene(); s._skillTypeWindow.processOk(); },
            skill_2_second: async function () { var s = scene(); s._itemWindow.select(1); },
            skill_3_passive: async function () { await skillType(2); },
            skill_4_magic: async function () { await skillType(1); },
            skill_5_other: async function () { await skillType(3); },
            skill_6_function: async function () { await skillType(4); }
        }
        ,
        extra: function () {
            var a = $gameActors.actor(1), P = window.CodexCombatPower, p = P && P.actor(a, true);
            return {params: [0, 1, 2, 3, 4, 5, 6, 7].map(function (i) { return a.param(i); }), skills: a._skills.slice(), picked: skillPicked, stypes: $dataSystem.skillTypes.slice(), allSkills: a.skills().map(function (k) { return k.id; }),
                equips: a.equips().map(function (e) { return e ? [e.id, e.name] : null; }), level: a.level,
                power: p && {total: p.total, self: p.self, gear: p.gear, parts: p.parts, selfParts: p.selfParts},
                ablation: (function () {
                    var out = {}, books = [6168, 5980, 5548, 2571, 2786];
                    function pw() { a.refresh(); var q = P.actor(a, true); return [q.total, q.self, q.gear]; }
                    out.all = pw();
                    books.forEach(function (k) { a.forgetSkill(k); }); out.none = pw();
                    books.forEach(function (k) { a.learnSkill(k); var o = pw(); out['+' + k] = o; a.forgetSkill(k); });
                    out.version = window.CodexDamage && CodexDamage.version;
                    a.addState(1691); out.addState1691 = pw().concat([a.isStateAffected(1691)]); a.removeState(1691);
                    a.addState(1631); out.addState1631 = pw().concat([a.isStateAffected(1631)]); a.removeState(1631);
                    books.forEach(function (k) { a.learnSkill(k); }); a.refresh();
                    return out;
                })(),
                difficulty: window.ConfigManager && ConfigManager.difficulty, passives: (a.states() || []).map(function (st) { return st.id; })};
        }
    };
    P.equip_detail = {
        setup: async function () {
            var a = $gameActors.actor(1), best = 0, bestN = 0;
            for (var id = 1; id < $dataWeapons.length; id++) {
                var w = $dataWeapons[id];
                if (!w || !w.name || id > 3000 || !a.canEquipWeapon(w)) continue;
                var n = detailRows(w);
                if (n > bestN) { bestN = n; best = id; }
            }
            longWeapon = best;
            $gameParty.gainItem($dataWeapons[best], 1);
            await push(Scene_Equip);
        },
        shots: {
            equip_detail_0_command: async function () {},
            equip_detail_1_slot: async function () { var s = scene(); s._commandWindow.selectSymbol('equip'); s._commandWindow.processOk(); },
            equip_detail_2_compare: async function () { scene().chooseDetail41(1); },
            equip_detail_3_sockets: async function () { scene().chooseDetail41(2); },
            equip_detail_4_item: async function () {
                var s = scene(); s.chooseDetail41(0); s._slotWindow.processOk(); await settle();
                var w = s._itemWindow, list = w._data || [];
                for (var i = 0; i < list.length; i++) if (list[i] && (list[i].baseItemId || list[i].id) === longWeapon) { w.select(i); break; }
            },
            equip_detail_5_page2: async function () { scene()._detail41.turn41(1); },
            equip_detail_6_scroll: async function () { var d = scene()._detail41; d.turn41(-1); d.scroll41(100); }
        },
        extra: detailState
    };
    P.item_detail = {
        setup: async function () {
            var best = null, bestN = 0;
            [$dataWeapons, $dataArmors].forEach(function (db) {
                for (var id = 1; id < db.length && id <= 3000; id++) {
                    var w = db[id];
                    if (!w || !w.name) continue;
                    var n = detailRows(w);
                    if (n > bestN) { bestN = n; best = w; }
                }
            });
            longWeapon = best.id; longKind = DataManager.isWeapon(best) ? 'weapon' : 'armor';
            $gameParty.gainItem(best, 1);
            await push(Scene_Item);
        },
        shots: {
            item_detail_0_weapon: async function () {
                var s = scene(); s._categoryWindow.selectSymbol(longKind); s._categoryWindow.update(); s.onCategoryOk(); await settle();
                var w = s._itemWindow, list = w._data || [];
                for (var i = 0; i < list.length; i++) if (list[i] && (list[i].baseItemId || list[i].id) === longWeapon) { w.select(i); break; }
            },
            item_detail_0b_page2: async function () { scene()._detail43.turn41(1); },
            item_detail_0c_scroll: async function () { var d = scene()._detail43; d.turn41(-1); d.scroll41(100); },
            item_detail_1_sockets: async function () { scene().gearTab43(2); },
            item_detail_2_item: async function () {
                var s = scene(); s.gearTab43(0); s.onItemCancel(); s._categoryWindow.selectSymbol('item'); s._categoryWindow.update(); s.onCategoryOk();
            }
        },
        extra: detailState
    };

    // 藏宝图批量使用（界面 ui-gaps1，installTreasureBatchRuntime）：特级藏宝图 212 ×5，物品页「使用」开数量窗；
    // 改数量、MAX、确定后逐帧用完，读结果（CodexTreasure.lastResult）与说明卡文字；另在地图上直接给一件至臻武器 1885，读至臻通知窗。
    function treasureState() {
        var s = scene(), w = s._codexTreasureNumber, T = window.CodexTreasure, ui = s._codexPrestigeNotice;
        var out = {lastResult: T ? T.lastResult : null, stock212: $gameParty.numItems($dataItems[212]), job: s._codexTreasureJob ? {state: s._codexTreasureJob.state, used: s._codexTreasureJob.used} : null};
        if (w) out.number = {rect: [w.x, w.y, w.width, w.height], visible: w.visible, active: w.active, number: w._number, max: w._max, padding: w.standardPadding(),
            buttonY: w.buttonY(), itemY: w.itemY(), cursorWidth: w.cursorWidth(), cursorX: w.cursorX(),
            buttons: (w._buttons || []).concat(w._codexMaxButton ? [w._codexMaxButton] : []).map(function (b) { return [b.x, b.y, b.width, b.height, b.visible]; })};
        if (s._helpWindow) out.help = {visible: s._helpWindow.visible, text: s._helpWindow._text || null, rows: (s._helpWindow.item && s._helpWindow.item.descParams || []).map(function (r) { return r[0]; })};
        if (ui) out.notice = {frames: ui.frames, flashFrames: ui.flashFrames, flash: ui.flash.opacity, rect: [ui.window.x, ui.window.y, ui.window.width, ui.window.height],
            visible: ui.window.visible, contentsOpacity: ui.window.contentsOpacity};
        return out;
    }
    P.treasure_batch = {
        setup: async function () {
            $gameParty.gainItem($dataItems[212], 5);
            await push(Scene_Item);
            var s = scene(); s._categoryWindow.selectSymbol('item'); s._categoryWindow.update(); s.onCategoryOk(); await settle();
            var w = s._itemWindow, list = w._data || [];
            for (var i = 0; i < list.length; i++) if (list[i] && list[i].id === 212) { w.select(i); break; }
        },
        shots: {
            treasure_0_open: async function () { var s = scene(); s.useItem(); },
            treasure_1_plus: async function () { var w = scene()._codexTreasureNumber; w.changeNumber(1); w.changeNumber(1); },
            treasure_2_max: async function () { var w = scene()._codexTreasureNumber; w._number = w._max; w.refresh(); w.changeNumber(-10); w.changeNumber(1); w.changeNumber(1); },
            treasure_3_done: async function () { var w = scene()._codexTreasureNumber; w.processOk(); await frames(30); },
            treasure_4_cancel: async function () { var s = scene(); s._itemWindow.processOk && 0; s.useItem(); await settle(); scene()._codexTreasureNumber.processCancel(); }
        },
        extra: treasureState
    };
    P.prestige_notice = {
        setup: async function () {},
        shots: {
            prestige_0_gain: async function () { $gameParty.gainItem($dataWeapons[1885], 1); $gameParty.gainItem($dataWeapons[1886], 1); $gameParty.gainItem($dataArmors[3623], 1); await frames(1); },
            prestige_1_f40: async function () { await frames(40); },
            prestige_2_f140: async function () { await frames(100); },
            prestige_3_end: async function () { await frames(40); }
        },
        extra: function () {
            var s = scene(), ui = s._codexPrestigeNotice;
            return ui ? {frames: ui.frames, flashFrames: ui.flashFrames, flash: ui.flash.opacity, rect: [ui.window.x, ui.window.y, ui.window.width, ui.window.height],
                visible: ui.window.visible, contentsOpacity: ui.window.contentsOpacity, padding: ui.window.standardPadding(), lineHeight: ui.window.lineHeight(),
                texts: (ui.window.contents.__ilrText || []).map(function (t) { return [t.text, t.x, t.y, t.w, t.align, t.size, t.color]; })} : null;
        }
    };

    // 界面逐页像素／矩形对照（白龙 ui-pixel1）：主菜单、物品、装备、状态、商店五页，新局原样（不另给东西，物品页另给 732 ×3），
    // Godot 一侧 tests/xiyou_ui_pixel -- --out=<目录> 出同名截图与窗口矩形，ui_pixel_compare.py 逐个比矩形、出像素差热图。
    // 头像先载好：直接 push 装备／状态页时头像图还没进缓存，Window_SkillStatus／Window_Status 画的是空（实际游戏从主菜单进，头像已载）
    async function faces() { $gameParty.members().forEach(function (a) { ImageManager.loadFace(a.faceName()); }); await settle(); }
    P.px_menu = {
        setup: async function () { await push(Scene_Menu); },
        shots: {
            px_menu_0_command: async function () {},
            px_menu_1_party: async function () { var w = scene()._commandWindow; w.selectSymbol('skill'); w.processOk(); }
        }
    };
    P.px_item = {
        setup: async function () { $gameParty.gainItem($dataItems[732], 3); await push(Scene_Item); },
        shots: {
            px_item_0_category: async function () {},
            px_item_1_list: async function () { var s = scene(); s._categoryWindow.selectSymbol('item'); s._categoryWindow.update(); s.onCategoryOk(); }
        }
    };
    P.px_equip = {
        setup: async function () { await faces(); await push(Scene_Equip); },
        shots: {
            px_equip_0_command: async function () {},
            px_equip_1_slot: async function () { var s = scene(); s._commandWindow.selectSymbol('equip'); s._commandWindow.processOk(); },
            px_equip_2_list: async function () { scene()._slotWindow.processOk(); }
        }
    };
    P.px_status = {
        setup: async function () { await faces(); await push(Scene_Status); },
        shots: { px_status_0: async function () {} }
    };
    P.px_shop = {
        setup: async function () {
            $gameParty.gainGold(50000);
            await push(Scene_Shop, function () { SceneManager.prepareNextScene([[0, 732, 0, 0], [1, 1, 0, 0], [2, 4375, 0, 0]], false); });
        },
        shots: {
            px_shop_0_command: async function () {},
            px_shop_1_buy: async function () { var s = scene(); s._commandWindow.selectSymbol('buy'); s._commandWindow.processOk(); },
            px_shop_2_sell_category: async function () { var s = scene(); s._buyWindow.deactivate(); s.onBuyCancel(); s._commandWindow.selectSymbol('sell'); s._commandWindow.processOk(); }
        }
    };

    // 界面像素对照三期（白龙 ui-pixel3）：页名 px3_*，截图名与 Godot 各专项 --out 的截图同名（ui_pixel_compare.py 按名配对）。
    // 整队：队伍 1/8/9/10/2/3/4（同 tests/xiyou_party）；打开 → 调整第 0 格、名单第 6 行（狗逍遥 3）→ 3 换进第 0 格、10 换进第 1 格、再「离队」清空第 1 格
    P.px3_party = {
        setup: async function () {
            [2, 3, 4].forEach(function (id) { $gameParty.addActor(id); });
            await faces();
            await push(Scene_Party);
            scene()._partyWindow.refresh();  // 领袖旗标第一次画时还没载好（见 party_leader）
        },
        shots: {
            '整队_打开': async function () {},
            '整队_名单': async function () {
                var s = scene();
                s._commandWindow.selectSymbol('change'); s._commandWindow.processOk(); await frames(2);
                s._partyWindow.processOk(); await frames(2);
                s._listWindow.select(6);
            },
            '整队_空位': async function () {
                var s = scene();
                s.onListOk(); await frames(2);
                s._partyWindow.select(1); s._partyWindow.deactivate(); s._listWindow.activate();
                s._listWindow.select(s._listWindow._data.indexOf(10)); s.onListOk(); await frames(2);
                s._partyWindow.deactivate(); s._listWindow.activate(); s._listWindow.select(0); s.onListOk();
            }
        },
        extra: function () { return {party: $gameParty._actors.slice(), battle: $gameParty._battleMembers.slice()}; }
    };
    // 宝珠坊：变量 20＝15，背包只有神秘珠·玄藏 ×12、尘封 ×1、残片 ×40（同 tests/xiyou_orb_shop_ui 的 _geometry）
    P.px3_orb_shop = {
        setup: async function () {
            $gameParty._items = {}; $gameParty._weapons = {}; $gameParty._armors = {};
            $gameVariables.setValue(20, 15);
            $gameParty.gainItem($dataItems[3029], 12); $gameParty.gainItem($dataItems[3027], 1); $gameParty.gainItem($dataItems[2531], 40);
            await push('Scene_CodexBindMenu', null, function () { if (!CodexOrbs.open()) throw new Error('打不开宝珠坊'); });
        },
        shots: {
            orb_shop_home: async function () {},
            orb_shop_identify_detail: async function () { yunPick('鉴定神秘珠'); await frames(2); yunPick('神秘珠·玄藏 ×12'); }
        }
    };

    // 人物图鉴（同 tests/xiyou_actor_book 的 _flow）：目录第 1 项、167 号以后各立绘、第 1 项技能详情（第 0 行）
    function bookPick(sid) {
        var s = scene(), iw = s._indexWindow, i = sid === 1 ? 1 : iw._list.findIndex(function (a) { return a && a.actorId && a.actorId() === sid; });
        if (i < 0) throw new Error('图鉴目录没有 ' + sid);
        iw.select(i); s._windowIdx = -1; s.update();
    }
    var bookShots = {actor_book_1: async function () { bookPick(1); }};
    [167, 168, 171, 173, 174, 175, 176, 177, 178, 179].forEach(function (sid) { bookShots['actor_book_' + sid] = async function () { bookPick(sid); }; });
    bookShots.actor_book_1_skills = async function () { bookPick(1); await settle(); scene().openActorSkillDetails(); };
    P.px3_actor_book = {
        setup: async function () { await push(Scene_ActorBook); },
        shots: bookShots
    };

    // 成就（同 tests/xiyou_achievement 的 _ui）：全局有 1、2（无时间）、22（本局无）、51，本局有 1、51；
    // 挑战类 → 事件类列表第 7 行 → 本局再得 60（弹窗推 90 帧）
    P.px3_achievement = {
        setup: async function () {
            var T = '2026年1月2日 3:4:5';
            ConfigManager.SAchievementS = {1: true, '1Time': T, 2: true, 22: true, '22Time': T, 51: true, '51Time': T};
            $gameParty.SAchievementS = {1: true, 51: true};
            await push(Scene_AchievementBook);
        },
        shots: {
            achievement_01_challenge: async function () {},
            achievement_02_event_list: async function () {
                var s = scene();
                s._indexTypeWindow.select(1); await frames(2); s.onRangeOk(); await frames(2); s._indexWindow.select(7);
            },
            achievement_03_popup: async function () { Star.AchievementSystem.GetAcReward(60); await frames(90); }
        }
    };

    // 设置（同 tests/xiyou_options_basic／_misc 的截图点；配置值照 Godot 截图那一刻：BGM 80、SE 40、只遇稀有开）：
    // 第 11 行 → 「步步遇敌」行 → 屏蔽掉落子页第 0 行确定（开）
    function optSelect(sym) { var w = scene()._optionsWindow, i = w.findSymbol(sym); w.select(i); }
    P.px3_options = {
        setup: async function () {
            ConfigManager.bgmVolume = 80; ConfigManager.seVolume = 40; ConfigManager.Boss = true;
            await push(Scene_Options);
        },
        shots: {
            '设置音量': async function () { scene()._optionsWindow.select(11); },
            '杂项开关': async function () { optSelect('yd100'); },
            '屏蔽掉落': async function () {
                optSelect('pingbiDrop'); scene()._optionsWindow.processOk();
                await wait(function () { return scene().constructor.name === 'Scene_PingbiMenu' && SceneManager._sceneStarted; });
                await settle();
                var s = scene(), w = s._commandWindow || s._pingbiWindow || s._windowLayer.children.filter(function (c) { return c instanceof Window_Selectable; })[0];
                w.select(0); w.processOk();
            }
        }
    };

    // 换装卡战斗外观（八戒_71 期一，单独跑：node review_system_pages.cjs <目录> battle_costume）：角色 1 学会 6801「变身——深渊骑士」，
    // 开战 StartPushState1201 100% 推上卡状态，Custom Apply Effect setBattlerImage('Enemy_General_M')；地图 5、敌群 2、难度 3、四人
    P.battle_costume = {
        setup: async function () {
            $gameSystem._difficultyId = 3;
            $gameParty.members().forEach(function (a) { a.recoverAll(); });
            $gameActors.actor(1).learnSkill(6801);
            BattleManager.setup(2, true, false);
            SceneManager.push(Scene_Battle);
            await wait(function () {
                var s = scene();
                return s instanceof Scene_Battle && SceneManager._sceneStarted && ImageManager.isReady() && s._actorCommandWindow && s._actorCommandWindow.isOpenAndActive();
            }, 60000);
            await settle(40);
        },
        shots: {
            battle_costume_card: async function () {}
        },
        extra: function () {
            return scene()._spriteset._actorSprites.filter(function (sp) { return sp._actor; }).map(function (sp) {
                var m = sp._mainSprite, b = m && m.bitmap;
                return {actor: sp._actor.actorId(), battlerName: sp._actor.battlerName(), states: sp._actor._states.slice(), x: sp.x, y: sp.y,
                    bitmap: b ? [b._url || '', b.width, b.height] : null, frame: m ? [m._frame.x, m._frame.y, m._frame.width, m._frame.height] : null,
                    scale: [sp.scale.x, sp.scale.y]};
            });
        }
    };

    // 战斗内怪物信息（放最后：进了战斗就回不到下一页的新局）：battle_enemy_book_oracle.json 的场面（地图 5、敌群 2、难度 3、四人），角色指令窗按 Shift 的原入口
    P.battle_book = {
        setup: async function () {
            $gameSystem._difficultyId = 3;
            $gameParty.members().forEach(function (a) { a.recoverAll(); });
            BattleManager.setup(2, true, false);
            SceneManager.push(Scene_Battle);
            await wait(function () {
                var s = scene();
                return s instanceof Scene_Battle && SceneManager._sceneStarted && ImageManager.isReady() && s._actorCommandWindow && s._actorCommandWindow.isOpenAndActive();
            }, 60000);
            await settle(40);
        },
        shots: {
            battle_42_enemy_book: async function () { scene()._actorCommandWindow.processAB_EnemyBook(); }
        }
    };
})();
