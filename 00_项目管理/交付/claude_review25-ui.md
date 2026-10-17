# 交付：claude/review25-ui

- 车道／工作者：审查·界面与系统／悟空（Claude，重制_悟空_10，中等努力）
- 状态：可合并

## 变更记录草稿

## 2026-10-17 【Claude·悟空·未经Codex检验】进度审查 20%＋25%（界面与系统）

- 范围：15% 基线 dev.015 以后的界面与系统：dev.016～021（地图 HUD、传送页、挂机两批、连击、七档品质、设置页、挂机子页）、029～031（整队、技能页、掉落动画、伤害记录）、040、043、046、049、051（出售报酬、商店数量窗、战力、技能武器类型、变量／物品购买）、055～056、059、061（装备检索、战力条、状态页、物品列表）、064～065（宝珠镶嵌、宝珠坊）、067（存读档页）、069～070（掉落 dh、技能动画画面）。dev.039 已在 20% 审过不重审。悟空不审自己的提交（本范围内无悟空提交）。各笔已由沙僧逐个核查，本轮不逐行重复，按 ①～④ 跨模块看。
- 方法：
  - ① 对照正式版：`ui_reference` 跑冻结 v0.28（`?item_list_ref=1` 内存四人新局，不读写存档；内置浏览器窗格隐藏时手动推帧），读各场景全部 Window 的矩形、可见与 openness；Godot 端实例化同一页面读可见 XMVWindow 的矩形。设置页另读 33 行文字、symbol、状态文字与可用性；地图 HUD 读 Map004 上的窗口（地图名滑入终点 y=78、金钱窗关闭）。读数 `04_验证/本地结果/悟空_审查25_界面/wukong_review25_mv_rects.json`（不入 Git）。
  - ② 代码：按框架维护约定「随重制照做的工程规则」回查缓存键与失效、界面层是否耗随机数、读档缺字段默认值、右键／滚轮／返回光标；查出售价、锁定判断等同一规则的多处写法。
  - ③ 测试：逐功能核对专项测试；④ 登记：界面类 O 项与界面风格、回退开关是否在代码里。

**发现**

