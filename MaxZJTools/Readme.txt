MaxZJTools - 3ds Max工具集
===============================

版本: 1.7.0
日期: 2026-10-13

# 项目概览

功能特性：
---------
✓ 自动清理旧版本菜单，避免重名问题
✓ 统一的MaxZJTools主菜单
✓ 模块化工具组织
✓ 支持版本迭代

# 功能说明与使用流程

包含工具：
---------
1. 重命名工具 (RenameTools)
   - 添加前缀/后缀
   - 查找替换
   - 批量重命名（带编号）
   - 大小写转换
   - 删除前缀/后缀/数字

2. 贴图路径重设 (ReSetTexturesPath)
3. Mesh动画检查 (MeshChecker)
4. 单骨骼替换 (BoneOverride)
5. 定点色写入工具 (VertexColorWriter)
   - 入口：MaxZJTools > 定点色写入工具 > 对应动作
   - 可设置统一映射高度（默认 1 米），选择按世界高度或各自底部对齐灰度
   - RGBA 独立勾选，支持双色高度渐变或固定颜色；未选通道保留，支持撤销
   - 12 pt 字体与纵向预览；说明见 tools/VertexColorWriter-使用说明.txt
   - 单选显示模型的世界 Z 高度，可开关视口标尺；测量只读，不创建修改器或导出对象
   - 新增贴图写入：按 UV 采样 PNG/JPG/BMP/TGA，支持颜色/遮罩、双线性/最近点和截取/平铺
   - 面板与入口使用绿色扁平图标；保留文字，提供深浅主题与多尺寸版本
   - 写入范围可选“整个模型 / 选中顶点”，三种模式均支持局部填充；实时显示点数，保留未选顶点的颜色

完整参数、流程图、输出与限制见 tools/VertexColorWriter-使用说明.txt。
在线美术使用指南（飞书）：https://t6bdpf8yjg.feishu.cn/docx/NTends7mso2kijx79Q5cWL3mnOf

# 安装与使用

安装方法：
---------
【推荐】一键安装（Install.ms）：

1. 打开 3ds Max
2. 将 Install.ms 拖入 3ds Max 视口
   或菜单：Scripting > Run Script，选择 Install.ms
3. 出现"安装成功"提示后，重启 3ds Max
4. 菜单栏将自动出现 MaxZJTools 菜单

说明：
- 安装脚本会自动识别当前机器的 3ds Max 版本和路径，无需手动填写任何路径
- 安装内容只有一个小文件（MaxZJTools_Loader.ms）写入 3ds Max 的 startup 目录
- 本工具包的所有脚本文件保留在原目录，不会被复制或移动
- 初始化脚本会将 VertexColorWriter 的 14 个 PNG 复制到 Max 用户图标目录，注册入口图标；其他资源仍使用包内路径
- 换电脑或重装 3ds Max 后，重新运行 Install.ms 即可

卸载方法：
---------
删除 3ds Max startup 目录中的 MaxZJTools_Loader.ms 文件：
  %LOCALAPPDATA%\Autodesk\3dsMax\[版本]\ENU\scripts\startup\MaxZJTools_Loader.ms
可另行删除 getDir #userIcons 下 Dark/MaxZJTools 与 Light/MaxZJTools 中本工具的 VertexColorWriter PNG，重启 Max 完成卸载。

手动加载（临时测试用）：
---------
在 3ds Max 中按 F11 打开 MaxScript 监听器，执行：
  fileIn @"[本文件夹路径]\startup\MaxZJTools_Init.ms"

文件结构：
---------
MaxZJTools/
├── Install.ms                  # 一键安装脚本（首次使用时运行）
├── Readme.txt                  # 本文件
├── icons/                     # VertexColorWriter 主图标、深浅主题多尺寸资源与生成说明
├── startup/
│   └── MaxZJTools_Init.ms      # 主初始化脚本（由安装脚本自动引导）
├── tools/
│   ├── RenameTools.ms          # 重命名工具
│   ├── ReSetTexturesPath.ms    # 贴图路径重设工具
│   ├── MeshChecker.ms          # Mesh动画检查工具
│   ├── BoneOverride.ms         # 单骨骼替换工具
│   ├── VertexColorWriter.ms    # 定点色写入工具
│   ├── VertexColorWriterUI.cs  # 同目录界面源码（必须保留）
│   ├── VertexColorWriterTexture.cs # 同目录图片读取与采样源码（必须保留）
│   ├── VertexColorWriter-使用说明.txt
│   ├── ZHeightToVertexRed.ms    # 旧文件兼容入口
│   └── ZHeightToVertexRed-使用说明.txt
└── config/
    └── version.ini             # 版本信息

# 技术与兼容性

