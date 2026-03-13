-- Install.ms
-- MaxZJTools 一键安装脚本
-- 在 3ds Max 中运行此脚本即可完成安装（拖入视口 或 Scripting > Run Script）

(
    -- 获取本脚本所在目录（即项目根目录）
    local installDir = getFilenamePath (getThisScriptFilename())
    
    -- 要写入的 Loader 内容：绝对路径指向工作目录中的 Init 脚本
    local initPath = installDir + "startup\\MaxZJTools_Init.ms"
    
    -- 校验 Init 脚本是否存在
    if not (doesFileExist initPath) then
    (
        messageBox ("安装失败：找不到主脚本\n" + initPath) title:"MaxZJTools 安装"
        return()
    )
    
    -- 获取 3ds Max 用户 startup 目录（自动适配当前版本）
    local startupDir = getDir #userStartupScripts
    local loaderFile = startupDir + "\\MaxZJTools_Loader.ms"
    
    -- 写入 Loader 文件
    local f = createFile loaderFile
    if f == undefined then
    (
        messageBox ("安装失败：无法写入文件\n" + loaderFile + "\n\n请检查目录权限。") title:"MaxZJTools 安装"
        return()
    )
    
    format "fileIn @\"%\"\n" initPath to:f
    close f
    
    -- 安装成功提示
    local msg = "安装成功！\n\n"
    msg += "已创建引导文件：\n"
    msg += loaderFile + "\n\n"
    msg += "指向主脚本：\n"
    msg += initPath + "\n\n"
    msg += "请重启 3ds Max，工具菜单将自动出现在菜单栏。"
    
    messageBox msg title:"MaxZJTools 安装完成"
)
