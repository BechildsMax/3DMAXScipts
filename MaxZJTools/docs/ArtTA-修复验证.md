ArtTA 规范落地与本轮验证
========================

# 项目概览

日期：2026-10-23（Asia/Shanghai）。MaxZJTools v1.7.1 开发候选；基于本仓库提交 `2fcc2e6`，当前修改尚未提交/发布。用户授权：按前述评估建议实施。

依据是本地 ArtTA 文档 v0.2.0（2026-10-22，简化规则提案、待团队采纳），来源目录 `C:/Users/yuanzijian/Documents/ChatGPT/Gitlab/ArtTA开发规范/`。按本次场景批处理影响归为“标准”，骨骼恢复另做专项验证；不把 Unity、RoleCreator 接口、双版本 Unity 编译或 CI 部署机械套用到 MAXScript。项目 AGENTS.md 与真实宿主结果优先。

# 功能说明与使用流程

## 本轮需求与方案

菜单与面板沿用现有实现。修改权威源码 `tools/`、安装/版本入口、测试和说明；不修改 VertexColorWriter 功能、不生成 AssetsMG 包、不写真实资产文件。按“收集明确范围 → 检查/预览 → 写入 → 回读 → 如实报告/恢复”处理，不新增常驻框架。

| 对象 | 原问题与实现 | 恢复与验收重点 |
|---|---|---|
| RenameTools v1.2.1 | 空选择不回退全场景材质；节点/骨骼去重；预览清单与参数绑定，执行复查名称冲突 | 单批 Undo；部分失败分别计数，保存前检查 |
| MeshChecker v1.0.1 | 扫描和清理共享 PRS 叶轨道遍历；禁止未完成/陈旧扫描写入；阻断范围外共享控制器 | 清理后回读剩余关键帧，验证 Undo 的轨道与时间 |
| ReSetTexturesPath v1.0.1 | 显式扫描、子材质遍历和引用去重；旧/新路径预览、目标存在检查、冲突拒绝 | 只改引用；统计已改/找到/跳过/失败，缺失图片不覆盖路径 |
| BoneOverride（V4，未设独立语义版本） | 全部 Skin 使用者与静态控制器预检；转移全部正权重；通过后才迁移层级/改名/隐藏 | Hold 取消后核对恢复，另验真实变形和失败注入；不支持动画迁移 |
| Install / Init | 必需文件检查、Loader 暂存回读和唯一备份、失效路径诊断；从 version.ini 取版本 | 安装文件靠备份回退；不属于场景 Undo |

<whiteboard type="mermaid">
flowchart TD
    A[准备规则 现有代码与回归场景] --> B[明确写入范围和失败处理]
    B --> C[实现修复 更新工具说明]
    C --> D[静态检查与宿主用例]
    D --> E{真实宿主与恢复证据是否齐全?}
    E -->|否| F[保留开发候选 记录阻挡]
    E -->|是| G[非作者复核和实际候选包验收]
    G --> H[按授权发布 保留版本与回退记录]
</whiteboard>

工具参数、流程、输出、限制分别见 [重命名](RenameTools.md)、[动画检查](MeshChecker.md)、[贴图引用](ReSetTexturesPath.md)、[骨骼替换](BoneOverride.md)。不在此重复维护参数表。

# 安装与使用

保留完整包；已有安装重新运行 Init 后重开面板。安装器有改动，要验证其备份/路径诊断需手工运行 Install.ms，写入位置与卸载见 [总说明](../Readme.txt)。本次未在真实用户 startup 安装或更新 Loader。

宿主冒烟入口：`tests/LegacyTools_Smoke.ms`。只在新空场景或独立 3dsmaxbatch 运行；脚本拒绝非空场景，不 reset、不保存、不安装，结束清理自己的测试节点与临时图片。读取 `%TEMP%/MaxZJTools-LegacyTools-smoke.txt`，本轮新报告中的 `ALL PASS` 才表示脚本通过，旧报告或启动进程退出码不算证据。

