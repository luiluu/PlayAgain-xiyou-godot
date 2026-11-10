# 交付：cc/review-74
- 状态：可合并
- 车道／工作者：cc（审查，GH6）

只有文档，没有游戏代码。分支从本地 main 6bc1af07 切，在 scratchpad 的 clone 里做，推回本库后删 clone。

## 变更记录草稿

## 2026-11-10 【cc·审查】核查 dev.421 这批与 merge18 接受单（审查第 74 期）

- 核查覆盖：cc/bajie-interp8、cc/events-seg-a5
- 报告：`核查报告_20261110_审查第74期.md`。P1 0、P2 2、P3 3。
  - P2-1：合并工具不给草稿表首格写「O-待定·名字」的行发号，interp8 的参照宿主中文路径读文件没进优化登记。
  - P2-2：seg-a5 的 `事件预设脚本/nb.py` 模块名「nb」撞上 guide_probe.cjs 正文子串，选测只读工具入口链撑大，merge18e 收工检查红在 test_real_repo_read_only_set。
  - P3-1：hboot 补丁不发 onload，onError 插件那段报错摘录在参照里缺（不进测量）。
  - P3-2：interp8 交付单说 event_states 不用接受单不准，车道该对 main 的已发布参照生成接受单。
  - P3-3：--accept-changes 相对路径按当前目录解析，merge18c 秒退。

## 已核／未核清单
已核：甲 cc/bajie-interp8（细核）、丙 cc/events-seg-a5、总装 merge18c～e 接受单 15 条。
未核：待核查.py 里 11-05～11-08 其余乙丙档 21 批（不在本期派单）。

## 交接板
- 下一步：P2-2 先处理才能让 merge18 收口推 github/main（最快是事件车道改脚本名，根治是工具车道改 pipeline_files 匹配）；P2-1 总装补 O 号、换占位，工具车道补发号；P3 不急，随下一期工具／事件车道做。
- 需要用户决定：无

## 待交叉核查
无（审查线程自己的文档分支）。

## 优化登记草稿

优化登记草稿：无

## 可优化
- `选测.pipeline_files` 用子串找模块名，短名脚本很容易误连；建议统一按词边界匹配（见 P2-2），归工具车道。
