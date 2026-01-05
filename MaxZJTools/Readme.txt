MaxZJTools - 3ds Max工具集
===============================

版本: 1.0.0
日期: 2026-01-05

功能特性：
---------
✓ 自动清理旧版本菜单，避免重名问题
✓ 统一的MaxZJTools主菜单
✓ 模块化工具组织
✓ 支持版本迭代

安装方法：
---------
方法1 - 手动加载（测试用）：
1. 在3ds Max中，按F11打开MaxScript监听器
2. 执行：filein "d:\\work\\TA\\Study\\DCC\\3dmaxScripts\\3DMAXScipts\\MaxZJTools\\startup\\MaxZJTools_Init.ms"

方法2 - 自动启动（推荐）：
1. 找到3ds Max的Startup文件夹：
   通常位于：C:\Program Files\Autodesk\3ds Max [版本]\scripts\Startup\
   或：%userprofile%\AppData\Local\Autodesk\3dsMax\[版本]\ENU\scripts\Startup\

2. 在Startup文件夹中创建文件：MaxZJTools_Startup.ms

3. 文件内容：
   filein "d:\\work\\TA\\Study\\DCC\\3dmaxScripts\\3DMAXScipts\\MaxZJTools\\startup\\MaxZJTools_Init.ms"

4. 重启3ds Max

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
├── startup/
│   └── MaxZJTools_Init.ms      # 主初始化脚本
├── tools/
│   ├── RenameTools.ms          # 重命名工具
│   └── KeyframeTools.ms        # 关键帧工具
├── config/
│   └── version.ini             # 版本信息
└── README.txt                  # 本文件

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