# 交付：luiluu/xa-t309-ui-polish

- 车道／工作者：小A（Neon high，P9）
- 状态：进行中（WIP：现状排查与共用件美化方案草稿完成；按公共规矩 v1.6 第 3 条上下文压缩停手线保存现场，待卡 N/O 推上 `github/main` 后由新 Neon 会话接续实装）
- 关联任务：T309 新界面整体美化（Neon 主笔＋实装）
- 红线守则（已确认不动）：D18 七印环方向、D25 菜单 7 组、D26 横屏铺满、D29 红乙（黑底／红选中／旧金）、D43 标题画面定稿、D50 R2 无框烟色面板（不给烟底加硬方框）、D231 宋体。

## 变更记录草稿

### 2026-11-20 【小A·未经审查】T309 新界面整体美化（dev.待定）

- 状态：草稿（尚未实装代码，待下一任接手补齐提交与验收结果）
- 玩家可见：待实装后按最终改动填写（预计为新界面整体暖炭金调和谐化、分割线与量条质感打磨、弹窗平滑渐变、列表与详情卡长看舒适度优化；单一总开关 `XUiSkin.POLISH_V1` 可逐像素回退）

## 现状排查：美化舒适 18 条逐条核对

基准提交：`github/main 2ad519a18`（含卡 E/I/J/K/L/M；卡 N/O 已合本机 `main` 待推 `github/main`）。
参考设计稿（只读）：私密仓 `界面风格提案_v0.7/README.md`、`小A审_美化舒适.md`、`T254_剩余页细节设计.md` 3.0。

### 一、美化 10 条

