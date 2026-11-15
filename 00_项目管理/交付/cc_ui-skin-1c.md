# 交付：cc/ui-skin-1c

- 车道／工作者：B 界面·新界面第 1C 批（装备页 #23＋装备详情部件 #24＋检索排序 #25＋状态页 #27＋战力面板 #28 照旧藏）／cc（Opus＋medium，派单定：装备页手工排、接装备比较和换装逻辑，属复杂接线）
- 状态：可合并
- **合并顺序**：本分支从 main（dev.598）切出后合了 `cc/ui-skin-1b`（含 1B 核查返工 123aa0b38），之后又合了 main（dev.599，含 1A）。**先合 1B 再合 1C**。

## 变更记录草稿

## 2026-11-15 【cc·未经审查】新界面第 1C 批：装备页、装备详情、检索排序、状态页换皮（dev.待定）

- 玩家可见：无（新界面只在天启篇存档里开，天启篇没对玩家开放；重制版 0.01.x 与西游存档仍是旧装备页、旧状态页、旧检索面板，已逐像素对照）。开发版里进天启篇存档开装备页：左上一条角色条，下面栏位环（13 栏一圈放不下分两页 7＋6，球里是身上那件的图标，空栏写「空」，不能换的变暗；环心是角色圆头像；环下「身上 n 件 · 栏位第 a / b 页」）；中间是当前栏位的候选（第一行「卸下」，每行名字、主属性「+35」、和身上那件比「▲23／▼2」，一屏 10 行，右上「可选 n 件」）；右边详情牌（名字、品质 · 类型、「换上后」只列变了的能力值「47 → 70 ▲23」＋「其余 n 项不变」，下面是说明卡的行），选候选时牌底「装备」按钮。按 Y 展开「全部属性与词条」（装备详情／属性对比／插槽与镶嵌三页），X 检索排序，C 清空，Q / E 换人。没有旧页的「装备／清空／返回」指令窗：开页就在栏位环上，取消直接关页。状态页：左边角色牌（圆头像、名字、称号、Lv · 职业、状态图标、生命／魔法／TP／经验四条量条），右边一大块：顶上五个页签（状态／加成与抗性／掌握／修行／修行·详细），下面是那一页的内容（就是旧页的那些数，换了字和颜色、按面板宽排）。检索排序面板（XWebPanel）换成黑面板、思源黑体、旧金小标题、绯红选中；宽屏时居中。战力照旧藏着（新布局不放战力条和按钮）。
- 依据：界面风格提案 v0.7 样稿 `equip`、README 第一节「装备」、第四节实装清单（私密设计仓 `重制设定/界面风格提案_v0.7/`）；第 0 期交付单「第 1～6 期拆批建议」1C 行；1B 交付单「模板页套用要点」；盘点清册 `xa/ui-audit` 35b648209（#23～#25、#27、#28）；文字口径照小A文字审 ba1f7ed（「已装备」口径、按键提示套框「Y 全部属性与词条」、「Q / E 换人」）。
- 开关：沿用第 0 期 `XUiSkin.ENABLED`（O-467，同一开关不另开）：关掉或不是天启篇存档时 `XEquipScene`／`XStatusPage`／`XWebPanel` 走旧代码，一行不变（`皮肤关闭对照.py --base main` 14 张逐像素一致，见「验证」）。
- 新增（独占）：
  - `modes/xiyou/ui/skin/skin_equip_page.gd`（`XSkinEquipPage`，借 `XSkinTemplatePage` 骨架、手动导航）：只管摆和画；状态机、换装、清空、检索筛选、候选缓存（O-374）、HP/MP 按比例保留、看过新装备全部还是 `XEquipScene` 原来的代码（同一套 `_mode`／`_slot`／`_item_index`），每次 `_refresh` 后 `sync()` 重画。「卸下」在数据里是最后一项，显示时放第一行（`to_display`／`to_data` 换算，上下走法在数据序里与旧页相同）。候选行的主属性：武器看攻击，其余看八项里绝对值最大的；「▲／▼」是同一项和身上那件相减（只显示）。「换上后」用 `XEquipment.preview`（同旧属性对比页），只在选中的候选换了才算。
  - `skin_gear_detail.gd`（`XSkinGearDetail`，#24 新皮肤）：Y 展开时盖在中、右两块上：图标＋名字＋品质 · 类型，三个页签（装备详情＝`XHelpCard.detail_rows` 全部行；属性对比＝八项「当前 → 换上后 ▲差」；插槽与镶嵌＝`XGearDetail.socket_rows`），左右换页签、上下／滚轮滚动、点页签。只读。
  - `skin_status_page.gd`（`XSkinStatusPage`，#27）：左角色牌、右页签＋页内容。页内容取旧页 `XStatusPage.page_ops`（去掉表头，表头的东西在左边牌上），横向按面板宽缩放，字换思源黑体（名字放不下先缩到 14 号），系统蓝→次要字、「【…】」→旧金，元素色、抗性档位色、品质色照旧；超一屏可滚、右侧细滚动条。页、滚动、换人还是旧页的 `page`／`tops`／`actor_index`。
  - `tests/xiyou_ui_skin_1c.gd`／`.tscn`（专项）。
