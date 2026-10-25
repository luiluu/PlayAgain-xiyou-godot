# 交付：codex/passive-content-power-books

- 车道／工作者：规则／沙僧（Codex，重制_沙僧_70）
- 状态：进行中（参照阶段，尚未修改Godot运行时）
- 基线：1132e919；前期stateOrigin最终b91b1a14、特殊react最终1132e919均独立可合并待Claude，不重跑旧验收。

## 本小期范围

- 权能五本1654／1656／1674／1683／1718：学习上限、普通遗忘保护、专用付费遗忘入口、静态效果。先原版宿主冒烟与矩阵，不能只读代码改规则。
- 已定位冻结源installNativeHonghuangRuntime.js 80～123：CodexHonghuang.powerClass优先CodexZones，超强3／强4／弱6；Game_Actor.learnSkill、forgetSkill与Game_Action.testItemEffect／itemEffectLearnSkill共同守卫。专用forgetLearnedPower消费3044遗忘符，不返书。新局free迁移名单为空；不移植MV旧档整理。
- 普通被动248效果与90科技静态链已交，不重做。旧首轮343参照因权能无法普通遗忘而污染，本期每例newGame，独立文件不覆盖旧证据。
- 尚未设计／修改actor.gd、道具使用或UI入口。容量满变量9返书／预约1317、PREE／ASUP、WPNM／SkEType、race-battle仍按后续顺序。
- 共享登记只读，保留所有.sandbox／generated和工作树；全部提交待Claude，不自销核、不自评完成度。

## 可优化

- 已做：每例新局隔离权能污染；先验证学会→普通遗忘被拒→缺符失败→付费遗忘的真实宿主链，再扩容量矩阵，避免重复大采样。

- 原版冒烟五本5／5 errors空（2b43a6bb9e78467889c6959d43f8861c）。已逐项核对学会、重复不可用、普通遗忘被拒、缺3044失败、付费遗忘成功且消费1枚；每例fresh newGame，无前期污染。下一步扩真实类别学习上限三组，不添加合成第六本来伪称弱者容量触顶已验。
