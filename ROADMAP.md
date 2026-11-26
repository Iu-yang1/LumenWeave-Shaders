# LumenWeave 仓库计划与当前进度

更新日期：2026-11-26。以当前源码、已归档构建和实际测试记录为依据。

## 1. 产品目标与当前定位

建立自然、柔和且具备物理依据的 Minecraft 光影系统，共享统一的色彩、材质和光源标定，支持从轻量前向到高级间接光照的配置组合。当前主线为 OpenGL / Iris；Vulkan 作为并行研究线，不阻塞传统光影包开发。

当前交付物是 **P5 Preview 开发预览**。包名中的 P5 表示已进入跨阶段集成和验收工作，不表示原始 P0–P5 总纲全部完成，也不表示已经达到 V1.0 稳定版标准。各阶段有交叉开发，不用一个缺少依据的完成百分比代替实际状态。

- 当前运行验证组合：Minecraft 1.21.1、Fabric Loader 0.16.5、Iris 1.8.8、Sodium 0.6.13、Java 21。
- 实测显卡：RTX 4070 Laptop；HD 630、AMD 和 Intel 独显仍是待验证硬件。
- 开发源码独立实现；MakeUp 为固定版本的管线参考，BSL 和 Complementary 为视觉及菜单组织参考，未导入其受限源码。
- 远程保留源码、根目录说明、测试和构建工作流；本机过程记录、完整实验日志及 ZIP 不放入 Git。

状态含义：“已实现”指代码已接入；“已验证”仅限明确列出的环境和场景；“待验收”表示实现存在但尚未满足完整交付标准；“待开发”表示没有可交付实现。

## 2. 主线里程碑

| 阶段 | 目标 | 当前进度 | 余项与完成标准 |
| --- | --- | --- | --- |
| P0 工程基线 | 参考审计、许可证、运行组合、工具链、最小光影、计算和体素可行性 | 基线包、独立体素实验、固定参考与许可记录、离线编译和游戏测试工具已建立；Iris 与 Vulkan 兼容层均做过有限原型实验 | 更换运行组合或引入外部代码时重新核查；已有 Vulkan 实验不能视为完整后端 |
| P1 自然物理视觉 | 线性光照、材质默认值、PBR、天空、曝光和显示变换 | 已实现纹理解码、线性 HDR、日月及环境光、原版材质属性、BRDF、色调映射和色彩控制；有数值与固定场景验证 | 继续统一日夜、洞穴、日出日落和天气的视觉标定；现有解析天空不等于完整物理大气模型 |
| P2 低配路径 | Lite、少附件、简化天空/阴影/水体、编译裁剪 | Potato/Low 前向路径、空间 AA、简化水体、低成本波浪和功能资源裁剪已实现；已有附件与关闭功能的资源检查 | HD 630/UHD 630 实机帧时间、显存带宽、多场景旧新版本配对基准未完成 |
| P3 标准渲染 | 混合延迟、基础 PBR、LabPBR、GTAO、SSR、软阴影、水体、TAA和体积效果 | 主体已接入，有离线、GPU 数值与后台游戏检查；水体和后期菜单已扩展 | SSR 仍以水体为主；继续补充一般材质反射、水下焦散、物理大气、云影和更完整的云模型，验收动态边缘及材质覆盖 |
| P4 高级光照 | 体素化、RGB 注入与传播、遮挡、缓存、SSGI、Voxel GI及融合 | 已实现阴影几何注入、四轮传播、32³–128³、体素漫反射、SSGI、历史拒绝与空间重建；验证混色、墙体、光源删除和相机移动 | 实体、非完整方块、透明体及未提交几何覆盖仍需扩展；增量/脏区更新、分级体素和更高阶传播尚未完成 |
| P5 V1.0 验收 | 三维度、预设、DH、跨 GPU、稳定性、双语说明和发布 | 三维度目录、六档预设、中英文菜单、自动/手动 Actions、可复现 ZIP 和校验文件已建立；RTX 后台集成检查已开展 | Intel/AMD、完整场景矩阵、持续 LOD 过渡、缓存维度返回首帧与正式稳定版发布验收尚未完成 |

## 3. 功能与工程任务清单

### 光照、材质与环境

- [x] sRGB 解码、线性 HDR、曝光、统一显示变换和色卡数值测试。
- [x] 原版方块默认材质、GGX/基础 PBR、LabPBR 法线和材质信息接入。
- [x] 日光/月光、环境光、方块光和维度环境强度配置。
- [x] 阴影图、过滤、GTAO、基础体积光和有限云层步进。
- [ ] 日夜、森林、洞穴、室内与雨雪天气的完整视觉标定。
- [ ] 更完整的 Rayleigh/Mie 大气、透射率及多次散射近似。
- [ ] 可扩展的云层质量、云影、时域重建和天气联动。
- [ ] 材质次表面散射、可选孔隙度及更完整的发光材质覆盖。