- 改（本批界面文件）：
  - `ui/equip_scene.gd`：`XUiSkin.on()` 时建 `XSkinEquipPage`、开页就在栏位（`_mode = "slot"`）；`_refresh` 末尾 `skin.sync()`，新布局时不再给旧详情排版（省一次 `detail_rows`）；按键全交新布局；栏位上取消＝关页；换人回栏位第一栏；点击交给组件。
  - `ui/status_page.gd`：`XUiSkin.on()` 时不建旧窗口和战力条／按钮，建 `XSkinStatusPage`；`_scroll`、`page_rows`、`max_top` 走新布局；点击页签交给新布局。
  - `ui/web_panel.gd`（#25）：`skin_color()` 按新皮肤换色（关着原样返回），`_font`／`_box`／`_label`／`_fixed`／`style_button`／`draw_frame` 新皮肤时用新字、新色、不描边、黑面板；`skin_center()` 宽屏居中。排版、尺寸、文字不变。**注意**：`XWebPanel` 是公共底，新皮肤开着时战力面板、异化工坊、我方状态面板（#69）用到的这些部件也跟着换色换字（都只在天启篇里）。
  - `ui/gear_search.gd`：搜索框、下拉的字和字色走 `_font()`／`skin_color()`；`_ready` 里 `skin_center()`。
  - 第 0 期组件（小改，向后兼容）：`skin_list.gd` 加可选第二右列 `right2`／`right2_color`／`right2_w`（装备候选的「▲23」；没给 `right2` 的项照旧）。
  - `tests/xiyou_ui_skin_offshot.gd`：关闭对照加装备检索（`XGearSearch`），共 7 页 × 2 情形。
  - `tests/xiyou_tianqi_gear.gd`：`_ui` 段开页先判 `_mode == "command"` 再按「装备」（天启篇开着新界面时没有指令窗，后面走栏位、候选的断言不变）。
  - `tests/virtual_player/virtual_player.gd`：换装那段认新界面（没有指令窗：一个人栏位走完按 E 换下一个，最后一个走完取消关页）。
- 不改：战斗计算、装备效果计算、存档格式；换装、清空都调原来的 `XEquipment.change`／`clear`、`XEquipScene._keep_rates`；没有新增数据。

## 优化登记草稿

无（沿用第 0 期 O-467，不新增）

## 新增可见文字（交付后派小A文字审）

