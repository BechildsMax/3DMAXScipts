AssetsMG · 定点色写入工具集成说明
================================

# 项目概览

集成包 v1.0.0，功能基线 VertexColorWriter v1.4.0，来源 MaxZJTools v1.7.0。
用于 AssetsMG 在自己的工具库中加载；与 MaxZJTools 原版使用不同的运行标识。
本包包含源码、图标、参数说明、已知问题与验证脚本，不包含 MaxZJTools 安装器或菜单初始化脚本。
交接状态：独立包检查、44 项 UI 与 41 项采样检查通过；真实 3ds Max / AssetsMG 集成验收仍待完成。
未连接或修改 AssetsMG 源项目。

# 功能说明与使用流程

## 定点色写入工具 · VertexColorWriter

### 菜单/入口

AssetsMG 的菜单或按钮先加载 Entry.ms，再调用 AssetsMG_VCW_Open()。
Entry.ms 本身不打开面板；手动试用可运行 Launch.ms。窗口标题带 AssetsMG，便于区分两版。
关闭调用 AssetsMG_VCW_Close()，也可点击窗口关闭按钮。
本包不自行创建菜单、工具栏、宏动作或 startup Loader，由 AssetsMG 按自己的规范注册。

{{FEATURES}}

# 安装与使用

将完整文件夹复制到 AssetsMG 指定的工具目录，不能只复制 .ms。
以下路径仅为示例，接入时替换为实际绝对路径：

```maxscript
-- 加载接口，不弹窗
fileIn @"D:\AssetsMG\Tools\VertexColorWriter\Entry.ms"

-- AssetsMG 菜单按钮触发
AssetsMG_VCW_Open()

-- AssetsMG 关闭/卸载工具面板时触发
AssetsMG_VCW_Close()
```

| 接入接口/资源 | 参数与默认行为 | 影响与约束 | 撤销/清理 |
|---|---|---|---|
| Entry.ms | 从实际文件位置记录包根目录；无用户参数 | 只定义接口，不注册菜单、不打开窗口、不写用户目录 | 重新加载可更新路径；不用 Ctrl+Z |
| AssetsMG_VCW_Open() | 无参数；首次编译同目录 C# | 打开本版面板；重复调用只关闭并重开本版面板，参数恢复默认 | 关闭面板释放控件/计时器/图标并注销本版回调 |
| AssetsMG_VCW_Close() | 无参数；没有窗口时可重复调用 | 只关闭本版面板，不撤销模型颜色，不关闭 MaxZJTools 面板 | 场景改动仍需 Ctrl+Z 或管理修改器 |
| 图标 | icons/AssetsMG_VertexColorWriter.png；Dark/Light/AssetsMG 下各七个尺寸 | 面板加载包内 Dark 32px；AssetsMG 可自行使用其他尺寸 | 不自动复制到 Max 用户图标目录；缺图时面板有内置回退 |
| 源贴图 | 用户手工选择单张图片 | 本包不会搜索、复制或自动打包美术资源；再次烘焙需要图片 | 图片只读；已经写入的修改器数据不依赖源图 |

目录结构：
  Entry.ms / Launch.ms
  tools/AssetsMG_VertexColorWriter.ms
  tools/AssetsMG_VertexColorWriterUI.cs
  tools/AssetsMG_VertexColorWriterTexture.cs
  icons/AssetsMG_VertexColorWriter.png
  icons/Dark/AssetsMG/VertexColorWriter_{16,24,30,32,36,48,64}.png
  icons/Light/AssetsMG/VertexColorWriter_{16,24,30,32,36,48,64}.png
  tests/、README.txt、已知问题-颜色显示.txt、manifest.json、SHA256SUMS.txt

安装/迁移不修改 Max 程序目录，也不调用 MaxZJTools/Install.ms。
如果 AssetsMG 需要 Max 宏动作，建议类别 AssetsMG、动作名 AssetsMG_VertexColorWriter；本包尚未注册该动作。
卸载时先调用 Close，再由 AssetsMG 移除自己的入口和包目录；不会删除场景中已有修改器。
更新源码后重新 Open 即可；通常无需重启。内存中的旧 C# 程序集会保留到 Max 进程退出，不能单独卸载。

# 技术与兼容性

目标宿主：3ds Max 2022 / Windows。依赖 Max 内置 mesh/meshop、ChannelInfo、Turn_to_Mesh、UVW_Mapping_Paste、
WinForms 与 System.Drawing。无第三方库，不分发 DLL；.cs 在首次打开时编译到内存。
保留 Max 2026+ CSharpCompilationHelper 分支，但未实测，不宣称覆盖所有 Max 版本。
正文 12 pt，面板内容基准 860×808；实际 Max 内 DPI、键盘焦点和高分屏仍需目标环境验证。

隔离映射：
| 范围 | MaxZJTools 原版 | 本集成版 |
|---|---|---|
| MAXScript 全局状态/函数/窗口/回调 | VCW_* | AssetsMG_VCW_* |
| 旧版兼容别名 | ZHR_* | 不声明、不改写、不关闭旧窗口 |
| C# namespace | MaxZJTools.VertexColorWriter | AssetsMG.Tools.VertexColorWriter |
| 修改器识别 | VCW - RGB / Alpha / Mesh Adapter；兼容 ZHR | AssetsMG VCW - RGB / Alpha / Mesh Adapter；不复用原版标识 |
| 临时节点 | __VCW_TEMP__ | __AssetsMG_VCW_TEMP__ |
| 图标分组 | Dark/Light/MaxZJTools | Dark/Light/AssetsMG |
| 撤销组 | VertexColorWriter | AssetsMG VertexColorWriter |

