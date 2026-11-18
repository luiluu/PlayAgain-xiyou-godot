# T203 交付单：T202 收尾（D205 不再避 4）

执行者：cc（Sonnet＋medium）｜核查：待审查

## 改动
1. `XTianqiMoney.reload()`、`XTianqiGojoTrial.reload()` 改名 `reload_table()`（全仓无调用处，无需同步）。
2. 删避 4 断言：tests/xiyou_tianqi_gear2.gd（`_no_four` 及 table_no_four）、xiyou_gojo_trials.gd data_nice、xiyou_rift2_canglong.gd no4、xiyou_tianqi_money.gd field_table_no_four；nice_no_four 改成 nice_positive（只查 >0）。
3. `XTianqiMoney.nice()` 去掉 4→5 进位，两位有效数字取整保留；nice_values 预期同步（1449→1400、41000→41000）。
4. 过时注释：tianqi_money.gd 头注与 nice 注释、money_table／rewards／qiyin_dragon 的 `_note` 改为「D205 起不再避 4」。skill_debt.gd:57 与 skill_rework.json:2969/2992 的 `_note`：T192 已合 main，现文字（reload_table()）已是对的，未发现要改的过时处，没动。
5. xiyou_tianqi_sect_b:155 台词检查按卡不动。

## nice() 典型金额 改前→改后
| 输入 | 改前 | 改后 |
|---|---|---|
| 4 | 5 | 4 |
| 14 | 15 | 14 |
| 1449 | 1500 | 1400 |
| 3960 | 5000 | 4000 |
| 41000 | 50000 | 41000 |

## 验证
语法检查 0 问题；专项全过：money 76、gojo_trials 161、gear2 46、rift2_canglong 85、skill_debt 31、rewards 81、qiyin_dragon 91、balance 88、json_cache 106、reforge 16、drop 101、sect_b 76。
