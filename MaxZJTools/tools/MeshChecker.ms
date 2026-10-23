-- MeshChecker.ms
-- 网格动画检查工具
-- 功能: 检查选择对象的动画帧并提供清理功能
-- 版本: 1.0.1
-- 日期: 2026-10-23

global meshCheckerRollout
global meshCheckerDialog
global MaxZJTools_Headless
try (closeRolloutFloater meshCheckerDialog) catch ()
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
        
        local scannedSelection = #()
        local scannedPlans = #()
        local scanComplete = false
        -- 只收集 PRS 的可关键帧轨道；检查和删除使用同一遍历。
        fn collectTracks ctrl tracks visited =
        (
            if ctrl == undefined or findItem visited ctrl != 0 do return tracks
            append visited ctrl
            local children = #()
            for i = 1 to ctrl.numSubs do
            (
                local childCtrl = try (ctrl[i].controller) catch (undefined)
                if childCtrl != undefined do appendIfUnique children childCtrl
            )
            if children.count > 0 then
                for childCtrl in children do collectTracks childCtrl tracks visited
            else
            (
                local count = numKeys ctrl
                if count > 0 do append tracks #(ctrl, (for i = 1 to count collect (getKeyTime ctrl i)))
            )
            tracks
        )
        fn objectTracks obj =
        (
            if not isValidNode obj do throw "对象已删除，请重新扫描。"
            local tracks = #()
            local visited = #()
            for ctrl in #(obj.position.controller, obj.rotation.controller, obj.scale.controller) do collectTracks ctrl tracks visited
            tracks
        )
        fn sameTracks oldTracks newTracks =
        (
            if oldTracks.count != newTracks.count do return false
            for i = 1 to oldTracks.count do
            (
                if oldTracks[i][1] != newTracks[i][1] or oldTracks[i][2].count != newTracks[i][2].count do return false
                for k = 1 to oldTracks[i][2].count do
                    if oldTracks[i][2][k] != newTracks[i][2][k] do return false
            )
            true
        )
        fn getKeysInfo ctrl =
        (
            local tracks = #()
            collectTracks ctrl tracks #()
            local frames = #()
            local keyCount = 0
            for track in tracks do
            (
                keyCount += track[2].count
                for t in track[2] do appendIfUnique frames (t as string)
            )
            #((if frames.count > 0 then "时间: " + (frames as string) else "无可清理关键帧"), keyCount)
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
            
            for columnIndex = 1 to dgvAnimInfo.Columns.Count - 1 do
                dgvAnimInfo.Columns.Item[columnIndex].ReadOnly = true
            for columnIndex = 0 to dgvAnimInfo.Columns.Count - 1 do
                dgvAnimInfo.Columns.Item[columnIndex].SortMode = (dotNetClass "System.Windows.Forms.DataGridViewColumnSortMode").NotSortable
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
            scanComplete = false
            dgvAnimInfo.Rows.Clear()
            objectsWithAnim = #()
            scannedPlans = #()
            scannedSelection = selection as array
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
                    append scannedPlans (objectTracks obj)
                    
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
                lblStatus.text = "状态: 没有可清理的 PRS 关键帧；约束、程序动画不在范围内"
            )
            
            scanComplete = true
            return true
        )
        
        -- 执行前复查整份扫描，防止清理旧列表指向的场景或轨道。
        fn validateScan =
        (
            if not scanComplete do throw "扫描未完整完成，请重新扫描。"
            local currentSelection = selection as array
            if currentSelection.count != scannedSelection.count do throw "场景选择已变化，请重新扫描。"
            for obj in currentSelection do
                if findItem scannedSelection obj == 0 do throw "场景选择已变化，请重新扫描。"
            for i = 1 to objectsWithAnim.count do
                if not sameTracks scannedPlans[i] (objectTracks objectsWithAnim[i]) do throw "轨道或关键帧已变化，请重新扫描。"
            true
        )
        -- 返回删除数和错误，不把部分清理写成全部成功。
        fn clearTracks tracks allowedNodes =
        (
            for track in tracks do
                for node in refs.dependentNodes track[1] do
                    if findItem allowedNodes node == 0 do throw ("轨道被范围外对象引用：" + node.name)
            local removed = 0
            local failures = #()
            for track in tracks do
            (
                try
                (
                    local beforeCount = numKeys track[1]
                    deleteKeys track[1] #allKeys
                    local remaining = numKeys track[1]
                    removed += beforeCount - remaining
                    if remaining != 0 do throw "清理后仍有关键帧"
                )
                catch (append failures (getCurrentException()))
            )
            #(removed, failures)
        )
        fn clearScanned selectedObjs =
        (
            validateScan()
            local tracks = #()
            local seen = #()
            for obj in selectedObjs do
            (
                local rowIndex = findItem objectsWithAnim obj
                if rowIndex == 0 do throw "清理目标不在扫描结果中。"
                for track in scannedPlans[rowIndex] where findItem seen track[1] == 0 do
                (
                    append seen track[1]
                    append tracks track
                )
            )
            local result
            undo "MaxZJTools 清理 PRS 关键帧" on (result = clearTracks tracks selectedObjs)
            scannedSelection = #()
            scanComplete = false
            result
        )
        fn runClear clearAll =
        (
            try
            (
                validateScan()
                dgvAnimInfo.EndEdit()
                local chosen = #()
                for i = 0 to dgvAnimInfo.Rows.Count - 1 do
                    if clearAll or dgvAnimInfo.Rows.Item[i].Cells.Item[0].Value == true do append chosen objectsWithAnim[i+1]
                if chosen.count == 0 do throw "请扫描并勾选要清理的对象。"
                if queryBox ("将删除 " + (chosen.count as string) + " 个对象列表中的 PRS 关键帧。\n会改变动画和当前姿态；建议先另存场景副本。\n已完成修改纳入 Max 撤销，工具不保存文件。") title:"确认清理" do
                (
                    local result = clearScanned chosen
                    local msg = "已删除关键帧: " + (result[1] as string) + "；失败轨道: " + (result[2].count as string)
                    for reason in result[2] do format "[MaxZJTools.MeshChecker 1.0.1] %\n" reason
                    scanSelectedObjects()
                    txtDetails.text = msg + "\n失败详情见 Listener；已完成部分可使用 Max 撤销。"
                    messageBox msg title:"清理结果"
                )
            )
            catch (messageBox (getCurrentException()) title:"清理未完成")
        )
        on btnScan pressed do try (scanSelectedObjects()) catch (messageBox (getCurrentException()) title:"扫描失败")
        on btnRefresh pressed do try (scanSelectedObjects()) catch (messageBox (getCurrentException()) title:"扫描失败")
        on btnClearSelected pressed do runClear false
        on btnClearAll pressed do runClear true

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
    
    if MaxZJTools_Headless != true do
    (
        meshCheckerDialog = newRolloutFloater "Mesh动画检查工具" 680 650
        addRollout meshCheckerRollout meshCheckerDialog
    )
)
