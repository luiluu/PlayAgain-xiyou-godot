# 交付：cc/rules-equip1

- 车道／工作者：C 规则／rules 线程（cc，派单第七批 AR）
- 状态：可合并
- 只有文档和注释：交付单（盘点表）、`orbs.gd`／`three_growth.gd` 头注释订正，不改代码行为。

## 变更记录草稿

## 2026-11-05 【cc·rules·未经审查】装备系统盘点：制作、法宝细项都已做完，订正三处过时注释（dev.待定）

- 按派单盘点装备相关插件与运行时，对照重制现状（表见下）。结论：进度核定里装备行写的「还缺：制作、法宝细项」都已经做完了，没找到要写代码的缺口。
- 订正过时的头注释：`orbs.gd` 写着「ShareLearnSkill 未移植、原作宝珠技能效果不生效」和「神秘珠掉落、宝珠坊、套装伤害钩子未移植」，实际都做了；`three_growth.gd` 写着「屠苏与璇的五相／列星特效未移植」，实际在 `tusu.gd`、`xuan_battle.gd`。

## 装备系统盘点（equip1，2026-11-05）

方法：plugins.js 里启用的装备相关插件＋codex 运行时逐个对重制文件头注释与代码；`插件备注覆盖.py` 现跑（1065 个标签：已读 218、已核 21、数据里没用到 805，没读的只有 1 个且与装备无关）；道具升级效果按数据里实际出现的写法（19 种）逐条查 `gear_upgrade.gd`。

| 项 | 原版位置 | 重制现状 | 剩下的 | 大小 |
| --- | --- | --- | --- | --- |
| 制作 | hc.js（1139 行；配方、类别等级、材料、数量确认、按钮、弹窗、主菜单指令） | `core/crafting.gd`＋`ui/crafting.gd`，版面逐条对浏览器参照（crafting_oracle），利维坦锻造 457／458 也接了 | `Scene_CraftingSpecific`（`crafting call`）数据里没用；成功率 chance 显示：配方都没写，恒 100 | 无 |
| 通用法宝 | CP_MagicWeapon（1064）＋CP_X_MagicWeaponLearnSkill（176） | `core/magic_weapon.gd`：经验、连续升级、满级、胜利结算（含后援）、经验丹、强制升级、升级特性、按等级授技、每级能力成长、图标等级字 | `<Magic Weapon LevelUp Effect>` 数据没用；战斗中特性缓存（等级战斗中不变，不影响）；经验条原版已注释掉 | 无 |
| 三角色法宝进化 | installThreeGrowthRelicRuntime（304） | `core/three_growth.gd`＋屠苏 60 级（`tusu.gd`、`battle_logic` 止戈环包装）＋璇 60 级列星（`xuan_battle.gd`） | 传家宝品质整理 RQ.normalize：这些法宝原表就是品质 9，无可见效果；`three_growth.gd` 头注释「屠苏与璇的五相／列星特效未移植」已过时 | 注释 |
| 专属法宝 | 渡鸦、饿狼、米拉等运行时 | 各角色模块（raven_artifact 等）；dev.224 起归角色行 | 不在装备行 | — |
| 升级插槽 | YEP_X_ItemUpgradeSlots（1375） | `core/gear_upgrade.gd`：数据里 19 种效果写法（八项能力、随机能力、元素增幅、打孔／加孔／删孔、镶嵌命中）都认 | 无 | 无 |
| 套装 | GT_EquipSuitCore（3154） | `core/equip_suits.gd`（累计件数门槛、状态、能力、抗性） | 无 | 无 |
| 镶嵌／符石／宝珠 | Star_EquipmentMosaic、Star_EquipInlayBook、Orb、Runeword | `orbs.gd`、`runewords.gd`、`ui/inlay_book.gd`、`ui/orb_shop.gd` | `orbs.gd` 头注释「ShareLearnSkill 未移植」「宝珠坊未移植」「套装伤害钩子」都已过时（`skill_share.gd`、宝珠坊、`damage.gd` general_set 都做了） | 注释 |
| 装备页、检索、对比 | YEP_EquipCore、installEquipmentStatusRuntime | `ui/equip_scene.gd`、`gear_search.gd`、`side_status.gd` | ui8／ui10 已对过 | 无 |
| 物品分类、置顶、NEW、品质颜色 | YEP_X_ItemCategories、Star_ItemTop、Galv_NewItemIndication、ItemQuality／ItemColor | `ui/item_scene.gd`、`item_marks.gd`、`item_row.gd` | 无 | 无 |

结论：派单写的「制作、法宝细项」两项其实都已做完，装备行 80% 偏低；找不到「大而确定」的缺口可做。能做的只有把三处过时的头注释订正。

## 交接板

- 下一步：无（装备行不再派写代码的活）。
- 用户试玩说明：无变化。
- 需要用户决定：无。

## 进度账

- **装备系统 80% → 建议重估为 98%**。依据：
  - dev.224／239／355 三次核定，装备行写的缺口都是「制作、法宝细项」，另有「法宝专属进化／绑定」已注明归角色行。本次逐项核对，这两项都已做完。制作有规则和界面，界面逐条对过浏览器参照；通用法宝做了经验、结算、经验丹、强制升级、升级特性、按等级授技和每级成长；三角色法宝进化做了 60 级特效。
  - `插件备注覆盖.py` 现跑：1065 个标签里，没读的只有 1 个，而且跟装备无关。道具升级效果按数据里实际出现的 19 种写法逐条查，都认。
  - 剩下的只有：数据里没用到的写法（`<Magic Weapon LevelUp Effect>`、`crafting call`），和没有可见效果的步骤（传家宝品质整理）。留 2% 给连续试玩里可能冒出来的零星显示细节；这部分按口径属于验收，不算系统缺口。如果核定口径是「数据里用到的都做了就记满」，可以记 100%。

## 可优化（流程／工具／效率）

- 建议：进度核定的「还缺」列表这几次都是照抄上一份，装备行连续三次没人核对。核定时对每个「还缺」条目 rg 一下文件头注释和测试（几分钟），可以免得派出空活。归总装。

## 验证

- 只改注释和文档。没跑 Godot 测试，因为不改行为，选测按规则只需文档检查；也跑了 `语法检查.py`。

## 本分支提交

- （本提交）盘点表、注释订正