| # | 条目（小A审_美化舒适） | 当前状态 | 现状依据（仓内相对路径:行号） | T309 处置 |
| --- | --- | --- | --- | --- |
| 美-1 | 暖炭黑底与锡灰线（`#080708` / `#b0a79b`） | **未启用（仍冷黑）** | `modes/xiyou/ui/skin/ui_skin.gd:35,107-118`：`WARM_BG := false`，`BG=#050506`、`PANEL=#18191c`、`LINE=#a2a5ab`、`TEXT_2=#a8aaaf`；实机新页截图测得中灰 `R-B = -1.1～-2.5`（偏冷蓝灰）。注：`xiyou_ui_skin_close.gd:262` 断言 `not WARM_BG and BG == Color("050506")` | **必改**：在 `POLISH_V1` 下通过语义色读取函数提供暖炭色板，不动 `WARM_BG` 默认值 |
| 美-2 | 面板去塑料渐变、换柔雾暗墨底＋顶缘微光 | **部分已做** | `modes/xiyou/ui/skin/skin_art.gd:266-280`：D50 R2 正式美术已把主面板换成无框 `smoke_reading_128x128`／`smoke_secondary_128x64`＋颗粒底纹；但烟底冷灰略平、主阅读卡与列表区层次弱，且 `skin_confirm.gd:22-23,178` 仍为 `DLG_TOP #26252c`／`DLG_LOW #16151a` 45% 硬切分 | **必改**：严守 D50 R2 不加硬方框；给烟底做微暖色调制＋居中渐隐顶缘金丝；彻底重做 `XSkinConfirm` 为平滑暖炭渐变 |
| 美-3 | 菜单背景换暗调氛围底图、停用裂纹纹理 | **已做（不再适用旧改法）** | `modes/xiyou/ui/skin/skin_art.gd:103-170`：phase01 五路线×三比例正式像素背景已启用（`BG := true`），并配 `READ` 压暗与顶底渐变（`READ_DIM=0.28`） | 保留现状；仅对 `ReadDim`/`ReadRing` 暖色微调检查（不损清晰度） |
| 美-4 | 选中态层次与焦点识别（暗红渐隐＋外置箭头＋悬停／按下区分） | **已做** | `modes/xiyou/ui/skin/skin_art.gd:359-388`、`ui_skin.gd:191-208`：D51 `selection_wash_128x24`＋外置 `selection_arrow_7x9`＋`SELECT_V2` 悬停减淡／按下压暗下沉 1px 已实装 | 保持核心不变；仅对选中条上标签防糊（加暗底）及选中行微细节润色 |
| 美-5 | 标题／节头／分割线精致化（渐隐金丝＋菱形点缀） | **没做** | 几乎所有共用件（`skin_card.gd:316,403`、`skin_template_page.gd`、`skin_party_strip.gd:142`、`skin_gear_detail.gd:217`、`skin_target_list.gd:120`、`skin_party_page.gd:350`、`skin_battle_list.gd:247`）仍画整宽平灰 `Color(XUiSkin.LINE, 0.14)` 直线 | **必改**：新增共用 `XUiSkin.draw_divider()`（两端渐隐暖锡／旧金细线＋主分隔可选中心微菱形）、页标题下微金短线与节头前 `◆` 点缀 |
| 美-6 | 环心改 3× 像素小人＋外圈状态区分 | **已做** | `ui_skin.gd:38-41`（`CENTER_STYLE := CenterStyle.SPRITE`，D45/D48）、`skin_ring_nav.gd`（`INNER_V2 := true`、卡 E）及 `skin_art.gd:398-406`（`HALO := true`）已实装 | 保持不变；仅将圆球冷灰底 `ORB_HI/ORB_LOW` 在 `POLISH_V1` 下调暖 |
| 美-7 | 详情卡排版与可读性（行距、节间距、展开滚动条） | **部分已做** | `skin_card.gd:32,299-316,442,490`：卡 M 已定 `line_h() == 30.0`（且被 `xiyou_ui_skin_card_m.gd:695` 断言）；但 `_paragraph` 行距偏紧（`1.5×`）、展开卡 `_sheet` 滚动条仅 `3px` 灰条（`skin_card.gd:315`）、信息块缺暖色内嵌底 | **必改**：不改 `line_h()` 返回值；扩宽 `_sheet` 滚动条至 `6px` 暖金圆角、微调段落行距、主阅读卡加极淡右下七芒暗印与暖色内嵌提示块 |
| 美-8 | 战斗 HUD 细节与量条槽质感 | **部分已做** | `skin_enemy_hp.gd:46-75` 已用 65% 黑底槽＋顶缘高光；但共用队伍条 `skin_party_strip.gd:198`、`skin_side_status.gd:127`、`skin_status_page.gd:192`、`skin_target_list.gd:152`、`skin_party_page.gd:224,343`、`skin_sub_page.gd:218`、`skin_arc_gauge.gd:83` 仍用发白浅灰 `Color(1,1,1,0.10..0.12)` 轨道 | **必改**：抽共用 `XUiSkin.draw_gauge()`（深炭内凹底槽＋1px 淡锡内框＋填充顶缘 1px 高光）统一替换所有共用条 |
| 美-9 | 地图 HUD 统一黑金胶囊 | **已做** | `modes/xiyou/ui/skin/skin_4a.gd:12,24-29,107-115`：`HUD_V2 := true` 已实装黑底暖锡边旧金字胶囊与琥珀状态点 | 保持不变 |
| 美-10 | 空态、标签、面包屑、步进器与滚动条收口 | **没做** | `skin_tag.gd:41,78`（标签无暗底易被烟底／红底干扰；空态仅灰字）、`skin_list.gd:416-419` 与 `skin_gear_detail.gd:272-277` 与 `skin_battle_list.gd:241-244`（硬直角灰滚动条）、`skin_crumb.gd:29`、`skin_inner_tabs.gd:84`、`skin_stepper.gd:294`、`skin_key_hints.gd:192` | **必改**：统一圆角暖金滚动条 `XUiSkin.draw_scrollbar()`；标签加半透深炭底；空态加淡七芒暗纹；密集列表加微斑马纹；键盘底部提示加轻质暖炭键帽底 |

### 二、视觉舒适 8 条

