# 交付：claude/bajie-orb-shop

- 车道／工作者：B 界面·宝珠坊／八戒（Claude，重制_八戒_10）
- 状态：进行中（开工；预分配 O-042～O-044）
- 入口：正式版宝珠坊只从主菜单「宝珠坊」进（installNativeOrbRuntime 给 Window_MenuCommand 加 codexOrbs → CodexOrbs.open），不在任何地图事件里，所以入口在本车道（menu.gd）。神秘珠掉落挂在 CodexEconomy.bossReward（副本 Boss 胜利奖励），宝珠残片的随机数在公共事件 1439（肝帝积分券）第 42 行用 CodexOrbs.rollInt('fragment',1,2)——这两处属悟空的副本/公共事件，本车道只提供 XOrbs 的接口，不接线。

## 变更记录草稿

（进行中）

## 交接板

（进行中）

## 进度账

（进行中）

## 本分支提交

（进行中）
