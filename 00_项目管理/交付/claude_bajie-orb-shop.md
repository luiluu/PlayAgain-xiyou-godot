# 交付：claude/bajie-orb-shop

- 车道／工作者：B 界面·宝珠坊／八戒（Claude，重制_八戒_10）
- 状态：可合并（main 无新提交、worktree 同步「测量不变」，`检查.sh --oracle` 全部通过：52 个场景、约 79,812 项）
- 预分配 O-042～O-044：未用。
- 入口：正式版宝珠坊只从主菜单「宝珠坊」进（installNativeOrbRuntime 给 Window_MenuCommand 加 codexOrbs → CodexOrbs.open），不在地图事件里，入口已在本车道接上（menu.gd）。
- 交给悟空（副本系统）接线：① 神秘珠掉落 `XOrbs.drop_boss_pearl(s, 楼层)`——正式版挂在 CodexEconomy.bossReward（副本 Boss 胜利奖励发出后，每场最多一次，楼层取开战时的 CodexHonghuang.bossFloor），返回的 `toast` 要用 $.toaster 提示；② 公共事件 1439（肝帝积分券）第 42 行 `$gameVariables.setValue(1473, CodexOrbs.rollInt('fragment',1,2))` 对应 `XOrbs.roll_int(s, "fragment", 1, 2)`（随存档的随机流，防 SL）。
- 合并注意：`dev.待定` 在 `00_设计/框架维护约定.md`（1 处）、`00_设计/界面风格.md`（1 处）。本分支新增探针 `orb_shop_probe.cjs`（PROBES 加一行），main 上同步时测量变化应只有新增 `orb_shop.json`。

## 变更记录草稿

## 2026-10-16 【Claude·八戒·未经Codex检验】宝珠坊：鉴定、残片兑换、分解、暂存领取、楼层分布、套装图谱；主菜单「宝珠坊」开放（dev.待定）

- 规则（严格级）：`XOrbs` 加宝珠坊部分，照正式 installNativeOrbRuntime。随存档的 `XState.orb_state`（各随机流已取次数、暂存宝珠、神秘珠暂存箱、最近鉴定）；`roll(流)` ＝ hash32(种子:流:序号) 混合（读档重来结果不变）。鉴定：每枚先按 legacyShare 50% 判原作宝珠（层段弱/中/强档池等概率），否则按层段阶位权重定阶、16 类等概率；先报价（神秘珠数量、可能产出的宝珠都要有背包空间）再换物。残片换神秘珠：层段按已到最高层（变量 20－1，限 0～33，至少按 1 层），价格 11/22/33/55/66。分解：新宝珠按阶 1/3/7/15/31 残片，原作宝珠按 legacyRefund。暂存宝珠／神秘珠暂存箱在打开宝珠坊时领（背包满的部分继续保留）。另留副本 Boss 掉落接口 `drop_boss_pearl`（流 drop、10%、背包满进暂存箱），接线交悟空。
- 界面（标准级）：新增通用选择窗 `XChoiceWindow`（正式 Window_YunChoices：宽 760 居中、说明区＋分隔线、命令行 36、最多 12 行可见、滚动、不可选半透明蜂鸣）与宝珠坊 `XOrbShop` 全部页面（主页、鉴定列表/详情/确认/结果与结果详情、残片兑换与确认、分解列表/详情/确认、暂存领取、楼层与品质分布、套装图谱与当前配装）；说明按 48 个半角宽换行。主菜单「宝珠坊」由灰显改为可用。
- 正式差异（照搬或说明）：正式版暂存箱若出现「weapon/armor N」，领取时会生成新装备却不扣暂存数（数据里不会出现）；Godot 只认「item N」，其余保留不领。
- 参照：`mv_oracle/orb_shop_probe.cjs`（接进同步 PROBES，输出 orb_shop.json）：4 个种子 × 4 条随机流前 25 个值与 rollInt、60 例鉴定（结果、背包、随机流序号、最近鉴定）、6 种鉴定失败、5 种神秘珠的可能产出与概率、37 例残片兑换、9 例分解、暂存宝珠与暂存箱领取、7 条宝珠坊点选路线的逐页行文。界面读数 `tests/fixtures/orb_shop_ui_oracle.json`（ui_reference 浏览器：主页/鉴定列表/鉴定详情的窗口矩形、说明高、可见行数）。
- 验证：`tests/xiyou_orb_shop` 22/22、`tests/xiyou_orb_shop_ui` 27/27；ui_smoke、hud、panels、flow、item_list、orbs、orb_ui 通过；首次全量检查报宝珠坊界面测试退出时音效资源未释放，改为退出前停掉音效后，`检查.sh --oracle` 全部通过（52 个场景、约 79,812 项）。
- 提交：40c7074、385be4b、17def8f、7d117c0、57ceb5b、e65ca0a、efc7522。
- 未完成：神秘珠掉落与 CE1439 残片随机数的接线（副本系统，交悟空）；原作宝珠 ShareLearnSkill 技能效果仍未移植；现阶段玩家手里没有神秘珠与残片来源，宝珠坊可打开但多半显示「尚无未鉴定神秘珠」。

## 交接板

- 下一步第 5 项：「宝珠坊／神秘珠鉴定未做」改为「宝珠坊已做（dev.待定）；神秘珠掉落与 CE1439 残片接线随副本系统（悟空）」。
- 第 2 项副本一批：加一句「副本 Boss 胜利后接 `XOrbs.drop_boss_pearl(s, 楼层)`，CE1439 第 42 行用 `XOrbs.roll_int(s, "fragment", 1, 2)`」。
- 待交叉核查加一行：claude/bajie-orb-shop 各提交及合并提交（dev.待定），Claude（八戒、唐僧），宝珠坊规则与界面、通用选择窗；养成与周边系统 4%→初值见下。
- 用户试玩说明：主菜单「宝珠坊」可以打开：鉴定神秘珠、用宝珠残片换神秘珠、分解宝珠、领取暂存宝珠、查看楼层掉落分布与套装图谱。神秘珠和残片要等副本系统接上后才拿得到。
- 需要用户决定：无新增。

## 进度账

- 养成与周边系统（权重 18）：4% → 6%（+0.36；宝珠坊是清单里 10 个周边系统之一，规则与界面完成、掉落接线未做，按约半个计）。装备系统 68% 不变（镶嵌已计）。初值待 Codex 复核。

## 本分支提交

- 40c7074 车道开工，建交付单
- 385be4b 宝珠坊参照探针 orb_shop_probe，接进 PROBES
- 17def8f 宝珠坊规则与正式参照比对 xiyou_orb_shop
- 7d117c0 宝珠坊界面（XChoiceWindow＋XOrbShop）与主菜单入口
- 57ceb5b 神秘珠掉落接口 drop_boss_pearl
- e65ca0a 界面风格、框架维护约定补宝珠坊
- efc7522 宝珠坊界面测试退出前停掉音效
