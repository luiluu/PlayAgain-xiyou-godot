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
        return {fixture: '冻结v0.28；内存新局 1/8/9/10；地图 5；无存档', page: name, shot: shot, scene: s.constructor.name,
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
})();