| 文字 | 在哪 | 说明 |
| --- | --- | --- |
| 装备、状态 | 页名 | 现有入口名 |
| 卸下 | 装备候选第一行、牌标题、牌按钮 | 样稿原文（旧页是插件的「卸载」） |
| 可选 %d 件 | 候选列表右上 | 样稿原文 |
| （已筛选） | 候选列表标题后（检索条件生效时） | 1B 已有 |
| 身上 %d 件 · 栏位第 %d / %d 页（一页时只写「身上 %d 件」） | 栏位环下 | 样稿原文 |
| 空 | 栏位环空栏的球里、牌上空栏的小字 | 样稿原文 |
| +%d、▲%d、▼%d | 候选行右侧（主属性、和身上比） | 样稿原文写法 |
| 换上后 | 牌分节标题 | 样稿原文 |
| %s → %s ▲%s／▼%s | 「换上后」每行、属性对比页 | 样稿原文写法 |
| 其余 %d 项不变 | 「换上后」最后一行 | 样稿原文 |
| 能力值不变 | 「换上后」一项都没变时 | 新写 |
| 装备 | 牌底按钮 | 样稿原文 |
| 装备详情、属性对比、插槽与镶嵌 | 展开后的页签 | 旧详情部件原有文字 |
| 确定 更换／取消 返回／Y 全部属性与词条／X 检索排序／键盘 C 清空／Q / E 换人 | 栏位时按键提示 | 「全部属性与词条」照小A必改项 108；「检索排序」「换人」样稿原文；「更换」「清空」新写（清空是旧页指令名）；「键盘 C」照小A核查 P2-2（手柄没有清空键） |
| 确定 装备／取消 回栏位／Y 全部属性与词条／X 检索排序／Q / E 换人 | 选候选时按键提示 | 样稿原文；「Q / E 换人」照小A核查 P2-2 补（候选时也能换人） |
| 左右 换页／上下 滚动／Y / 取消 收起 | 展开时按键提示 | 新写；「Y / 取消」照小A核查 P3-2 |
| 左右 换页／上下 滚动／Q / E 换人／取消 返回 | 状态页按键提示 | 新写 |
| 「称号」 | 状态页角色牌名字下 | 新写的括法（称号本身是数据；旧页写「, "称号"」） |
| Lv %d · 职业 | 状态页角色牌 | 同 1A 角色条 |
| HP、MP、TP、距离下一Lv | 状态页四条量条的标签 | 都是游戏原有用语（数据库 terms） |

旧状态页各页的内容（能力名、元素名、「其他加成」、修行页文字）、说明卡的行、装备名和说明、检索面板的全部文字都是原有文字，没改。

## 核查后返工（小A 乙档 0ddc431cb）

- P2-1：`gear_search.gd` 检索列表选中行的底线、悬停底色走 `skin_color()`（天启篇是朱红线、绯红底，不再是旧光标青）；专项 `web_search_row_line`。
- P2-2：按键提示照小A给的字改：栏位「键盘 C 清空」、候选补「Q / E 换人」；文字表同步；专项 `equip_item_hints_qe`、`equip_slot_hints_c`。
- P2-3：按 Y 展开详情时左边栏位环不收鼠标（`MOUSE_FILTER_IGNORE`，收起恢复），`_on_ring_changed`／`_equip_ring_activated` 展开时也直接返回；专项 `equip_detail_ring_ignores_mouse`、`equip_detail_ring_blocked`。
- P3-2：展开时提示改「Y / 取消 收起」。
- P3-3：吸取过特效的专武，详情牌和展开的「装备详情」页都照说明卡先取效果视图（`XSkinGearDetail.absorb_view` ＝ `XAffixAbsorb.view`），吸取的特效行跟悬浮卡一样显示。
- P3-1（不改，记档）：新皮肤开着时 `XWebPanel` 的公共部件（字、`_box`、按钮）换了，但异化工坊（`alien_workshop.gd` 自己的深蓝底、旧窗口皮肤边框、`PRIMARY` 青按钮、直接读 `XWebPanel.LINE`／`GOLD`）、我方状态面板（`party_status_panel.gd` 搜索框硬写 `XUI.font()`／`TEXT`）是半新半旧；留给对应批处理：异化工坊归 3B（#78），我方状态弹窗归 2B（#69）。
- 复验：`xiyou_ui_skin_1c` 无头 78/78、有窗口 90/90（截图重拍覆盖原目录）；`xiyou_gear_search`、`xiyou_status_page`、`xiyou_gear_detail`、`xiyou_affix_absorb` 全过；`皮肤关闭对照.py --base main` 14 张全 SAME；`语法检查.py` 0 问题；`发行空壳.py check` 通过。

## 交接板

- 下一步：2A／2B（战斗）；5A 套模板的检索数量窗等可参考 `XWebPanel.skin_color`。
- 用户试玩说明：无（天启篇没对玩家开放）。开发版里进天启篇存档开装备页、状态页、装备检索能看到新布局；截图见「验证」。
- 需要用户决定：无。

## 进度账

