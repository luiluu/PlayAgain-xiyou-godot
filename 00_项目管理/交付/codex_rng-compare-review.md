# 交付：codex/rng-compare-review

- 车道／工作者：规则核查／沙僧（Codex，重制_沙僧_62）
- 状态：进行中；基线2g026f6ee3，依赖四零散→2g；只用已有state-effects-2b树，共用登记只读。
- 范围：复核敌群事件other_状态44放宽、军团676～693／739两类随机比较豁免，以及recover_all保留Permanent。没有新功能或随机数框架改造。
- 初读发现：状态44已有第1回合末严格有无／回合数断言，末态只在Godot确实走完第2回合时容许44到期；不是任意忽略。recover_all已调用clear_states，后者保留Permanent，先补边界证据再判断是否需改生产。
- 军团旧测试保留五种种子；拟另加原版Math.random=0.5等价的测试专用本场流与单轮场景，试恢复被略过的行动者集合和命中附伤比较。流只注入测试，不改游戏侧分布、存档或真实玩家数据；发现额外差异先分析，不放宽参照。
- 未完成前不可报可合并；自己的改动待Claude核查。旧证据/.sandbox/generated及整树保留。

- 新半值场景首测2951/2951，包含恢复军团行动者集合与命中附伤比较，没有新豁免。原五种种子场景保留，最终还要回归。Permanent原版四例（actor/enemy×clearStates/recoverAll）errors为空；保留686及5回合、清普通状态2，TP37和buff／剩余回合原样，recoverAll才回满HP／MP。stdin首测因原版插件依赖主脚本filename启动失败，改用实体脚本后4例通过；不是游戏失败。下一步补对应Godot对照。
