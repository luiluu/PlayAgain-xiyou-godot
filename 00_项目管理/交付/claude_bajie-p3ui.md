# 交付：claude/bajie-p3ui

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_61）
- 状态：可合并

## 变更记录草稿

## 2026-10-24 【Claude·八戒_61·未经Codex检验】沙僧核查留下的界面 P3 三项：图鉴掉落卡外框、人物图鉴返回残留（O-084）、伤害弹数纵向锚点（dev.待定）

- **怪物图鉴掉落说明卡**（沙僧52「P3」）：冻结 `AB_EnemyBook.js` updateHelp 设好卡后 `HEw.hide()`，而 `ItemQuality.js` 与 `HelpExtend.js` 的 `Sprite_ItemHelp.hide` 会移除 4 层品质发光窗口和技能书附卡，随后只把卡设回可见，所以图鉴掉落入口只有卡本体。`XHelpCard` 新增 `show_frame`（默认 true），`XEnemyBook` 设为 false，并以 `with_extras=false` 调 `show_for`。其他界面的说明卡不变。卡高 239 与 267 的差别来自已保留的 O-007，没有改动。
- **人物图鉴返回目录**（沙僧52 人物图鉴）：原版返回目录时只藏起卡本体，品质边框留在状态页 [535,-2,747,315]；重制返回时整张卡隐藏。保留重制做法，登记为优化 **O-084**，开关是 `XActorBook.HIDE_HELP_ON_RETURN`。设为 false 时只藏卡本体（`help_card.canvas`），边框留在原处，再进详情时照常重画（`show_for` 会把 canvas 设回可见）。
- **伤害弹数纵向锚点**（沙僧51「P3」）：`LGP_BetterDamagePopup` 的 drawDefaultNumber 先设 anchor.y = 1，再加上「该目标当前存活的回复弹数（含自己）− 1」，所以没有回复时普通伤害的锚点是 0，回复是 1。YEP 的 Popup Overlap Rate 0.9 是在 pushDamageSprite 时加的，那时新弹数还没有子精灵，所以实际不起作用。新写的原版参照证实了这两点。`XDamagePopup.anchor_y()` 改为「此前存活的回复弹数 ＋（自己是回复则加 1）」，Miss 仍是 0.5；`battle_scene._popup` 传入同一目标存活的回复弹数，不再传全部弹数。修正后单个普通伤害的顶边从 264 落到 302，与正式版一致。未改 `damage.gd`。
- **原版参照**：新增 `03_转换工具/ui_reference/popup_anchor_ref.py`/`.js`（只读，端口 8768，沿用 serve.py 守卫）。在四人内存夹具上，对敌人 0 和角色 0 用真实 startDamagePopup／setupDamagePopup 依次弹出七种组合（伤害、回复、伤害＋伤害、回复＋回复、回复＋伤害、伤害＋回复、回复＋回复＋伤害），记录锚点、根位置和边界，errors=[]。压缩后存 `tests/fixtures/popup_anchor_oracle.json`。冻结源身份前后相同（按 source_before 的 7 个文件哈希手动复核）。
- **测试**：`xiyou_enemy_book` 新增 drops_help_no_frame；`xiyou_actor_book_review` 的三个 `_mode` 断言挪到取图之前，常规检查也会验（1 项变为 6 项），另新增 O-084 回退两项（边框矩形等于 [535,-2,747,卡高+20]，再进详情时卡重新显示）；`xiyou_popup_overlap` 新增 14 例锚点对照，以及单个伤害 5 帧后顶边与原版 302 对照。重叠矩形改用 `anchor_y()` 计算。
- 提交：见「本分支提交」。

## 交接板

- 下一步：无新增。
- 用户试玩说明：怪物图鉴的掉落说明卡不再有品质彩框（与原版一致）；战斗中普通伤害数字比之前低约一个字高，回复数字位置不变。
- 需要用户决定：
  - O-084 人物图鉴返回目录时整卡隐藏（原版残留品质边框），是否保留。

## 三项以外的发现（未做）

- 冻结源 `HelpExtend.js` 的 `Sprite_ItemHelp.hide` 还会移除 `Star_ItemHelp`～`Star_ItemHelp3`，但冻结源里没有任何地方定义这几个对象，所以不影响任何画面。
- 原版普通伤害没有回复时，锚点 0 让数字画在根点下方。叠在回复弹数上的普通伤害锚点会跟着回复数升高，连续普通伤害则完全重叠（两个都在同一高度，只靠 x 轨迹略错开）。这些都照原版复现，没有作为优化处理。

## 验证

- `并行测试.py` 专项 31 场，全部首次通过、无偶发（并行 2，880 秒）：help_card 970、enemy_book 52、actor_book 22、actor_book_review 6、popup_overlap 8（无窗口模式，像素负控按原设计跳过）、battle_ui 70、combat 34、battle_options 92、drop_record 26、item_list 38、item_marks 108、item_use 11、gear_ui 47、gear_search 58、shop_buy 5680、shop_stock 46、skill_page 21、status_page 43、status_power 36、status_power_panel 11、panels 35、pets 27、orb_ui 39、magic_level 7、lobby_shops 92、window_rects 9、zhenqi 181、zhenqi_break 83、zhenqi_daofa 68、review_fix 60、review_fixes 16。说明卡改动涉及的界面测试都在其中。
- 合 main（fd393a51，只带进文档和开发编号）后没有重跑。没有改 mv_oracle 探针和切片，所以没跑同步。按车道规则不跑全量。
- 临时输出已清理：原版参照服务已停，`04_验证/本地结果/popup_anchor_ref/`（原始读数、日志）和 `04_验证/本地结果/bajie-p3ui/`（测试日志）已删，压缩后的读数在 fixture 里。

## 本分支提交

- addf3d64 WIP: 怪物图鉴掉落卡去品质外框、人物图鉴 O-084 开关、伤害弹数锚点照原版（含原版参照 popup_anchor_ref）
- f2a74296 WIP: 优化登记 O-084、界面风格注明、ui_reference README 补弹数锚点参照
- 50f2c657 合并 main