- 天启篇新界面：页面重排 4/83 → 9/83（＋装备 #23、装备详情 #24、检索排序 #25、状态 #27；战力面板 #28 照旧藏，算处理过）。

## 要注意的（给核查、总装）

1. **X 键**：派单与样稿写「X 检索排序」，1B 物品页也这么做了；但键盘上 X 本是取消键（`XKeyMap` 照原版 BCE：Esc、Insert、X、K、小键盘 0）。新装备页里键盘 X＝检索，取消要按 Esc／K／右键（手柄 B 不受影响）。和 1B 一致，没另改；要换键（比如检索改 Tab）物品页、装备页两处一起改。
2. **没有指令窗**：样稿没有「装备／清空／返回」，新布局开页就在栏位，「清空」挪到 C 键（提示条里写着）。手柄没有 C 键，现在手柄清空不了（逐栏卸下可以）；要的话 5C 设置期可加一个手柄键位，或在牌上加按钮。
3. **「已装备」**：样稿列表里有「装备中」那一行，但游戏的候选只列背包里的（身上那件不在候选里），所以不会出现「已装备」角标，没做；身上那件看栏位球和牌（栏位阶段牌上就是身上那件）。
4. **卡顿**：挪一格候选整次刷新约 6 毫秒（本机，专项里打印 `equip move sync us=`），旧页同样一格约 3.3 毫秒（`legacy move us=`）；多出来的是「换上后」要算一次预览角色的八项能力值（旧页默认页签不算）。列表行只在候选数组换了才重建（专项 `equip_move_no_rebuild`），角色条、栏位环只在换人／换装后重取。旧详情在新布局下不再排版。
5. **XWebPanel 换皮范围**：见「改」里那条，新皮肤开着时其它网页面板也跟着换色；关着一行不变（关闭对照含检索面板）。

## 验证

- `tests/xiyou_ui_skin_1c.tscn`：无头 72/72；有窗口 84/84（多 12 张截图）。覆盖：
  - 纯函数：「卸下」显示换算往返、栏位分页（13→7＋6、10→1 页、19→10＋9）、主属性（武器攻击、防具最大项、全零）、带号；
  - 装备页：天启篇存档建新布局、旧窗口（指令、状态、列表、右下、旧详情、工具条）全藏；开页在栏位环；13 栏；三块宽（384／476）、一屏 10 行；空栏「空」；左右走栏位、跨页（第 2 / 2 页 6 颗）再回来；确定进列表光标落第一件候选；候选行主属性与「▲」；牌标题、「装备」按钮、「换上后」只列变了的＋「其余 n 项不变」（和 `XEquipment.preview` 逐项比）；挪光标不重建列表行；上移到「卸下」牌写「卸下」；Y 展开（三页签、属性对比 8 行）、取消收起；换上（身上就是那件、环球换图标、列表重建）；卸下；再换上后 C 清空；鼠标点列表第 3 行进列表并选中；取消回栏位；E／Q 换人；X 打开检索、新布局隐藏、关掉后恢复；栏位上取消关页；西游存档、`ENABLED = false` 都走旧页（有指令窗）；
  - 检索换皮：开时字色、光标色换成新皮肤的，别的颜色不动；关时原样；
  - 状态页：建新布局、没有旧窗口和战力条／按钮；页面宽；第 1 页一屏放得下；内容不含表头；系统蓝换次要字；右换页；超一屏的页能滚；E 换人；点页签；取消关页；西游存档走旧页。
