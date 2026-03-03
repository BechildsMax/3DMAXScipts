/*
============================================================
单骨骼替换工具 - V4
修复缩放控制器中的负值问题
============================================================
*/

try(destroyDialog SingleBoneReplacer)catch()

rollout SingleBoneReplacer "单骨骼替换工具 V4" width:360 height:540 (
    
    group "1. 选择要替换的骨骼" (
        pickButton btnPickBone "点击选择骨骼" width:320 height:28
        label lblBoneInfo "" align:#left
        label lblScaleNode "" align:#left
        label lblScaleCtrl "" align:#left
        label lblScaleWarning "" align:#left
    )
    
    group "2. 蒙皮物体" (
        listbox lstSkinned height:5 width:320
        button btnAutoFind "自动查找" width:155 across:2
        button btnAddManual "手动添加选中" width:155
        label lblFindStatus "" align:#left
    )
    
    group "3. 选项" (
        checkbox chkKeepParent "保持父子关系" checked:true
        checkbox chkKeepChildren "保持子物体关系" checked:true
        checkbox chkHideOld "隐藏旧骨骼" checked:true
        checkbox chkRename "使用原骨骼名称" checked:true
    )
    
    button btnExecute "执行替换" width:320 height:40
    progressBar pbProgress value:0 color:green
    label lblStatus "" align:#left
    
    local selectedBone = undefined
    local skinnedObjects = #()
    
    fn updateList = (
        lstSkinned.items = for obj in skinnedObjects collect obj.name
    )
    
    -- 获取真实的缩放值（包括控制器）
    fn getRealScale obj = (
        local scl = obj.scale
        
        -- 尝试从缩放控制器获取
        try (
            local sclCtrl = obj.scale.controller
            if sclCtrl != undefined then (
                scl = sclCtrl.value
            )
        ) catch ()
        
        return scl
    )
    
    -- 检查缩放是否有问题
    fn hasScaleProblem obj = (
        local scl = getRealScale obj
        
        -- 检查负值
        if scl.x < 0 or scl.y < 0 or scl.z < 0 then return true
        
        -- 检查非单位值
        if abs(scl.x) < 0.99 or abs(scl.x) > 1.01 then return true
        if abs(scl.y) < 0.99 or abs(scl.y) > 1.01 then return true
        if abs(scl.z) < 0.99 or abs(scl.z) > 1.01 then return true
        
        return false
    )
    
    -- 查找使用该骨骼的蒙皮物体
    fn findSkinnedObjects bone = (
        local result = #()
        local boneName = bone.name
        
        for obj in objects where obj.modifiers[#Skin] != undefined do (
            try (
                local skinMod = obj.modifiers[#Skin]
                select obj
                max modify mode
                modPanel.setCurrentObject skinMod
                
                local numBones = skinOps.GetNumberBones skinMod
                for i = 1 to numBones do (
                    if (skinOps.GetBoneName skinMod i 0) == boneName then (
                        append result obj
                        exit
                    )
                )
            ) catch ()
            windows.processPostedMessages()
        )
        return result
    )
    
    -- 创建干净的新骨骼
    fn createCleanBone originalBone = (
        -- 获取世界空间变换
        local worldTM = originalBone.transform
        local worldPos = worldTM.row4
        
        -- 从变换矩阵提取方向（归一化）
        local xDir = normalize worldTM.row1
        local yDir = normalize worldTM.row2
        local zDir = normalize worldTM.row3
        
        -- 检查本地矩阵行列式，判断是否需要翻转
        if originalBone.parent != undefined then (
            local localTM = worldTM * (inverse originalBone.parent.transform)
            local det = dot (cross localTM.row1 localTM.row2) localTM.row3
            if det < 0 then (
                -- 有负缩放，翻转一个轴
                zDir = -zDir
                print ("检测到负缩放（本地行列式: " + det as string + "），已修正")
            )
        )
        
        -- 获取骨骼长度
        local boneLen = 5.0
        try ( 
            boneLen = abs(originalBone.length)
            if boneLen < 0.1 then boneLen = 5.0
        ) catch ()
        
        -- 创建新骨骼
        local startPos = worldPos
        local endPos = worldPos + xDir * boneLen
        
        local newBone = BoneSys.createBone startPos endPos zDir
        newBone.name = originalBone.name + "_FIXED"
        
        -- 复制骨骼外观
        try (
            newBone.width = abs(originalBone.width)
            newBone.height = abs(originalBone.height)
            newBone.taper = originalBone.taper
            newBone.length = abs(originalBone.length)
        ) catch ()
        
        -- 设置干净的变换
        local cleanTM = matrix3 xDir yDir zDir worldPos
        newBone.transform = cleanTM
        
        -- 强制缩放为正
        newBone.scale = [1, 1, 1]
        
        -- 确保缩放控制器也是正值
        try (
            newBone.scale.controller.value = [1, 1, 1]
        ) catch ()
        
        return newBone
    )
    
    -- 替换蒙皮中的骨骼权重
    fn replaceBoneInSkin skinnedObj oldBoneName newBone = (
        local skinMod = skinnedObj.modifiers[#Skin]
        if skinMod == undefined then return false
        
        print ("\n处理: " + skinnedObj.name)
        
        select skinnedObj
        max modify mode
        modPanel.setCurrentObject skinMod
        completeredraw()
        sleep 0.05
        
        -- 查找旧骨骼 ID
        local oldBoneID = 0
        local numBones = skinOps.GetNumberBones skinMod
        
        for i = 1 to numBones do (
            if (skinOps.GetBoneName skinMod i 0) == oldBoneName then (
                oldBoneID = i
                exit
            )
        )
        
        if oldBoneID == 0 then (
            print ("  未找到骨骼: " + oldBoneName)
            return false
        )
        
        -- 统计旧骨骼的权重
        local numVerts = skinOps.GetNumberVertices skinMod
        local vertsWithWeight = #()
        
        for v = 1 to numVerts do (
            local numWeights = skinOps.GetVertexWeightCount skinMod v
            for w = 1 to numWeights do (
                local bID = skinOps.GetVertexWeightBoneID skinMod v w
                local wt = skinOps.GetVertexWeight skinMod v w
                if bID == oldBoneID and wt > 0.0001 then (
                    append vertsWithWeight #(v, wt)
                    exit
                )
            )
        )
        
        print ("  旧骨骼 ID: " + oldBoneID as string + ", 影响顶点: " + vertsWithWeight.count as string)
        
        if vertsWithWeight.count == 0 then (
            print ("  无权重，跳过")
            return false
        )
        
        -- 添加新骨骼
        skinOps.addBone skinMod newBone 0
        completeredraw()
        sleep 0.05
        
        -- 获取新骨骼 ID
        local newNumBones = skinOps.GetNumberBones skinMod
        local newBoneID = 0
        
        for i = 1 to newNumBones do (
            if (skinOps.GetBoneName skinMod i 0) == newBone.name then (
                newBoneID = i
                exit
            )
        )
        
        if newBoneID == 0 then (
            print ("  添加新骨骼失败")
            return false
        )
        
        print ("  新骨骼 ID: " + newBoneID as string)
        
        -- 进入顶点模式
        subobjectLevel = 1
        completeredraw()
        
        -- 转移权重
        local transferCount = 0
        
        for vData in vertsWithWeight do (
            local v = vData[1]
            
            local allBoneIDs = #()
            local allWeights = #()
            
            local numWeights = skinOps.GetVertexWeightCount skinMod v
            
            for w = 1 to numWeights do (
                local bID = skinOps.GetVertexWeightBoneID skinMod v w
                local wt = skinOps.GetVertexWeight skinMod v w
                
                if wt > 0.0001 then (
                    if bID == oldBoneID then (
                        append allBoneIDs newBoneID
                    ) else (
                        append allBoneIDs bID
                    )
                    append allWeights wt
                )
            )
            
            if allBoneIDs.count > 0 then (
                try (
                    skinOps.ReplaceVertexWeights skinMod v allBoneIDs allWeights
                    transferCount += 1
                ) catch ()
            )
        )
        
        subobjectLevel = 0
        completeredraw()
        
        print ("  ? 转移: " + transferCount as string + " 顶点")
        return (transferCount > 0)
    )
    
    -- UI 事件
    on btnPickBone picked obj do (
        if obj != undefined then (
            selectedBone = obj
            btnPickBone.text = obj.name
            lblBoneInfo.text = "类型: " + (classof obj) as string
            
            -- 显示节点缩放
            lblScaleNode.text = "节点缩放: " + obj.scale as string
            
            -- 显示控制器缩放
            local ctrlScale = [1,1,1]
            try (
                ctrlScale = obj.scale.controller.value
            ) catch ()
            lblScaleCtrl.text = "控制器缩放: " + ctrlScale as string
            
            -- 检查是否需要修复
            if hasScaleProblem obj then (
                lblScaleWarning.text = "?? 检测到负缩放，需要修复！"
            ) else (
                lblScaleWarning.text = "? 缩放正常"
            )
            
            skinnedObjects = #()
            updateList()
            lblFindStatus.text = ""
        )
    )
    
    on btnAutoFind pressed do (
        if selectedBone == undefined then (
            messageBox "请先选择骨骼"
            return()
        )
        
        btnAutoFind.enabled = false
        lblFindStatus.text = "搜索中..."
        windows.processPostedMessages()
        
        skinnedObjects = findSkinnedObjects selectedBone
        updateList()
        
        btnAutoFind.enabled = true
        lblFindStatus.text = "找到 " + skinnedObjects.count as string + " 个"
    )
    
    on btnAddManual pressed do (
        for obj in selection do (
            if obj.modifiers[#Skin] != undefined then (
                appendIfUnique skinnedObjects obj
            )
        )
        updateList()
        lblFindStatus.text = "共 " + skinnedObjects.count as string + " 个"
    )
    
    on btnExecute pressed do (
        if selectedBone == undefined then (
            messageBox "请先选择骨骼！"
            return()
        )
        
        if skinnedObjects.count == 0 then (
            messageBox "请先添加蒙皮物体！"
            return()
        )
        
        if not queryBox "确定执行？\n\n建议先保存文件！" then return()
        
        btnExecute.enabled = false
        pbProgress.value = 0
        
        local originalBoneName = selectedBone.name
        
        undo on (
            try (
                -- 1. 创建新骨骼
                lblStatus.text = "创建新骨骼..."
                pbProgress.value = 10
                
                print "\n========================================"
                print ("替换骨骼: " + originalBoneName)
                print ("原始节点缩放: " + selectedBone.scale as string)
                try ( print ("原始控制器缩放: " + selectedBone.scale.controller.value as string) ) catch()
                print "========================================"
                
                local newBone = createCleanBone selectedBone
                
                print ("新骨骼: " + newBone.name)
                print ("新骨骼缩放: " + newBone.scale as string)
                try ( print ("新骨骼控制器缩放: " + newBone.scale.controller.value as string) ) catch()
                
                -- 2. 设置父级
                lblStatus.text = "设置层级..."
                pbProgress.value = 20
                
                if chkKeepParent.checked and selectedBone.parent != undefined then (
                    local worldTM = newBone.transform
                    newBone.parent = selectedBone.parent
                    newBone.transform = worldTM
                    newBone.scale = [1, 1, 1]
                    try ( newBone.scale.controller.value = [1, 1, 1] ) catch()
                    print ("父级: " + selectedBone.parent.name)
                )
                
                -- 3. 转移子物体
                pbProgress.value = 30
                if chkKeepChildren.checked then (
                    local children = for child in selectedBone.children collect child
                    for child in children do (
                        local worldTM = child.transform
                        child.parent = newBone
                        child.transform = worldTM
                        print ("子物体: " + child.name)
                    )
                )
                
                -- 4. 转移权重
                lblStatus.text = "转移权重..."
                local totalSkin = skinnedObjects.count
                local successCount = 0
                
                for i = 1 to totalSkin do (
                    pbProgress.value = 30 + (50.0 * i / totalSkin) as integer
                    lblStatus.text = "权重 " + i as string + "/" + totalSkin as string
                    
                    if replaceBoneInSkin skinnedObjects[i] originalBoneName newBone then (
                        successCount += 1
                    )
                )
                
                -- 5. 重命名和隐藏
                pbProgress.value = 90
                
                if chkRename.checked then (
                    selectedBone.name = originalBoneName + "_OLD"
                    newBone.name = originalBoneName
                )
                
                if chkHideOld.checked then (
                    selectedBone.isHidden = true
                )
                
                pbProgress.value = 100
                lblStatus.text = "? 完成"
                
                select newBone
                
                print "\n========================================"
                print "替换完成！"
                print ("新骨骼最终缩放: " + newBone.scale as string)
                print ("成功: " + successCount as string + "/" + totalSkin as string)
                print "========================================"
                
                messageBox ("完成！\n\n新骨骼: " + newBone.name + "\n缩放: " + newBone.scale as string + "\n\n成功: " + successCount as string + "/" + totalSkin as string)
                
            ) catch (
                local err = getCurrentException()
                print ("错误: " + err)
                messageBox ("错误:\n" + err)
                lblStatus.text = "错误"
            )
        )
        
        btnExecute.enabled = true
    )
)

createDialog SingleBoneReplacer