定向静态检查（仓库根目录）：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File MaxZJTools/tests/Test-MaxScriptSource.ps1
```

ExecutionPolicy 仅用于当前进程，不修改机器策略。此脚本只检查指定源文件的关键字、括号和菜单参数，不是完整 MAXScript 语法解析器。

# 技术与兼容性

目标宿主继续保留 Max 2022，另尝试本机 Max 2024（26.2.0.22013）。无新增第三方依赖；使用 Max 内置 MAXScript、SkinOps、Hold 与 .NET。代码与说明采用 UTF-8 BOM + CRLF。

本轮运行证据：

| 检查 | 实际结果 | 证据/边界 |
|---|---|---|
| 定向静态检查 | 通过 | 覆盖四工具、Install、Init、新旧 smoke；非编译器 |
| 版本、文档引用、编码与差异 | 完成交付前核对 | 运行版本源 config/version.ini；四份工具说明与主日志同步 |
| Max 2024 独立批处理 | 未进入用例执行 | 2026-10-23 12:40:56 启动，12:41:19 报 `License Error: user canceled authorization`；未得到 Listener/测试报告 |
| Max 2022 | 本轮未执行 | 旧许可证错误是历史记录，不能当本轮结果 |
| 独立 C#/VertexColorWriter 回归 | 本轮未重跑 | 本轮未改该工具，不继承为本轮运行 PASS |
| 安装/重复加载/卸载 | 待宿主验证 | 未向用户目录部署 |
| 非作者复核、正式试用/发布 | 待完成 | 不声称满足 ArtTA 正式放行条件 |

前两次批处理仅停在启动阶段；第三次获取上述授权错误。所有本轮创建的 batch 进程已停止，未关闭用户其他 Max。启动证据留在 `tests/evidence/2026-10-23-max2024-startup.txt`，不据此推断脚本本身通过或失败。

API 核对依据：[Autodesk Undo 分组](https://help.autodesk.com/cloudhelp/2025/ENU/MAXScript-Help/files/MAXScript-Language-Reference/Names-Literal-Constants-and/Context-Expressions/GUID-C8517C4A-A75F-4D4E-A058-BE3EE61A2A11.html)、[Hold 事务](https://help.autodesk.com/cloudhelp/2025/ENU/MAXScript-Help/files/MAXScript-Tools-and-Interaction/Miscellaneous-Functions/GUID-17BFEAAF-3395-4FFB-9F98-54767481AB08.html)、[SkinOps](https://help.autodesk.com/cloudhelp/2021/ENU/3DSMax-MAXScript/files/GUID-0820AA26-920F-434D-A6BC-E8B6B57F54AC.htm)。文档核对不代替本机运行。

# 发布与更新规则

以下项目完成前保持开发候选，不标记稳定发布：

| 待验收项 | 可执行检查及预期 |
|---|---|
| 四工具基础回归 | 在目标 Max 运行 LegacyTools_Smoke.ms；空选择零写入、去重、陈旧范围拒绝、共享控制器拒绝、贴图缺失跳过、微小权重保留及 Undo 均通过 |
| 骨骼专项 | 两个 Skin 对象，第二个写入时注入异常；确认无新增骨骼残留、旧身份/层级及所有权重恢复，失败不报完成；还需负缩放、父子关系、实际变形和副本保存重开 |
| 边界输入 | 重名、同路径冲突、被删除对象、修改过的预览、非标准控制器、实例 Skin、遗漏 Skin 使用者均明确拒绝且不误写 |
| UI/生命周期 | 连续打开/关闭/重载两次、菜单不重复、结果计数准确、焦点恢复、不额外生成 Undo 步骤 |
| 安装/回退 | 备份已存在 Loader；新路径生效、缺文件/无权限有诊断、旧备份可恢复；卸载只移除本工具资源 |
| 版本覆盖 | 先完成主目标 Max 2022，再验实际要声明支持的 2024；不把双 Unity 版本要求写成 Max 已支持 |
| 人工复核 | 由非作者核对差异和运行记录，确认恢复与限制后才考虑合并/发布 |

恢复优先使用本批 Undo；骨骼失败有自动取消及回读，仍须留场景副本。回退源码使用配套旧工具包并重载；安装文件使用该次 .bak。已保存到资产里的修改不能靠回退源码自动撤销。

AssetsMG.VertexColorWriter v1.0.0 ZIP 未重新生成，仍对应原 MaxZJTools v1.7.0 / VCW v1.4.0 记录；该包不含本轮四工具，不能说它已经包含此次修复，也不能仅因工具包升版说 VCW 功能过时。没有上传、部署、Git 提交或推送。

# 更新日志

唯一主日志：[CHANGELOG](../../CHANGELOG.md)。实施进度沿用 [integration-validation.txt](../integration-validation.txt)，不新增平行模块档案。
