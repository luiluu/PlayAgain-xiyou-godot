# cc/bailong-ui2 交付单（白龙）

状态：**可合并**（P3-3 完成；饿狼任务另立 cc/bailong-ui3）

## 做了
- 审查 29 P3-3：`mv_window.gd` 新增 `backdrop_rect()`（内框 grow(-4)），`_draw()` 底色只铺内框；`xiyou_bulk_pills` 加断言 `win.backdrop_inner`。

## 验证
- 语法检查通过；专项 xiyou_bulk_pills、xiyou_window_rects、xiyou_choice_window、xiyou_message、xiyou_item_marks 全部通过。选测名单剩余 10 个（actor_advanced、actor_warehouse、book_capacity_ui、change_clothes、event_compare、hangup_options、pet_synth、power_books_menu、star_warehouse、transfer）11-03 已跑，全部通过。

## 接续
- 饿狼任务转 `cc/bailong-ui3` 交付单，本分支无接续。

## 待交叉核查
- 无核心文件改动。