- **开关关掉与 main 一致**：`python3 07_开发环境/皮肤关闭对照.py --base main --out 04_验证/本地结果/ui_skin_1c/关闭对照` → 主菜单、状态、物品、技能、装备、设置、**装备检索** × 「西游存档开关默认」「天启篇存档 `ENABLED = false`」共 14 张逐像素 SAME（基线 main 17c4ba6b2 dev.599，本分支含 1B）。
- 截图（有窗口，git 忽略目录 `03_再刷重制_Godot/04_验证/本地结果/ui_skin_1c/`）：`ui_skin_1c_equip_slot_16x9／20x9`（栏位环有焦点）、`equip_list_*`（选候选＋换上后）、`equip_detail_*`（Y 展开、属性对比页）、`gear_search_*`（检索面板换皮，20:9 居中）、`status_p0_*`、`status_p1_*`（加成与抗性）；`关闭对照/base`、`关闭对照/branch` 各 14 张。
- 选测（本地，`选测.py main --list` 75 个去掉事件对照四片 `xiyou_event_compare*` 和 `xiyou_floor_reach041`：本批没碰事件、楼层，事件对照不开这些页；70 个）：分三轮跑完全过——第一轮 34 个（装备、检索、详情、专武吸取、双持、状态、战力、网页面板、界面像素、窗口矩形、皮肤各专项等）只有 `xiyou_tianqi_gear` 挂（`_ui` 段按旧页先按「装备」指令，新界面没有指令窗），改测试后过；合 main 后重跑 8 个（`xiyou_tianqi_gear`、`xiyou_ui_skin*` 四个、`xiyou_tianqi_e2e`、`xiyou_status_page`、`xiyou_gear_ui`）全过；其余 42 个（含 `xiyou_virtual_player`）全过，其中 `xiyou_battle_log` 并行时挂、单跑过，按偶发记（累计第 2 次，1B 那次也是它；本批没碰战斗日志），日志 `04_验证/本地结果/并行测试/20261115_080455__nz1c1zx/`。
- `语法检查.py`：0 个问题。`工具回归.py`：全部通过（103 秒）。`发行空壳.py check`：通过（58 个脚本，492 个函数都有；合了 main 后 1A 的 `XTianqiQiyin.shards` 已由总装补特例）。
- 给总装：`合并车道.sh --finish --affected --cloud`。

## 可优化（流程／工具／效率）

- 已做：`tests/xiyou_ui_skin_offshot.gd` 加装备检索面板（`XGearSearch`），关闭对照覆盖 7 页（回退：PAGES 去掉 `XGearSearch` 和那三行）。
- 建议：栏位球现在用身上那件的图标、空栏写「空」；co 出栏位图标后可在 `XSkinEquipPage._sync_ring` 给空栏放栏位图标（归美术接入）。
- 建议：X 键与取消键冲突（见「要注意的」1），归 5C（设置期统一定键位）。

## 本分支提交

- c7e46696e WIP：装备页新布局、装备详情部件、列表第二右列
- 5451922aa WIP：状态页、检索排序换皮、专项测试
- eb5cbc395 WIP：关闭对照加装备检索、天启篇装备测试兼容新界面
- fc16377c9 虚拟玩家换装认新界面、交付单
- 另有合并：cc/ui-skin-1b（d6c36554e、123aa0b38）、main（dev.599，含 1A）

## 小A 乙档核查

- **核查对象**：`cc/ui-skin-1c`（交付提交 `20248229a`，含 1C 四笔提交 `c7e46696e..fc16377c9`，已合 `1B` 返工 `123aa0b38` 与 `main` `dev.599` `17c4ba6b2`），执行者：小A（只读核查＋轻量前台无头验证，未改任何游戏代码）。
- **结论：不通过**（**P1 0 条**；**P2 3 条**〔含**文字／按键提示必改 1 条**、检索选中行底边未换色 1 条、详情覆盖时未屏蔽左侧栏位环点击 1 条〕；**P3 4 条**）。

### 协调截图两问核实

1. **① `ui_skin_1c_status_p0_16x9` 状态页（Lv 1、HP 485、物攻 47）与装备页（Lv 80、最大生命 6,818、攻击 263）数值不同（核了测试规则＋源码＋实跑）**：
   - **结论**：是测试函数用了**不同的测试存档**，**不是**状态页读错数据。
   - 依据：`tests/xiyou_ui_skin_1c.gd` 中 `_equip_page()`（`L136-158`）建档后显式调用了 `a.change_level(80)` 再拍 `ui_skin_1c_equip_*`；而 `_status_page()`（`L311-312`）重新调用 `_state()` 建了一个全新 **1 级**存档（`a.level == 1`，初始 HP 485、ATK 47），未升 80 级即拍 `ui_skin_1c_status_*`。`XSkinStatusPage`（`skin_status_page.gd:130-191, 240`）直接读取 `scene.actor()` 及 `XStatusPage.page_ops(a, p, 612.0)`，数据一致。
