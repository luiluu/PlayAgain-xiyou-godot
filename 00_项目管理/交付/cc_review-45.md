# 交付：cc/review-45
- 状态：可合并
- 车道／工作者：cc（审查）

只含文档，无游戏代码。

## 变更记录草稿

## 2026-11-05 【cc·审查】核查 nezha-raven4、bajie-events6、bailong-ui9、wukong-accept3、bailong-ui8、bailong-ui8b、review-44（审查第 45 期，dev.待定）

- 报告：`核查报告_20261105_审查第45期.md`。P1 0、P2 0、P3 4：raven4 的 setHp「值变了」看的是扣完以后的值，原版看请求值（蛮骨限额用完、0 血 immortal 时原版会 refresh）；raven4 跨行动的清除点比原版少（加减状态、buff、效果回复都会 refresh），到回合末才兜住；events6 回退支同一次得经验连升多级时，原版每级都回到进战斗时缓存的上限，没量；accept3 的 `xiyou_unlock_chain` 强制页只打印、不断言。
- events6 的语法错误正则：扫冻结源全部 355 脚本，命中 52 处全都编译不过，没吞掉真脚本。ui9 的 Q／E 键位对 `party.json` keys 和 YEP_ButtonCommonEvents 的 revert 都对得上。本机复跑 `xiyou_raven_reflect`、`xiyou_raven_battle`、`xiyou_script_census`，都通过。
- 核查覆盖：cc/nezha-raven4（4fd82e99）、cc/bajie-events6（a8e0e6f3）、cc/bailong-ui9（分支 2b5f5321）、cc/wukong-accept3（分支 ee6a9aff）、cc/bailong-ui8（d39ef366）、cc/bailong-ui8b（68dcb984）、cc/review-44（f011b8ab）
- 方法限制：ui9、accept3 开审时还没合，按分支末端核；乙、丙档没跑 Godot。

## 已核／未核清单
已核：全部 7 批。未核：无。合并 ui9、accept3 时如果解冲突改了代码，补看那几处。

## 交接板
- 下一步：P3-1、P3-2 派规则车道（哪吒），在 refseq 探针补「中间夹一次加 buff／效果回血」和蛮骨限额用完两例，再定清除点；P3-4 派 accept 车道（悟空），给 unlock_chain 加 `known_forced` 断言；P3-3 等真要切回原版时再量；review-44 的 `raven.gd:36` 头注释还没改，顺手订正。
- 需要用户决定：无

## 待交叉核查
无（审查线程自己的文档分支）。

## 可优化
- 建议：`_stale_frames.erase(frame)` 是按值删，改成 `pop_back()` 更直白（现在结果正确，不急）。
