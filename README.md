# LumenWeave Shaders

面向 Minecraft Java Edition 的 Iris/OpenGL 光影包。视觉方向是自然、柔和的光照，目标覆盖 Intel HD 630 至 RTX 4070。

## P0 预览

P0 只在 Iris 的 `final` 阶段采样场景颜色，保留 Iris 的基础场景渲染。默认 **柔和** 档略微降低饱和度和对比度，**中性** 档原样输出颜色，可用于测量全屏处理的基础开销。后续阶段加入材质、阴影、彩色光照与间接照明。

1. 运行 `python3 tools/package.py`（Windows 可用 `py -3 tools/package.py`），生成 `dist/LumenWeave-Shaders-P0.zip`。也可从 [GitHub Actions](https://github.com/Iu-yang1/LumenWeave-Shaders/actions) 的成功运行中下载产物，解开 Actions 外层压缩包以取得光影 ZIP。
2. 将光影 ZIP 放进 Minecraft 实例的 `shaderpacks` 目录，游戏内通过「选项 → 视频设置 → 光影包」启用。
3. 在光影包设置中切换「中性」和「柔和」。建议先用 [Minecraft 1.21.1、Fabric 与 Iris 1.8.8](https://modrinth.com/version/zsoi0dso) 复现基准。

预览阶段的硬件兼容性和性能按[基准方案](docs/iris-p0-benchmark.md)记录。

## 参考项目

[MakeUp Ultra Fast 审计](docs/makeup-audit.md)记录了 P0 参考的渲染结构及其许可证。P0 源码为独立实现。[Iris 开发文档](https://shaders.properties/current/reference/programs/final/)提供了最终输出通道的接口约定。