2. **② 状态页「状态」页签右边第 3 列孤零零一个带图标的「练习剑」（核了旧状态页排版规则＋源码）**：
   - **结论**：这是角色第 0 栏（武器槽）当前身上装备，**位置与旧状态页完全一致**（非错位或遗留控件）。
   - 依据：旧状态页 `XStatusPage._params_ops()`（`status_page.gd:48-49, 302-328`）把第 1 页排成 3 列——前两列 `PARAM_X := [82.0, 466.0]` 画 13 行能力值，第 3 列 `EQUIP_X := 850.0`（占基准宽 `OLD_W = 1252.0` 的约 68%）按 `XTianqiGear.view(a)` 13 栏逐行绘制身上装备并跳过空槽（`if not e is Dictionary or e.is_empty(): continue`）。`XSkinStatusPage._draw_page_body()`（`skin_status_page.gd:215-282`）去 6 行表头后按板宽等比横移。1 级狗逍遥开局只有第 0 栏装了「练习剑」、其余 12 栏均空，因此第 3 列只在第 0 行画出一个「练习剑」。注：旧 `JAH_StatusMenuCore` 本身就没有为第 3 列加列标题，开局仅 1 件时顶部无标题略显孤立（属忠实继承旧页，非 bug）。

### 核查项与核实深度（分清规则本身／只看代码）

1. **皮肤关闭隔离与 14 张 SAME 对照（核了源码＋实跑无头测试＋已有对照图 `--compare`）**：
   - 源码：`equip_scene.gd:83`、`status_page.gd:71`、`web_panel.gd:40-53,128` 均严格守门 `XUiSkin.on()`；关皮肤或进西游／重制版存档时完全回退旧装备页、旧状态页、旧 `XWebPanel`／`XGearSearch`，`XStatusPage` 旧战力条与按钮照旧工作。
   - 实跑前景测试：`语法检查.py`（906 个 `.gd` 0 问题）、`发行空壳.py check`（58 脚本 492 函数通过）、`xiyou_ui_skin_1c.tscn`（**72/72**）、`xiyou_ui_skin_offshot.tscn`（**14/14**，含新加 `XGearSearch`）、工程内已有 `04_验证/本地结果/ui_skin_1c/关闭对照/` `--compare` **14/14 SAME**；另加跑相关专项 `xiyou_ui_skin_menu`（58/58）、`xiyou_ui_skin_1b`（85/85）、`xiyou_gear_detail`（56/56）、`xiyou_tianqi_gear`（36/36）、`xiyou_status_page`（47/47）、`xiyou_gear_ui`（49/49）、`xiyou_alien_workshop`（45/45）、`xiyou_gear_search`（60/60）、`xiyou_party_status_panel`（19/19）全过。
2. **换装逻辑与数值只读隔离（核了 `XEquipment`/`XEquipScene` 规则本身＋读代码＋跑专项）**：
   - **P1 0 条**。`XSkinEquipPage` 不改装备数据：换上／卸下调 `scene._ok()`（走 `_keep_rates` ＋ `XEquipment.change`），清空调 `clear_all()`（走 `_keep_rates` ＋ `XEquipment.clear`）；候选仍读 `scene.candidates()`（经 `bag_gear`＋`XEquipment.fits`＋`_filter_view`＋`XEquipment.dual_blocked`，未碰 `equip_list`／`raw_equip_list` 语义与专武吸取视图 `XCat.sword_view`／`XAffixAbsorb`）。
   - 「换上后」只列变的项：通过 `scene._temp_actor()` → `XEquipment.preview()`（深拷贝角色＋重算被动与不可装备卸下）与 `a.param(i)`（`i = 0..7`）逐项对比（有缓存键控且包了 `XActor.read_begin/end`），与旧属性对比页来源相同。
   - 候选行右列 `+主属性 ▲▼`：`main_param` / `candidate_row`（`skin_equip_page.gd:206-237`）只读对比 `rec.params` 与当前槽 `_slot_item().params`（武器优先 `params[2]`，其余取 8 项中绝对值最大项），不修改任何属性。
