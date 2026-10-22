# 交付：codex/module-hooks

- 车道／工作者：框架 · Codex（沙僧）。
- 状态：进行中
- 用户 2026-10-22 插队：第二期2b～2d已经可合并，2e仅原版TP测量WIP保留，先做架构审查13「模块挂接点表」，之后回状态效果第三期往后。
- 基于 main e5e283b；不改主工作区共用登记。独占 damage.gd、新 module_registry.gd、自己的探针／专项、框架约定本节；不改 battle_logic.gd／actor.gd／battler.gd、切片或角色实现。
- 本期：登记表校验、稳定次序、只读上下文、有类型的数值变换与逐次trace；先迁既有orb-sets。以冻结cat-sword原版数值与临时减伤为首个扩展用例，不提前开放178。资源提交与其他宿主挂点保持pending，不能冒充已挂接。
- 哈基米提案在 claude/wukong-hajimi 尚未落盘；交付前读取。原版先测后实现。长任务脱离会话运行；车道只跑相关专项，合并后由唐僧统一全量 --oracle。全部提交待Claude交叉核查。
