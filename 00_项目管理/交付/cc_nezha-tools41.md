# 交付：cc/nezha-tools41

- 车道／工作者：工具／哪吒（cc），总装十二派单，从 main 5692e099 切出
- 状态：可合并
- 范围：并行测试开跑前比对 generated/；选测 xstate_fields 认存档行写法；审查第 19 期 P3④ 两处注释。

## 变更记录草稿

## 2026-11-01 【cc·哪吒·未经审查】并行测试比对 generated/、选测认存档行写法、改两处注释（dev.待定）

1. **并行测试开跑前比对 generated/**（`参照批次.py compare`，`并行测试.py` 的 `stale_generated`）：只在 worktree 里查。两边切片指纹相同而 manifest 产物清单有差异，或本树没自己同步过、主工作区参照比本树新，就打印差异项并退出 2，提示先 `git merge main` 再 `--补齐`，不跑出假失败（审查第 20 期 yunshang_shop 挂在 HD 图标的情形）。车道改了切片／自己同步过的不拦。**回退**：`--skip-generated-check` 或 `XIYOU_SKIP_GENERATED_CHECK=1` 跳过；彻底去掉就删 `并行测试.py` 里 `stale_generated` 调用那四行。没做自动补齐开关（补齐要分支名、会跑转换器与导入，不宜藏在测试里）。
2. **选测 xstate_fields**（`选测对照.json`）：onlyLines 另认 `a[str(id)]["k"] = …`、`var m := XFoo.to_save(x2)`、`XFoo.from_save(x2, …)`、`if not x2.f.is_empty() [or …]:` 四种行。**回退**：把 onlyLines 改回提交前版本（git revert 该文件）。
3. **注释**（只改注释）：`actor_modules.gd` 云裳指令栏的理由改成「原版直接包 addSkillCommands，固定 [2,1,5]」；`actor.gd` param 链与云裳节的模块编号统一按 modules.json 从 1 数（米拉 2、宿傩 18、小猫 20、云裳 31、异化 33、谷雨 38、种族 53，取自审查报告对冻结 v0.28 的核对；本机找不到冻结 modules.json 副本，我没有自己再核）。

## 优化登记草稿

无。

## 验证

- 先红后绿：测试参照批次 17/17（新增 4 个 compare 用例＋1 个接线）、测试选测 65/65（新增存档行用例，含「塞别的逻辑仍退回 game」）。
- 测试合并工具 243/243、测试增量同步、测试角色同步提速、测试提交守卫 全 OK；语法检查通过。
- 实机：在本 worktree 把 manifest 的一个产物哈希改掉，并行测试打印「落后主工作区（db/Actors.json）」并停下；还原后 xiyou_save_page 通过。

## 交接板

- 下一步：无。需要用户决定：无。

## 进度账

- 工具：不记。

## 可优化（流程／工具／效率）

- 总装可顺手核一下 modules.json 序号（我没有冻结副本可对）。

## 待交叉核查

- 工具：`参照批次.py compare`、`并行测试.py` 接线、`选测对照.json` onlyLines 正则（注意别放过逻辑行）；`actor.gd`／`actor_modules.gd` 只改了注释。