| # | 条目（小A审_美化舒适） | 当前状态 | 现状依据（仓内相对路径:行号） | T309 处置 |
| --- | --- | --- | --- | --- |
| 舒-1 | 正文降刺眼纯白→骨白、禁用灰提亮至对比度 ≥5 | **已做** | `ui_skin.gd:121-127`：`COMFORT_V2 := true` 已改为 `TEXT=#e6e2dc`、`TEXT_3=#8e8982`（`xiyou_ui_skin_close.gd:230` 断言） | 保留；另把冷灰 `TEXT_2=#a8aaaf` 在 `POLISH_V1` 下调暖为 `#b8b2a8` |
| 舒-2 | 柔和「优秀」荧光绿、消除语义色撞色 | **部分已做** | `QUALITY[1]` 已由 `#80ff1c` 调柔为 `#8fdc5a`（`ui_skin.gd:142`）；但 `DOWN (#ffa35c)` 与传说 `QUALITY[4] (#ffa040)` 几乎同色，神话 `QUALITY[6] (#ff483c)` 与选中线 `SEL_LINE (#ff5a48)` 撞色 | **必改**：`POLISH_V1` 下在显示层分离 `DOWN`（偏暖赤陶橙 `#e88252`）与神话色（宝石玫红 `#ff5c84`，仍与生命糖果粉 `#ff78b0` 及选中朱红 `#ff5a48` 拉开色相） |
| 舒-3 | 常驻主按钮去刺眼大红，平时深褐金、焦点才红 | **已做** | `ui_skin.gd:51-59`：`primary_button_style` 在 `COMFORT_V2` 下平时用 `BTN_IDLE_FILL #2b2318`＋旧金边 | 保持不变（`xiyou_ui_skin_close.gd:234` 断言）；`XSkinButton` 常态边线随暖锡色柔和化 |
| 舒-4 | 选目标去 2Hz 急闪、放慢常驻呼吸与漂浮火星 | **部分已做** | `ui_skin.gd:44,63-66`：`target_pulse` 已改 2.4s 余弦慢呼吸；但左侧光标 `BREATH_TIME := 1.6`（`ui_skin.gd:211`）偏快、背景火星速度 `110～180 px/s`（`ui_skin.gd:844-845`）仍偏急 | **必改**：`POLISH_V1` 下呼吸周期放缓至 `2.4s`（下限 `0.75→0.82`）、火星速度降为 `48～82 px/s` 且微降透明度，减少余光分神 |
| 舒-5 | 血条加粗可读（5→8px）与清晰槽对比 | **部分已做** | `ui_skin.gd:47-48`：`bar_h("hp") == 8.0` 已实装；但底槽为浅白半透，亮部与低血残段辨识度弱 | **必改**：配合美-8 改深炭内凹底槽＋微亮边 |
| 舒-6 | 小字下限与色盲辅助（七印状态加形状前缀） | **部分已做** | `FONT_V2 := true` 正文下限 15px、`tianqi_skin_altar.gd` 已加 `◆/◇/·`；但战斗局部仍有 9–12px 小字（`skin_side_status.gd:95-97` 回合数 `12px`、`skin_boss_status.gd:247` 属性抗性最低压到 `9px`、`skin_otb_bar.gd` 小标 `12px`） | **必改**：在不溢框前提下抬升战斗极小数字可读性（`skin_side_status` 状态回合数加深底小胶囊 12→13px；`skin_boss_status` 属性行下限 9→11px＋微间距整理） |
| 舒-7 | 全屏闪光 ≤3 次/秒、高倍速压弱闪白 | **已做** | `skin_4a.gd:20,174-205`：`FLASH_V2 := true` 已实装 | 保持不变 |
| 舒-8 | 亮战斗背景压暗（0/15%/30%）＋战斗无底浮字深胶囊 | **已做** | `skin_4a.gd:17-18,118-137,151-171`：`DIM_V2 := true`（默认 15%）、`TEXT_V2 := true` 已实装 | 保持不变 |

