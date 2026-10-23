3dmaxScript 项目统一更新日志
==========================

本文件统一记录 MaxZJTools、各工具及 AssetsMG 集成包的版本迭代。维护规则与可复用模板见 [AGENTS.md](AGENTS.md) 的“统一 Changelog 规则”。

**填写 GitHub 时**：找到本次条目的“GitHub 修改概要”，复制代码块第一行作为提交标题，其余内容作为提交说明；Release 可再附该条目的“改动与影响”和“验证与发布说明”。概要不代表已提交、推送或发布。

版本按产品分区，分区内从新到旧。历史条目于 2026-10-16 根据现有说明与验证记录整理，保留原日期；未核实远端 GitHub 发布状态。纯文档维护引用当前基线，不构成工具新版本。

| 当前版本归属 | 版本 | 依据与状态 |
|---|---|---|
| MaxZJTools 工具包 | v1.7.1（开发候选） | [version.ini](MaxZJTools/config/version.ini)，Max 宿主验收待完成 |
| VertexColorWriter 工具 | v1.4.0 | [使用说明](MaxZJTools/tools/VertexColorWriter-使用说明.txt)，随上述工具包维护 |
| AssetsMG.VertexColorWriter 集成包 | v1.0.0 | [生成器](integrations/AssetsMG/Build-Package.ps1)，基于 MaxZJTools v1.7.0 / 工具 v1.4.0；已生成本地候选包，实际接入待验证 |

# 未发布（Unreleased）

## 2026-10-23 · v1.7.1 · 收紧四工具写入范围与恢复处理 · 旧工具、安装入口、测试和说明 · 重开面板，安装验证需重启

**版本归属**：MaxZJTools 工具包 v1.7.1；RenameTools v1.2.1、MeshChecker v1.0.1、ReSetTexturesPath v1.0.1；BoneOverride 保留旧 V4 标识，未设独立语义版本。VertexColorWriter v1.4.0、AssetsMG.VertexColorWriter v1.0.0 均不变。
**状态**：未发布开发候选；源码与定向静态检查完成，Max 宿主运行、失败恢复及非作者复核待完成。

### GitHub 修改概要

```text
fix(MaxZJTools): 修复批处理范围、过期预览和骨骼权重恢复处理

- 重命名增加空选择保护、目标去重和冲突检查；动画检查与清理使用同一轨道清单。
- 贴图引用预览目标路径、跳过不存在的图片；骨骼替换先核对完整权重，失败取消本批并核对恢复。
- 安装器检查依赖并备份旧 Loader，菜单统一读取版本配置；补齐四工具说明与宿主冒烟用例。
- Max 2024 批处理被授权错误阻断，宿主编译、Undo 与骨骼失败恢复待验证；尚非稳定发布。
```

### 改动与影响

- 按 ArtTA v0.2.0 简化提案采用一份简短方案和真实验证记录，沿用现有面板、宿主 Undo 与项目记录；不新增审批框架或 CI。
- RenameTools 空选择不会修改全场景材质；对象/骨骼合并去重；参数、目标、旧名变化或新重名冲突时要求重新预览。部分失败分别计数。
- MeshChecker 递归检查/删除同一 PRS 叶轨道，拒绝不完整扫描、陈旧清单和范围外共享控制器；关闭排序以保持行与引用一致。
- ReSetTexturesPath 显式全场景材质扫描，递归子材质并按引用去重；列出旧/新路径，检查目标文件与冲突，只改引用、不复制或覆盖图片。
- BoneOverride 拒绝不支持的动态/约束、实例 Skin、歧义和不完整范围；完整快照及转移所有正权重，包括微小权重和未关联顶点。全部回读通过后才修改层级/身份，失败以 Hold 取消并验证恢复。仅支持静态标准骨骼；需要场景副本和专项宿主验收。
- Install 在替换前检查必要文件、写入暂存 Loader 并回读，保留唯一备份；丢失包路径有诊断。Init 从 version.ini 读版本/日期，保留已有菜单去重修复。
- 补四工具参数、流程、范围和限制，移除 README 中未实现的大小写转换/删除数字宣称；新增 LegacyTools_Smoke.ms。四工具重开只处理自己的窗口，不修改 VertexColorWriter。

### 验证与发布说明

