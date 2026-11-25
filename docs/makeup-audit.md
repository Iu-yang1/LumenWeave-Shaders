# MakeUp Ultra Fast 审计

上游基准为 Javier Garduño 的 MakeUp Ultra Fast 9.6a，固定提交 [65c3ac0](https://github.com/javiergcim/MakeUpUltraFast/tree/65c3ac0818120c97d2b7ad6686b3318f5c14f24e)。仓库的许可证为 [LGPL-3.0](https://github.com/javiergcim/MakeUpUltraFast/blob/65c3ac0818120c97d2b7ad6686b3318f5c14f24e/LICENSE)。上游 README 还请求在使用或修改时署名并尽量附原始链接。P0 参考了管线结构，使用独立编写的着色器。未来如导入具体文件、片段或纹理，先核对对应文件和 Credits，再记录来源、版本、改动和适用的分发条款。

| 上游阶段 | 职责 | LumenWeave P0 的取舍 |
| --- | --- | --- |
| `prepare` 和天空程序 | 生成背景天空和远处雾色 | 由 Iris 基础渲染提供场景 |
| `gbuffers` 和 `shadow` | 世界几何、直接照明、阴影贴图 | 由 Iris 基础渲染提供场景 |
| `deferred` 和半透明程序 | 云、环境遮蔽、水面反射与折射 | 留到后续逐项测量 |
| `composite*` | 曝光历史、辉光、抗锯齿等 | P0 不分配额外的时域缓冲 |
| `final` | 最终色彩处理和屏幕输出 | 读取一次 `colortex0`，提供中性和柔和选项 |

上游通过维度入口和 `common` 目录复用渲染逻辑。P0 共用一对入口文件。后续可在分阶段引入材质、阴影之前保留中性对照，按通道记录帧时间变化。[上游开发文档与缓冲区说明](https://github.com/javiergcim/MakeUpUltraFast/blob/65c3ac0818120c97d2b7ad6686b3318f5c14f24e/ForDevelopers.EN.md)
