# LumenWeave Shaders

[English](README.en.md) 

LumenWeave 是面向 Minecraft Java Edition 的 Iris / OpenGL 光影包,追求自然柔和的日光,清澈水体,具有层次感的天空,以及保留黑暗氛围的彩色人工光照.从轻量前向渲染到高级混合延迟渲染,提供独立可调的性能与画质设置.

## 画面展示

<!-- Add actual in-game screenshots from screenshots/ -->
| 主世界 · 日光与体积云 | 主世界 · 水面与日落 |
| :---: | :---: |
| 截图待补充 | 截图待补充 |
| 下界 · 岩浆与彩色光照 | 末地 · 深紫星云 |
| 截图待补充 | 截图待补充 |

## 主要特性

- 自然日夜光照,柔和阴影,GTAO 和 HDR 色调映射.
- 物理大气查找表,体积云,太阳光束及深度感知重建.
- 彩色体素光照,局部光源空气散射,SSGI,材质 SSR（高级预设）.
- 多尺度水面波浪,水深吸收与散射,反射和折射.
- LabPBR 资源包,植被风场,TAA / 空间抗锯齿,可调辉光.
- 三个原版维度的独立环境风格；Distant Horizons 可选集成.
- 预计算资产,局部环形缓存,自适应采样和时域复用.

## 安装

1. 安装与你的 Minecraft 版本匹配的 Iris,Sodium 和相应模组加载器.
2. 在 [Releases](https://github.com/Iu-yang1/LumenWeave-Shaders/releases) 下载对应游戏版本的光影 ZIP.
3. 将 ZIP 原样放入实例的 `shaderpacks` 目录.若下载 All-Versions 外层合集,先解压并选择一个内层 ZIP.
4. 在游戏中打开「选项 → 视频设置 → 光影包」,选择 LumenWeave 并应用.
5. 建议首次选择 **高（High）**,再根据显卡负载调整.升级时如有旧配置冲突,请重新选择预设.

| 构建文件 | 目标版本 |
| --- | --- |
| `LumenWeave-Shaders-MC-1.20.x.zip` | Minecraft 1.20 系列 |
| `LumenWeave-Shaders-MC-1.21.x.zip` | Minecraft 1.21 系列 |
| `LumenWeave-Shaders-MC-26.x.zip` | Minecraft 26.x（OpenGL） |

暂时不提供 Vulkan 或 OptiFine 支持.

## 画质预设

| 预设 | 主要定位 | 阴影 / 抗锯齿 |
| --- | --- | --- |
| 极低 Potato | 核显,低功耗优先 | 无场景阴影 / FXAA |
| 低 Low | 基础光影,轻量水体 | 1024 硬阴影 / FXAA |
| 中 Medium | 延迟光照,AO,高级水体 | 1024 硬阴影 / TAA + FXAA |
| 高 High | 日常画质与性能平衡,推荐起点 | 2048 软阴影 / TAA + FXAA |
| 超高 Ultra | 大气,体积效果,SSGI,SSR,彩色体素光照 | 2048 软阴影 / TAA |
| 极致 Extreme | 最大默认覆盖范围与体素漫反射 | 4096 软阴影 / TAA |

Ultra / Extreme 分别默认使用 96³ / 128³ 体素网格.自然,自然低曝光,自然高曝光是无场景阴影的色彩对照预设；