- 验证：本轮定向静态检查通过，版本/文档链接/UTF-8 BOM + CRLF 与差异核对完成。定向检查不是 MAXScript 编译器。新增宿主脚本已编写，未取得执行报告。
- 阻挡：2026-10-23 Max 2024（26.2.0.22013）独立 batch 报 `License Error: user canceled authorization`；未进入测试。Max 2022、安装/重复加载/卸载、实际修改和 Undo、骨骼失败恢复仍待验证。不将历史 VCW UI/采样结果计作本轮通过。
- 使用：目标仍为 Max 2022，2024 尚未确认；无新增第三方依赖或图片资源，保留完整包。更新后重载 Init 并重开面板；安装器备份/自动启动需运行 Install.ms 并重启验证。宿主资源原有要求不变。
- 回退：场景修改使用本批 Undo 或执行前副本；安装文件使用对应 .bak；源包回退需匹配文件并重载。BoneOverride 的静态范围限制与贴图不存在时跳过属于本版明确保护行为；不得绕过后用于未支持资产。
- 依据：[本轮方案与验证](MaxZJTools/docs/ArtTA-修复验证.md)、[实际启动日志](MaxZJTools/tests/evidence/2026-10-23-max2024-startup.txt)、[实施记录](MaxZJTools/integration-validation.txt)。未执行 Git 提交/推送、Tag、Release、真实安装或外发。
- 集成：现有 AssetsMG VCW v1.0.0 ZIP 未重打包，仍按原 v1.7.0/VCW v1.4.0 基线；其中没有本轮四工具，不包含此次修复。

## 2026-10-16 · v1.7.0 · 统一版本日志与 GitHub 修改概要 · 仓库文档和集成说明模板 · 无需重启

**版本归属**：MaxZJTools v1.7.0 为当前基线，版本未变，不构成新版本；VertexColorWriter v1.4.0 与 AssetsMG 集成包 v1.0.0 均未升版。
**状态**：本地文档维护完成，未执行 GitHub 上传；本条供本次文档改动提交使用。

### GitHub 修改概要

```text
docs(changelog): 统一工具版本日志与 GitHub 修改概要

- 建立根目录 CHANGELOG.md，汇总 MaxZJTools 与 AssetsMG 集成包的已有迭代记录。
- 规定每次实际改动交付前记录版本归属、修改概要、影响范围、验证状态和重启要求。
- 每条提供可复制的 GitHub 标题与说明，统一 README、工具说明和集成模板的日志入口。
- 本次仅维护文档，运行工具版本不变，现有集成 ZIP 未重新生成。
```

### 改动与影响

- 新增统一主日志，整理 MaxZJTools v1.0.0～v1.7.0 和 AssetsMG.VertexColorWriter v1.0.0 的已有记录；每条补充 GitHub 修改概要。
- 在 [AGENTS.md](AGENTS.md) 固化记录时机、未发布区、独立版本归属、概要模板及交付检查；纯文档改动纳入记录但不强行升工具版本。
- [总说明](MaxZJTools/Readme.txt)、[工具说明](MaxZJTools/tools/VertexColorWriter-使用说明.txt) 改为指向主日志，旧日志保留为历史快照；[集成说明模板](integrations/AssetsMG/README.template.txt) 明确从主日志摘取对应版本。
- 不改变脚本、UI、菜单、场景数据、安装行为或颜色数值。现有 `dist/AssetsMG-VertexColorWriter-1.0.0.zip` 未包含本轮文档更新；下次生成时同步说明并按交付规则确定版本。

### 验证与发布说明

- 验证：检查记录格式、每条概要覆盖、版本对应、链接及文档编码/换行；本次无代码改动，未运行 Max 或重跑功能回归。
- 使用：文档维护，无新增依赖或外部资源；无需安装、重载或重启。Max 2022 运行验收状态保持原记录，不因日志整理变为通过。
- 依据：本次文档差异及下方各版本的原始依据；未创建 GitHub Commit、Tag 或 Release。

## 2026-10-13 · v1.7.0 · 补充美术指南与 AssetsMG 维护规则 · 文档和问题记录 · 无需重启

**版本归属**：MaxZJTools v1.7.0 为文档对应基线，版本未变，不构成新版本；工具 v1.4.0。独立集成包的生成另见下方 AssetsMG v1.0.0。
**状态**：补录已完成的文档维护；飞书指南已写入，GitHub 发布状态未确认。

### GitHub 修改概要

```text
docs(VertexColorWriter): 补充美术使用指南与集成维护规则

- 整理高度对齐、固定填色、局部选点及贴图写入的美术指南，并在工具说明中加入飞书入口。
- 固化 AssetsMG 从原工具生成独立副本的命名隔离、资源和验收规则。
- 记录选色与视口显示差异的已知问题及待验证项；未修改颜色写入逻辑。
```

