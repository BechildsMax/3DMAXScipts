-- ReSetTexturesPath.ms
-- 贴图路径重设工具
-- 功能: 查找和修复场景中丢失的贴图文件
-- 版本: 1.0.0
-- 日期: 2026-01-05

(
    rollout reSetTexturesRollout "贴图路径重设工具" width:600 height:700
    (
        group "扫描选项"
        (
            button btnScan "扫描丢失的贴图" width:550 height:40
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
        
        -- 递归获取材质中的所有贴图
        fn getBitmapsFromMat m bmpArray =
        (
            if m != undefined then
            (
                local numSubs = getNumSubTexmaps m
                for i = 1 to numSubs do
                (
                    local subTex = getSubTexmap m i
                    if subTex != undefined then
                    (
                        if classOf subTex == Bitmaptexture then
                        (
                            append bmpArray subTex
                        )
                        else
                        (
                            getBitmapsFromMat subTex bmpArray
                        )
                    )
                )
            )
        )
        
        -- 获取场景中所有贴图节点
        fn getAllBitmapTextures =
        (
            local bitmaps = #()
            
            -- 遍历场景中所有材质
            for mat in sceneMaterials do
            (
                getBitmapsFromMat mat bitmaps
            )
            
            return bitmaps
        )
        
        -- 扫描丢失的贴图
        fn scanMissingTextures =
        (
            missingBitmaps = #()
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
            scanMissingTextures()
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
        
        -- 应用新路径
        on btnSetPath pressed do
        (
            if txtNewPath.text == "" then
            (
                messageBox "请输入或选择新路径！" title:"提示"
                return()
            )
            
            if not doesFileExist txtNewPath.text then
            (
                local result = queryBox ("路径不存在: " + txtNewPath.text + "\n\n是否继续？") title:"警告"
                if not result then return()
            )
            
            local selected = getSelectedBitmaps()
            if selected.count == 0 then
            (
                messageBox "请选择要修改的贴图！" title:"提示"
                return()
            )
            
            undo "重设贴图路径" on
            (
                local successCount = 0
                for bmp in selected do
                (
                    local fileName = filenameFromPath bmp.filename
                    local newFullPath = txtNewPath.text + "\\" + fileName
                    
                    bmp.filename = newFullPath
                    successCount += 1
                )
                
                messageBox ("成功为 " + (successCount as string) + " 个贴图设置新路径") title:"完成"
                scanMissingTextures()
            )
        )
        
        -- 替换前缀
        on btnReplacePrefix pressed do
        (
            if txtOldPrefix.text == "" and txtNewPrefix.text == "" then
            (
                messageBox "请输入旧前缀或新前缀！" title:"提示"
                return()
            )
            
            local selected = getSelectedBitmaps()
            if selected.count == 0 then
            (
                messageBox "请选择要修改的贴图！" title:"提示"
                return()
            )
            
            undo "替换贴图前缀" on
            (
                local successCount = 0
                for bmp in selected do
                (
                    local filePath = getFilenamePath bmp.filename
                    local fileName = filenameFromPath bmp.filename
                    
                    -- 如果有旧前缀，先移除
                    if txtOldPrefix.text != "" then
                    (
                        if (substring fileName 1 txtOldPrefix.text.count) == txtOldPrefix.text then
                        (
                            fileName = substring fileName (txtOldPrefix.text.count + 1) -1
                        )
                    )
                    
                    -- 添加新前缀
                    if txtNewPrefix.text != "" then
                    (
                        fileName = txtNewPrefix.text + fileName
                    )
                    
                    bmp.filename = filePath + fileName
                    successCount += 1
                )
                
                messageBox ("成功为 " + (successCount as string) + " 个贴图替换前缀") title:"完成"
                scanMissingTextures()
            )
        )
        
        -- 替换文件名
        on btnReplaceName pressed do
        (
            if txtFind.text == "" then
            (
                messageBox "请输入要查找的文本！" title:"提示"
                return()
            )
            
            local selected = getSelectedBitmaps()
            if selected.count == 0 then
            (
                messageBox "请选择要修改的贴图！" title:"提示"
                return()
            )
            
            undo "替换贴图文件名" on
            (
                local successCount = 0
                for bmp in selected do
                (
                    local filePath = getFilenamePath bmp.filename
                    local fileName = filenameFromPath bmp.filename
                    local fileExt = getFilenameType fileName
                    local fileNameOnly = getFilenameFile fileName
                    
                    -- 替换文件名（不包括扩展名）
                    local newFileName = substituteString fileNameOnly txtFind.text txtReplace.text
                    
                    if newFileName != fileNameOnly then
                    (
                        bmp.filename = filePath + newFileName + fileExt
                        successCount += 1
                    )
                )
                
                messageBox ("成功替换 " + (successCount as string) + " 个贴图的文件名") title:"完成"
                scanMissingTextures()
            )
        )
        
        -- 刷新列表
        on btnRefresh pressed do
        (
            scanMissingTextures()
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
            scanMissingTextures()
        )
    )
    
    -- 创建并显示对话框
    createDialog reSetTexturesRollout
)