## 实机截图定量基线（改造前）

> 工具诚实报备：当前环境无多模态看图工具，采用纯 Python PNG 像素解码脚本对归档实机图逐图定量采样（亮度 `L = 0.2126R + 0.7152G + 0.0722B`；中灰段为 `15 <= L <= 70`）：

| 已合页面样例（归档路径） | 尺寸 | 均亮 L | 暗部占比 (L<25) | 高亮占比 (L>200) | 中灰平均 RGB | 冷暖 R-B |
| --- | --- | --- | --- | --- | --- | --- |
| `00_项目管理/归档/交付截图/luiluu_cc-t283-ui-card-i/shop_buy_16x9.png` | 800×450 | 21.7 | 84.2% | 0.4% | (20.9, 21.0, 22.1) | **-1.2（偏冷）** |
| `00_项目管理/归档/交付截图/luiluu_cc-t292-ui-card-j/party_16x9.png` | 800×450 | 26.1 | 83.0% | 0.9% | (20.2, 20.0, 21.3) | **-1.1（偏冷）** |
| `00_项目管理/归档/交付截图/luiluu_cc-t299-ui-card-k/craft_category_16x9.png` | 800×450 | 20.8 | 86.8% | 0.4% | (19.4, 20.5, 21.9) | **-2.5（偏冷）** |
| `00_项目管理/归档/交付截图/luiluu_cc-t299-ui-card-k/craft_confirm_16x9.png` | 800×450 | 22.3 | 83.4% | 0.4% | (21.1, 21.1, 22.1) | **-1.1（偏冷）** |
| `00_项目管理/归档/交付截图/luiluu_cc-t300-ui-card-l/L_主页进画质_常态_16x9.png` | 800×450 | 22.4 | 85.0% | 0.4% | (20.3, 20.7, 22.0) | **-1.8（偏冷）** |
| `00_项目管理/归档/交付截图/luiluu_cc-t304-ui-card-m/M_主页进挂机_常态_16x9.png` | 800×450 | 22.9 | 82.8% | 0.4% | (21.4, 21.5, 22.4) | **-1.1（偏冷）** |

结论：所有新页面板中灰均呈 `B > R` 的冷青蓝灰（`-1.1`～`-2.5`），与暖旧金 `#e3bd72`、暖骨白 `#e6e2dc`、暖朱红 `#cf2a1f` 产生明显色温割裂；同时超过 83% 区域陷入 `L < 25` 的平暗区，缺乏「背景→列表→主阅读卡→确认弹窗」的层次梯度。

## 美化改法清单（一处改、全页受益）

### 总开关设计

在 `03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/skin/ui_skin.gd` 新增单一总开关：
```gdscript
## T309 新界面整体美化总开关（默认 true；false 时逐像素回退至美化前；不改动 WARM_BG 等既有开关的默认常量）
static var POLISH_V1 := true
static func polish_on() -> bool:
	return POLISH_V1 and on()
```
- **回退铁律**：`POLISH_V1 = false` 时所有新增绘制分支跳过、颜色读取返回原值，与美化前逐像素一致；`XUiSkin.ENABLED = false` 或非天启档时 `polish_on()` 恒为 `false`，确保 `皮肤关闭对照.py` 零差异。
- **不破坏旧测试断言**：见下文「必须保护的旧测试不变量」。

### 分项改动清单

