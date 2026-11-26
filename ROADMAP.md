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

### Dynamic jitter research: explicit ownership and coordinate contract
- Forced dynamic advanced path adds RG32F geometry ownership attachment (native opaque/water/translucent and DH opaque/water plus exact raster depth). An unjittered entity cannot inherit stale terrain sampling ownership merely because a normal was present. Common reconstruction now accepts projection and actual jitter state, exposes normalized-UV depth lookup, and a shared planar surface intersection. Reprojection uses exact Iris integer/fraction camera delta instead of wrapped floating camera position. Auto advanced mode remains fixed. The following change uses the attachment for volume and temporal shading.
- Dynamic path now stabilizes planar lighting origins in deferred, AO/SSGI hit intersections and volumetric integration while preserving the raw dynamic G-buffer raster. SSGI history follows its actual stable sample grid and stores viewport dimensions. Half-resolution GI maps from actual fullscreen UV (including odd viewport sizes). TAA consumes exact owner metadata, distinguishes native vs DH history, handles sky rotation-only history, and allows a bounded temporal variance envelope in flat regions. Nonjittered entities are no longer unprojected as jittered by these paths. Remaining work: runtime capture of forced-dynamic Ultra/Extreme, true geometry edges/motion vectors, SSR and optional motion-blur coordinate audit. Static numerical tests alone cannot establish all defects are gone.
- P6 rolling cache refinement: physical stage storage now uses world-aligned modulo coordinates, including negative world positions. On camera-grid movement retain overlap, mark newly entered voxels and the retained boundary that lost neighbours. Exact dirty tiles propagate deletion effects; nonoverlapping teleports mark the whole domain. Irradiance uses hardware filtering except across physical ring seams, where explicit wrapped trilinear sampling prevents seams. The CPU regression emulates ring storage and tile updates over movement/edits/teleports against full rebuild, in addition to the earlier abstract reference. No GPU readback yet.
- P6 SSR refinement: separate exact environment contribution (colortex13) from Fresnel/roughness metadata; indoor smooth materials now reflect even without skylight. Shared native/DH ray intersection uses independent projections, true depth-texel centers, first valid crossing and five refinement steps. Roughness-dependent depth-aware hit filtering, receiver-depth/normal/viewport validated temporal correction (colortex14/15), miss decay, and stable receiver positions for forced dynamic mode. Native opaque reflectors only; water shares ray intersection, DH as reflection source. Screen-space limitations, loader attachment support and GPU readback remain open. This uses 16 numbered color attachments at maximum, not 16 simultaneous outputs.
- P6 DH shadows: retain actual DH shadow caster in the Iris native shadow pass (water discarded); opaque DH gets a deferred shading path when DH_SHADOWS and deferred are enabled. Within the native shadow frustum sample the real shadow map, beyond it blend to bounded screen-space terrain ray visibility. Only direct sunlight is attenuated, not ambient or atmospheric inscatter. DH depth uses its own projection and texel size. Unfogged DH radiance is stored for material/water reflections. Far occlusion is screen-space, not a true kilometer-scale cascaded shadow map; offscreen occluders and DH shadow draw submission costs remain limitations. Forward/DH water retains native map shading only.
- P6 atmosphere refinement: quadratic altitude and signed-square elevation LUT parameterization concentrates samples near ground and horizon. Both-end quadrature improves long rays; direct solar irradiance uses the physical transmittance table. Aerial distance extends to 120 km (3000 scene blocks at calibrated scale). Per-direction prefix integration writes all 16 aerial slices with at most 60 medium evaluations instead of 384 (84.4% fewer integrations, not a GPU frame-time measurement). Sky/aerial weather and twilight blend continuously. Static transmittance/multiscattering remain cached by setup; dynamic sky/aerial update every frame. Rain/multiscattering and world scaling still approximate.

