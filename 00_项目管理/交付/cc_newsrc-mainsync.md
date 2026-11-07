# 交付：cc/newsrc-mainsync（集成分支追 main，总装派单 EI）

- 车道／工作者：A 内容·楼层／八戒（cc）
- 状态：做完（集成分支用，由总装快进集成分支，不走合并工具，不标可合并）
- 从 `cc/newsrc-switch` 6caaac78 切出，先合 `cc/bajie-dropseq` d82b98cc（无冲突），再合 github main 75757b4e（合并提交 a146df3a）。

## 冲突解法

| 文件 | 解法 |
| --- | --- |
| `00_设计/优化登记.md` | 两边的行都留。**O-212 撞号**：main 的 O-212 是「按键标已处理」（`XKeyMap.handled`），集成分支的 O-212 是「角色 HP 包装被更早的自有重写遮住」（`XResourceContext.o_actor_hp_wrappers`）。按「O 号以 main 为准」，main 留 O-212；集成那条改成 `O-待定·角色HP包装`，放在其余 O-待定 行前面，等合 main 时发号。同一个号在集成侧引用的地方都跟着改了：`guyu.gd`、`resource_context.gd`、`shield_ledger.gd`、`tests/xiyou_shield_ledger.gd`、`tests/xiyou_xuan_auto.gd`（只改了注释和检查项说明），还有交付单 `cc_rules-newsrc1／3／4／5.md`、`cc_wukong-newsrc9.md`。其余 O-待定 行没动，main 的 O-213～O-220 照原样留。 |
| `03_转换工具/event_presets.json` | 按用例号三方比对：main 相对共同祖先改动了 1104 例（新增），全部已经在集成版里，而且内容逐字相同，没有删除。所以直接取集成版，共 16532 例。 |
| `03_转换工具/xiyou_export.py` | manifest 里两个字段都留：集成的 `mvStringParameters` 和 main 的 `audio96k`。 |
| `03_转换工具/事件祖先预设.py` | `trace_var` 两边的新增都留：先放 main 的 playtime（游戏数据 7/4，以及 122 脚本 `$gameSystem.playtime()`），再放集成的随机门 `_rand`。两者判的是不同的操作数类型（4 和 2），互不影响。 |

## 验证（本工作树，新源 v0.62.12）

- `语法检查.py`：616 个 .gd，0 个问题。
- 用合并后的转换器重跑 generated（演员 161→162，main 新增），然后 `godot --import`，没有报错。
- `xiyou_event_compare` 全量：22491 例，22484 例一致。剩下 7 例原来就登记过，regressions、oracleErrors 都是空的，11/11。**ce9043 现在一致了（nowMatching）**：main 带进了流萤招募，基线里登记的这一例可以在同步时用 `--update-baseline` 去掉。
- 事件空绿扫描 `--check` 过：空绿 93 例，都在基线里。
- 参照 generated/oracle 用的是 funny-wing 树（新源）的，event_states 是 dropseq 那轮的。main 带进来的 event_state_probe 改动（tools81 按地图增量、摘要第 2 版）只换了增量摘要的算法，测量结果不变。集成树同步会按新摘要整份重量一次。

## 本分支提交

- d82b98cc（来自 cc/bajie-dropseq）、a146df3a 合并 main、本交付单