v1.7.0 提供高度渐变、固定颜色、贴图写入三种 RGBA 模式、局部顶点填充及只读高度测量。目标验证宿主为 3ds Max 2022；
其他版本尚未验证。依赖 Max 内置 mesh/ChannelInfo、Turn_to_Mesh、UVW_Mapping_Paste
及现有 menuMan 菜单接口；界面依赖内置 .NET WinForms/System.Drawing，无第三方库。
必须保留同目录 VertexColorWriterUI.cs 与 VertexColorWriterTexture.cs，首次打开编译到内存。
贴图模式使用模型已有 UV（默认通道 1），完整颜色勾选 RGB；灰度数值/遮罩选择“遮罩”。
局部填充：单选模型，在 Editable Mesh / Poly 或 Edit Mesh / Poly 顶点模式选点，范围选“选中顶点”，确认点数后写入。
只支持连接网格面的硬选择；选点层上方若有其他修改器，需在栈顶添加 Edit Poly / Mesh 后选点。空选禁用，三种模式都保留未选顶点。
贴图文件只读，不自动打包；已有写入结果不依赖图片，再次烘焙需重新选择源图片。顶点密度决定能保留的细节。
工具包整体保留原目录；安装器只注册启动 Loader，初始化脚本注册随包入口 PNG，不自动打包其他依赖。
首次安装/迁移目录后运行 Install.ms；已有安装可重新运行 startup/MaxZJTools_Init.ms。
发布前检查：连续加载两次菜单仅保留一份、新入口可反复打开关闭、旧入口可用；
按工具说明验证烘焙、撤销和资源路径。卸载时删除 Loader 并重启，不会删除场景修改器。
本次检查记录见 integration-validation.txt。
重载初始化脚本后重新打开面板；工具栏若缓存旧图标可重启 Max。图标缺失不阻止面板与颜色写入使用。
本轮独立 UI 44 项与定向静态检查通过；读取器此前独立采样 41 项通过，本轮未改读取器。
Max 宿主测试受此前许可证错误阻挡，新增局部网格写入/Undo/导出验收仍待完成，测试脚本见 tests/VertexColorWriter_Selection_Smoke.ms。

# 发布与更新规则

项目规则入口：仓库根目录 ../AGENTS.md。后续输出给 AssetsMG 的工具默认遵守其中“AssetsMG 集成输出”约定。
统一版本日志：../CHANGELOG.md；每次实际改动交付前更新，并提供可复制到 GitHub 的“标题 + 修改概要”。
具体格式、版本归属、纯文档维护和发布状态按 AGENTS.md 的“统一 Changelog 规则”执行。
原版功能源码保留在 MaxZJTools；在 ../integrations/AssetsMG/ 维护接入模板与生成器，输出到 ../dist/。
不得直接改写原版 namespace 来制作交付版，也不得只手工修改输出副本；集成包使用独立名称、入口、资源标识和版本。
VertexColorWriter 当前生成器为 ../integrations/AssetsMG/Build-Package.ps1，-Archive 生成 ZIP；先按规则完成本轮适用验证。
纯文档维护记入统一日志的未发布区，不提升运行工具版本；生成新版集成包时另按规则更新，现有 ZIP 不自动重打包。

版本管理说明：
-------------
每次加载脚本时，会自动检测并清理旧版本的MaxZJTools菜单，
确保菜单栏中只有一个MaxZJTools菜单，避免版本迭代导致的重名问题。

更新流程：
1. 替换新版本文件
2. 重新执行 MaxZJTools_Init.ms
3. 旧菜单会自动清理，新菜单自动创建

版本遵循语义化版本：修复升 patch，新增功能升 minor，破坏兼容升 major。

# 更新日志

完整版本迭代及每版 GitHub 修改概要见 ../CHANGELOG.md。
以下保留截至 2026-10-13 的历史快照；后续版本统一记录到主日志，不在此独立追加。

2026-10-13 · v1.7.0 · 新增整个模型/选中顶点范围、三模式局部 RGBA 填充、选点计数与空选保护 · VertexColorWriter v1.4.0、UI、核心与说明 · 重载 Init 并重开面板，无需重启

2026-10-13 · v1.6.0 · 新增 VertexColorWriter 面板与入口图标，增加深浅主题多尺寸 PNG 与用户图标注册 · 工具 v1.3.0、资源、UI 和初始化 · 重载 Init 并重开面板；旧图标缓存未刷新时重启

2026-10-13 · v1.5.0 · 新增贴图写入、UV 面角采样、颜色/遮罩用途、采样及越界选项和原图预览 · VertexColorWriter v1.2.0、读取器、界面及说明 · 重载 Init 并重开窗口，无需重启

2026-10-13 · v1.4.0 · 新增只读模型高度与可开关视口标尺，关闭时清理且不创建场景实体 · VertexColorWriter、界面与测试说明 · 重载 Init 并重开窗口，无需重启

2026-10-13 · v1.3.0 · 更名 VertexColorWriter，放大字体、纵向预览、RGBA 通道及渐变/固定填色 · 工具与界面资源；保留旧入口 · 重载 Init 并重开窗口，无需重启

2026-10-13 · v1.2.1 · 修复高度映射脚本关键字命名和旧菜单按序号删除错误，补充静态回归检查 · 工具加载与菜单重载 · 从磁盘重载 Init 并重开工具，无需重启

2026-10-13 · v1.2.0 · 新增可设置映射高度、世界/底部对齐、范围限制及美术友好界面 · ZHeightToVertexRed 与版本说明 · 关闭工具重开即可；菜单版本需重载 Init，无需重启

2026-10-12 · v1.1.0 · 整合 ZHeightToVertexRed 菜单动作，修复重载不刷新菜单及清理异常处理，同步版本信息 · 菜单初始化、工具入口及文档 · 手动重载无需重启；自动启动加载需重启

v1.0.0 (2026-01-05)
- 初始版本发布
- 重命名工具完整功能
- 旧记录曾列关键帧工具；当前仓库没有对应脚本或菜单，不作为已实现功能列出
- 菜单版本管理机制
