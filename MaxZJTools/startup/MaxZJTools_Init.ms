-- MaxZJTools_Init.ms
-- 主菜单初始化脚本 - 避免版本迭代导致的重名菜单问题
-- 作者: MaxZJ
-- 包版本从 config/version.ini 读取
-- 日期: 2026-10-23

(
    global MaxZJTools_MenuName = "MaxZJTools"
    local packageRoot = getFilenamePath (getThisScriptFilename()) + "..\\"
    local versionFile = packageRoot + "config\\version.ini"
    global MaxZJTools_Version = getINISetting versionFile "Version" "Version"
    global MaxZJTools_VersionDate = getINISetting versionFile "Version" "Date"
    if not ((dotNetClass "System.Text.RegularExpressions.Regex").IsMatch MaxZJTools_Version "^[0-9]+\\.[0-9]+\\.[0-9]+$") do throw "MaxZJTools: config/version.ini 缺失或版本无效。"
    -- 在 startup 脚本执行时计算工具目录，避免 macroscript 内 getThisScriptFilename() 返回 usermacros 路径
    global MaxZJTools_ToolsPath = getFilenamePath (getThisScriptFilename()) + "..\\tools\\"

    -- Register only this package's own PNGs; never write to the Max program directory.
    -- iconName resolves these per-theme folders below #userIcons (Max 2017+).
    fn RegisterVertexColorWriterIcons =
    (
        local sourceRoot = MaxZJTools_ToolsPath + "..\\icons\\"
        local fileAPI = dotNetClass "System.IO.File"
        local convertAPI = dotNetClass "System.Convert"
        local changed = 0
        for theme in #("Dark","Light") do
        (
            local sourceDir = sourceRoot + theme + "\\MaxZJTools\\"
            local targetDir = (getDir #userIcons) + "\\" + theme + "\\MaxZJTools\\"
            for size in #(16,24,30,32,36,48,64) do
            (
                local name = "VertexColorWriter_" + (size as string) + ".png"
                local sourcePath = sourceDir + name
                local targetPath = targetDir + name
                try
                (
                    if not (doesFileExist sourcePath) do throw ("Missing icon: " + sourcePath)
                    local needsCopy = not (doesFileExist targetPath)
                    if not needsCopy do
                        needsCopy = (convertAPI.ToBase64String (fileAPI.ReadAllBytes sourcePath)) != (convertAPI.ToBase64String (fileAPI.ReadAllBytes targetPath))
                    if needsCopy do
                    (
                        makeDir targetDir all:true
                        fileAPI.Copy sourcePath targetPath true
                        changed += 1
                    )
                )
                catch (format "[MaxZJTools] Optional icon registration: %\n" (getCurrentException()))
            )
        )
        if changed > 0 do
        (
            try (colorMan.reInitIcons()) catch (format "[MaxZJTools] Icon cache refresh: %\n" (getCurrentException()))
            format "[MaxZJTools] Registered % VertexColorWriter icon files.\n" changed
        )
    )
    try (RegisterVertexColorWriterIcons()) catch (format "[MaxZJTools] Optional icons unavailable: %\n" (getCurrentException()))
    
    -- 定义菜单动作（总是重新定义，确保使用最新版本）
    macroscript MaxZJTools_RenameTools
        category:"MaxZJTools"
        tooltip:"节点重命名工具"
    (
        local toolPath = MaxZJTools_ToolsPath + "RenameTools.ms"
        
        if doesFileExist toolPath then
        (
            fileIn toolPath
        )
        else
        (
            messageBox ("找不到 RenameTools.ms 文件\n路径: " + toolPath) title:"错误"
        )
    )
    
    macroscript MaxZJTools_ReSetTexturesPath
        category:"MaxZJTools"
        tooltip:"贴图路径重设工具"
    (
        local toolPath = MaxZJTools_ToolsPath + "ReSetTexturesPath.ms"
        
        if doesFileExist toolPath then
        (
            fileIn toolPath
        )
        else
        (
            messageBox ("找不到 ReSetTexturesPath.ms 文件\n路径: " + toolPath) title:"错误"
        )
    )
    
    macroscript MaxZJTools_MeshChecker
        category:"MaxZJTools"
        tooltip:"Mesh动画检查工具"
    (
        local toolPath = MaxZJTools_ToolsPath + "MeshChecker.ms"
        
        if doesFileExist toolPath then
        (
            fileIn toolPath
        )
        else
        (
            messageBox ("找不到 MeshChecker.ms 文件\n路径: " + toolPath) title:"错误"
        )
    )
    
    macroscript MaxZJTools_BoneOverride
        category:"MaxZJTools"
        tooltip:"单骨骼替换工具"
    (
        local toolPath = MaxZJTools_ToolsPath + "BoneOverride.ms"
        
        if doesFileExist toolPath then
        (
            fileIn toolPath
        )
        else
        (
            messageBox ("找不到 BoneOverride.ms 文件\n路径: " + toolPath) title:"错误"
        )
    )
    
    macroscript MaxZJTools_VertexColorWriter
        category:"MaxZJTools"
        tooltip:"定点色写入工具"
        buttonText:"定点色写入工具"
        iconName:"MaxZJTools/VertexColorWriter"
    (
        local toolPath = MaxZJTools_ToolsPath + "VertexColorWriter.ms"

        if doesFileExist toolPath then
        (
            fileIn toolPath
        )
        else
        (
            messageBox ("找不到 VertexColorWriter.ms 文件\n路径: " + toolPath) title:"错误"
        )
    )

    -- 保留旧动作标识，已有快捷键和工具栏按钮仍可调用。
    macroscript MaxZJTools_ZHeightToVertexRed
        category:"MaxZJTools"
        tooltip:"定点色写入工具（兼容旧入口）"
        iconName:"MaxZJTools/VertexColorWriter"
    (
        macros.run "MaxZJTools" "MaxZJTools_VertexColorWriter"
    )
    macroscript MaxZJTools_About
        category:"MaxZJTools"
        tooltip:"关于 MaxZJTools"
    (
        local versionStr = MaxZJTools_Version
        local aboutText = "MaxZJTools\n"
        aboutText += "版本: " + versionStr + "\n\n"
        aboutText += "专业的3ds Max工具集合\n\n"
        aboutText += "包含工具：\n"
        aboutText += "- 节点重命名工具\n"
        aboutText += "- 贴图路径重设工具\n"
        aboutText += "- Mesh动画检查工具\n"
        aboutText += "- 单骨骼替换工具\n"
        aboutText += "- 定点色写入工具\n\n"
        aboutText += "作者: MaxZJ\n"
        aboutText += "日期: " + MaxZJTools_VersionDate
        
        messageBox aboutText title:"关于 MaxZJTools"
    )
    
    format "[MaxZJTools] macroscript 已更新到版本 %\n" MaxZJTools_Version
    
    -- 从后向前按序号删除，避免删掉一个菜单后后续序号移动。
    fn CleanupOldMenus menuName =
    (
        local mainMenuBar = menuMan.getMainMenuBar()
        if mainMenuBar == undefined do throw "无法获取 3ds Max 主菜单栏。"
        local removedCount = 0
        for itemIndex = mainMenuBar.numItems() to 1 by -1 do
        (
            local menuItem = mainMenuBar.getItem itemIndex
            if menuItem != undefined do
            (
                if menuItem.getTitle() == menuName do
                (
                    -- removeItem 接收菜单项对象；序号必须传给 removeItemByPosition。
                    local countBefore = mainMenuBar.numItems()
                    mainMenuBar.removeItemByPosition itemIndex
                    if mainMenuBar.numItems() != countBefore - 1 do
                        throw ("旧菜单未能移除，位置：" + (itemIndex as string))
                    removedCount += 1
                )
            )
        )
        menuMan.updateMenuBar()
        format "[MaxZJTools] 已移除 % 个旧菜单\n" removedCount
        removedCount
    )
    -- 创建主菜单
    fn CreateMainMenu = 
    (
        -- 每次加载先清理旧菜单，使新增工具立即出现在菜单中。
        CleanupOldMenus MaxZJTools_MenuName

        -- 清理失败时保留现有菜单并报告错误，避免重复创建。
        local mainMenuBar = menuMan.getMainMenuBar()
        local menuExists = false
        
        for i = 1 to mainMenuBar.numItems() do
        (
            local item = mainMenuBar.getItem i
            if item != undefined then
            (
                local itemTitle = try (item.getTitle()) catch (undefined)
                if itemTitle == MaxZJTools_MenuName then
                (
                    menuExists = true
                    format "[MaxZJTools] 旧菜单未能移除\n"
                    exit
                )
            )
        )
        
        -- 不将清理失败误报为更新成功。
        if menuExists then
        (
            throw "MaxZJTools: could not remove the old menu. Restart 3ds Max and try again."
        )
        
        -- 创建主菜单
        local mainMenu = menuMan.createMenu MaxZJTools_MenuName
        
        -- 创建重命名工具子菜单
        local renameMenu = menuMan.createMenu "重命名工具"
        local renameAction = menuMan.createActionItem "MaxZJTools_RenameTools" "MaxZJTools"
        renameMenu.addItem renameAction -1
        local renameToolsMenu = menuMan.createSubMenuItem "重命名工具" renameMenu
        
        -- 创建贴图路径重设工具子菜单
        local textureMenu = menuMan.createMenu "贴图路径重设"
        local textureAction = menuMan.createActionItem "MaxZJTools_ReSetTexturesPath" "MaxZJTools"
        textureMenu.addItem textureAction -1
        local textureToolsMenu = menuMan.createSubMenuItem "贴图路径重设" textureMenu
        
        -- 创建Mesh检查工具子菜单
        local meshMenu = menuMan.createMenu "Mesh动画检查"
        local meshAction = menuMan.createActionItem "MaxZJTools_MeshChecker" "MaxZJTools"
        meshMenu.addItem meshAction -1
        local meshToolsMenu = menuMan.createSubMenuItem "Mesh动画检查" meshMenu
        
        -- 创建单骨骼替换工具子菜单
        local boneMenu = menuMan.createMenu "BoneOverride"
        local boneAction = menuMan.createActionItem "MaxZJTools_BoneOverride" "MaxZJTools"
        boneMenu.addItem boneAction -1
        local boneToolsMenu = menuMan.createSubMenuItem "BoneOverride" boneMenu
        
        -- 创建定点色写入工具子菜单
        local heightMenu = menuMan.createMenu "定点色写入工具"
        local heightAction = menuMan.createActionItem "MaxZJTools_VertexColorWriter" "MaxZJTools"
        heightMenu.addItem heightAction -1
        local heightToolsMenu = menuMan.createSubMenuItem "定点色写入工具" heightMenu

        -- 添加分隔符
        local separator1 = menuMan.createSeparatorItem()
        
        -- 添加关于菜单项
        local aboutAction = menuMan.createActionItem "MaxZJTools_About" "MaxZJTools"
        
        -- 将所有项添加到主菜单
        mainMenu.addItem renameToolsMenu -1
        mainMenu.addItem textureToolsMenu -1
        mainMenu.addItem meshToolsMenu -1
        mainMenu.addItem boneToolsMenu -1
        mainMenu.addItem heightToolsMenu -1
        mainMenu.addItem separator1 -1
        mainMenu.addItem aboutAction -1
        
        -- 将主菜单添加到菜单栏
        local mainMenuBar = menuMan.getMainMenuBar()
        local subMenuItem = menuMan.createSubMenuItem MaxZJTools_MenuName mainMenu
        mainMenuBar.addItem subMenuItem -1
        menuMan.updateMenuBar()
        
        format "[MaxZJTools] 版本 % 菜单已创建\n" MaxZJTools_Version
        
        return true
    )
    
    -- 执行创建菜单
    try
    (
        CreateMainMenu()
        format "[MaxZJTools] 初始化完成\n"
    )
    catch
    (
        local errMsg = getCurrentException()
        format "[MaxZJTools] 初始化失败: %\n" errMsg
        messageBox ("MaxZJTools 初始化失败:\n" + errMsg) title:"错误"
    )
)