| 编号 | 目标文件与位置（仓内相对路径:行号） | 具体改法 | 为什么（视觉问题） | 对长时间视觉舒适度的影响 |
| --- | --- | --- | --- | --- |
| P1 | `modes/xiyou/ui/skin/ui_skin.gd:35,107-143` | 新增 `POLISH_V1` 与语义读取函数：`bg_c()` `#090808`、`panel_c()` `#1e1b1b`、`panel_low_c()` `#131112`、`line_c()` `#b5ab9c`、`text2_c()` `#bab4aa`、`orb_hi_c()` `#38322f`、`orb_low_c()` `#161312`、`down_c()` `#e88252`、`mythic_c()` `#ff5c84`；保留原常量供旧代码／测试断言 | 消除冷青灰 (`R-B=-1.1..-2.5`) 与暖金／骨白／朱红的色温割裂；分开下降橙与传说橙、神话红与选中朱红 | 降低蓝光冷刺激与色温冲突疲劳；装备比对／品质扫读一眼分辨、减少误判 |
| P2 | `modes/xiyou/ui/skin/skin_art.gd:55-56,141-170,266-280` | 严守 D50 R2 无框烟底：`draw_smoke` 在 `polish_on()` 时给 `smoke_reading` 乘极微暖色调制 `Color(1.04, 1.01, 0.96, a * k)`（主阅读卡微提 4% 暖明度），并在大面板（`w > 180, h > 120`）顶部中央 65% 宽度画一条 1px 两端渐隐的极淡旧金丝线（`alpha 0.22→0`，无外框）；`_add_scrims` 压暗层改极深暖黑 `#070606` | 让无框烟底融入暖炭金体系，拉出「深底→次面板→主阅读卡」的呼吸层次而不违背无框定稿 | 视线快速锁定阅读焦点，减轻大面积死黑带来的压抑感 |
| P3 | `modes/xiyou/ui/skin/ui_skin.gd` 新增共用绘制函数，接入 `skin_card.gd:316,403`、`skin_template_page.gd:427`、`skin_party_strip.gd:142`、`skin_gear_detail.gd:217`、`skin_target_list.gd:120`、`skin_party_page.gd:350`、`skin_status_page.gd:229`、`skin_battle_list.gd:247`、`skin_main_menu.gd:954` | 新增 `XUiSkin.draw_divider(ci, x0, x1, y, gold := false, alpha := 1.0)`（多段或 1×3 渐变线：两端 alpha=0、中段暖锡 `0.26` 或旧金 `0.36`，`gold=true` 时中点加 3px 菱形微粒）与 `XUiSkin.draw_title_accent(ci, x, y, w)`（页标题下方 48px 渐隐金线） | 替代全库生硬的 1px 整宽平灰线，让每个页面的结构分区瞬间具备暗黑奇幻手稿精致感 | 柔和边界不割裂视线，扫读分节更快更轻松 |
| P4 | `modes/xiyou/ui/skin/skin_confirm.gd:22-23,178-240` | `polish_on()` 时去掉 45% 高度的硬水平色块切分（`DLG_TOP` / `DLG_LOW`），改为垂直平滑暖炭渐变（`#211d1d` → `#121011`，纹理留静态引用缓存防释放白块）＋顶部渐隐旧金高光丝线＋精致双层外边（外暗影＋1px 暖金／危险赤陶边）＋标题下方 `draw_divider(..., true)` | 原弹窗中部有一条极其突兀的冷紫灰硬折痕，是当前新界面最明显的粗糙点 | 弹窗主次明确、不再刺眼，危险确认与普通确认一眼区分 |
| P5 | `modes/xiyou/ui/skin/ui_skin.gd` 新增 `draw_gauge()`，接入 `skin_party_strip.gd:198-200`、`skin_side_status.gd:127`、`skin_status_page.gd:192`、`skin_target_list.gd:152`、`skin_party_page.gd:224,343`、`skin_sub_page.gd:218-219`、`skin_arc_gauge.gd:83` | 新增 `XUiSkin.draw_gauge(ci, rect, ratio, fill_col, alpha := 1.0)`：深炭内凹底槽 `Color(0.03, 0.025, 0.025, 0.68)`＋1px 淡暖锡描边 `Color(0.76, 0.70, 0.62, 0.16)`＋圆角填充＋顶缘 1px 柔和亮线 `Color(1, 1, 1, 0.24)`（与 `XSkinEnemyHp` 统一视觉语言） | 消灭全库发白发糊的 `Color(1,1,1,0.12)` 浅灰条槽，统一地图／菜单／战斗全部量条材质 | 残血／蓝量边缘更锐利，长时间扫视血条不费眼 |
| P6 | `modes/xiyou/ui/skin/ui_skin.gd` 新增 `draw_scrollbar()`，接入 `skin_list.gd:416-419`、`skin_card.gd:315`、`skin_gear_detail.gd:272-277`、`skin_battle_list.gd:241-244` | 统一圆角滚动条：暖黑微凹槽 `Color(0.04, 0.035, 0.035, 0.45)`＋暖金锡圆角滑块 `Color(0.76, 0.68, 0.54, 0.62)`；将 `skin_card.gd:315` 展开卡滚动条从 `3px` 提至 `6px` | 消灭直角冷灰细条，尤其是详情卡展开页 3px 细线几乎不可见 | 翻长词条／长列表时滚动进度一目了然 |
| P7 | `modes/xiyou/ui/skin/skin_list.gd:339-425`、`skin_card.gd:238-325,490-510`、`skin_gear_detail.gd:245` | ① `XSkinList` 在单列密集列表每偶数行叠加极微暖带 `Color(0.95, 0.90, 0.82, 0.025)`（选中行跳过，避免叠加红底）；② `XSkinCard` 节头文字前加 2px×12px 旧金微竖标、段落行距从 `1.5×` 微调至 `1.62×`（不动 `line_h()` 的 `30.0` 返回值）、右下角在空白处叠极淡 `seven_seal_128x128` 暗印（alpha 0.05，缓存引用）；③ `XSkinGearDetail` 对比行底改为暖微带 `Color(0.95, 0.90, 0.82, 0.045)` | 解决 16:9／20:9 宽行左右扫视易串行、详情卡文字块偏密缺呼吸感的问题 | 显著降低长列表扫读与长装备词条阅读的眼动追踪负担 |
| P8 | `modes/xiyou/ui/skin/skin_tag.gd:41-95`、`skin_inner_tabs.gd:84`、`skin_crumb.gd:29`、`skin_stepper.gd:294`、`skin_key_hints.gd:192`、`skin_back_button.gd:55`、`skin_button.gd:8` | ① `XSkinTag.draw` 加深炭半透底 `Color(0.05, 0.04, 0.04, 0.62)`＋微色罩 `Color(c, 0.12)`，防止标签贴在红选中条或烟底上发糊；`draw_empty` 居中加淡七芒暗印＋暖灰字＋下方短渐隐分割线；② `XSkinInnerTabs` 未选页签加轻暗底、当前页签底部加旧金微光条；③ `XSkinCrumb` 分隔符改旧金 `›`；④ `XSkinStepper` 加暖炭胶囊外底与聚焦旧金细边；⑤ `XSkinKeyHints` 键盘态给按键名加轻暖炭键帽底（不改控件高度 `H`/`TOUCH_H`）；⑥ `XSkinBackButton` 加柔和圆底微晕；⑦ `XSkinButton` 常态边线改暖锡色 | 收口所有散件的精致度，让商店、制作、设置、仓库、挂机等所有次级交互控件风格浑然一体 | 控件边界与状态更清晰，按键提示不再飘浮难寻 |
| P9 | `modes/xiyou/ui/skin/ui_skin.gd:211,368,844-845` | `polish_on()` 时：`breath_alpha()` 周期从 `1.6s` 放缓至 `2.4s`、下限从 `0.75` 提至 `0.82`；`_add_embers()` 粒子初速从 `110～180` 降至 `48～82`、粒子透明度再乘 `0.78` | 降低常驻界面高频呼吸和快速飘升火星对余光的持续刺激 | 长时间挂机／整理装备／配装时显著减缓视觉疲劳 |
| P10 | `modes/xiyou/ui/skin/skin_side_status.gd:95-97`、`skin_otb_bar.gd:23`、`skin_boss_status.gd:16,214,247,258,286`、`skin_battle_2c.gd` | ① `skin_side_status` 状态回合数加小暗胶囊底并由 12→13px；② `skin_otb_bar` 敌方底色 `ENEMY_DARK` 略暖化、小字 12→13px；③ `skin_boss_status` 卡片底改暖微带、底部分页线用 `draw_divider`、属性行下限 9→11px；④ 战斗结算／浮层（`skin_battle_2c.gd`）中平灰分割线与底槽同步走 `draw_divider`／`draw_gauge` | 补齐战斗 HUD 与菜单页面的暖炭金一致度，消除极小数字糊字 | 长时间刷本盯战斗信息更省眼 |
| P11 | 卡 N/O 接入后补齐：`skin_roster_page.gd`（及卡 N/O 新增共用件） | 待 `git merge github/main` 带入卡 N/O 后，逐一核对 `skin_roster_page.gd` 与 N/O 新增页中的分割线、量条槽、滚动条、冷灰常量并接入上述共用函数 | 保证卡 E～O 全部新页无遗漏、一处改全页受益 | 全游戏新界面风格统一 |

