# 交付：cc/ui-newsrc2（换源追平 B 界面第三段：修行两页、安全出售、参照重取）

- 车道／工作者：界面 CV（cc）
- 状态：交回集成分支 `cc/newsrc-switch`（不合 main，不标可合并）
- 依据：协调派单（接 `cc_ui-newsrc1.md`「接续要点」）；总装二十七批 ②③。从 96169c95 切，中途合了集成分支 58340027。
- 工作树 `.claude/worktrees/nezha-raven2-3bafc5`：`generated/`、`.godot`、`mv_oracle/.sandbox` APFS 克隆自集成分支工作树（58340027 时的产物，v0.62.12），`generated/oracle/zhenqi.json` 换成本分支探针重跑的一份（只多 `detail`）；测试带 `--skip-generated-check`，探针一律 `XIYOU_APP=…/冻结正式源/v0.62.12/app.nw`。

## 变更记录草稿

## 2026-11-06 【cc·界面·未经审查】换源追平界面第三段：修行拆两页、安全出售、怪物图鉴／战力覆盖参照重取（dev.待定）

- **② 修行两页**（O-待定·修行两页，`XGuide.PANEL_V062`，默认开；关＝v0.28 一页写法）：跟 `installNativeGuidanceRuntime` v0.62 版。第 4 页「修行」照 `G.panelRows`（路线·层数、挑战评估、境界与真气伤害、突破条件／下一境所需、待选奖励、天道加持、结算伤害、必备属性四项、建议前两条、「详细数据见第二页」）；新增第 5 页「修行·详细」照 `G.detailRows`（真气、难度对照四列＝难度影响／不含难度／实际、结算伤害三行）。「战力构成」一段是 CodexZones 五乘区预算，照 O-044 不移植（整段连同段后空行不显示）。面板专用格式 `pct0／dmg_pct／stat_pct／mult1／big_panel`、建议 `panel_suggestions`（秘境抽奖被动书下一本、丹药）、`challenge` 照原版。状态页按 maxCols＝页数排成 5 列（项宽 240、间距 252），表头／滚动与第 4 页同一套 drawPanelRows。原版第 4 页按安卓虚拟按键缩进（CodexV019.padRects），重制暂不缩进（桌面同原版）。区段表 `guide_atlas.json` 换成新源抽出（a 段多被动书一句，d／g 段文字指向「修行·详细」）；里程碑 d 段的改写跟着指向「修行·详细」，g 段同时去掉「战力构成和」。`zhenqi_probe.cjs` 的 page.* 多记 `detail`（新源有 ZhenqiDetail 才记）。
- **③ 安全出售**（O-待定·安全出售，`XSafeSell.ENABLED`，默认开；关＝换源前的筛法）：新文件 `core/safe_sell.gd` 照 `installSafeSellRuntime` v0.40～v0.53.01。一键出售与挂机自动卖出共用 `plan`／`reason`：旧档按 Q.legacy（没品质备注按 1）、一键出售按七档成员（含旧档 15）；保留原因依次为锁定、模板找不到、专属武器（专属法宝照卖）、已培养或镶嵌（法宝升级／经验、异化、心钢与狂妄层数、强化、宝珠孔）、吞器占用、不可出售（无金币售价也无别的货币）、词条达到门槛或待确认（九档，默认「不朽及以上」，存在挂机卖出配置 `keepAffixTier41`，认旧键 `keepAffixGrade40`）。商店一键出售窗宽 680、首行「保留词条：门槛」（确定循环）、各档改叫「出售X装备」；选档后弹确认窗（720 宽、4 行居中：待售／保留件数、门槛、确认出售、取消，默认停在取消；确认时计划变了就刷新不卖）。挂机卖出页宽 680、状态宽 250，末行「保留词条品质」（确定往后一档，←/→ 前后），上方两行说明窗。深渊商人的吞噬／额外词条（重制未移植）不判；CodexElements 的备注元素统一重制不改实例备注，模板与实例原样比。
- **参照重取**：
  - 怪物图鉴 `enemy_book_oracle.json`：`ui_reference/review_system_pages.js` 的 enemy_book 页加 `enemyBookFixture()`，在原场景里按原格式整份重出（目录 850 项、状态窗每 8 项、掉落每 41 项、神话 3 只；记在 Bitmap.drawText／drawIcon、颜色为改色前、对齐非 center/right 按 left 记；神话掉落用替身目录取，免得目录重建）。「99%→299%」是旧夹具的数，新源本来就是 99%。`battle_enemy_book_oracle.json` 仍是 v0.28，新源上照样全过，没重取。
  - 战力覆盖 `power_coverage_oracle.json`：新加 `ui_reference/power_coverage_ref.cjs`（无画面 hboot，写 `mv_oracle/.sandbox/` 再复制）；在 v0.28 上跑与 2026-10-16 浏览器读数逐角色相同，新源上 141／148／149／159／162／166 六处与重制一致，多出新角色 179。`power_panel_oracle.json` 未动（新源上照样过）。
  - 宠物：`review_system_pages.cjs … pets` 在新源重取，说明卡仍在 (880,572)、技能名单不变，夹具不用换；`xiyou_pets` 的 skill_list 挂是 O-007 把 15 号背景说明放大到 16 号，新排版的这张卡因此高 25、碰底被推到 557。测试改为按原版字号（`min_font = 0`）比位置。