### 水体与反射

- [x] 原生水面不再继承原版水纹与 alpha；玻璃保持独立材质处理。
- [x] 多尺度法线波浪、像素覆盖和时间过滤、粗糙度控制。
- [x] Fresnel、分通道吸收、深度透射、散射、折射和水面 SSR。
- [x] 水下雾与天空散射颜色一致；修正水下透过水面观察空气时的光程。
- [x] 群系水色影响、密度、浑浊度、波浪和反射步数菜单。
- [ ] 水下焦散、地表湿润和可选雨滴效果。
- [ ] 屏幕空间反射缺失、岸线/瀑布/侧面水体的连续画质验收。
- [ ] DH 水体的深度光学与近远景一致性；目前仍采用远景近似。

### 植被、时间域与后期

- [x] 叶片、草、花卉和作物共用风场，地形与阴影同步变形。
- [x] 固定草根、双高植物接缝连续、风速/强度/距离控制。
- [x] AA 关闭、空间 AA、TAA、TAA 加空间 AA 四模式。
- [x] 深度、法线和表面分类历史拒绝；SSGI 独立时域滤波。
- [x] 相机动态模糊、HDR 辉光、锐化、饱和度、对比度和白平衡。
- [x] 19 个子菜单、51 个实际解析选项；个人效果独立于画质预设。
- [ ] 独立实体和物体运动矢量；目前动态模糊只反映相机运动。
- [ ] 高速转向、遮挡显露、方块变化、天气突变和返回维度首帧的完整历史验收。
- [ ] 按实际需求增加景深等可选镜头效果；不强制绑定画质等级。
- [ ] 法线、材质、间接光照、体素、SSR 和历史状态的完整调试视图。

### 低配性能与资源

- [x] 六档预设共享算法，编译期裁剪与程序开关控制资源。
- [x] 无需体素时不声明三个体素图像；关闭辉光后释放独立附件。
- [x] 辉光使用四分之一宽高；SSGI 有可选半分辨率路径。
- [x] 非植被顶点跳过风场变换；水体跳过普通材质着色。
- [x] 低档减少波浪层数和滤波成本；阴影及 AO 预算可调。
- [ ] 相同世界、相机、天气、资源和配置的版本配对基准。
- [ ] 补齐 GPU/CPU 帧时间、P95/P99、1% low 与实际资源占用。
- [ ] HD 630、AMD、Intel 独显驱动和功能组合验证。
- [ ] 在 profiling 支持下推进增量体素、带宽和全屏通道优化。

### 集成与发布

- [x] 主世界、下界、末地分别使用入口目录，共享通道算法。
- [x] DH 地形/水体入口及分类历史；已有三维度往返检查。
- [x] 静音隔离桌面、复制存档、隐藏 GPU 数值测试和读回工具。
- [x] 主分支推送、面向主分支的 PR、手动触发三种构建入口。
- [x] Include、配置、语言、能力、调度、编译、单测及 ZIP/许可证检查。
- [x] 三类独立 ZIP、SHA-256、跨平台固定打包元数据。
- [ ] 完整场景回归矩阵、跨硬件数据和已知问题逐项关闭。
- [ ] 有对应源码、兼容范围、说明和校验值的 V1.0 正式 Release。

## 4. 当前代码组织

| 路径 | 职责 |
| --- | --- |
| `shaders/world0/`、`world-1/`、`world1/` | 每个维度的 Iris 程序入口，各 43 个阶段文件 |
| `shaders/programs/shared/` | 共享计算、几何、延迟、合成与最终输出阶段 |
| `shaders/programs/p1/`、`p5/` | 原生场景与 DH 的公共几何实现 |
| `shaders/lib/dimensions/` | 主世界、下界、末地的环境光差异 |
| `shaders/lib/lighting/`、`materials/` | BRDF、直接光、AO、SSGI 和材质解码 |
| `shaders/lib/voxel/`、`temporal/` | 体素注入/传播/采样与时域重投影 |
| `shaders/lib/water/`、`vegetation/`、`post/` | 水光学、风场及显示调节 |
| `shaders/shaders.properties`、`lang/` | 画质预设、分层菜单、能力开关与双语文本 |
| `tools/`、`tests/`、`experiments/` | 编译/打包、数值与工具测试、独立实验 |
| `.github/workflows/iris-preview.yml` | 自动和手动构建、检查与三类产物上传 |