### 改动与影响

- [飞书美术指南](https://t6bdpf8yjg.feishu.cn/docx/NTends7mso2kijx79Q5cWL3mnOf) 包含四种操作流程、1 米高度对齐示例、参数表、流程图及限制；地址已加入原工具说明与 README。
- 保留 [指南源稿](MaxZJTools/docs/VertexColorWriter-美术使用指南.feishu.xml)、[颜色显示调查](MaxZJTools/bugs/2026-10-13-vcw-color-display.txt) 和 AssetsMG 规则。颜色显示差异仍处于调查状态。

### 验证与发布说明

- 验证：飞书正文已回读核对、流程图预览已检查；问题分析基于代码和截图，不代表 Max 内颜色回读验证完成。
- 使用：文档与问题记录，无新增运行依赖，无需重启；访问飞书指南需具备相应文档权限。该记录不表示在线指南已打包进旧 ZIP。
- 依据：上述文档及 2026-10-13 维护记录；未补造功能版本或远端发布信息。

# MaxZJTools 版本记录

以下版本日期与变化取自 [原 README 历史快照](MaxZJTools/Readme.txt)、[工具使用说明](MaxZJTools/tools/VertexColorWriter-使用说明.txt) 和 [实现/验证记录](MaxZJTools/integration-validation.txt)。测试结论仅对应当时版本与环境。

## 2026-10-13 · v1.7.0 · 新增选中顶点局部写入 · VertexColorWriter、UI 与回归说明 · 无需重启

**版本归属**：MaxZJTools v1.7.0；VertexColorWriter v1.4.0。
**状态**：源码与独立检查完成；Max 宿主验收待完成，未确认 GitHub 发布。

### GitHub 修改概要

```text
feat(VertexColorWriter): 支持选中顶点局部 RGBA 写入

- 新增整个模型/选中顶点范围，高度渐变、固定颜色和贴图写入均可局部应用。
- 显示已选点数并保护空选场景，保留未选顶点和未勾选通道；高度仍按整模型基准计算。
- 独立 UI 及定向静态检查通过，Max 内写入、选择恢复、Undo 和导出仍待验证。
```

### 改动与影响

- 支持单模型 Editable Mesh / Poly 或 Edit Mesh / Poly 的顶点硬选择，整模型范围继续支持批处理。
- 写入前捕获选择并验证拓扑，失败时移除该对象本次新增修改器；添加选点计数、空选禁用及局部写入用例。
- 已知限制：不支持软选择权重或孤立点；固定/高度选色与视口外观可能不同，见 [颜色显示调查](MaxZJTools/bugs/2026-10-13-vcw-color-display.txt)，尚未修复。

### 验证与发布说明

- 验证：当次独立 UI 44 项及定向静态检查通过；新增 Max 选点回归已编写，未取得宿主通过证据。图片读取器本轮未改，历史 41 项结果不作为本轮重跑。
- 使用：目标 Max 2022，无新增运行依赖；保留工具 `.ms`、两份 `.cs` 与图标目录，重载 Init 并重开面板，无需重启。外部贴图需自行保留，不自动打包。
- 依据：[实现/验证记录](MaxZJTools/integration-validation.txt) 的 v1.7.0 段及 [局部写入用例](MaxZJTools/tests/VertexColorWriter_Selection_Smoke.ms)。

## 2026-10-13 · v1.6.0 · 新增面板与入口图标 · VertexColorWriter UI、图标和初始化 · 通常无需重启

**版本归属**：MaxZJTools v1.6.0；VertexColorWriter v1.3.0。
**状态**：历史源码版本；独立 UI/资源检查完成，Max 图标注册待验证。

### GitHub 修改概要

```text
feat(VertexColorWriter): 增加面板和入口图标

- 为模式、分区和主要按钮增加图标，保留中文文字，提供深浅主题多尺寸入口资源。
- 初始化时注册本工具图标，缺失资源时保留可用界面；颜色写入行为不变。
- Max 内图标注册、DPI 与安装卸载仍待验证。
```

### 改动与影响

- 新旧入口共用工具图标，初始化仅复制本工具的 14 个 PNG 到用户图标目录。
- 主图标随包，面板小符号由 C# 绘制；不修改公共参考图标库。

### 验证与发布说明

- 验证：历史记录确认独立 UI/资源检查通过；Max 内主题、DPI、入口显示与资源注册待运行。未改变采样/写入逻辑，不虚列新采样测试。
- 使用：目标 Max 2022；新增随包图标资源，无第三方依赖。保留 icons，重载 Init 并重开面板；工具栏仍缓存旧图标时需重启。
- 依据：[图标说明](MaxZJTools/icons/说明.txt) 及 [实现/验证记录](MaxZJTools/integration-validation.txt) 的 v1.6.0 段。

## 2026-10-13 · v1.5.0 · 新增贴图颜色写入 · VertexColorWriter、图片读取器与 UI · 无需重启

**版本归属**：MaxZJTools v1.5.0；VertexColorWriter v1.2.0。
**状态**：历史源码版本；独立读取/采样及 UI 验证完成，Max 内写入待验证。

### GitHub 修改概要

```text
feat(VertexColorWriter): 按 UV 将贴图颜色写入顶点 RGBA

- 新增贴图写入模式，支持颜色/遮罩用途、双线性/最近点采样和 UV 截取/平铺。
- 提供图片预览与重新读取，保留未勾选通道及 UV 接缝；不自动展开 UV 或细分模型。
- 独立采样检查通过，Max 内 RGBA 写入、Undo 与导出仍待验证。
```

### 改动与影响

- 支持普通 PNG/JPG/JPEG/BMP/TGA，按 UV 面角采样；颜色 RGB 做 sRGB 转线性，遮罩保持原始数值，Alpha 始终线性。
- 单批共用一张图片，读取失败清空缓存；文件变化后需重新读取并再次写入，不自动监视。
- 不支持材质树、程序贴图或 UDIM；图片细节受模型顶点密度限制，尺寸和格式限制见工具说明。

### 验证与发布说明

- 验证：当次独立读取/采样 41 项及 UI 检查通过；Max 几何写入与源 UV 保留、Undo、导出待宿主运行。
- 使用：目标 Max 2022；新增同目录 `VertexColorWriterTexture.cs`，使用内置 .NET，无第三方库。源图片由用户提供，跨电脑重写需手工复制；不自动打包。重载 Init 并重开窗口，无需重启。
- 依据：[实现/验证记录](MaxZJTools/integration-validation.txt) 的 v1.5.0 段及 [贴图回归用例](MaxZJTools/tests/VertexColorWriter_Texture_Smoke.ms)。

## 2026-10-13 · v1.4.0 · 新增模型高度与视口标尺 · VertexColorWriter 测量和显示 · 无需重启

**版本归属**：MaxZJTools v1.4.0；VertexColorWriter v1.1.0。
**状态**：历史源码版本；独立 UI 验证完成，Max 实际测量及绘制待验证。

### GitHub 修改概要

```text
feat(VertexColorWriter): 显示模型高度与临时视口标尺

- 单选模型时显示世界 Z 高度及两端值，支持开关视口尺寸标尺。
- 测量只读，不创建辅助节点或修改器；关闭工具与选择变化时清理显示。
- Max 内测量、视口绘制和 DPI 验收仍待完成。
```

### 改动与影响

- 面板与标尺统一以米显示，测量整模型，不自动改动颜色映射高度。
- 标尺采用临时绘制，不写入场景，不会被塌陷为模型或作为节点参与导出；复杂模型采用延迟刷新。

### 验证与发布说明

- 验证：当次代码与独立 UI 检查完成；Max 变换/父级/单位测量、回调清理、塌陷与导出隔离仍待验收。
- 使用：目标 Max 2022，无新增外部依赖；重载 Init 并重开面板，无需重启。大型网格不承诺逐帧刷新。
- 依据：[实现/验证记录](MaxZJTools/integration-validation.txt) 的 v1.4.0 段及 [高度回归用例](MaxZJTools/tests/VertexColorWriter_Height_Smoke.ms)。

## 2026-10-13 · v1.3.0 · 更名并增加 RGBA 与固定填色 · VertexColorWriter、菜单和界面 · 无需重启

**版本归属**：MaxZJTools v1.3.0；VertexColorWriter v1.0.0。工具名称由 ZHeightToVertexRed 迁移，旧入口保留。
**状态**：历史源码版本；独立 UI 验证完成，Max 加载及几何运行待验证。

### GitHub 修改概要

```text
feat(VertexColorWriter): 支持 RGBA 渐变和固定颜色填充

- 更名为定点色写入工具，增加 RGBA 独立通道选择、双色高度渐变和固定填色。
- 放大界面字体，改为纵向映射预览，并保留旧脚本与宏入口。
- 独立 UI 验证通过，Max 内加载、颜色写入与撤销仍待验证。
```

### 改动与影响

- 未勾选分量保持原值；增加 Alpha 参数与示意预览、处理明细和批次撤销机制。
- 旧 `ZHeightToVertexRed.ms` 转到新工具，旧函数调用行为保留；面板使用独立 C# WinForms 源码。

### 验证与发布说明

- 验证：独立 UI 控件状态与颜色参数检查通过；真实 Max 菜单、几何写入、Alpha 和 Undo 待验收。
- 使用：目标 Max 2022；必须随包保留 `VertexColorWriterUI.cs`，使用内置 .NET，不要求第三方库。重载 Init 并重开面板，无需重启。
- 依据：[实现/验证记录](MaxZJTools/integration-validation.txt) 的 v1.3.0 段及 [旧入口说明](MaxZJTools/tools/ZHeightToVertexRed-使用说明.txt)。

## 2026-10-13 · v1.2.1 · 修复脚本关键字和菜单删除错误 · 高度工具加载与菜单重载 · 无需重启

**版本归属**：MaxZJTools v1.2.1；当时的 ZHeightToVertexRed v1.1.1。
**状态**：历史修复记录，fixed_pending_validation；静态验证完成，Max 内复验待完成。

### GitHub 修改概要

```text
fix(MaxZJTools): 修复高度脚本语法与菜单重载错误

- 修正高度映射中的保留关键字命名，消除已定位的语法问题。
- 修正旧菜单删除 API 的使用，并补充定向静态回归检查。
- 静态检查通过，修复后的 Max 加载与运行仍待复验。
```

### 改动与影响

- 处理用户报告的脚本加载报错及重载时旧菜单无法清理问题，不增加写入功能。

### 验证与发布说明

- 验证：历史静态回归在修改前检出问题、修改后通过；不能据此认定 Max 编译和实际加载通过。
- 使用：目标 Max 2022，无新增依赖或外部资源；从磁盘重载 Init 并重新打开工具，无需重启。
- 依据：[加载错误记录](MaxZJTools/bugs/2026-10-13-zhr-load-errors.txt) 及 [实现/验证记录](MaxZJTools/integration-validation.txt) 的 v1.2.1 段。

## 2026-10-13 · v1.2.0 · 新增统一高度映射与对齐方式 · ZHeightToVertexRed 和操作界面 · 无需重启

**版本归属**：MaxZJTools v1.2.0；当时的 ZHeightToVertexRed v1.1.0。历史验证记录的段落标题带有 v1.2.0，工具版本以同段“实现检查”明确记录的 v1.1.0 为准。
**状态**：历史源码版本；定向静态检查完成，Max 运行未完成。

### GitHub 修改概要

```text
feat(ZHeightToVertexRed): 统一映射高度并支持跨模型对齐

- 默认以 1 米作为共同过渡跨度，支持同一世界高度或距各自底部高度对齐。
- 增加起始高度、范围限制和操作预览，不按各模型自身高度分别拉满灰度。
- 静态检查完成，Max 内运行与导出回读仍待验证。
```

### 改动与影响

- 将高度权重计算集中到统一映射函数；界面使用米制参数，保留原函数调用默认值及 G/B/Alpha。
- 增加选择数量、空选择保护、参数示意和处理明细；修改参数后需要再次写入。

### 验证与发布说明

- 验证：关键字/括号与菜单引用等定向检查通过；独立 Max 批处理受许可证错误阻断，未取得宿主 PASS。
- 使用：目标 Max 2022，无新增第三方依赖或需分发的外部资源；关闭重开工具，菜单版本刷新需重载 Init，无需重启。
- 依据：[实现/验证记录](MaxZJTools/integration-validation.txt) 的 v1.2.0 段；不将段落标题混作单工具版本。

## 2026-10-12 · v1.1.0 · 整合高度顶点色工具并修复菜单刷新 · 工具入口、初始化和说明 · 手动重载无需重启

**版本归属**：MaxZJTools v1.1.0；原 ZHeightToVertexRed 的独立工具版本在此记录中未确认，不补造版本号。
**状态**：历史源码集成完成；静态检查通过，Max 加载与写入验收待完成。

### GitHub 修改概要

```text
feat(MaxZJTools): 接入高度顶点色工具并完善菜单重载

- 将 ZHeightToVertexRed 接入 MaxZJTools 菜单，按需加载工具脚本。
- 修复重载时菜单刷新与清理异常处理，同步版本、入口说明和回归记录。
- 静态检查通过，Max 加载、写入及导出回读仍待验证。
```

### 改动与影响

- 保留原高度烘焙脚本，新增宏动作和相对路径加载；菜单清理失败时报告失败，不误报初始化成功。
- README 移除当前仓库不存在的关键帧工具条目，说明与实际菜单保持一致。

### 验证与发布说明

- 验证：当次定向静态检查、差异检查和原脚本指纹核对通过；独立 Max 启动未完成，未操作用户原有场景。
- 使用：目标验证宿主 Max 2022，无新增外部依赖；已有安装手动重载 Init 无需重启，首次安装的自动启动 Loader 需重启生效。
- 依据：[实现/验证记录](MaxZJTools/integration-validation.txt) 的 v1.1.0 段及原 README 历史快照。

## 2026-01-05 · v1.0.0 · 初始工具集记录 · 重命名功能与菜单版本管理 · 重启要求未记录

**版本归属**：MaxZJTools v1.0.0；单工具版本未记录。
**状态**：旧 README 标记为初始发布；没有足够资料确认 GitHub 发布链接、Tag 和当时验收情况。

### GitHub 修改概要

```text
feat(MaxZJTools): 建立初始工具集与菜单版本管理

- 提供重命名工具功能及统一菜单版本管理机制。
- 本条由旧 README 补录，历史运行验证和远端发布信息未记录。
```

### 改动与影响

- 保留原 README 可确认的重命名功能与菜单机制记录。
- 旧记录曾提到关键帧工具，但当前没有对应脚本或菜单，不将其补记为已实现功能。

### 验证与发布说明

- 验证：当时的语法、加载/卸载和宿主测试结果未记录。
- 使用：当时的目标 Max 版本、依赖、外部资源、安装及重启要求未记录；不以当前工具要求倒推历史版本。
- 依据：[原 README 的 v1.0.0 记录](MaxZJTools/Readme.txt)。

# AssetsMG 集成包版本记录

## 2026-10-13 · v1.0.0 · 新增独立集成包 · AssetsMG.VertexColorWriter 的入口、资源和命名隔离 · 通常无需重启

**版本归属**：AssetsMG.VertexColorWriter v1.0.0；功能基线 VertexColorWriter v1.4.0，来源 MaxZJTools v1.7.0；不改变原版版本。
**状态**：已生成本地集成候选包，独立检查通过；未在 AssetsMG 实际部署，Max 宿主验收待完成。

### GitHub 修改概要

```text
feat(AssetsMG.VertexColorWriter): 提供独立集成包 v1.0.0

- 隔离脚本全局标识、C# 类型、修改器和图标，提供被动入口及 Open/Close 接口。
- 随包提供资源、说明、校验和与共存用例，保留原版 MaxZJTools。
- 集成包独立检查通过；Max 实际共存与 AssetsMG 接入仍待验证，颜色显示差异未修复。
```

### 改动与影响

- 在 `integrations/AssetsMG/` 建立生成器和接入模板，从权威源码生成 `dist/AssetsMG-VertexColorWriter-1.0.0.zip`；不是直接将原工具整体改名。
- C# 使用 `AssetsMG.Tools.VertexColorWriter`，脚本使用 `AssetsMG_VCW_*`；修改器、回调、资源身份独立。两版写同一模型时仍共享模型通道数据。
- 包含 Entry/Launch、工具源码、图标、README、manifest、SHA-256、测试和已知问题；不包含 MaxZJTools 整套安装器和菜单。

### 验证与发布说明

- 验证：2026-10-13 的包清单/哈希/标识检查、两份 C# 类型同进程实例化及独立释放通过；集成版 UI 44 项、采样 41 项通过。Max 内加载/重载/关闭、模型写入、Undo、导出和 AssetsMG 自身入口仍待验收。
- 使用：目标 Max 2022，无新增第三方依赖；代码与图标随包，用户源图片不自动打包。AssetsMG 负责注册菜单，加载 Entry 后调用 Open；手工试用运行 Launch.ms。重载 Entry 并重开面板通常无需重启。
- 依据：[接入模板](integrations/AssetsMG/README.template.txt)、[生成器](integrations/AssetsMG/Build-Package.ps1)、[本地 manifest](dist/AssetsMG-VertexColorWriter-1.0.0/manifest.json) 和 [集成验证记录](MaxZJTools/integration-validation.txt)。无远端上传或正式部署凭据。
