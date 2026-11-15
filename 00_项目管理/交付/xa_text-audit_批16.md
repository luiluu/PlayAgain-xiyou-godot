# 全库游戏文字审查——批 16（`modes/xiyou/core/*.gd` 核心脚本 1/3）

> 所属总单：[xa_text-audit.md](xa_text-audit.md)
> 范围：`modes/xiyou/core/` 下按文件名排序从 `abyss_merchant.gd` 至 `gear_query.gd` 共 57 个非天启篇核心脚本（其中 38 个含玩家可见文字或正则匹配中文，合计约 556 段）。

| 序号 | 位置 | 原文 | 问题 | 建议改成 | 级别 | 版本 |
| --- | --- | --- | --- | --- | --- | --- |
| 16-001 | `modes/xiyou/core/difficulty_notice.gd:78` | `text = "当前难度：" + (... else "undefined")` | 难度索引越界时向玩家直出 JS 遗留字样 `undefined`（同 13-006、15-001） | 兜底改为 `"未知"`（或 `"未知难度"`） | 建议 | 两边都有 |
| 16-002 | `modes/xiyou/core/dungeon.gd:273` | `"；背包已满，暂存祝福管理"` | 主菜单与对应功能页名为「种族祝福」（`ui/race_menu.gd`），并无名为「祝福管理」的入口，玩家易找不到暂存箱位置 | `"；背包已满，已暂存至种族祝福"`（或 `"；背包已满，可在种族祝福中领取"`） | 建议 | 两边都有 |
| 16-003 | `modes/xiyou/core/garou.gd:535-544` | `"专属:饿狼；法宝形态:%s；等级上限:%d"` 等十行 `RELIC_HELP` 说明 | 源自原版 `CodexGarou` 的十行法宝说明全部使用英文半角冒号 `:`，直接送入说明卡渲染后与全库 `成长：`、`冷却时间：`、`品质：` 全角冒号不统一 | 将十行说明的半角冒号统一改为全角 `：`（如 `"专属：饿狼；法宝形态：%s；等级上限：%d"`） | 建议 | 两边都有 |
| 16-004 | `modes/xiyou/core/change_clothes.gd:98` | `return "获得途径:" + ...` | 换装界面「获得途径」标签使用了英文半角冒号 `:`，与其余界面全角冒号 `：` 不统一 | `return "获得途径：" + ...` | 建议 | 两边都有 |
| 16-005 | `modes/xiyou/core/fabao_feed.gd:54, 60` | `"不能喂"` / `"商店买的不能喂"` | 过分口语化，且与同文件 L113、L120「喂入」用词不统一 | `"无法喂入"` / `"商店购买的装备无法喂入"` | 建议 | 两边都有 |
| 16-006 | `modes/xiyou/core/achievement.gd:127` | `"%d年%d月%d日 %d:%d:%d"` | 成就解锁时间戳未对时分秒补零，玩家面板会显示如 `6:5:3` 的不齐整时间 | `"%d年%d月%d日 %02d:%02d:%02d"` | 建议 | 两边都有 |
| 16-007 | `modes/xiyou/core/demon_crown.gd:34-37, 190, 193, 204, 227` | `NAME := "\"头顶\""` / `DROP_TEXT := "获得了\"头顶\"！"` / `"\"头顶\"成长记录..."` | 沿用原版 `Armors.json` #7940 的字面命名 `"头顶"`，导致新写提示语带英文直引号 `""`，与全库直角引号 `「」` 口径略异 | 若需严格对齐原版物品字面名可不改；若统一引号风格可改为 `获得了「头顶」！`（提示外层不用直引号） | 可不改 | 两边都有 |

> 批 16 复核：本批共核对 `modes/xiyou/core/` 下前段 57 个非天启篇脚本（含 `abyss_merchant.gd`、`achievement.gd`、`affix_absorb.gd`、`affix_rate.gd`、`alien_battle.gd`、`alienation.gd`、`black_flash.gd`、`bonds.gd`、`boss_status.gd`、`bulk_pills.gd`、`canglong.gd`、`casino_batch.gd`、`cat.gd`、`difficulty_notice.gd`、`dungeon.gd`、`fabao_feed.gd`、`fest.gd`、`fest_text.gd`、`garou.gd`、`gear_query.gd` 等）。`abyss_merchant.gd`、`alienation.gd`、`affix_rate.gd`、`fest_text.gd`、`gear_query.gd` 口径规范（货币已统一为战利品点／精魂，装备状态均作「未装备」，概率均作「概率」）；`actor.gd`、`auto_save.gd`、`battle_common_event.gd`、`data_file.gd` 中的报错均为开发者控制台 `push_error`/`push_warning`，不计入玩家可见文字。
