# cc/bailong-ui2 交付单（白龙）

状态：**部分完成，未标可合并**（额度用完，任务 2 未开始）

## 做了
- 审查 29 P3-3：`mv_window.gd` 新增 `backdrop_rect()`（内框 grow(-4)），`_draw()` 底色只铺内框；`xiyou_bulk_pills` 加断言 `win.backdrop_inner`。

## 验证
- 语法检查通过；专项 xiyou_bulk_pills、xiyou_window_rects、xiyou_choice_window、xiyou_message、xiyou_item_marks 全部通过。选测名单其余场景未跑。

## 接续
- 任务 2「饿狼输入阶段预排琦玉、读档同步」一点没做：先在冻结正式源 `02_内容与素材/冻结正式源/app.nw/js/codex/runtime/` 里 rg 饿狼相关 install*.js，弄清原版预排与读档同步，再对照重制，规则改动先有 mv_oracle 参照。
- 选测名单剩余未跑：xiyou_actor_advanced、xiyou_actor_warehouse、xiyou_book_capacity_ui、xiyou_change_clothes、xiyou_event_compare、xiyou_hangup_options、xiyou_pet_synth、xiyou_power_books_menu、xiyou_star_warehouse、xiyou_transfer。

## 待交叉核查
- 无核心文件改动。