上述修改隔离运行标识。两版写同一个模型时，仍操作同一份 RGB（map 0）和 Alpha（map -2）。
本版保留另一版的修改器，不自动接管或删除；叠加写入会新增自己的修改器组，最终颜色按当前栈求值。
局部选点时，另一版的修改器算作其他修改器；需在其上方的 Edit Poly / Edit Mesh 选点，避免编号错位。
ChannelInfo 内部缓冲区、场景选择、撤销栈及 Max 快捷键开关属于宿主共享状态，命名隔离不能令其私有化；
两版不应并行/重入写入场景，两个面板的焦点切换和关闭順序需实际验证。
标尺只画缓存，不增加场景对象；两版同时开标尺可能重叠，可关闭其中一个。
本工具不执行导出；写入结果的 FBX/Unity RGB/Alpha 支持需要目标管线回读验证。

已知问题：固定填色当前采用 RGB/255 原值，尚未增加显示色到线性颜色的转换和无光照检查模式。
视口 Gamma/颜色管理、光照及局部顶点插值可能让色块与模型看起来不同；完整调查见 已知问题-颜色显示.txt。
本次只处理打包隔离，没有声称修复上一轮颜色显示差异，也没有改变高度遮罩数值约定。

# 发布与更新规则

仓库维护以根目录 CHANGELOG.md 为唯一主日志，按 AGENTS.md 的“统一 Changelog 规则”记录集成包独立版本及 GitHub 修改概要。
包内“更新日志”从主日志的对应集成版本摘取；生成新版包前同步本模板，不独立编写另一条版本历史。独立包可直接阅读下方摘录，无需访问仓库路径。
集成包与原工具分别维护版本：修复升 patch，新功能升 minor，破坏接入接口升 major。
包内 manifest.json 记录版本、命名空间、功能基线与源文件 SHA-256；SHA256SUMS.txt 校验交付文件。
由仓库 integrations/AssetsMG/Build-Package.ps1 从原工具生成，避免手工维护两份不同逻辑的代码。
生成器执行前后校验原输入哈希；隔离转换规则不匹配新源码时中断，不静默漏改。

独立检查（Windows PowerShell 5.1 -STA）：
  powershell.exe -NoProfile -STA -File tests/Test-Package.ps1
  powershell.exe -NoProfile -STA -File tests/Test-VertexColorWriterUI.ps1
  powershell.exe -NoProfile -File tests/Test-VertexColorWriterTexture.ps1
Test-Package.ps1 可传 -OriginalToolRoot <MaxZJTools目录>，同时编译两份 C# 检查类型隔离与分别关闭。
2026-10-13 已执行上述三类独立检查：包清单/校验和/标识扫描通过；两份 C# 同进程实例化、状态独立及分别释放通过；
集成版 UI 44 项、贴图读取/采样 41 项通过。生产源文件哈希与生成前一致。
这些检查不运行 MAXScript，不等于已通过 Max 场景写入或实际加载/卸载验收。

交付前/集成后仍需在目标宿主的新建空场景中验证：
1. 指定原工具路径后运行 tests/AssetsMG_Coexistence_Smoke.ms：两版加载、重载、关闭、回调和修改器相互保留。
2. 运行 tests/VertexColorWriter_Selection_Smoke.ms、VertexColorWriter_Texture_Smoke.ms、VertexColorWriter_Height_Smoke.ms。
3. 人工检查 AssetsMG 入口/图标/完整资源路径、不同加载与关闭順序、焦点/快捷键、DPI 和标尺开关。
4. 验证批次 Ctrl+Z、RGBA/UV 接缝及目标导出器回读；确认颜色显示已知限制适合使用场景。
5. Close 后移除 AssetsMG 入口，确认 MaxZJTools 仍可打开；迁移包目录后重新加载 Entry。
Max 宿主测试此前被独立批处理的许可证错误阻断，本包附用例但没有宿主 PASS 证据。

共存测试路径设置示例（必须是新建空场景、两版窗口均关闭，示例路径需替换）：
```maxscript
AssetsMG_VCW_TestOriginalPath = @"D:\MyTools\MaxZJTools\tools\VertexColorWriter.ms"
fileIn @"D:\AssetsMG\Tools\VertexColorWriter\tests\AssetsMG_Coexistence_Smoke.ms"
```

# 更新日志

2026-10-13 · v1.0.0 · 新增 AssetsMG 独立接入包，隔离全局状态/C# 类型/修改器与图标，提供 Open/Close 接口 · 集成副本、资源、说明和回归；原工具不变 · 重载 Entry 并重开面板，通常无需重启

GitHub 修改概要（摘自统一日志）：
```text
feat(AssetsMG.VertexColorWriter): 提供独立集成包 v1.0.0

- 隔离脚本全局标识、C# 类型、修改器和图标，提供被动入口及 Open/Close 接口。
- 随包提供资源、说明、校验和与共存用例，保留原版 MaxZJTools。
- 集成包独立检查通过；Max 实际共存与 AssetsMG 接入仍待验证，颜色显示差异未修复。
```
