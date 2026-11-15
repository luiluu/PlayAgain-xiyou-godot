# 全库游戏文字审查——批 14（`modes/xiyou/ui/*.gd` 界面脚本 2/3）

> 所属总单：[xa_text-audit.md](xa_text-audit.md)
> 范围：`modes/xiyou/ui/` 下按文件名排序从 `graphics_options.gd` 至 `options_scene.gd` 共 21 个非天启篇界面脚本（其中 14 个含玩家可见文字，合计约 481 段）。

| 序号 | 位置 | 原文 | 问题 | 建议改成 | 级别 | 版本 |
| --- | --- | --- | --- | --- | --- | --- |
| 14-001 | `modes/xiyou/ui/hang_up_sub_page.gd:119` | `卖出的回合(为0不卖出)` | 经核 `core/hang_up_auto.gd:8, 434-439`，该项实际统计的是**战后场数**（`better_frequency` 每场 `+1`，等于 `SellQuality` 时卖出），而非战斗内「回合」；且使用了半角括号 `()` | `自动卖出间隔场数（0 为不卖出）`（或 `每 N 场自动卖出（0 为不卖出）`） | 建议 | 两边都有 |
| 14-002 | `modes/xiyou/ui/merchant29_page.gd:328` | `成色照常掷，不保证是极；其余词条照常掷。` | 同句重复两次口语「照常掷」，且成色档位「极」未加直角引号 | `成色随机，不保底「极」；其余词条照常随机抽取。` | 建议 | 天启篇 |
| 14-003 | `modes/xiyou/ui/map_transfer.gd:226, 233` | `确定看详情 / %s，消耗 ` vs `确定查看详情 / ` | 同一提示栏里相邻分支一个写「看详情」、一个写「查看详情」，用词略不统一 | 统一写作 `确定查看详情` | 建议 | 两边都有 |
| 14-004 | `modes/xiyou/ui/map_transfer.gd:350` | `是否传送至 %s?` | 中文问句末尾使用了英文半角问号 `?` | `是否传送至 %s？` | 建议 | 两边都有 |
| 14-005 | `modes/xiyou/ui/map_transfer.gd:207` | `(图片加载中...)` | 占位提示使用了半角括号与英文三点省略号 | `（图片加载中……）` | 建议 | 两边都有 |
| 14-006 | `modes/xiyou/ui/options_scene.gd:28` | `["Battle Camera", "battleCamera", true]` | 设置菜单其余条目均为中文，仅此项直接保留了插件英文原名 `Battle Camera` | `["战斗镜头", "battleCamera", true]`（若为保留原版插件习惯亦可） | 建议 | 两边都有 |
| 14-007 | `modes/xiyou/ui/hang_up_sub_page.gd:114` | `[["Hp恢复开关", "Open"], ["Mp恢复开关", "Open"], ["Hp恢复比例", ...], ["Mp恢复比例", ...]]` | 沿用原版 `XdRs_HangUp` 插件文案，`HP`/`MP` 写为 `Hp`/`Mp`，开关状态写为 `Open`（实际点选不可开关） | 属原版插件既有展示；若统一界面可改为 `HP`/`MP` 及 `开启` | 可不改 | 两边都有 |

> 批 14 复核：本批共核对 `modes/xiyou/ui/` 下中段 21 个非天启篇脚本（含 `hang_up_options.gd`、`intro_anim.gd`、`item_row.gd`、`movie_player.gd`、`mv_canvas.gd`、`mv_text.gd`、`mv_window.gd` 7 个无新增中文文案的底座/辅助脚本）。`help_card.gd`、`growth_help.gd`、`liuying_help.gd`、`graphics_options.gd`、`inlay_book.gd`、`menu.gd`、`notice_options.gd` 文案均规整一致，无错别字或口径冲突。