1. 【已修】装备战力缓存键少了输入。`XPower.equipment` 用一张全局表缓存，键只有 params／traits／note／level；正式版按物品对象（WeakMap）缓存，Godot 两件只差武器类型的装备会取到同一结果，而武器类型乘区（`<SkETypeHarmRi N>`）和 `_is_weapon` 都要看 kind／wtypeId。实测：同一把武器加「本类型 +50%」后改 wtypeId，修复前缓存给 1068（应为 35）。现切片基础库里没有真撞键的装备（Weapons 全表查过 0 例），属预防。修：键加 kind、wtypeId、atypeId；`xiyou_power` 加 gear_cache_key_wtype（修复前失败、修复后通过）。角色战力签名与正式 `signature` 对过：Godot 无 _paramPlus／转生／形态等字段，现有 actor_id、职业、等级、技能、状态、装备整件、变量 8 已覆盖实际输入；参照伤害缓存只依赖参照档，无问题。
2. 【已修】状态页右键不能返回，Esc 返回也不播取消音。正式 JAH 页签窗是唯一活动窗口，Window_Selectable.processTouch 的 isCancelled → processCancel（播取消音、popScene）。Godot 只接 ui_cancel 且没音效。修：`XStatusPage.cancel()`，右键与 Esc 同走它，战力面板开着时不处理；`xiyou_status_page` 加 right_click_and_cancel_close（并按测试规则停播放器等 0.5 秒）。滚轮：正式版滚轮只滚页签窗自身（1 行），不滚属性页，Godot 不接滚轮与原版一致。
3. 【对照通过】九页窗口矩形与正式 v0.28 逐个一致：设置 (440,130,400,460)；装备 4 窗（指令与状态窗 y=1、槽／说明 y=173 高 547）；状态 2 窗；存档 4 窗（确认窗打开时按文字宽重算、居中，与 save_page 夹具一致）；物品 4 窗（类别 y=0、状态窗 y=1、列表 y=172 高 548）；技能 3 窗；地图传送 2 窗；挂机设置 15 窗（427 宽三列、范围图 854×480）；商店 5 窗。设置、挂机设置、传送页原来只对过 v0.13～v0.16 的读数，这次补成 v0.28 回归：新测试 `xiyou_window_rects`（9 项，夹具 `tests/fixtures/window_rects_oracle.json`）。设置页 33 行顺序、symbol 与正式一致。
4. 【观察，不改】设置页未开放的 5 行（Battle Camera、测试模式、GM、换装、反馈）Godot 灰显且不写状态；正式版除 GM 外都可用并写「ON／密码验证／需开启／打开／0 份」。已在交接板「下批功能」与进度账（33 项开放 28 项）登记，不算新问题；实现时状态文字照正式补。
5. 【观察，原版行为】说明卡「出售价格」照 HelpExtend 写 Math.round(price/2)，实际卖出按 MV 向下取整（有 `<Sell Price>` 时用该值）——奇数价格说明比实卖多 1。Godot 与正式一致；要统一可另登记 O 项（未做）。
6. 【观察，重复写法】挂机自动卖出（`XHangUpAuto.after_battle_sell`）与一键出售（`XItemMarks.onekey_sell`）各写一遍「七档→旧档、跳过名字含[锁定]」的筛选，而 `XItemMarks.is_locked` 已有同一判断。现在行为一致，建议以后改出售规则时合成一个 `XItemMarks` 函数（八戒／界面车道顺手做即可）。设置页 `status_text`／`ok`／`_side` 三处各列一遍开关类 symbol，同理。
7. 【回查通过】随机数：界面层与战力／检索不调 randf；地图传送掉落预览、商店说明只用 `XGear.template`（不掷预掷池）；宝珠坊鉴定报价 `quote_identify` 不调 `roll`。全局 randf 被掉落弹跳、呼吸相位、打字音高共用——正式版同样用 Math.random，不构成偏差。
8. 【回查通过】存档字段：`XState.from_dict` 对 dev.016 以后新增的 battleSlots、saveCount、orbState／orbSeed（缺时按正式 seedFromSave 推算）、seen、hangUp、dungeon、pingbiQuality（读写都按长度判断）、unlockedMaps（dev.016 前补大厅）等都有缺省；物品锁定／置顶在 flags 里。
9. 【回查通过】返回与停位：设置子页返回保留光标（O-024）；商店出售后光标钳回列表内；物品页操作后按原对象找回位置。
10. 【登记已修】（唐僧转来）界面风格补注 O-013、O-020、O-026（新节「界面类优化」）；「未做（目标）」里的存档（dev.014）、存读档页（dev.067）、$.toaster 提示、说明卡隐藏规则移到新节「已实现」；说明卡隐藏一条原写「技能页未做」，核对技能页进入选人即隐藏（mode≠list），改标已实现并给 `xiyou_skill_page` 的 list_to_actor 加断言。界面类 O 项（O-005～O-008、O-010～O-014、O-017、O-018、O-020、O-022、O-024、O-025、O-030～O-032、O-042）的回退开关在代码里都找到了。O-030 已含 20% 审查第 2 条（不校验类型）。
- 测试覆盖：范围内各功能都有专项（hud、transfer、hangup／hangup_auto／hangup_options、battle_ui／combat 连击、rules 品质、options_basic／misc、party、skill_page、drop_record、item_marks、shop_buy、power／status_power／status_page、wtype、gear_search、item_list、orbs／orb_ui／orb_shop／orb_shop_ui、save_page、drop_dh、mv_animation）；本轮新增 1 个测试、补 3 条断言。
- 验证：合并 main（f765e73）并 `新建工作树.sh --补齐` 后，worktree `检查.sh` 全部通过（本轮无战斗规则改动，未加 --oracle）；新增与改动的专项 xiyou_window_rects 9/9、xiyou_power 103/103、xiyou_status_page 43/43、xiyou_skill_page 21/21。
- 提交：dbae35b（窗口矩形对照）、3d42be6（战力缓存键）、b9f7445（状态页右键返回）、f0b5407（界面风格登记）、合并 main f765e73。
- 遗留：①说明卡卖价与实卖差 1（原版行为，要不要登记 O 项由唐僧定）；②出售筛选与设置页 symbol 表的重复写法（建议顺手合并）；③20% 审查遗留的 KMS 商店库存仍未做。
- 给沙僧（⑤完成度）：界面页面 67% 的依据里「设置页按半页计」合理（灰显 5 行没状态文字）；状态页第 4 页是 O-032 的「套装」代替「修行」，真气未移植，不能算整页复现；状态页右键返回本轮才补，此前「已复现」缺这一项输入。其余抽查页矩形全对，未见需要下调的。

## 交接板

- 下一步（审查遗留，改界面时顺手）：出售筛选合成 `XItemMarks` 一个函数（挂机自动卖出与一键出售共用，锁定用 `is_locked`）；设置页开关 symbol 表合成一份；设置页其余 5 项实现时照正式补状态文字。
- 需要用户决定：说明卡「出售价格」照原版四舍五入，实卖向下取整，奇数价差 1——是否登记成优化改为显示实卖价（唐僧定是否列入）。
- 用户试玩说明：状态页可以右键返回，返回时有取消音。

## 进度账

- 无变化（审查不改进度；完成度复核归沙僧）。

## 本分支提交

- dbae35b 九页窗口矩形对照正式 v0.28（xiyou_window_rects）
- 3d42be6 装备战力缓存键补种类与武器／防具类型
- b9f7445 状态页右键返回、返回播取消音
- f0b5407 界面风格补注 O-013／O-020／O-026，「未做」已实现条目移出；技能页选人隐藏说明卡补断言
- f765e73 合并 main
- a1a2381 交付单草稿＋新测试 uid

可合并
