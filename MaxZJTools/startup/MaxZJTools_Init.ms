-- MaxZJTools_Init.ms
-- 主菜单初始化脚本 - 避免版本迭代导致的重名菜单问题
-- 作者: MaxZJ
-- 版本: 1.0.2 (修复版)
-- 日期: 2026-01-05

(
    global MaxZJTools_MenuName = "MaxZJTools"
    global MaxZJTools_Version = "1.0.2"
    
    -- 定义菜单动作（总是重新定义，确保使用最新版本）
    macroscript MaxZJTools_RenameTools
        category:"MaxZJTools"
        tooltip:"节点重命名工具"
    (
        local scriptPath = getThisScriptFilename()
        local toolPath = getFilenamePath scriptPath + "..\\tools\\RenameTools.ms"
        
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
        local scriptPath = getThisScriptFilename()
        local toolPath = getFilenamePath scriptPath + "..\\tools\\ReSetTexturesPath.ms"
        
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
        local scriptPath = getThisScriptFilename()
        local toolPath = getFilenamePath scriptPath + "..\\tools\\MeshChecker.ms"
        
        if doesFileExist toolPath then
        (
            fileIn toolPath
        )
        else
        (
            messageBox ("找不到 MeshChecker.ms 文件\n路径: " + toolPath) title:"错误"
        )
    )
    
    macroscript MaxZJTools_About
        category:"MaxZJTools"
        tooltip:"关于 MaxZJTools"
    (
        local versionStr = "1.0.2"
        local aboutText = "MaxZJTools\n"
        aboutText += "版本: " + versionStr + "\n\n"
        aboutText += "专业的3ds Max工具集合\n\n"
        aboutText += "包含工具：\n"
        aboutText += "- 节点重命名工具\n"
        aboutText += "- 贴图路径重设工具\n"
        aboutText += "- Mesh动画检查工具\n\n"
        aboutText += "作者: MaxZJ\n"
        aboutText += "日期: 2026-01-06"
        
        messageBox aboutText title:"关于 MaxZJTools"
    )
    
    format "[MaxZJTools] macroscript 已更新到版本 %\n" MaxZJTools_Version
    
    -- 清理旧版本菜单的函数（安全版本）
    fn CleanupOldMenus menuName = 
    (
        format "[MaxZJTools] 检查是否存在旧菜单...\n"
        
        try
        (
            local mainMenuBar = menuMan.getMainMenuBar()
            if mainMenuBar == undefined then
            (
                format "[MaxZJTools] 无法获取主菜单栏\n"
                return 0
            )
            
            local removedCount = 0
            local maxAttempts = 10
            
            -- 简单的查找和删除
            for attempt = 1 to maxAttempts do
            (
                local foundIndex = 0
                local itemCount = 0
                
                try
                (
                    itemCount = mainMenuBar.numItems()
                )
                catch
                (
                    format "[MaxZJTools] 无法获取菜单数量\n"
                    exit
                )
                
                -- 查找菜单
                for i = 1 to itemCount do
                (
                    try
                    (
                        local item = mainMenuBar.getItem i
                        if item != undefined then
                        (
                            try
                            (
                                local itemTitle = item.getTitle()
                                if itemTitle != undefined and itemTitle == menuName then
                                (
                                    foundIndex = i
                                    exit
                                )
                            )
                            catch()
                        )
                    )
                    catch()
                )
                
                -- 如果找到了，尝试删除
                if foundIndex > 0 then
                (
                    try
                    (
                        mainMenuBar.removeItem foundIndex
                        menuMan.updateMenuBar()
                        removedCount += 1
                        format "[MaxZJTools] 删除了位置 % 的菜单\n" foundIndex
                    )
                    catch
                    (
                        format "[MaxZJTools] 无法删除位置 % 的菜单，跳过\n" foundIndex
                        exit
                    )
                )
                else
                (
                    exit
                )
            )
            
            if removedCount > 0 then
                format "[MaxZJTools] 清理完成，删除了 % 个旧菜单\n" removedCount
            else
                format "[MaxZJTools] 未发现旧菜单\n"
            
            return removedCount
        )
        catch (e)
        (
            format "[MaxZJTools] 清理过程出错: %\n" (e as string)
            return 0
        )
    )
    
    -- 创建主菜单
    fn CreateMainMenu = 
    (
        -- 先检查是否已经存在菜单，如果存在就不重复创建
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
                    format "[MaxZJTools] 菜单已存在，跳过创建\n"
                    exit
                )
            )
        )
        
        -- 如果菜单已存在，直接返回
        if menuExists then
        (
            format "[MaxZJTools] 版本 % 已加载\n" MaxZJTools_Version
            return true
        )
        
        -- 尝试清理可能存在的损坏菜单（仅首次创建时）
        CleanupOldMenus MaxZJTools_MenuName
        
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
        
        -- 添加分隔符
        local separator1 = menuMan.createSeparatorItem()
        
        -- 添加关于菜单项
        local aboutAction = menuMan.createActionItem "MaxZJTools_About" "MaxZJTools"
        
        -- 将所有项添加到主菜单
        mainMenu.addItem renameToolsMenu -1
        mainMenu.addItem textureToolsMenu -1
        mainMenu.addItem meshToolsMenu -1
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