3. **按键与手柄清空说明（核了 `XKeyMap` 规则＋对比 1B 口径＋读代码）**：
   - 键盘 `X` 原属 `XKeyMap` 取消键，新装备页在 `input()` `L416` 先拦 `KEY_X` 调 `scene.open_search()`（与 1B `skin_item_page.gd` 一致；微差：1C 取 `physical_keycode if != 0 else keycode`，1B 只取 `physical_keycode`）；Esc／K／Insert／小键盘 0／右键／手柄 B 取消仍有效；`Q / E` 与 `ui_page_up`／`ui_page_down`（LB/RB）换人有效。
   - 存在两处不一致见 **P2-2**（`item` 态漏列 `Q / E 换人`、`C 清空` 未标明仅键盘／手柄无清空键）及 **P2-3**（展开详卡时未拦截左侧环点击，与 1B 返工 `123aa0b38` 兜底口径不一致）。
4. **`XWebPanel` 换皮连带范围（核了源码＋像素查看截图＋跑无头专项）**：
   - 皮肤关闭（重制版／西游存档）时 `skin_color`、`_font`、`_outline`、`draw_frame`、`skin_center` 全部原样透传，不受影响（`45/45`、`60/60`、`19/19` 无头全过）。
   - 天启篇 `XUiSkin.on()` 时：`gear_search.gd:424` 漏调 `skin_color()` 导致选中行底线仍呈青色（见 **P2-1**，已在 `ui_skin_1c_gear_search_16x9.png` 核实）；`XAlienWorkshop` 与 `XPartyStatusPanel` 出现半新半旧混色见 **P3-1**；战力面板按 `XPower.SHOW_POWER_UI := false`（`power.gd:40`）照旧隐藏（`XGearSearch` 亦据此不显示战力块）。
5. **测试改动审查（只看代码＋实跑 `xiyou_tianqi_gear`）**：
   - `tests/xiyou_tianqi_gear.gd:148-149`：仅加 `if equip._mode == "command": equip._ok()` 以跳过新界面已取消的指令窗，其后 13 栏位、换装与神器断言一行未改（实跑 `36/36` 全过）。
   - `tests/virtual_player/virtual_player.gd:1502-1511`：仅补 `if eq.skin != null` 在 `job.row >= view.size()` 时按 `e` 换下一人或标记 `done` 退出，未放松换装判定（未单跑该测试，留云端）。
6. **文字审（对照 `ba1f7ed` 口径＋全量提取三文件字符串核对交付单表）**：
   - 现有术语「卸下」（替换旧插件「卸载」，与 `v0.7` 样稿及 `ba1f7ed` 统一）、「装备」「可选 %d 件」「（已筛选）」「身上 %d 件 · 栏位第 %d / %d 页」「空」「换上后」「其余 %d 项不变」「能力值不变」「装备详情」「属性对比」「插槽与镶嵌」「「称号」」「Lv %s · 职业」均通顺准确、无残余旧称或语病；按键提示存在 **P2-2** 必改项与 **P3-2 / P3-4** 微调。

### 问题清单（P1/P2/P3，含文字必改）

- **P1**：无。
- **P2-1（检索面板选中行底线未换色｜代码＋截图实测）**：
  - `modes/xiyou/ui/gear_search.gd:424`：`normal.border_color = CURSOR_EDGE if active else Color(1, 1, 1, 0.1)` 漏掉 `skin_color()`，导致天启篇 `ui_skin_1c_gear_search_16x9.png` 左侧选中行虽已变为绯红底，底边 1px 边框仍是亮青色（`#9abbc0` 视觉混色）而非红线 `XUiSkin.SEL_LINE`。
  - **改法**：改为 `normal.border_color = skin_color(CURSOR_EDGE) if active else Color(1, 1, 1, 0.1)`。