## 5. 当前验证进度

截至 2026-11-25 的本地记录：

| 验证层 | 已完成范围 | 解释边界 |
| --- | --- | --- |
| 离线 | 2,134 个程序组合，384 个能力配置，84 个调度组合 | 最后 Lite 水下光程修正另补跑 90 个水体程序 |
| 单元测试 | 14 项：色彩、菜单、维度入口、预设及体素数值 | 不能代替实际游戏画质 |
| 隐藏 GPU 数值测试 | 体素、SSGI、TAA、阴影、水波、风场、维度光照及空间 AA | RTX 4070 Laptop，不能外推其他显卡 |
| 后台游戏 | 本轮 33 次附件读回均 GL error=0；覆盖 AA 切换、资源释放、三维度/DH、水体与相机运动 | 迭代使用三个候选哈希，最终修正另做 Low 水体复测，并非全部使用同一 ZIP |
| 资源检查 | 960×540 时辉光开启为 240×135；关闭后无独立辉光附件 | 实测证明该功能的资源开关，不代表所有组合已验收 |
| 静态审查 | aislop 96/100、零错误、三个格式/文件体积警告 | PMD 未安装；不声称全部 Java 静态分析已覆盖 |

最近可复现预览 ZIP 的 SHA-256 为：

`1E806ED6D8BC6CB8C3F50724C1854CFBD2EE557E07801412F82108E7FF93E2CE`

已有记录中，Iris/DH 曾出现启动期合并渲染通道诊断，首帧影响尚未确认。本轮还有一次 Modrinth 联网超时，后续场景和读回完成。日志有错误记录与 GPU 读回无 GL 错误是不同结论。

## 6. 下一步执行顺序与验收条件

1. **水体与画质收敛**：固定浅河、深水、岸线、瀑布、水下和夜间机位，检查颜色、底部透射、反射缺失及波浪闪烁；以同场景截图和用户反馈调整默认参数。
2. **时域与 DH 稳定性**：覆盖高速移动/旋转、区块加载、持续 LOD 过渡、方块放置破坏和维度往返首帧；保留连续帧证据，区分静态采样与运动画质。
3. **低配性能**：先完成统一配置的新旧版本配对与逐通道计时，再安排 HD 630/AMD/Intel 实机；没有设备时继续可执行的代码优化并明确未验收项。
4. **补齐 Standard/Advanced**：优先一般材质反射、焦散、物理大气和云影等有明确视觉收益的功能；为每项建立关闭/开启对照和资源预算。
5. **Beta 与 V1.0**：按场景、画质、维度、硬件交叉矩阵收敛已知问题，再形成可复现正式发布；版本号和日期由验收结果决定。

完整场景矩阵包括平原、森林、日出、日落、夜晚、海洋、河流、水下、洞穴、村庄、彩色光源室、间接光照测试室、PBR 材质、雨天、雷暴、下界、末地、高速飞行、方块变化、区块加载/卸载、重载、尺寸变化和 DH。

性能目标保留总纲中的 1080p、固定 8–12 区块配置口径：Potato 30 FPS、Low 45 FPS、Medium/High/Ultra 60 FPS、Extreme 90 FPS。这些是工程目标，尚非对应硬件的已验证结果；正式配对比较必须固定同一个渲染距离。

## 7. Vulkan 并行研究线

以下状态依据 2026-11-25 的本地研究记录，不代表对外部项目最新状态的持续保证。

| 阶段 | 目标与状态 |
| --- | --- |
| VK-P0 可行性 | 已做接口研究和有限 Vitrail 计算/图像/SSBO 原型。兼容层实验显示传统预览缺少可用场景色，不能称为完整 Vulkan 光影 |
| VK-P1 公共算法原型 | 下一步验证显式地形和场景色生产、半透明顺序与资源重建；尚无正式可交付后端 |
| VK-P2 光栅化与 Compute | 待建立完整场景输入、同步及资源生命周期 |
| VK-P3 加速结构与 Ray Query | 待验证宿主实际提供的几何、设备能力和命令接口，再实现 BLAS/TLAS |
| VK-P4 混合光追 | 待开发 RT 阴影、反射、AO 与 GI |
| VK-P5 降噪与重建 | 待建立光追结果、运动信息和可信历史，再实现时空降噪 |
| VK-P6 高级算法与超分 | 研究 DLSS/FSR/XeSS、ReSTIR、DDGI 的接口、许可证和实际收益；均未实现 |
| VK-P7 路径追踪 | 长期实验事项，不纳入当前 V1.0 功能承诺 |

