-- MeshChecker.ms
-- 网格动画检查工具
-- 功能: 检查选择对象的动画帧并提供清理功能
-- 版本: 1.0.0
-- 日期: 2026-01-06

(
    rollout meshCheckerRollout "Mesh动画检查工具" width:650 height:600
    (
        group "检查选项"
        (
            button btnScan "检查选择对象的动画" width:600 height:40
            label lblStatus "状态: 未检查" align:#left
        )
        
        group "动画信息"
        (
            dotNetControl dgvAnimInfo "System.Windows.Forms.DataGridView" width:620 height:300
            label lblSummary "总计: 0 个对象" align:#left
        )
        
        group "关键帧详情"
        (
            editText txtDetails "" height:80 width:620 readOnly:true
        )
        
        group "操作"
        (
            button btnClearSelected "清理选中对象的动画" width:200 height:35 across:3
            button btnClearAll "清理全部动画" width:200 height:35
            button btnRefresh "刷新" width:200 height:35
        )
        
        -- 全局变量
        local objectsWithAnim = #()
        
        -- 递归收集控制器关键帧
        fn collectKeys c keyArray =
        (
            if c != undefined then
            (
                -- 检查主控制器的keys
                if c.keys != undefined and c.keys.count > 0 then
                (
                    for i = 1 to c.keys.count do
                    (
                        local frameNum = (c.keys[i].time / ticksPerFrame) as integer
                        appendIfUnique keyArray frameNum
                    )
                )
                
                -- 检查子控制器（比如欧拉角的X/Y/Z）
                try
                (
                    local numSubs = c.numSubs
                    if numSubs != undefined and numSubs > 0 then
                    (
                        for subIdx = 1 to numSubs do
                        (
                            try
                            (
                                local subCtrl = c[subIdx].controller
                                if subCtrl != undefined then
                                    collectKeys subCtrl keyArray
                            )
                            catch()
                        )
                    )
                )
                catch()
            )
        )
        
        -- 获取控制器的关键帧信息
        fn getKeysInfo ctrl =
        (
            local keysInfo = ""
            local keyCount = 0
            local allKeyFrames = #()
            
            collectKeys ctrl allKeyFrames
            
            if allKeyFrames.count > 0 then
            (
                sort allKeyFrames
                keyCount = allKeyFrames.count
                keysInfo = "帧: " + (allKeyFrames as string)
            )
            
            return #(keysInfo, keyCount)
        )
        
        -- 初始化 DataGridView
        fn initDataGridView =
        (
            dgvAnimInfo.AllowUserToAddRows = false
            dgvAnimInfo.AllowUserToDeleteRows = false
            dgvAnimInfo.ReadOnly = false
            dgvAnimInfo.SelectionMode = (dotNetClass "System.Windows.Forms.DataGridViewSelectionMode").FullRowSelect
            dgvAnimInfo.MultiSelect = true
            dgvAnimInfo.RowHeadersVisible = true
            dgvAnimInfo.ColumnHeadersVisible = true
            
            -- 清空现有列
            dgvAnimInfo.Columns.Clear()
            
            -- 创建列
            local chkCol = dotNetObject "System.Windows.Forms.DataGridViewCheckBoxColumn"
            chkCol.HeaderText = "选择"
            chkCol.Width = 50
            dgvAnimInfo.Columns.Add chkCol
            
            local nameCol = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn"
            nameCol.HeaderText = "对象名称"
            nameCol.Width = 150
            dgvAnimInfo.Columns.Add nameCol
            
            local posCol = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn"
            posCol.HeaderText = "位置动画"
            posCol.AutoSizeMode = (dotNetClass "System.Windows.Forms.DataGridViewAutoSizeColumnMode").Fill
            dgvAnimInfo.Columns.Add posCol
            
            local rotCol = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn"
            rotCol.HeaderText = "旋转动画"
            rotCol.AutoSizeMode = (dotNetClass "System.Windows.Forms.DataGridViewAutoSizeColumnMode").Fill
            dgvAnimInfo.Columns.Add rotCol
            
            local sclCol = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn"
            sclCol.HeaderText = "缩放动画"
            sclCol.AutoSizeMode = (dotNetClass "System.Windows.Forms.DataGridViewAutoSizeColumnMode").Fill
            dgvAnimInfo.Columns.Add sclCol
            
            local keyCol = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn"
            keyCol.HeaderText = "总关键帧"
            keyCol.Width = 80
            dgvAnimInfo.Columns.Add keyCol
            
            dgvAnimInfo.Refresh()
        )
        
        -- 检查对象的动画
        fn checkObjectAnimation obj =
        (
            local hasAnim = false
            local posInfo = "无"
            local rotInfo = "无"
            local sclInfo = "无"
            local totalKeys = 0
            
            -- 检查位置动画
            if obj.position.controller != undefined then
            (
                local result = getKeysInfo obj.position.controller
                if result[2] > 0 then
                (
                    posInfo = result[1]
                    totalKeys += result[2]
                    hasAnim = true
                )
            )
            
            -- 检查旋转动画
            if obj.rotation.controller != undefined then
            (
                local result = getKeysInfo obj.rotation.controller
                if result[2] > 0 then
                (
                    rotInfo = result[1]
                    totalKeys += result[2]
                    hasAnim = true
                )
            )
            
            -- 检查缩放动画
            if obj.scale.controller != undefined then
            (
                local result = getKeysInfo obj.scale.controller
                if result[2] > 0 then
                (
                    sclInfo = result[1]
                    totalKeys += result[2]
                    hasAnim = true
                )
            )
            
            return #(hasAnim, posInfo, rotInfo, sclInfo, totalKeys)
        )
        
        -- 扫描选择的对象
        fn scanSelectedObjects =
        (
            if selection.count == 0 then
            (
                messageBox "请先选择要检查的对象！" title:"提示"
                return false
            )
            
            -- 清空数据
            dgvAnimInfo.Rows.Clear()
            objectsWithAnim = #()
            
            -- 检查每个选择的对象
            for obj in selection do
            (
                local animInfo = checkObjectAnimation obj
                
                if animInfo[1] then  -- 有动画
                (
                    append objectsWithAnim obj
                    
                    -- 直接添加行到DataGridView
                    local rowIndex = dgvAnimInfo.Rows.Add()
                    dgvAnimInfo.Rows.Item[rowIndex].Cells.Item[0].Value = true
                    dgvAnimInfo.Rows.Item[rowIndex].Cells.Item[1].Value = obj.name
                    dgvAnimInfo.Rows.Item[rowIndex].Cells.Item[2].Value = animInfo[2]
                    dgvAnimInfo.Rows.Item[rowIndex].Cells.Item[3].Value = animInfo[3]
                    dgvAnimInfo.Rows.Item[rowIndex].Cells.Item[4].Value = animInfo[4]
                    dgvAnimInfo.Rows.Item[rowIndex].Cells.Item[5].Value = (animInfo[5] as string)
                )
            )
            
            -- 刷新DataGridView显示
            dgvAnimInfo.Refresh()
            
            -- 更新显示
            lblSummary.text = "总计: " + (objectsWithAnim.count as string) + " 个对象有动画（共检查 " + (selection.count as string) + " 个对象）"
            
            if objectsWithAnim.count > 0 then
            (
                lblStatus.text = "状态: 找到 " + (objectsWithAnim.count as string) + " 个对象有动画关键帧"
            )
            else
            (
                lblStatus.text = "状态: 选择的对象都没有动画"
            )
            
            return true
        )
        
        -- 清理对象的动画
        fn clearObjectAnimation obj =
        (
            local clearedCount = 0
            
            try
            (
                -- 清理位置动画
                if obj.position.controller != undefined and obj.position.controller.keys != undefined then
                (
                    while obj.position.controller.keys.count > 0 do
                    (
                        deleteKey obj.position.controller 1
                        clearedCount += 1
                    )
                )
                
                -- 清理旋转动画
                if obj.rotation.controller != undefined and obj.rotation.controller.keys != undefined then
                (
                    while obj.rotation.controller.keys.count > 0 do
                    (
                        deleteKey obj.rotation.controller 1
                        clearedCount += 1
                    )
                )
                
                -- 清理缩放动画
                if obj.scale.controller != undefined and obj.scale.controller.keys != undefined then
                (
                    while obj.scale.controller.keys.count > 0 do
                    (
                        deleteKey obj.scale.controller 1
                        clearedCount += 1
                    )
                )
            )
            catch
            (
                format "清理 % 的动画时出错\n" obj.name
            )
            
            return clearedCount
        )
        
        -- 事件：检查按钮
        on btnScan pressed do
        (
            scanSelectedObjects()
        )
        
        -- 事件：刷新按钮
        on btnRefresh pressed do
        (
            scanSelectedObjects()
        )
        
        -- 事件：清理选中对象
        on btnClearSelected pressed do
        (
            if objectsWithAnim.count == 0 then
            (
                messageBox "没有可清理的对象！" title:"提示"
                return()
            )
            
            -- 获取选中的行
            local selectedObjs = #()
            for i = 0 to (dgvAnimInfo.Rows.Count - 1) do
            (
                if (dgvAnimInfo.Rows.Item[i].Cells.Item[0].Value) == true then
                (
                    append selectedObjs objectsWithAnim[i + 1]
                )
            )
            
            if selectedObjs.count == 0 then
            (
                messageBox "请在列表中勾选要清理的对象！" title:"提示"
                return()
            )
            
            local msg = "确定要清理 " + (selectedObjs.count as string) + " 个对象的动画关键帧吗？\n\n此操作无法撤销！"
            if queryBox msg title:"确认清理" then
            (
                local totalCleared = 0
                
                with undo on
                (
                    for obj in selectedObjs do
                    (
                        totalCleared += clearObjectAnimation obj
                    )
                )
                
                messageBox ("成功清理 " + (totalCleared as string) + " 个关键帧！") title:"完成"
                
                -- 刷新显示
                scanSelectedObjects()
            )
        )
        
        -- 事件：清理全部
        on btnClearAll pressed do
        (
            if objectsWithAnim.count == 0 then
            (
                messageBox "没有可清理的对象！" title:"提示"
                return()
            )
            
            local msg = "确定要清理全部 " + (objectsWithAnim.count as string) + " 个对象的动画关键帧吗？\n\n此操作无法撤销！"
            if queryBox msg title:"确认清理" then
            (
                local totalCleared = 0
                
                with undo on
                (
                    for obj in objectsWithAnim do
                    (
                        totalCleared += clearObjectAnimation obj
                    )
                )
                
                messageBox ("成功清理 " + (totalCleared as string) + " 个关键帧！") title:"完成"
                
                -- 刷新显示
                scanSelectedObjects()
            )
        )
        
        -- 事件：选择行变化时显示详情
        on dgvAnimInfo SelectionChanged args do
        (
            try
            (
                if dgvAnimInfo.SelectedRows.Count > 0 then
                (
                    local selectedIndex = dgvAnimInfo.SelectedRows.Item[0].Index + 1
                    if selectedIndex > 0 and selectedIndex <= objectsWithAnim.count then
                    (
                        local obj = objectsWithAnim[selectedIndex]
                        local details = "对象: " + obj.name + "\n"
                        details += "类型: " + (classOf obj as string) + "\n\n"
                        
                        local animInfo = checkObjectAnimation obj
                        details += "位置动画: " + animInfo[2] + "\n"
                        details += "旋转动画: " + animInfo[3] + "\n"
                        details += "缩放动画: " + animInfo[4] + "\n"
                        details += "总关键帧数: " + (animInfo[5] as string)
                        
                        txtDetails.text = details
                    )
                )
            )
            catch()
        )
        
        -- 初始化
        on meshCheckerRollout open do
        (
            initDataGridView()
        )
    )
    
    -- 创建对话框
    try (closeRolloutFloater meshCheckerDialog) catch()
    
    global meshCheckerDialog = newRolloutFloater "Mesh动画检查工具" 680 650
    addRollout meshCheckerRollout meshCheckerDialog
)