- **P2-2（文字／按键提示必改｜对比 1B 口径与 `ba1f7ed`）**：
  1. `XSkinEquipPage.item_hints()`（`skin_equip_page.gd:104-105`）缺少 `["Q / E", "换人"]`，但 `input()`（`L422-427`）在 `"item"` 态同样响应 `Q / E` 与手柄 LB/RB 换人——与 1B「提示必须匹配当前态生效按键」口径不一致；
  2. `XSkinEquipPage.slot_hints()`（`skin_equip_page.gd:100-101`）仅写 `["C", "清空"]`，未写明仅键盘可用（`input()` `L420` 仅判 `KEY_C`，手柄无清空键）。
  - **给改好的字**：
    - `slot_hints()`：`[["确定", "更换"], ["取消", "返回"], ["Y", "全部属性与词条"], ["X", "检索排序"], ["键盘 C", "清空"], ["Q / E", "换人"]]`
    - `item_hints()`：`[["确定", "装备"], ["取消", "回栏位"], ["Y", "全部属性与词条"], ["X", "检索排序"], ["Q / E", "换人"]]`
    - 同步把 `键盘 C` 及候选态的 `Q / E 换人` 补入交付单「新增可见文字」表。
- **P2-3（展开装备详情时未屏蔽左侧栏位环点击｜对比 1B 返工 `123aa0b38` 口径）**：
  - `XSkinEquipPage` 按 Y 展开 `XSkinGearDetail`（`expanded == true`）时仅遮盖 `center + right`，`layout.left` 栏位环仍可见且 `ring.mouse_filter` 为 `STOP`；`_on_ring_changed`（`skin_equip_page.gd:470`）与 `_equip_ring_activated`（`L484`）未检查 `if expanded: return`。玩家展开详卡后点击左环会直接切栏位或触发 `scene._ok()`，状态与提示栏停在详情态产生错位。
  - **改法**：`_on_ring_changed` 与 `_equip_ring_activated` 开头加 `if _syncing or expanded: return`，且在 `sync()` 展开态设 `ring.mouse_filter = Control.MOUSE_FILTER_IGNORE`（收起恢复 `STOP`）。
- **P3-1（`XWebPanel` 换皮连带异化工坊／我方状态面板呈半换色状态｜仅看代码）**：
  - `XUiSkin.on()` 时：`alien_workshop.gd:750-776, 806, 816, 860, 913, 938, 970, 1007` 仍用旧深蓝黑底 `#16161f`＋旧 `XUI.skin()` 边框、`PRIMARY` 青色按钮及直接读取未转换的 `XWebPanel.LINE`/`GOLD`，但同时通过 `XWebPanel._para`/`style_button` 换成了思源黑体与绯红悬停；`party_status_panel.gd:102-104` 主框已换黑面板＋绯红，但 `_search` 输入框仍硬写 `XUI.font()` 与常量 `TEXT`。不影响皮肤关闭与重制版，建议记入后续网页面板专项统一。
- **P3-2（`detail_hints()` 漏提 `Y 收起`｜仅看代码）**：
  - `skin_equip_page.gd:108-109` `detail_hints()` 为 `[["左右", "换页"], ["上下", "滚动"], ["取消", "收起"]]`，实际 `input()` `L409` 也支持再按 `Y` 收起；可维持精简或按需补作 `["Y / 取消", "收起"]`。
- **P3-3（与 1B/旧详情页微差记档｜只看代码）**：
  - `KEY_X` 替换原取消键与 1B 一致（留 5C 统一定键）；`XSkinGearDetail` 第 1 页同旧 `XGearDetail` 调 `XHelpCard.detail_rows`（不含仅悬浮卡 `XHelpCard.show_for` 才显示的 `XAffixAbsorb.view` 专武吸取附加行）。
- **P3-4（交付单文字表小补充｜只看代码）**：
  - 三文件可见字样均已核对（含 `XSkinGearDetail` 无数据兜底「空」）；待落实 **P2-2** 时同步更新表内 `键盘 C` 与候选态 `Q / E 换人`。

### 没核到的（留给总装 `--affected --cloud`）

- 未重跑有窗模式的 `皮肤关闭对照.py --base main` 与 `xiyou_ui_skin_1c.tscn -- --out=...` 截图重拍（本次仅对已有 `关闭对照/` 14 张图跑了 `--compare`）；
- 未跑 `并行测试.py`、`选测.py` 全集、`工具回归.py`、`xiyou_virtual_player`、`xiyou_tianqi_e2e`、楼层及事件对照四片；
- 交付单所引私密设计仓 `重制设定/界面风格提案_v0.7/` 与早先 `ba1f7ed` 原提交未在当前工作树直接读到，文字审对照 `cc_ui-skin-1b.md` 与 `变更记录.md` 所载 `ba1f7ed` 口径核实。

