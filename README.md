# LumenWeave Shaders

[English](README.en.md)

面向 Minecraft Java Edition 的 Iris/OpenGL 光影包。视觉方向是自然、柔和的光照，目标覆盖 Intel HD 630 至 RTX 4070。

## P5 本地预览

三个原版维度共享线性高动态范围光照，提供轻量前向和标准混合延迟路径。标准路径支持 LabPBR 和屏幕空间水体。提供极低、低、中、高、超高和极致六档预设。极低和低档默认使用快速空间抗锯齿，超高和极致启用实验光照。

1. 运行 `python3 tools/package.py`（Windows 可用 `py -3 tools/package.py`），生成 `dist/LumenWeave-Shaders-P5-Preview.zip`。
2. 将光影 ZIP 放进 Minecraft 实例的 `shaderpacks` 目录，游戏内通过「选项 → 视频设置 → 光影包」启用。
3. 新安装默认使用「高」档，开启阴影、高级水体和 TAA。已有设置会由 Iris 保留，请在光影包设置中重新选择「高」或「极致」以测试完整效果；「自然」保留为早期无阴影对照档。验证环境为 Minecraft 1.21.1、Fabric Loader 0.16.5、Iris 1.8.8、Sodium 0.6.13 和 Java 21。

SSGI 需要开启延迟光照。超高和极致档默认开启独立的 SSGI 时域滤波，用来平滑天空光和日光的间接反弹，可以在光影包设置中单独关闭。体素漫反射还需要开启彩色体素光照。体素网格可独立选择 32³、64³、96³ 或 128³，超高默认 96³，极致默认 128³；高档预选 64³，彩色体素光照默认关闭。该路径需要加载器提供计算着色器、自定义图像、方块发光属性和反向阴影裁剪。

体素分辨率为每方块一格，扩大网格增加相机周围的覆盖范围，传播仍为四轮。三张体素图像分别占用合计 0.625、5、16.875 或 40 MiB，不包含阴影贴图、屏幕缓冲和其他维度缓存。关闭彩色体素光照时不分配这些图像。

下界与末地使用同一套材质、局部光源和时域路径。下界保留生物群系雾色与原版雾距离，末地使用偏紫环境光。根据维度的天空光属性关闭太阳/月亮直射、高光、日光束和云层；极低、低档继续使用原版方块光，超高、极致档可使用彩色体素光照。

Distant Horizons 有独立远景地形和水体路径。开启延迟光照与 TAA 时，地形与水面分别进行历史累积，用深度、法线和表面类型拒绝错误历史。水体采用按像素覆盖范围过滤的多尺度波纹和太阳高光。2.3.2-b 已在 RTX 4070 Laptop 上完成河流远近视图、日出、夜晚和雷雨的后台运行检查。持续移动时的区块加载与 LOD 接缝仍待完整画质验收。

开发检查使用 `python tools/check_shaders.py` 和 `python -m unittest discover -s tests -v`。前者需要安装 `glslang`，也可用 `--compiler` 指定路径。

使用 `python tools/package.py --p0` 生成包含「中性」和「柔和」档的 P0 对照包。`python tools/package.py --voxel-probe` 生成独立体素实验包，屏幕上方的绿条表示合成场景的 GPU 自检通过。

## 自动构建与手动构建

推送到 `main`、提交面向 `main` 的 Pull Request 时，GitHub Actions 的 **Build shader packs** 工作流会执行配置和语言检查、离线 GLSL 编译、数值与工具测试，并打包三个独立的光影 ZIP。也可在仓库 **Actions → Build shader packs → Run workflow** 中选择分支并手动构建。

构建成功后，在该次运行的 **Artifacts** 中下载 `LumenWeave-Shaders-P5-Preview`，解压下载的产物，将其中的 `LumenWeave-Shaders-P5-Preview.zip` 原样放入游戏的 `shaderpacks` 目录。P0 对照包和体素实验包分别提供，产物保留 30 天。

每个包附带 `.zip.sha256` 校验文件，运行摘要记录源码提交及校验值。本地打包同样生成校验文件。光影源码由 Iris 在游戏加载时按显卡编译；Actions 执行离线编译检查和可安装 ZIP 打包，不能代替游戏内 GPU 验证。

当前预览仍有未完成的兼容性与画质验收：Iris 1.8.8 与 Distant Horizons 2.3.2-b 联用时曾记录一次启动阶段的组合渲染通道诊断，首帧影响尚未确认；缓存维度返回首帧、持续 LOD 切换及 Intel/AMD 实机仍待验证。

## 参考项目

P0 源码为独立实现，采用 LGPL-3.0-only。归属与上游出处见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