## 必须保护的旧测试不变量（实装防踩坑清单）

已逐一扫描 `03_再刷重制_Godot/01_Godot工程/tests/xiyou_ui_skin_*.gd`，以下常量与行为被严格断言，**严禁直接改坏**：
1. `xiyou_ui_skin_close.gd:230`：`XUiSkin.TEXT == Color("e6e2dc")`、`XUiSkin.TEXT_3 == Color("8e8982")`、`XUiSkin.QUALITY[1] == Color("8fdc5a")`
2. `xiyou_ui_skin_close.gd:231`：`XUiSkin.bar_h("hp") == 8.0`、`XUiSkin.bar_h("mp") == 5.0`
3. `xiyou_ui_skin_close.gd:234`：`primary_button_style` 常态 `sb.bg_color == XUiSkin.BTN_IDLE_FILL` 且 `sb.border_color` 近似 `Color(XUiSkin.GOLD, 0.85)`
4. `xiyou_ui_skin_close.gd:262,274`：`not XUiSkin.WARM_BG and XUiSkin.BG == Color("050506")`；开 `WARM_BG` 时 `BG == Color("080708")` 且 `LINE == Color("b0a79b")`
5. `xiyou_ui_skin_close.gd:136-143`：`FS_LIST/FS_AUX/FS_MIN/FS_PAGE` 各档字号精确值
6. `xiyou_ui_skin_close.gd:156,164,174,307`：`XSkinKeyHints.H`、`TOUCH_H` 及底部贴边边界
7. `xiyou_ui_skin_card_m.gd:685,695`：`XSkinList.dis_color(1) == Color("c9cbd0")`、`XSkinCard.line_h() == 30.0`
8. `xiyou_ui_skin_shop.gd:210,287`、`xiyou_ui_skin_card_l.gd:234,323`：比较颜色均引用符号（`XUiSkin.GOLD`/`XUiSkin.DOWN`/`XUiSkin.UP`/`XUiSkin.TEXT_2`），因此将暖色替换放在绘制层 helper（而非粗暴改常量值）既保测试全绿，又保总开关 `POLISH_V1 = false` 逐像素回退。
9. **纹理引用防白块（卡 M 教训）**：任何新建 `GradientTexture2D`／`ImageTexture`（如 `XSkinConfirm` 渐变底）必须保存在 `static var` 缓存字典中持强引用，绝不作为临时局部变量传入 `RenderingServer` 后释放。

