# 交付：claude/bajie-alien

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_59）
- 状态：可合并

## 规模与分期

原版异化四个模块约 115KB（installAlienationRuntime／Workshop／Affixes／Advanced）。工坊本身是 DOM 叠加层，不是 MV 窗口。

- 期一（本单）：菜单侧。异化数据表（词条 20 条、兼容池、Boss 专属、材料 ID）；装备实例上的异化标记与账本存档；工坊页（能量与异化石、合成、装备列表与详情、重抽与待选、分解与确认、无装备时的获取说明、最近异化掉落）；主菜单入口；原版参照探针与专项。
- 期二：配置异化（绑定队友、作用技能、吞器供体、百相、无面借技能）与穿戴限制（每人最多一件、配置未就绪不能穿、商店与挂机不卖）。
- 期三（战斗，沙僧）：异化敌人遭遇与掉落发放、五种变体、20 种词条的战斗效果，接口见「规则接口」。

## 变更记录草稿

## 2026-10-23 【Claude·八戒_59·未经Codex检验】异化工坊菜单侧期一（dev.待定）

- **数据**：新 `modes/xiyou/alienation.json`（冻结 v0.28 CodexAlienation.config 与 20 条词条的名字、收益、代价：材料 ID 能量 2872／异化石 2873、20 点合成、22 个本体兼容池、Boss 专属 4 条、需绑定／需技能的词条、小怪来源地图 29／30／32／33），由新探针导出，专项核对与原版一致。
- **运行时**（新 `core/alienation.gd` XAlienation，照 installAlienationRuntime＋Advanced 的工坊侧）：异化标记放在装备实例的 `alien` 字段（uid、来源、词条、兼容池、配置、原名），随装备存档，名字改成「词条名·原名」；账本新存档字段 `XState.alien_ledger`（序号、待选重抽、最近掉落）。合成（20 能量换 1 异化石，有待选时不行）、重抽（消耗 1 异化石，从兼容池里去掉当前词条后随机一条，进入待选）、待选（保留旧／采用新，都不返还材料）、分解（小怪装备 1 点、Boss 装备 5 点能量）；只能操作背包里未装备、未锁定（名字带「[锁定]」）、未被吞器占用、没有待选的异化装备。错误文字逐字照原版。`create`／`attach` 供期三掉落发放用。
- **工坊页**（新 `ui/alien_workshop.gd` XAlienWorkshop）：原版是盖在菜单上的网页叠加层，这里先按原版 render 搭同样的节点树，再照它的 CSS 摆成 Godot 控件（暗底、居中面板 1080 宽、紫色按钮与选中态、灰显按钮）。页面：标题与返回、能量与异化石及合成按钮、待选时两张选择卡、列表（锁定的加「　[锁定]」）与详情（异化、收益、代价、来源、保留说明、装备属性、不能操作时的提示、重抽／分解／配置异化）、分解确认框、没有异化装备时的获取说明、可展开的「最近异化掉落（N）」前 10 条。选中项跨开关保留（同原版模块变量）。Esc 关闭。字体用游戏字体（原版是系统字，Godot 系统字回退会缺「敌」等字）。
- **入口**：主菜单「异化工坊」开放（原版 Scene_Menu 直接 openWorkshop）。主菜单只剩「反馈」灰显（不接）。
- **参照与测试**：新探针 `mv_oracle/alien_workshop_probe.cjs`（配置与词条；合成、异化、重抽、待选、分解与失败返回 16 项；jsdom 里打开工坊，按按钮点 5 条路线，逐步读叠加层节点树），产物 `generated/oracle/alien_workshop.json`；新专项 `xiyou_alien_workshop` 40 项（窗口模式 `-- --out=<目录>` 存截图）。`xiyou_panels` 灰显名单只剩「反馈」，`xiyou_notice_options` 灰显蜂鸣改用「反馈」，`界面风格.md` 同步。
- **规则接口（期三交沙僧）**：
  - 读：装备实例 `alien` 字段 `{affix, origin, config}`；角色身上的异化装备＝`equip_list()` 里带 `alien` 的那件（原版 `A.forActor`）；词条说明与分组在 `XAlienation.config()`（boundKeys 需绑定队友、skillKeys 需作用技能）。战斗开始时原版把它冻结成 `_alienBattle {item, affix, config 副本, observed, selected}`，战后清掉，不进存档。
  - 掉落：遭遇时按 `C.bossSources`／`mobSources` 与转换表选本体（这两张表还没导出，期三导出时一起），胜利后 `XAlienation.create(s, kind, id, origin)` 得到装备、放进 `s.gear`，账本 `recent` 头插 `{name, origin, uid, kind, id}`、保留 30 条，提示「获得 …」。
  - 敌人变体（烈变、蜕壳、蚀能、灾疫、镜骸，小怪是「异化」）：生命 ×1.5（小怪 ×1.25）、名字前加【异化·X】、各自效果见原版 `A.variants` 说明与 Runtime 的 drain／plague／mirror 钩子；腐蚀状态 2652。
  - 词条效果在原版 installAlienationAffixes／Advanced 的伤害、治疗、状态、技能替换钩子里，全部属战斗。
- **未做**：配置异化页（按钮照原版显示与灰显，点了不打开，期二）；穿戴限制与商店、挂机不卖（期二）；掉落与战斗（期三）。
- 唐僧_16 合并时修：探针把原版抛出的提示记成 `{thrown: 文字}`（原记 `error`，同步的错误守卫会当成探针失败拒收），专项同步改读 `thrown`；Godot 运行时仍返回 `{"error": 文字}`。

## 交接板

- 下一步：异化工坊期二（配置异化与穿戴限制，八戒）；期三战斗与掉落（沙僧，接口见变更记录本条「规则接口」）。
- 用户试玩说明：主菜单「异化工坊」可以打开了，能看到能量、异化石和获取说明；异化装备要等期三接上掉落才会出现，现在打开会是「尚未获得异化装备」。

## 进度账

- 界面：主菜单 18 项除「反馈」（不接）外都已接入。

## 验证

- `并行测试.py` 专项：`xiyou_alien_workshop` 40/40、`xiyou_panels` 35/35、`xiyou_notice_options` 71/71、`xiyou_race_menu` 66/66、`xiyou_orb_shop_ui` 27/27、`xiyou_save_page` 40/40。
- `同步正式西游.py --accept-additions` 在本 worktree 跑过（新探针 alien_workshop）。

## 本分支提交

- 29940f0c 交付单规模与分期
- c5bd42e5 XAlienation、工坊页、主菜单入口、原版参照与专项
- 1f370032 异化随机改固定值开关（修退出崩溃），界面风格说明更新
- aa419857 合并 main
