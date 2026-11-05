# 交付：cc/nezha-accept-dupkey

- 车道／工作者：工具／哪吒（cc，Opus）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·哪吒·未经审查】同步「同键 N→M 条」进 changeCandidates（dev.待定）

- 总装 11-05 记的工具活：`oracle_additions.compare_file` 原来只在同键新旧各 1 条时才记可接受变化（`change()`），同 id 多条（重号、追加或删掉其中几条）只报问题「既有用例改变、删除或同键追加」，`changeCandidates` 里没有，`生成接受单.py` 接不住，只能手写。
- 现在同键多条整组当一条（新 `group_value`：多条按规范串排序展开成列表），`fields` 记 `*`，`oldDigest`／`newDigest` 取整组；`current_digest` 用同一取法，所以「已在基线」提示与「之后又变了照旧拒收」都照常。同键各 1 条的取法不变（旧接受单照旧对得上）。
- 是否放行仍由接受单决定：这只是让候选出现，不自动接受。
- 自测：`测试增量同步.py` 67／67（新增 `test_same_key_group_change_is_a_change_candidate`：2→3 条进候选、接受后放行、再带同单只提示、3→2 拒收；`test_field_augmentation_matches_every_row_once` 改为期望一条 `*` 候选——它原来钉的正是旧行为）。

## 优化登记草稿

优化登记草稿：无

## 交接板

- 下一步：无。
- 用户试玩说明：无（只改同步工具）。
- 需要用户决定：无。

## 进度账

- 无变化（工具）。

## 验证

- `测试增量同步.py` 67／67；`工具回归.py` 全过（48 秒）；`测试合并工具.py` 256／256；`测试公式程序.py` 通过。不涉及 Godot 工程，未跑 Godot 场景。

## 待交叉核查

- `oracle_additions.py`：整组摘要的排序口径（按 canonical 串排序）是否会让同一组在两次量出时顺序不同而摘要变（groups 是多重集，排序后与出现顺序无关）。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 见 `git log main..cc/nezha-accept-dupkey`