## 新美术素材需求（只列需求，不画像素）

本次 T309 主体通过共用件代码与 phase01 现有像素资产即可落地，**不阻塞实装**；若 Kyo 看完对照图后希望再上一个台阶，建议后续美术单可选补两类小件：
1. **设置页／功能分类专用小图标（32×32，暗旧金线稿风格）**：替代 `skin_options_page.gd` 当前单字圆球（常／战／敌／画／声／挂／他）与部分沿用 MV 旧图标的分类节点。
2. **弹窗四隅微雕饰角件（16×16 透明底旧金像素角花）**：供 `XSkinConfirm` 与重要提示框四角轻缀，强化暗黑奇幻仪式感（无框主烟底面板按 D50 R2 仍不加角花）。

## 玩家可见文字

- 当前草稿阶段：无新增或修改玩家可见文字。
- 实装阶段若新增任何玩家可见文字（原则上 T309 纯视觉美化不新增文案），须在此节逐条列出并由小A（本车道自带文字审）标注审定结论。

## 下一任 Neon 接手实装清单

1. **同步卡 N/O**：`git fetch github && git merge github/main`（只合 `github/main`），必要时重跑 `zsh 03_再刷重制_Godot/07_开发环境/新建工作树.sh --补齐 <工作树>`，检查 `skin_roster_page.gd` 及 N/O 新增件并补齐上表 P11。
2. **按 P1～P11 实装**：全部改动挂在 `XUiSkin.POLISH_V1` 下（`false` 时与美化前逐像素一致）。
3. **拍 ≥8 页同状态前后对照图（800×450，左现在｜右美化后，拼成 1600×450）**：
   - 存放目录：`00_项目管理/归档/交付截图/luiluu_xa-t309-ui-polish/对照/`
   - 建议覆盖 10 页：`01_主菜单`、`02_装备`、`03_物品`、`04_商店`、`05_整队`、`06_制作与确认弹窗`、`07_宝珠坊或种族祝福`、`08_设置与挂机子页`、`09_战斗指令与浮层`、`10_战斗结算`（若含卡 N/O 页面一并选入）。
   - 所有 Godot 命令必带 `--audio-driver Dummy`，前台逐一运行，不用 `并行测试.py`、不后台、不设定时器、不用子代理。
   - 同时跑自动化像素核验：确认 `POLISH_V1=false` 与美化前 0 像素差异、`POLISH_V1=true` 暖度 `R-B > 0` 且无纯黑裁切／溢出。