### P6 quality preview — clear water, colored emitters and explicit quality budget
- Clear water uses RGB extinction (0.115, 0.028, 0.012) plus default turbidity 0.01, previously (0.18, 0.045, 0.018) plus 0.025. Underwater fog uses local eye light; sun scattering follows skylight. Fresnel/Snell retained. Native refraction reads exact depth-texel centers and stable dynamic water position. Visual clarity is an artistic calibration, not measured physical water properties.
- 16-kind emitter palette (including fallback) shared by material and voxel light. Split lava, glowstone, torches, soul lights, sea lantern, redstone lamp/torch, three froglights, shroomlight, jack-o-lantern, end rod, magma and lantern. 4-bit kind and 4-bit emission level remain below wall sentinel 256. Vanilla light strength applies to voxel result. Non-voxel tiers retain a generic warm lightmap color; no per-source RGB without voxel data.
- Ultra/Extreme experimental presets now explicitly enable PHYSICAL_ATMOSPHERE, MATERIAL_SSR, DH_SHADOWS, INCREMENTAL_VOXELS and PROJECTION_JITTER:2. Lower tiers keep the new features disabled by default. Fixed mode (1) and previous auto compatibility (0) remain selectable. The normal main baseline remains unchanged until runtime acceptance. Explicit profile keys reset advanced toggles when changing tier; personal effects remain independent.
- Preserve shadow maps and voxel grids. Water ray steps 0/0/8/16/16/16 by tier. Material SSR 16/24 steps on Ultra/Extreme, cloud 12/16, shafts 6/8, DH far occlusion 10/14; budget controls are exposed. Ray march distributes samples across its range rather than wasting extra steps beyond cutoff. Fixed TAA bypasses four-tap current resolve; zero-weight taps and empty cloud layers skip work. Reversed-culling radius now declared in deferred stage at half the grid size, fade out voxel irradiance before its guaranteed sphere boundary. This may increase shadow geometry submission versus the former 28-block value; measure actual GPU/CPU costs.
- Test acceptance: same seed/time/weather, default Ultra/Extreme dynamic and manually fixed A/B, fullscreen/windowed/resize, local terrain and DH, underwater clear/dark, individual colored emitters with placement/deletion, steady and moving camera. Compare GPU VRAM and frame-time distributions, not only FPS. No claim of runtime validation until observed.
- Reproducible memory accounting: `python tools/quality_budget.py --width 1920 --height 1080` lists named GPU texture payloads, including incremental caches, atmospheric LUTs and the new SSR/ownership color attachments. Single/double-buffered payloads are estimates, not total VRAM usage; exclude existing color/depth buffers, textures, geometry and driver allocation.
- Run pinned aislop v0.19.1 as a separate Actions gate with read-only permissions; GLSL validation remains the authoritative compiler check for shader code.

### P6.1 runtime regression response
- User reports severe Extreme frame loss, Ultra/Extreme flicker, and mild distant leaf shimmer on Medium/High after enabling advanced features. Default Medium/High use fixed TAA + FXAA, Ultra/Extreme fixed TAA, retaining all four P6 features and every existing shadow/grid resolution. Explicit forced dynamic remains available; it failed runtime acceptance and is not claimed fixed. Foliage wind fades earlier, distant leaf sampling uses modest mip bias and stationary history weights recover with distance. This changes distant vegetation detail/motion.
- Three sequential prepare suffix passes perform separable tile-mask expansion into disjoint slabs of the existing dirty image. Radius 1/2 masks match the old Chebyshev neighborhoods exactly. All five propagation passes read one cached mask per workgroup rather than repeating neighborhoods. Group-shared previous metadata and dirty flags avoid per-voxel metadata fetch/global atomics. Additional 384 KiB storage; no new custom image. Iris requires serial compute, already configured. Keep 96/128 grid sizes. Extreme budget 16 SSR, 12 cloud, 6 shaft, 10 DH, 3 AO slices (was 24/16/8/14/4); Ultra DH 8. DH ray spacing covers the configured range. These are explicit sampling-quality tradeoffs, not measured performance gains. P6 GPU timing and forced-dynamic investigation remain open.
- Forced-dynamic research: fix double correction of the stable lighting grid. Advanced deferred/volume/water shading already uses a stable output ray; the previous final resolve shifted the combined radiance a second time by the current subpixel offset. Advanced dynamic now feeds the center radiance directly into temporal accumulation; basic dynamic still uses the raw-raster spatial reconstruction. This removes an analytically demonstrable artificial brightness variation, not proof that all coverage/disocclusion flicker is gone. Added a ramp counterexample and preprocessor checks across fixed/basic/advanced dynamic modes. Keep fixed default until an actual runtime pass.


