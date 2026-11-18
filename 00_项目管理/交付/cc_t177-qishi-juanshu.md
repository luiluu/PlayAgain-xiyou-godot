# 交付：cc/t177-qishi-juanshu

- 车道／工作者：T177 天启篇「天道眷顾者」改「启示眷属」（cc 车道，Sonnet＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-18 【cc·未经审查】天启篇「天道眷顾者」改「启示眷属」（dev.待定）

- 依据：Kyo 11-18 D197「按推荐」；T070 核查 P3-2（18 张图 code=355 的 `$.toaster` ＋ Skills:6162，XTextFix 不扫 code=355）。
- `MVScript._toaster_text` 统一换字：原逻辑挪到 `_toaster_text_raw`，外面套 `_qishi_text`，只在 `XTianqi.active` 时把「天道眷顾者」换成「启示眷属」，西游档原样。开关 `MVScript.QISHI_RENAME`（默认 true，false＝回原版文字）。
- Skills 6162（劫天运备注）：`text_fix/rules.json` 的 `tianqi_dict` 天启篇专用段加一条，不进全局规则；`XTextFix.DICT` 关掉回原貌。
- 天道加持／补偿等别的「天道」文字不动。
- 专项 `tests/xiyou_tianqi_qishi_juanshu`：18 图（Map030/032/033/045/046/047/064/116~120/144~147/155/182）全部页、天启篇档与西游档两侧、开关两侧，78/78。
- 玩家可见：天启篇里原「天道眷顾者」的提示与劫天运说明改称「启示眷属」（文字待小A 审）。

## 交接板

- 下一步：无
- 用户试玩说明：天启篇里「天道眷顾者」一律显示为「启示眷属」，西游档不变。
- 需要用户决定：无

## 进度账

- 无变动

## 优化登记草稿

- O-待定　天启篇「启示眷属」换字：开关 `MVScript.QISHI_RENAME`（true＝换字，false＝原版「天道眷顾者」）；状态：保留（默认接受，Kyo 11-11）。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 21e1141e1 T177 toaster 执行时换字＋tianqi_dict 管 Skills 6162＋专项
- 本次：补 .gd.uid、写交付单
