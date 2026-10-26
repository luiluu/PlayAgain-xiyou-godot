# 交付：codex/passive-content-book-capacity

- 车道／工作者：规则／沙僧（Codex，重制_沙僧_72）
- 状态：进行中
- 基线：34184d36；同树接续，权能五本上一期已独立交付，不重做。

## 本小期范围

- 容量满变量9返书／预约1317：先实采真实物品入口、未满／满额／重复／取消／缺书，以及普通容量与权能类别限额的关系，再设计接线。
- 已定位冻结源 rpg_οbjects.js 的 itemEffectLearnSkill：仅技能类型5受变量9约束，按队伍选定角色的 skills() 数量判断；满额 gainItem(this.item(),1) 与预约1317，否则学习。权能实际为类型4，另有先行类别守卫。公共事件1317仅提示。
- 开工工作区干净，HEAD34184d36；新分支名未占用，已从该点切出。额度五小时84%、周13%。共用登记只读；所有提交待Claude，不自销核、不自评完成度。
- 正在准备独立冒烟与小矩阵，尚未运行，不称已掌握实际结果或可合并。长任务只占共用四槽；保留全部.sandbox／失败／generated／工作树。

## 交接板

- 下一步：有效冒烟后跑独立小矩阵，核完整链后实施；后续PREE／ASUP不混本期。
- 需要用户决定：无。

## 进度账

- 由Claude合并与交叉核查时登记，不自评。

## 可优化

- 无新增；沿用上一期共用槽公平性建议，不动工具车道。

## 冒烟与首轮矩阵

- 原版5例冒烟与17例首轮矩阵均errors空，源指纹一致；满额仍canUse=true，实际先扣再返1本、预约1317，回地图解释器清槽后提示；重复与取消／缺书无变化。直接learnSkill不受变量9约束，所以上限挂点不能放actor.learn_skill。
- 选定角色与效果目标不一致时，原版以选定角色计数并提示其名字，学习仍给效果目标；准备保留该语义。权能类型4与普通主动书不受变量9限制。
- 首轮17中power.class-full实际是已学权能的重复拒绝，不能称权能满额实采；保留原件book_capacity_initial17.json，修正命名并追加角色1四本后第五本的真实类别满额，后续以18例为准。
- 设计：独立XPassiveBooks接效果43，仅类型5在物品效果层检查正式选定角色的skills()，满额返当前物品并预约共享单槽1317；不改actor学习。UI记录本次选定角色、消费顺序与预约回地图，公共事件1317按原脚本翻译提示。不碰mv_event_core／formula_execution。

## 重制接线与当前验证

- 新XPassiveBooks仅在物品效果43处理类型5容量，使用选定角色的skills()计数；不限制直接actor.learn_skill。物品页消费顺序改为先扣再效果返还，_after_use检查现有共享预约槽；CE1317在MVScript按真实完整脚本翻译。不改mv_event_core或formula_execution，未改切片／generated。
- 18例修正参照唯一ID且errors空，新增真实角色1四本后第五本权能拒绝；fixture保留源runtimeInputs。Godot专项898/898通过（task7bf2744c22b94bb6936e940d0ef28010），导入taskb4988aa0643c41ebb050f111dba5b58b无Script／Parse／Compile错误。
- 首轮专项EventHost误用RefCounted而解释器要求Node，留下Parse Error，已保存godot原日志并只停本车道已知无效子进程32604；改成Node后专项通过，失败日志全保留。
- 当前仍进行中：直接依赖回归与界面成对图／实际读数尚未完成，不称可合并。item_target_actor_id为会话内物品选人上下文，每次物品使用重设，未增加存档迁移。
