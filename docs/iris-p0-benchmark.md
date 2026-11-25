# Iris P0 基准

基准组合为 Minecraft Java 1.21.1、Fabric、Iris 1.8.8、Sodium 0.6.13、Java 21。记录操作系统、显卡驱动、CPU、内存及 Fabric Loader 版本。使用默认资源包，关闭垂直同步和帧率上限，渲染距离 8 区块、模拟距离 5 区块，视野 70，云关闭，实体距离 100%，亮度 50%。Intel HD 630 与 RTX 4070 都先跑 1920×1080。HD 630 可补测 1280×720，RTX 4070 可补测 2560×1440。

创建超平坦创造模式世界，种子 `854361`，使用默认超平坦预设。给草地昼景与夜景使用相同视角。

```mcfunction
/gamerule doDaylightCycle false
/gamerule doWeatherCycle false
/gamerule doMobSpawning false
/weather clear
/tp @s 0.5 -60 0.5 0 20
```

| 场景 | 设置 |
| --- | --- |
| 昼景 | `/time set 6000` |
| 夜景 | `/time set 18000`，并执行 `/setblock 0 -60 8 minecraft:torch` 和 `/setblock 2 -60 8 minecraft:soul_torch`。在昼景复跑前清除这两支火把。 |

逐场景切换 **Iris 光影关闭 → 中性 → 柔和**。每次切换后等待 30 秒，待区块绘制和帧时间稳定后采样 60 秒，重复三次。使用同一帧时间采集方式，按次记录帧时间中位数、P95、P99（ms）与截图，注明工具和版本。以每组的三次结果中位数比较。中性与关闭的差值包含 Iris 启用光影管线的开销。柔和与中性的差值用于观察调色开销。

实机冒烟时在主世界、下界和末地检查首帧、切换光影后的画面、粒子、透明材质及光影重载。中性档应正常显示，柔和档应只有轻微调色。记录游戏日志中的着色器报错。本文件是测试规程，实测数值待采集。