4. **全项验收**：
   - 前台逐个跑（均加 `--audio-driver Dummy`）：`xiyou_ui_skin_card_e`、`xiyou_ui_skin_shop`（卡 I）、`xiyou_ui_skin_card_j/k/l/m/n/o`、`xiyou_ui_skin_2c`、`xiyou_ui_skin_5c`、`xiyou_ui_skin_offshot`、`xiyou_ui_skin_close`、`xiyou_ui_skin_menu`、`xiyou_ui_skin_hud` 及新建的 `xiyou_ui_skin_polish`。
   - 跑 `python3 03_再刷重制_Godot/07_开发环境/皮肤关闭对照.py` 通过。
   - 跑 `python3 03_再刷重制_Godot/07_开发环境/语法检查.py` 为 0。
   - 更新本交付单状态为 `可合并`（注：美术定稿需 Kyo 点头，回执「要 Kyo 定」写明，发完 `worker_done` 即停手不自合 `main`），提交后跑 `python3 03_再刷重制_Godot/07_开发环境/交付自检.py` 到退出码 0。

## 交接板

- 下一步：待卡 N/O 推上 `github/main` 后，由新 Neon 会话接续 `luiluu/xa-t309-ui-polish` 分支合并 `github/main` 并按本交付单 P1～P11 实装、出 ≥8 页并排对照图与全项验收。
- 用户试玩说明：暂未实装代码（WIP 方案草稿）。
- 需要用户决定：实装完成后，≥8 页前后对照图待 Kyo 目视定稿后再决定合入 `main`。

## 进度账

- 本轮为 WIP 调研与方案草稿，暂不改动进度账。

## 可优化（流程／工具／效率）

- 建议：为 `tests/xiyou_ui_skin_offshot.gd` 同类对照脚本增加「同分支双开关一键拍并排对照图（`1600×450`）」通用小工具，后续美术／UI 调优单可直接复用（预计每次省 15 分钟写拍图脚本；归 UI 皮肤车道）。

## 本分支提交

- 待本 WIP 提交后由下一任补全完整提交列表。
