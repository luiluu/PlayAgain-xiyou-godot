# 交付：claude/cloud-lane-q98dru

- 车道／工作者：云端协助（Claude，云端会话；不占车道名额，只改下面两处）
- 状态：可合并（云端 Godot 测试 65/65 通过，含 `xiyou_help_card` 392/392；`--oracle` 未跑）

## 变更记录草稿

## 2026-10-18 【Claude·云端·未经Codex检验】待决优化项全部定案；说明卡出售价格写实卖价（dev.待定）

- 用户方向：用户 2026-10-18 看完待决优化项清单后定案：O-001～O-046 当时的 36 项待决全部保留，O-035「随机角色」暂缓到角色招募系统时实现；说明卡出售价格差 1 选 B（显示实际卖出价）。
- 优化登记：36 项状态改为「保留（用户 2026-10-18）」，O-035 改为「暂缓」；规则段记一笔。新增 O-049。
- O-049：`XHelpCard._prices` 的「出售价格」改用 `XItemMarks.selling_price`（<Sell Price> 优先，否则半价向下取整），与商店、一键出售、挂机卖出一致；原版 HelpExtend 是 Math.round(价格/2)，奇数价格多 1。开关 `XHelpCard.REAL_SELL_PRICE`。
- 测试：`xiyou_help_card` 逐行比对正式参照时关掉 O-049（参照是原版四舍五入），另加 3 项（奇数价 7 → 3、<Sell Price> 1 → 1、关掉后 → 4）。
- 验证：云端用 Godot 4.7.2 Linux 版（与 Mac 同一构建）和 Mac main 的转换产物跑了全部 Godot 测试 65/65 通过（`xiyou_help_card` 392/392）；工具检查全部通过；`--oracle` 未跑（云端没有冻结正式源）。
- 提交：见下。

## 2026-10-18 【Claude·云端·未经Codex检验】云端测试环境（工具，dev 不递增）

- `07_开发环境/云端准备.sh`：装 zsh、下载与环境登记同版本的 Godot Linux 版并校验 SHA512、解开转换产物打包、`--import`；`云端测试.md` 写取产物的办法与首次实测结果。
- `检查.sh`：`GODOT` 可用环境变量覆盖（默认仍是 `07_开发环境/godot`）。
- 未做：注册成仓库 SessionStart hook（改 `.claude/settings.json` 需用户同意；用户 2026-10-18 说项目额度当天到期，暂不开云端车道）。

## 2026-10-18 【Claude·云端·未经Codex检验】代码审查 dev.068～081：修复复制角色丢真气境界（dev.待定）

- 范围：c85f6e3..a70c28d 的 `modes/` 与 `core/` 改动（约 2,500 行），分真气／副本与事件／界面与战斗演出三块读，相关专项在云端全部通过。
- 修复（`core/equipment.gd`、`core/power.gd`，不在任何车道独占文件里）：`XEquipment.clone` 没复制 `zhenqi`，装备页预览与 `XPower` 评估里道法被动一律按炼气 1/4 缩放（境界 6 学灵台：真实 TP 上限 300，预览 225），战力偏低；`XPower._signature` 加境界，突破后不再返回旧战力。`xiyou_power` 补 3 项，去掉修复时其中 2 项失败。
- 验证：`xiyou_power` 106/106、`xiyou_equipment` 1228/1228、`xiyou_status_power*`、`xiyou_zhenqi*` 全部通过。
- 只记录、未修（低影响或在车道独占文件里，请唐僧转给对应车道）：
  - 悟空（解释器）：`mv_interpreter.gd` 指令 214 暂时消除没检查是否仍在原地图（MV `isOnCurrentMap`），传送后执行会消掉新地图同号事件；切片里目前没有触发点。`FLUSH_BEFORE` 漏了带等待的 225 画面震动，排队的升级文字会晚到震动之后。
  - 悟空／地图：`map_scene.gd` 只靠 214 消除（不开独立开关）的事件读档后会重新出现，MV 把 `_erased` 存在 `$gameMap` 里；要先查有没有这种事件再决定修不修。
  - 八戒（演出）：`battler_sprite.gd` `_body_material()` 对「场景」外观的子节点一律设 `use_parent_material`，会盖掉它们自己的材质（目前没有场景外观，不触发）；地图动画 `map_scene.gd` `show_animation` 没设 `MVAnimation.target`，flashScope 1／3 的目标闪光与隐藏在地图上不生效（缺功能，不是回退）。
- 八戒_17 在做道法运行时：这次修复让预览和战力开始按实际境界计入道法被动，战力参照若有变化以此为准。

## 2026-10-18 【Claude·云端·未经Codex检验】代码审查 dev.049～067：宝珠存读档后取不下等 3 处修复（dev.待定）

- 范围：98ce46d..c85f6e3 的 `modes/` 与 `core/` 改动（约 4,700 行），分宝珠与物品商店／战力与状态装备页／战斗规则与地图三块读。
- 修复：
  - `core/orbs.gd` `_param_rate` 取下时按 `==` 找特性：存档 JSON 把 0.36+1 写成 1.36、读回 1.3600000000000001，存读档后取下 宝珠·长生·归真（3006）、藏气·归真（3011）删不掉特性，宝珠回背包而 ×1.36 留在装备上，每轮镶嵌／存读档／取下多叠一条。改为差小于 1e-9 即算同一条。`xiyou_orbs` 补 1 项（修复前失败）。
  - `ui/choice_window.gd` 点最后一行下方的留白会选中画面外的下一行（光标消失，再点就确定看不见的行）；加行号上限，同 `battle_list._hit`。新测试 `xiyou_choice_window` 3 项（修复前 1 项失败）。
  - `ui/status_page.gd` 头部 HP／MP／TP／EXP 条：记录的填充宽换回比例时 floor 误差，w=458 时 13 个宽度少画 1px；换比例时加半格。只是画面，测试比的是记录值，未加测试。
- 只记录、未修：
  - `ui/shop.gd` `_buy_data` 把武器／防具商品的原始记录交给 `XItemMarks.shop_display`，没有 kind，按 Items 表查 `<Proxy Buy>`：防具 1991、2495～2520 与带 Proxy Buy 的物品同号，若有商店卖这些防具会显示代购物品的名字和图标（购买本身正确）；目前没有商店卖。
  - `core/orbs.gd` 303～308 行 Element Amplify 元素名写法的正则少一个分组，数值读错；目前没有宝珠用这种写法。
  - `ui/gear_search.gd` 改排序就存配置，按「关闭」不应用也会改装备列表顺序；要对照原版再定是不是问题。
- 验证：`xiyou_orbs`、`xiyou_orb_*`、`xiyou_status_page`、`xiyou_choice_window` 通过，全部测试见本分支最后一次提交。

## 交接板

- 需要用户决定：删掉「说明卡『出售价格』差 1」与「优化登记的 O 项」两条（已定）。
- 编号：O-049 是云端会话自取的下一个空号（O-045、O-047 已分给悟空，O-048 分给八戒）；如要改号，改优化登记、`help_card.gd` 注释与测试名三处。

## 进度账

- 无变化。

## 本分支提交

- （见 `git log main..claude/cloud-lane-q98dru`）