能力按实际设备与宿主接口判断，不按品牌限制。保持 OpenGL、Vulkan 与画质等级解耦，不为 Vulkan 研究重写整个客户端或阻塞现有光影交付。

## 8. 构建、发布与工作约束

本地执行 `python tools/check_shaders.py`、`python -m unittest discover -s tests -v`，再使用 `python tools/package.py`、`--p0`、`--voxel-probe` 分别打包。GitHub Actions 自动执行对应检查，也保留手动触发入口。

Actions 生成可安装 ZIP，运行时仍由 Iris 针对实际 GPU 编译。每次交付应记录源码提交、ZIP 摘要、运行组合、覆盖场景和已知问题。推送主分支不自动等同于发布稳定版。

持续遵守：UTF-8 无 BOM、Git 提交签名、不提交本地日志和工具、不复制受限参考源码。游戏测试使用静音隔离桌面和存档副本，保持用户前台可用；安装与缓存优先放在 H 盘。

## Natural Rendering V2 (candidate)

- Correct water-to-air Snell direction and preserve sky radiance before water fog; screen-space reflection/refraction remains an approximation, including DH.
- Fix neighbor UV reprojection, tighten distant history normal rejection, fade unresolved water waves, and tune sun/ambient balance and shadow bias.
- Add optional-density analytical height-dependent aerial perspective, shared by native terrain and DH. Lite uses midpoint density; standard uses an exponential-height integral. No extra textures or passes. Existing volume effects remain separate.
- Night sky uses the existing star geometry and a broad sky band. No SEUS PTGI source imported.
- Medium uses 8 SSR steps; High through Extreme retain 16. Actual frame-time and runtime visual acceptance are pending.
- Research reference: [Hillaire, EGSR 2020](https://sebh.github.io/publications/egsr2020.pdf) and [AtmosphereRenderer](https://github.com/AirGuanZ/AtmosphereRenderer) (MIT). Future LUT work is separate from this analytic implementation; no upstream code or paper PDF copied.

### Natural V2.1 — runtime feedback follow-up (candidate)
- Ultra/Extreme user reports whole-image and distant jitter. Move volume composition before TAA, use a stable angular ray, keep geometry depth reconstruction projection-specific, avoid contaminating sky history with foreground depth. This is a source-level hypothesis pending replay.
- Volume uses a four-depth comparison (or hardware PCF) instead of per-step blocker search/PCSS. Enable existing half-resolution SSGI with depth/normal-aware full-resolution fallback on Ultra and Extreme; no voxel grid reduction.
- Split shadowed sky diffuse from independent block/voxel irradiance. Explicit cutout shadow alpha, tilted solar path, analytic environment specular for smooth materials.
- Use separate wavelength-dependent molecular and aerosol optical depths with a bounded directional phase function; same analytic atmospheric model for native terrain and DH, no new pass or LUT.
- Water SSR uses wider marching reach and four crossing-refinement steps only on candidate intersections. Preserve Fresnel and screen edge confidence. Offscreen and DH reflections remain approximate.
- Actual GPU frame-time, continuous LOD and visual acceptance remain pending. No stable release claimed.

### Natural V2.2 — stable-grid temporal resolve
- Runtime feedback: Ultra/Extreme still shake, especially fullscreen, after V2.1. Static compile was successful, not a runtime acceptance.
- Separate resolved TAA history coordinates (unjittered) from raw SSGI history coordinates (jittered). Reconstruct the current raster sample onto a fixed output grid with a depth/normal-aware four-tap filter, use a local plane for reprojection, and record viewport dimensions in history metadata. Remove depth-donor replacement at distance edges. Center the finite jitter sequence.
- Resolve volume using the geometry sample ray before TAA, blend half-resolution GI and full-resolution fallback continuously, and expand compile/test coverage. No preset disables TAA, volumes, or voxel lighting.
- Runtime A/B matrix: fixed camera 64+ frames, native/DH edges and moving camera, windowed/fullscreen/resized, 720p/1080p/1440p/4K; isolate VOLUME_EFFECTS, SCREEN_GI_HISTORY, SCREEN_GI_SPATIAL and VOXEL_LIGHTING independently; measure image shift and p95/p99 frame time. Actual runtime acceptance pending.
- Next gated implementation sequence: physical atmospheric transmittance/multiple-scattering/sky-view/aerial LUTs; shared depth-aware material SSR; DH shadow caster and receiver integration; incremental world-aligned voxel cache with dirty-region propagation and deletion correctness. Keep changes isolated until the stability regression is accepted.

### Advanced rendering research — isolated branch
- Material SSR: opt-in deferred2 pass, reuse the water ray tracer, retain the exact environment specular weight/occlusion in an RGBA16F attachment, replace rather than double-add the sky reflection. Native opaque terrain and LabPBR only; no offscreen/DH hit tracing, no roughness-prefiltered history yet.
- DH shadows: opt-in dh_shadow caster and DH receiver shadow sampling. Normal Iris shadow projection and radius still bound the covered area, no kilometer-scale cascaded shadows. DH water is excluded from the caster via Iris mini-ID. Actual pinned-loader compatibility and LOD transition performance remain to be measured.
- Both settings default off; the normal V2.2 stability branch remains unchanged. No new quality defaults until runtime validation.

- Physical atmosphere numerical reference: `tools/atmosphere_lut_reference.py` generates spherical RGB transmittance, isotropic multiple-scattering closure, sky-view and direction-space aerial volume. It is an independent CPU reference based on the rendering equation and Hillaire EGSR 2020; no external implementation copied. Production Iris LUT compute passes, physical-to-Minecraft length calibration, dynamic cache keys and actual GPU validation remain open.
- Incremental voxel numerical reference: `tools/voxel_incremental_reference.py` caches each finite propagation stage in world coordinates, recomputes the dependency region on emitter/wall edits and camera-grid shifts, including removal. Compare every stage against a full rebuild. GPU dirty-tile dispatch/occupancy comparison, storage budgeting, world transitions and diffuse-bounce updates remain open.
- Run the existing CI with opt-in SSR/DH combinations plus `tests/test_advanced_references.py`; no advanced feature is enabled in a quality profile yet.

### Natural V2.3 — evidence-driven projection compatibility
- V2.2 user isolation: D00, D07, D08, D11 normal; D01–D06, D09, D10, D12, D13 flicker. D07 fixes projection only with all Ultra lighting enabled. D12 bar colors were not recorded. This establishes a necessary trigger in the tested configuration, not a unique GPU/driver cause. Do not claim a dynamic-jitter root-cause fix yet.
- Introduce independent projection mode (auto/fixed/dynamic), using exactly the zero-jitter path proven by D07 for advanced lighting in auto. Preserve all quality preset flags, TAA/SSGI accumulation and voxel dimensions. Dynamic remains available. Fixed sampling does not provide temporal supersampling; optional spatial AA can improve edges.
- Validate normal Ultra/Extreme auto, explicit dynamic Ultra, and explicit fixed High in the compile matrix. Runtime acceptance: Ultra/Extreme auto, fullscreen and windowed, plus DH edges and stationary/moving camera. Keep research branch isolated until acceptance.

- User confirmed both normal Ultra and Extreme presets work. PR #1 merged as ca7166c; CI passed. This research branch retains that accepted baseline.

### P6 GPU atmosphere integration prototype
- Opt-in PHYSICAL_ATMOSPHERE uses Iris custom images; static setup/setup1 transmittance and isotropic multiple-scattering closure, begin1/begin2 sky and RGB aerial volume. Static LUTs 128x32 and 32x16, dynamic sky 128x64, aerial 32x32x16 with separate spectral transmission and inscatter. No new image allocation when disabled. Direction-space parameterization avoids screen jitter. Clear atmosphere calibrated at 0.04 km/block; rain and night use approximate blending. Compute cost, loader setup ordering and visual calibration still require game readbacks. Hillaire 2020 and Iris documented compute ordering informed the independent implementation.

### P6 incremental GPU voxel prototype
- Opt-in INCREMENTAL_VOXELS retains stage0..3 and existing stage4 light field. Compare each newly injected seed (including walls/deletions) against previous occupancy; mark dirty 4^3 tiles atomically. Clear tile bits in begin, propagate only tiles within one tile of edits (covers four cell steps), diffuse gathers within two tiles (covers six cell dependency). Workgroup-coherent early return; no intra-pass neighbour races. Metadata in setup2/prepare6 forces full rebuild on integer camera-grid shift or discontinuous frameCounter. This is exact for the existing fixed-stage propagation, not yet rolling-grid reuse or indirect dispatch. All invocations are launched; expensive propagation can be skipped. Extra four RGBA16F stage images + R32UI previous seed + small metadata/tile image. Combined atmosphere+voxel uses 15 custom images, within the documented 16 limit; runtime hardware binding limits must still be checked. No default enablement.