## 交接板

- 下一步：
  - 179 流萤的「天火轰击」：原版战力覆盖记「当前条件不可用」，重制记成「尚未完整评估」（`xiyou_status_power_panel` 只剩这一项挂）。是 XPower 的条件判断，归 C 或角色车道。
  - actor_book 剩 5 项图鉴代码（目录名单、【光环】标签、主动列宽 225、168／173～179 立绘、179 技能表）仍未做；gear_search 等穿透口径。
  - 修行页安卓缩进：原版第 4 页避开虚拟按键（padRects），平台车道接虚拟键位时可一起做。
  - `tests/fixtures/zhenqi_page_ui_oracle.json`、`status_page_oracle.json`（选页窗 4 项）仍是 v0.28 手取：drawPanelRows 新旧同码，5 页的项宽按 Window_HorzCommand 公式推（测试里写明）；要逐像素再核可补无头取数。
- 用户试玩说明：状态界面多一页「修行·详细」；「修行」页变短，只给挑战评估、必备属性和两条建议。商店一键出售先弹确认窗，锁定／已装备／培养过／专属武器／词条够好的装备会留下；挂机卖出页能选「保留词条品质」。
- 需要用户决定：无（两项都是总装二十七已批的改版，回退开关见上）。

## 优化登记

- O-待定·修行两页：`XGuide.PANEL_V062`（关＝v0.28 一页写法），测试 `xiyou_zhenqi` 两头测（`_panel_rollback`）。
- O-待定·安全出售：`XSafeSell.ENABLED`（关＝`XItemMarks.sellable_gear` 旧筛法），测试 `xiyou_item_marks`（`_safe_sell_extra`、旧流程段）与 `xiyou_hangup_auto` 两头测。

## 可优化（流程／工具／效率）

- 已做：`power_coverage_ref.cjs`（无画面，一条命令重出战力覆盖夹具，替代浏览器手取；回退＝删文件，夹具照旧可手取）；`review_system_pages.js` 的 enemy_book 页能直接吐整份怪物图鉴夹具（回退＝去掉 extra）。
- 建议：`zhenqi_probe` 跑一轮约 50 分钟（301 例），只为 page.* 也要整份跑。可加 `XIYOU_PROBE_ONLY=page.` 之类的过滤（工具车道，省换源返工时间）。

## 验证

- 本机 `并行测试.py --skip-generated-check`（XIYOU_APP＝v0.62.12）：xiyou_zhenqi、xiyou_guide、xiyou_status_page、xiyou_item_marks、xiyou_hangup_auto、xiyou_enemy_book、xiyou_pets 全过；xiyou_status_power_panel 只挂 179（见上）。
- 选测（`选测.py cc/newsrc-switch --list`，126 个，云端 workflow_dispatch 指定场景，run 42220606308）：挂 18 个，和集成分支 7520680b 整轮（refs/ci/results/…/full，挂 111 个）对过，只有 xiyou_gear_ui 是本单引起（断言旧修行页的「【真气】」），已改成第 4 页查挑战评估、第 5 页查真气与难度对照，本机单跑通过；其余 17 个集成分支上同样挂。xiyou_status_power_panel 由挂 6 处变成只挂 179。
- `事件空绿扫描.py --check`：空绿 96 例均在基线内。
- `工具回归.py`：只挂「探针登记检查」的 `death_admission_probe.cjs 读伤害却没关五乘区`，这个探针是 96169c95 之前的提交 1f32c8ed 加的，集成分支上同样挂，不是本单引起。
- `语法检查.py`：通过。

## 待交叉核查

- `core/guide.gd`（panel_rows／detail_rows／格式函数／milestone d、g）、`ui/status_page.gd`（5 页、item_w）、`core/safe_sell.gd`（全文）、`core/item_marks.gd`（onekey_commands、onekey_sell 分支）、`core/hang_up_auto.gd`（after_battle_sell 分支）、`ui/shop.gd`（确认窗）、`ui/hang_up_sub_page.gd`（保留词条行、说明窗）、`mv_oracle/zhenqi_probe.cjs`（detail）、`ui_reference/review_system_pages.js`（enemyBookFixture）、`ui_reference/power_coverage_ref.cjs`。

## 本分支提交

- 见 `git log 96169c95..cc/ui-newsrc2`
