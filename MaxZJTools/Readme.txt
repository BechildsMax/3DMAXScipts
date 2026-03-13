MaxZJTools - 3ds Max工具集
===============================

版本: 1.0.2
日期: 2026-03-13

功能特性：
---------
✓ 自动清理旧版本菜单，避免重名问题
✓ 统一的MaxZJTools主菜单
✓ 模块化工具组织
✓ 支持版本迭代

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
- 换电脑或重装 3ds Max 后，重新运行 Install.ms 即可

卸载方法：
---------
删除 3ds Max startup 目录中的 MaxZJTools_Loader.ms 文件：
  %LOCALAPPDATA%\Autodesk\3dsMax\[版本]\ENU\scripts\startup\MaxZJTools_Loader.ms

手动加载（临时测试用）：
---------
在 3ds Max 中按 F11 打开 MaxScript 监听器，执行：
  fileIn @"[本文件夹路径]\startup\MaxZJTools_Init.ms"

包含工具：
---------
1. 重命名工具 (RenameTools)
   - 添加前缀/后缀
   - 查找替换
   - 批量重命名（带编号）
   - 大小写转换
   - 删除前缀/后缀/数字

2. 关键帧工具 (KeyframeTools)
   - 设置/删除关键帧
   - 烘焙动画
   - 时间缩放
   - 关键帧偏移
   - 关键帧优化

版本管理说明：
-------------
每次加载脚本时，会自动检测并清理旧版本的MaxZJTools菜单，
确保菜单栏中只有一个MaxZJTools菜单，避免版本迭代导致的重名问题。

更新流程：
1. 替换新版本文件
2. 重新执行 MaxZJTools_Init.ms
3. 旧菜单会自动清理，新菜单自动创建

文件结构：
---------
MaxZJTools/
├── Install.ms                  # 一键安装脚本（首次使用时运行）
├── Readme.txt                  # 本文件
├── startup/
│   └── MaxZJTools_Init.ms      # 主初始化脚本（由安装脚本自动引导）
├── tools/
│   ├── RenameTools.ms          # 重命名工具
│   ├── ReSetTexturesPath.ms    # 贴图路径重设工具
│   ├── MeshChecker.ms          # Mesh动画检查工具
│   └── BoneOverride.ms         # 单骨骼替换工具
└── config/
    └── version.ini             # 版本信息

技术支持：
---------
如有问题或建议，请联系开发者。

更新历史：
---------
v1.0.0 (2026-01-05)
- 初始版本发布
- 重命名工具完整功能
- 关键帧工具完整功能
- 菜单版本管理机制