### P9–P15 deep rendering optimization and dimension art pass
- P9: prepare7 reduces the final RGB field to 4^3 occupied tiles; prepare8 conservatively dilates occupancy by one tile for trilinear support. Reuses two dead dirty-mask slabs, with no additional image. Local scattering skips the sample centres strictly inside a proven-empty tile, advances the same quadrature lattice and applies the corresponding extinction. Nonincremental mode retains the original march.
- P10: native-depth min/max atlas (4x4 and 16x16 levels), built from shared 2x2 quads by deferred_a. Fixed-projection SSR and SSGI use conservative front-of-tile sample rejection, retaining exact-depth crossings/refinement; DH sky-containing tiles fall back. This is hierarchical point rejection, not full hierarchical ray traversal; water SSR has a different depth ownership and remains unchanged. One RG32F half-width/half-height custom image brings the maximum to 16; 3.96 MiB named payload at 1920x1080. No measured speedup claimed.
- P11: adaptive 4^3 cooperative stencil with 64 interior and 96 face texels, omitting unused edge/corner halo; 160 versus up to 384 source image loads for a fully open tile. Sparse/solid tiles use the direct path. Exact six-neighbour propagation retained; the barriers and cache behaviour require GPU profiling.
- P12: isolated reset/compact/consume GPU queue probe under experiments/voxel_compaction, with two bounded workgroup lists and two indirect command records. Current production fixed dispatch keeps dirty-mask early return. Inspected Iris 1.21.1 branch lacks an explicit command-fetch barrier before indirect dispatch; pinned 1.8.8 must be verified and probe GPU readbacks completed before production indirect dispatch.
- P13: composite_a integrates local coloured scattering on the existing quarter-width/quarter-height colortex11 before the existing full-size composite. Depth-aware bilinear reconstruction falls back to the full-resolution ray at depth discontinuities. Fixed grid only; forced dynamic retains full resolution. Bloom reuses colortex11 later. No extra full-screen attachment.
- P14: tools/gpu_pass_profile.py summarizes normalized measured capture CSV (frame,pass,gpu_ms, optional read_bytes/write_bytes), aggregates same-frame pass occurrences, reports median/p95/mean and measured bandwidth only where complete counter data is available. Logical memory estimates remain separate in quality_budget.py. No GPU timings inferred from sample counts.
- P15: original direction-space End nebula and antialiased stars, purple horizon, warmer lower Nether fog while retaining biome tint; increased lava/glowstone/shroomlight voxel source intensity. Overworld analytic HDR solar disc and two-scale corona; cool phase-dependent lunar halo with vanilla moon texture/phase preserved. Artistic reference BSL official description (https://capttatsu.com/bslshaders/about.html); no external shader code copied. Detailed sky evaluated in sky stages, not every terrain fog lookup.
- Acceptance: run compiler, Python regressions, all three pack variants and aislop. Runtime: Minecraft 1.21.1/Fabric/Iris 1.8.8/Sodium 0.6.13, three dimensions, fixed/forced dynamic, DH, odd viewport/resize, lava/soul torches, emissive changes, sky transitions and moon phases. Capture comparable per-pass timings and hardware counters on the same GPU/settings; inspect occupancy/Hi-Z/upsampling readbacks. No game/GPU result claimed until measured.


### P16 cross-version and runtime visual correction
- Separate visible emissive texture chromaticity from the voxel illuminant palette; reduce exaggerated lava/glowstone/shroomlight radiance, use alpha support propagated with RGB, taper the outer light frontier, and smoothly blend edge fallback in low-resolution scattering. The original four propagation stages and RGB cache remain; visual acceptance requires game screenshots.
- Explicit End sky shader and dimension markers, darker procedural nebula/star field, no Overworld solar clouds or LUT updates in the Nether/End. MC 1.21.9 adds End skylight, so skylight capability is not used as a dimension ID in packaged entry points.
- Full native hierarchical interval traversal through 64/16/4/1-pixel cells with separate depthtex0/depthtex1 atlases, conservative min/max bounds, exact perspective cell-boundary crossing and bounded fallback. Native material SSR, water/lava SSR and SSGI consume the hierarchy. DH sky regions fall back to their independent depth projection; no claim of a DH-specific depth pyramid.
- Modern Iris 26.1/26.3 branches explicitly insert GL_COMMAND_BARRIER_BIT before indirect dispatch. Integrate two SSBO task lists in prepare_d/e, radius-one for stages 1–4, radius-two for diffuse. Enable only with Iris >=1.11.7, MC >=26.1 and SSBO + existing voxel features; older loaders retain direct dispatch. Reference: https://github.com/IrisShaders/Iris/blob/26.3/common/src/main/java/net/irisshaders/iris/gl/program/ComputeProgram.java . GPU readback and performance capture pending.
- Version target packages: 1.20.x, 1.21.x, 26.x through 26.3, plus outer bundle; no separate shader forks. Legacy grass name and pale-oak/poplar IDs version-conditioned; explicit dimension entry generation. Offline legacy and modern compile branches do not certify runtime loading; representative tests on 1.20.1, 1.20.4, 1.20.6, 1.21.1, 1.21.8, 1.21.11, 26.1, 26.2 and 26.3 planned.


### P17 performance regression correction
- User reports up to 50% FPS loss after P16. Source-level cost audit: 48 visits per SSGI ray and up to 128 per SSR ray, each potentially 3 hierarchy reads plus a native depth read and subsequent full legacy retrace; P13 weighted edge path can invoke the exact integral on ordinary slopes; P9 rebuilt the occupancy mask with a full grid scan each frame.
- Default HIZ_MODE=1 retains the original sampling lattice and performs at most one conservative 64-pixel interval test per ray to skip three original taps. Medium/High water-only profiles do not build a hierarchy by default; mode 2 keeps complete hierarchical interval traversal with a bounded budget and legacy fallback, mode 0 uses original tracing. Iris copies pre-translucent depth before deferred rendering (IrisRenderingPipeline.beginTranslucents), so opaque and water SSR share one depth atlas. Adaptive mode builds only the 64-pixel min/max level in one dispatch, no second reduction pass, ~19.4 KiB named atlas at 1080p. Full mode retains 4/16/64 levels. No change to shadow map/grid resolution, original SSR/SSGI ray count or visual palette.
- P9: encode emitter presence in the existing seed tile mask, dilate conservatively by radius two through the existing three separable passes (four propagation steps plus one trilinear support cell). No full-grid final-light scan; remove prepare7/8 dispatch from active config. Cache per-ray tile lookup and reciprocal direction. False positives only reduce skipping; no valid light is rejected.
- P11: fold wall presence into the seed classification; reuse group-coherent mask for shared/direct choice, eliminate repeated per-stage contended atomics and barriers, short-circuit dirty tiles without any possible emitters by clearing their destination field. Eight seed flag bins reduce contention. Wrap in bounded ring indices with one correction rather than modulo.
- P13: reuse any depth-compatible bilateral reconstruction; reserve exact fallback for uncovered surfaces or near-zero matched weight. Keep original 24-tap cap and continuous fallback blend. Potential minor reconstruction difference on slopes; runtime image comparison required.
- Fix missing voxel settings include in modern compaction reset. CI and game GPU timings are required before declaring regression resolved.

### P18 non-celestial border fog and visible-work budgeting
- Explicit depth-empty Nether and End background before translucent rendering, including forward profiles; preserve DH coverage and medium fog. End procedural sky evaluated once in deferred background, with an analytic uniform pixel footprint and sparse star early-out. Far terrain uses common sky base and End low-frequency nebula; stars remain behind geometry. Border uses world-space cylindrical distance and min(far,fogEnd), terminates before nominal chunk range; DH End uses its separate far range when available. Fully opaque fog skips deferred material, AO, GI and SSR metadata. No new render pass on deferred profiles; forward non-celestial profiles run the existing deferred1 background-only program.
- SSGI bilateral fallback requires genuinely missing compatible samples; relax depth/normal tolerance, preserve exact fallback and transition at disocclusion. GTAO uses 2 horizon taps per direction beyond 32 blocks, preserving near 4-tap path; cloud and shaft sampling scales with visible path length, skips negligible shaft contributions; far DH shadow tracing skips direct contribution below 0.015. No change to user-selected near quality settings. Offline checks do not establish actual frame time or visual equivalence.

Additional visible-work budget: near GI retains four rays; beyond 22 blocks two opposed rays preserve normalized average, with existing 30-block fade. Fog visibility attenuates AO, GI and SSR metadata continuously; full material shading only skipped at exact opacity. Near cloud paths retain configured tap budget. Tests cover short/long view range, camera heading, fog color invariance, DH ownership and forward mode.

### P19–P23 visible work and bandwidth
- P19: material SSR contribution and distance fade; retain near mirrors, shorten distant/rough-ray sample budget without changing long ray range; low-energy SSGI shadow term smoothly bypasses expensive PCSS.
- P20: static, fixed-projection SSGI checkerboard reuse of the previous half-resolution result (including block GI), alternating fresh trace each frame; depth/normal/camera validation, existing Iris flipped buffers, no added texture. Static TAA near-identical history shortcut avoids four donor and 3x3 clipping fetches. Animated occluder/light changes can lag one frame; compare runtime images.
- P21: stationary seed comparison avoids scroll/boundary calculations, group-shared ring origin, overwrites every tile flag directly to remove redundant clear writes. Preserve full occupancy raster/seed comparison each frame to detect actual block changes; no motion-only cache invalidation.
- P22: near full PCSS search, reduced blocker search after 28 blocks and filter after 48 or small radius. Full legacy path remains available via option.
- P23: R16UI previous seed (max 259), R8UI dirty flags (max 15), keep R32UI atomic occupancy. Positive environment fallback colortex13 uses R11F_G11F_B10F; fetch only on a hit. Full HDR scene, signed SSR history and normal/depth remain unchanged. Iris 1.21.1 InternalTextureFormat supports all these formats.
- Design reference: Javier Garduño, MakeUp Ultra Fast, ForDevelopers.EN.md blob e942c2c0661570bbaee36c944d012848536f00d3 (https://github.com/javiergcim/MakeUpUltraFast/blob/master/ForDevelopers.EN.md), LGPL-3.0. Inspired by selective temporal reuse and compact/reused buffers; no source code imported.

### P24 measured GPU profiling
RenderDoc actual EventGPUDuration counter exporter with explicit per-capture event ranges, unclassified event reporting, and baseline/candidate median/p95 comparison. See docs/gpu-profiling.md. No real replay or game captures available in this environment.

P19 follow-up: use a projected one-block pixel footprint (viewport height and projection scale) for distant SSR budget; high resolution/narrow FOV retains more samples. P20: Iris 1.21.1 FinalPassRenderer copies non-cleared flipped buffers back to main, so the half-resolution histories incur one copy per persistent target (Ultra sky only; Extreme sky+block). Only declare clear=false when reuse is active. The A/B protocol includes this copy cost; no net GPU speedup claim.

### P25 — dimension-specific performance follow-up
User-reported Extreme measurements: End 136 to 240 FPS (refresh cap, >= measured throughput gain), Overworld 120 to about 105 FPS. These are user measurements, not controlled GPU pass captures. Auto GI reuse now retains checkerboard history for Nether/End only; explicit 0/2 allows disabled/all-world comparisons, ordinary TAA and GI temporal filtering remain. Overworld SSGI secondary hit uses the same bias/projection and single bilinear shadow comparison instead of repeating PCSS (direct surface PCSS retained). Hoist celestial irradiance out of the GI ray loop; eliminate variable integer division in PCSS loops; bypass discarded analytic atmosphere in full LUT daylight and defer sky lookup for zero boundary fade. Changes target suspected Overworld overhead, not a measured root-cause attribution.

P25 contrast: EMISSION_STRENGTH=1.5 (lava/glowstone/shroomlight etc., texture hue unchanged; indicator sources gain only 17.5%); LOCAL_GLOW_STRENGTH=1.7 multiplies existing occlusion-aware local single scattering, no extra ray samples or full-screen pass. Voxel seed curve lifts full-strength lights 15%, suppresses low levels. DARK_AMBIENT=0.65 dims ambient floor, low skylight and non-celestial environment, leaves full skylight/direct sun intact; weak vanilla block light curve falls from x²(0.45+1.35x) to x²(0.20+1.60x), identical level-15 energy. Existing optional Bloom recognizes saturated HDR peaks; remains opt-in, no extra pass forced. Far fog extinction and sky matching unchanged; no emission visible through opaque walls or beyond render border. Controls independently adjustable.

### P26 settings and affordable HDR bloom
Single owner per setting in menu tree, independent emissive/volume/screen glow controls, dedicated reflection and temporal reuse menus, bilingual tooltips. Explicit P25 defaults and Bloom defaults in every profile. Medium uses 4 extraction + 1 full-resolution composite taps, High/Ultra/Extreme 4 + 4, Wide optional 9 + 9. Same colortex11 storage (RGBA16F required for volume depth), no new render pass beyond existing optional composite3. Low/Potato/Natural/legacy presets disable Bloom. Profile selection intentionally resets these new controlled options; custom values remain editable. Motion blur and foliage remain personal options. GPU timing and UI in-game verification still required.

### P27 shadow-acne correction and Overworld work sharing
Likely striping source: PCSS compares offset texels against one flat receiver depth even on inclined surfaces. Use analytic receiver-plane gradient in orthographic shadow UVZ, correct each actual texel center for blocker search and bilinear PCF, bound the grazing-angle singularity, and compute blocker separation relative to the plane. Symmetric 4/8 probes and a far narrow-penumbra uniform-blocker shortcut. Volume path retains ordinary PCF. Reference: Microsoft Common Techniques to Improve Shadow Depth Maps (receiver-plane bias), Iris ShadowTex docs, MakeUp developer notes (shared low-resolution passes). No external shader code copied. Runtime verification still needed; LabPBR shading normals can differ from geometry normals.
