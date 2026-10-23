-- ReSetTexturesPath.ms
-- 贴图路径重设工具
-- 功能: 查找和修复场景中丢失的贴图文件
-- 版本: 1.0.1
-- 日期: 2026-10-23

global reSetTexturesRollout
global MaxZJTools_Headless
try (destroyDialog reSetTexturesRollout) catch ()
(
    rollout reSetTexturesRollout "贴图路径重设工具" width:600 height:700
    (
        group "扫描选项"
        (
            button btnScan "扫描全场景丢失贴图" width:550 height:40
            label lblStatus "状态: 未扫描" align:#left
        )
        
        group "丢失的贴图列表"
        (
            multiListBox lstMissingFiles "丢失的贴图文件:" height:12 width:550
            label lblCount "总计: 0 个丢失文件" align:#left
        )
        
        group "批量操作"
        (
            label lbl1 "重设路径:" align:#left
            editText txtNewPath "新路径:" text:"" fieldWidth:450
            button btnBrowsePath "浏览..." width:80 height:25 across:2 align:#right
            button btnSetPath "应用新路径" width:450 height:35
            
            label lbl2 "" height:5
            
            label lbl3 "修改前缀:" align:#left
            editText txtOldPrefix "旧前缀:" text:"" fieldWidth:250 across:2
            editText txtNewPrefix "新前缀:" text:"" fieldWidth:250
            button btnReplacePrefix "替换前缀" width:550 height:35
            
            label lbl4 "" height:5
            
            label lbl5 "查找替换文件名:" align:#left
            editText txtFind "查找:" text:"" fieldWidth:250 across:2
            editText txtReplace "替换为:" text:"" fieldWidth:250
            button btnReplaceName "替换文件名" width:550 height:35
        )
        
        group "操作"
        (
            button btnRefresh "刷新列表" width:180 height:35 across:3
            button btnSelectAll "全选" width:180 height:35
            button btnClearSelection "取消选择" width:180 height:35
        )
        
        -- 全局变量
        local missingBitmaps = #()
        local allBitmapNodes = #()
        
        -- 按材质/贴图引用去重，同时遍历 MultiMaterial 子材质。
        fn getBitmapsFromMat m bmpArray visited =
        (
            if m == undefined or findItem visited m != 0 do return bmpArray
            append visited m
            if classOf m == Bitmaptexture do appendIfUnique bmpArray m
            for i = 1 to getNumSubMtls m do getBitmapsFromMat (getSubMtl m i) bmpArray visited
            for i = 1 to getNumSubTexmaps m do getBitmapsFromMat (getSubTexmap m i) bmpArray visited
            bmpArray
        )
        fn getAllBitmapTextures =
        (
            local bitmaps = #()
            local visited = #()
            for mat in sceneMaterials do getBitmapsFromMat mat bitmaps visited
            bitmaps
        )

        -- 扫描丢失的贴图
        fn scanMissingTextures =
        (
            missingBitmaps = #()
            allBitmapNodes = #()
            lstMissingFiles.items = #()
            lblCount.text = "总计: 0 个丢失文件"
            lblStatus.text = "状态: 扫描中"
            allBitmapNodes = getAllBitmapTextures()
            
            for bmp in allBitmapNodes do
            (
                if bmp.filename != "" and not doesFileExist bmp.filename then
                (
                    append missingBitmaps bmp
                )
            )
            
            -- 更新列表
            local displayItems = #()
            for bmp in missingBitmaps do
            (
                append displayItems bmp.filename
            )
            
            lstMissingFiles.items = displayItems
            lblCount.text = "总计: " + (missingBitmaps.count as string) + " 个丢失文件"
            
            if missingBitmaps.count > 0 then
            (
                lblStatus.text = "状态: 找到 " + (missingBitmaps.count as string) + " 个丢失的贴图"
                
                -- 默认全选
                local selArray = #{}
                for i = 1 to missingBitmaps.count do
                    selArray[i] = true
                lstMissingFiles.selection = selArray
            )
            else
            (
                lblStatus.text = "状态: 没有发现丢失的贴图"
            )
        )
        
        fn runScan =
        (
            try (scanMissingTextures(); true)
            catch
            (
                missingBitmaps = #()
                allBitmapNodes = #()
                lstMissingFiles.items = #()
                lblCount.text = "扫描未完成"
                lblStatus.text = "状态: 扫描失败；没有可执行清单"
                format "[MaxZJTools.ReSetTexturesPath] 扫描失败：%\n" (getCurrentException())
                messageBox (getCurrentException()) title:"贴图扫描失败"
                false
            )
        )

        -- 获取选中的贴图
        fn getSelectedBitmaps =
        (
            local selected = #()
            local selIndices = lstMissingFiles.selection as array
            for i in selIndices do
            (
                if i <= missingBitmaps.count then
                    append selected missingBitmaps[i]
            )
            return selected
        )
        
        -- 扫描按钮
        on btnScan pressed do
        (
            runScan()
        )
        
        -- 浏览路径
        on btnBrowsePath pressed do
        (
            local newPath = getSavePath caption:"选择新的贴图路径"
            if newPath != undefined then
            (
                txtNewPath.text = newPath
            )
        )
        
        -- 预览项：贴图引用、旧路径、新路径、可执行状态。只更改引用，不移动文件。
        fn buildPathPlan mode selected =
        (
            local pathAPI = dotNetClass "System.IO.Path"
            if mode == #folder do
            (
                if not (pathAPI.IsPathRooted txtNewPath.text) do throw "新路径必须是绝对目录或 UNC 目录。"
                if not ((dotNetClass "System.IO.Directory").Exists txtNewPath.text) do throw "目标目录不存在。"
            )
            if mode == #prefix and txtOldPrefix.text == "" and txtNewPrefix.text == "" do throw "请输入旧前缀或新前缀。"
            if mode == #name and txtFind.text == "" do throw "查找文本不能为空。"
            local plan = #()
            local seen = #()
            local liveMaps = getAllBitmapTextures()
            for bmp in selected where findItem seen bmp == 0 do
            (
                append seen bmp
                if findItem liveMaps bmp == 0 do throw "贴图已脱离当前场景材质，请重新扫描。"
                local oldPath = bmp.filename
                local folder = getFilenamePath oldPath
                local fileName = filenameFromPath oldPath
                local newName = fileName
                local status = "可修改"
                case mode of
                (
                    #folder: (folder = txtNewPath.text + "\\")
                    #prefix:
                    (
                        if txtOldPrefix.text != "" then
                        (
                            if (substring fileName 1 txtOldPrefix.text.count) == txtOldPrefix.text then
                                newName = txtNewPrefix.text + substring fileName (txtOldPrefix.text.count + 1) -1
                            else status = "跳过：旧前缀不匹配"
                        )
                        else newName = txtNewPrefix.text + fileName
                    )
                    #name: (newName = (substituteString (getFilenameFile fileName) txtFind.text txtReplace.text) + getFilenameType fileName)
                    default: (throw "未知的路径操作。")
                )
                if newName == "" or pathAPI.GetFileName newName != newName do throw "替换结果必须是文件名，不能含目录。"
                for invalid in #("<",">",":","\"","/","\\","|","?","*") do
                    if findString newName invalid != undefined do throw "文件名包含非法字符。"
                local newPath = folder + newName
                if status == "可修改" do
                (
                    if newPath == oldPath then status = "跳过：未变化"
                    else if not doesFileExist newPath then status = "跳过：目标文件不存在"
                )
                append plan #(bmp, oldPath, newPath, status)
            )
            -- 不同原路径合并到同一目标容易错贴，阻断并要求用户缩小选择。
            for i = 1 to plan.count do
                for j = 1 to plan.count where j > i and plan[i][4] == "可修改" and plan[j][4] == "可修改" do
                    if toLower plan[i][3] == toLower plan[j][3] and toLower plan[i][2] != toLower plan[j][2] do
                        throw ("不同源贴图映射到同一文件：" + plan[i][3] + "；请分别处理。")
            plan
        )
        fn applyPathPlan plan =
        (
            local liveMaps = getAllBitmapTextures()
            for row in plan do
            (
                if findItem liveMaps row[1] == 0 or row[1].filename != row[2] do throw "场景引用已变化，请重新预览。"
                if row[4] == "可修改" and not doesFileExist row[3] do throw "预览后的目标文件已消失。"
            )
            local changed = 0
            local found = 0
            local skipped = 0
            local failures = #()
            undo "MaxZJTools 贴图引用修复" on
            (
                for row in plan do
                    if row[4] != "可修改" then skipped += 1
                    else try
                    (
                        row[1].filename = row[3]
                        if row[1].filename != row[3] do throw "路径回读不一致"
                        changed += 1
                        if doesFileExist row[1].filename then found += 1
                        else append failures (row[3] + ": 写入后文件不可访问")
                    )
                    catch (append failures (row[2] + ": " + getCurrentException()))
            )
            #(changed, found, skipped, failures)
        )
        fn runPathChange mode =
        (
            try
            (
                local selected = getSelectedBitmaps()
                if selected.count == 0 do throw "请先扫描并选择贴图。"
                local plan = buildPathPlan mode selected
                local count = 0
                for row in plan do
                (
                    format "[MaxZJTools.ReSetTexturesPath 1.0.1] % -> % [%]\n" row[2] row[3] row[4]
                    if row[4] == "可修改" do count += 1
                )
                lstMissingFiles.items = for row in plan collect (row[2] + " -> " + row[3] + " [" + row[4] + "]")
                -- 保持显示行与引用索引一致；取消后仍可再次修改参数。
                missingBitmaps = for row in plan collect row[1]
                lstMissingFiles.selection = #{1..(plan.count)}
                if count == 0 do throw "没有可修改项：请检查列表中的缺失文件、匹配条件和路径。"
                if queryBox ("将修改 " + (count as string) + " 个贴图引用，跳过 " + ((plan.count-count) as string) + " 项。\n完整旧/新路径和状态已列在面板及 Listener。\n共享贴图的所有使用者都会受影响；不复制图片、不保存场景。") title:"检查路径映射" do
                (
                    local result = applyPathPlan plan
                    local msg = "引用已改: " + (result[1] as string) + "；文件已找到: " + (result[2] as string) + "；跳过: " + (result[3] as string) + "；失败: " + (result[4].count as string)
                    for reason in result[4] do format "[MaxZJTools.ReSetTexturesPath 1.0.1] %\n" reason
                    runScan()
                    lblStatus.text = msg
                    messageBox (msg + "\n已完成修改可使用 Max 撤销；不代表图片格式或内容已验证。") title:"路径修改结果"
                )
            )
            catch (messageBox (getCurrentException()) title:"路径修改未完成")
        )
        on btnSetPath pressed do runPathChange #folder
        on btnReplacePrefix pressed do runPathChange #prefix
        on btnReplaceName pressed do runPathChange #name

        -- 刷新列表
        on btnRefresh pressed do
        (
            runScan()
        )
        
        -- 全选
        on btnSelectAll pressed do
        (
            local selArray = #{}
            for i = 1 to missingBitmaps.count do
                selArray[i] = true
            lstMissingFiles.selection = selArray
        )
        
        -- 取消选择
        on btnClearSelection pressed do
        (
            lstMissingFiles.selection = #{}
        )
        
        -- 对话框打开时
        on reSetTexturesRollout open do
        (
            lblStatus.text = "状态: 未扫描；点击按钮显式扫描全场景 Bitmaptexture"
        )
    )
    
    -- 创建并显示对话框
    if MaxZJTools_Headless != true do createDialog reSetTexturesRollout
)
