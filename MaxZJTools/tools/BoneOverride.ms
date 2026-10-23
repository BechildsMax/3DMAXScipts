/*
============================================================
单骨骼替换工具 - V4
修复缩放控制器中的负值问题
2026-10-23：完整权重预检/回读与失败恢复；V4 为旧标识，未设独立语义版本。
============================================================
*/

global SingleBoneReplacer
global MaxZJTools_Headless
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
    
    fn restoreContext nodes stackObject subLevel commandMode =
    (
        try
        (
            with undo off
            (
                select (for node in nodes where isValidNode node collect node)
                setCommandPanelTaskMode mode:commandMode
                if commandMode == #modify and stackObject != undefined and nodes.count == 1 and isValidNode nodes[1] do
                    modPanel.setCurrentObject stackObject node:nodes[1]
                subObjectLevel = subLevel
            )
        )
        catch (format "[MaxZJTools.BoneOverride] 界面状态恢复失败：%\n" (getCurrentException()))
    )
    fn activateSkin obj skinMod =
    (
        with undo off
        (
            select obj
            max modify mode
            modPanel.setCurrentObject skinMod
        )
    )
    fn boneID skinMod boneName =
    (
        local result = 0
        for listIndex = 1 to skinOps.GetNumberBones skinMod do
        (
            local id = skinOps.GetBoneIDByListID skinMod listIndex
            if skinOps.GetBoneName skinMod id 0 == boneName do
            (
                if result != 0 do throw ("Skin 内同名骨骼：" + boneName)
                result = id
            )
        )
        result
    )
    fn findSkinnedObjects bone =
    (
        if not isValidNode bone do throw "骨骼已删除。"
        local result = #()
        local failures = #()
        local savedSelection = selection as array
        local savedStack = modPanel.getCurrentObject()
        local savedLevel = subObjectLevel
        local savedMode = getCommandPanelTaskMode()
        for obj in objects where obj.modifiers[#Skin] != undefined do
        (
            try
            (
                for skinMod in obj.modifiers where classOf skinMod == Skin do
                (
                    activateSkin obj skinMod
                    if boneID skinMod bone.name != 0 do appendIfUnique result obj
                )
            )
            catch (append failures (obj.name + ": " + getCurrentException()))
        )
        restoreContext savedSelection savedStack savedLevel savedMode
        if failures.count > 0 do throw ("蒙皮扫描不完整；不使用部分结果：\n" + (failures as string))
        result
    )
    fn checkStaticController ctrl visited =
    (
        if ctrl == undefined or findItem visited ctrl != 0 do return true
        append visited ctrl
        local supported = #("prs","position_xyz","euler_xyz","bezier_position","bezier_rotation","bezier_scale","bezier_float","linear_float","linear_position","linear_rotation","linear_scale","tcb_position","tcb_rotation","tcb_scale")
        if findItem supported (toLower ((classOf ctrl) as string)) == 0 do throw ("不支持的约束/程序控制器：" + ((classOf ctrl) as string))
        if numKeys ctrl > 0 do throw "当前仅支持静态绑定修复；检测到动画关键帧。"
        for i = 1 to ctrl.numSubs do
        (
            local childCtrl = try (ctrl[i].controller) catch (undefined)
            if childCtrl != undefined do checkStaticController childCtrl visited
        )
        true
    )
    fn checkStaticNode node =
    (
        local visited = #()
        local current = node
        while current != undefined do
        (
            checkStaticController current.transform.controller visited
            current = current.parent
        )
        true
    )
    -- 记录所有顶点，防止 addBone 的自动权重影响未使用旧骨骼的顶点。
    fn captureSkin obj bone =
    (
        if not isValidNode obj do throw "蒙皮对象已删除。"
        local skins = for modifier in obj.modifiers where classOf modifier == Skin collect modifier
        if skins.count != 1 do throw (obj.name + ": 仅支持一个 Skin 修改器。")
        local skinMod = skins[1]
        if (refs.dependentNodes skinMod).count != 1 do throw (obj.name + ": 暂不支持实例共享 Skin。")
        activateSkin obj skinMod
        local oldID = boneID skinMod bone.name
        if oldID == 0 do throw (obj.name + ": Skin 中未找到旧骨骼。")
        local weights = #()
        local influenced = 0
        for vertexIndex = 1 to skinOps.GetNumberVertices skinMod do
        (
            local ids = #()
            local values = #()
            local total = 0.0
            for weightIndex = 1 to skinOps.GetVertexWeightCount skinMod vertexIndex do
            (
                local id = skinOps.GetVertexWeightBoneID skinMod vertexIndex weightIndex
                local value = skinOps.GetVertexWeight skinMod vertexIndex weightIndex
                if value > 0 do
                (
                    append ids id
                    append values value
                    total += value
                    if id == oldID do influenced += 1
                )
            )
            if ids.count == 0 or abs(total - 1.0) > 0.0001 do throw (obj.name + ": 顶点权重为空或未归一化，编号 " + (vertexIndex as string))
            append weights #(ids, values)
        )
        if influenced == 0 do throw (obj.name + ": 旧骨骼无权重，不执行替换。")
        #(obj, skinMod, oldID, weights, skinOps.GetNumberBones skinMod, influenced)
    )
    fn verifyWeights snapshot newID =
    (
        local skinMod = snapshot[2]
        activateSkin snapshot[1] skinMod
        if skinOps.GetNumberVertices skinMod != snapshot[4].count do throw "顶点数量发生变化。"
        for vertexIndex = 1 to snapshot[4].count do
        (
            local expected = snapshot[4][vertexIndex]
            local ids = #()
            local values = #()
            for weightIndex = 1 to skinOps.GetVertexWeightCount skinMod vertexIndex do
            (
                append ids (skinOps.GetVertexWeightBoneID skinMod vertexIndex weightIndex)
                append values (skinOps.GetVertexWeight skinMod vertexIndex weightIndex)
            )
            local mappedIDs = for id in expected[1] collect (if newID != 0 and id == snapshot[3] then newID else id)
            for i = 1 to mappedIDs.count do
            (
                local index = findItem ids mappedIDs[i]
                if index == 0 do throw ("权重回读缺少骨骼，顶点 " + (vertexIndex as string))
                if abs(values[index] - expected[2][i]) > 0.00001 do throw ("权重回读不一致，顶点 " + (vertexIndex as string))
            )
            for i = 1 to ids.count where findItem mappedIDs ids[i] == 0 do
                if values[i] > 0.00001 do throw ("出现额外权重，顶点 " + (vertexIndex as string))
        )
        true
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
        
        if (dot (cross xDir yDir) zDir) < 0 do zDir = -zDir

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
        newBone.name = uniqueName (originalBone.name + "_FIXED")
        
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
    
    fn replaceBoneInSkin snapshot newBone =
    (
        local skinMod = snapshot[2]
        activateSkin snapshot[1] skinMod
        skinOps.addBone skinMod newBone 0
        local newID = boneID skinMod newBone.name
        if newID == 0 do throw (snapshot[1].name + ": 添加新骨骼失败。")
        for vertexIndex = 1 to snapshot[4].count do
        (
            local original = snapshot[4][vertexIndex]
            local ids = for id in original[1] collect (if id == snapshot[3] then newID else id)
            skinOps.ReplaceVertexWeights skinMod vertexIndex ids original[2]
        )
        verifyWeights snapshot newID
        snapshot[6]
    )
    fn executeReplacement bone targets keepParent:true keepChildren:true renameOld:true hideOld:true =
    (
        if not isValidNode bone or classOf bone != BoneGeometry do throw "请选择有效的标准 BoneGeometry 骨骼；不支持 Biped/CAT。"
        if targets.count == 0 do throw "请添加蒙皮对象。"
        if theHold.Holding() or theHold.IsSuspended() do throw "宿主正在执行其他撤销操作，请结束后重试。"
        if theHold.getMaxUndoLevels() < 1 do throw "请先启用 Max 撤销，再执行骨骼修复。"
        checkStaticNode bone
        local children = for child in bone.children collect #(child, child.transform)
        if keepChildren do for row in children do checkStaticNode row[1]
        local matchingNodes = for node in objects where toLower node.name == toLower bone.name collect node
        if matchingNodes.count != 1 do throw "场景存在同名骨骼，无法安全匹配 Skin。"
        local allSkinned = findSkinnedObjects bone
        for obj in allSkinned where findItem targets obj == 0 do
            throw ("仍有使用旧骨骼的蒙皮未列入本批：" + obj.name + "；请自动查找后检查完整清单。")
        local worldTM = bone.transform
        for axis in #(worldTM.row1,worldTM.row2,worldTM.row3) do
            if length axis < 0.00001 do throw "骨骼变换不可逆：存在零缩放。"
        if abs(dot (normalize worldTM.row1) (normalize worldTM.row2)) > 0.0001 or abs(dot (normalize worldTM.row1) (normalize worldTM.row3)) > 0.0001 or abs(dot (normalize worldTM.row2) (normalize worldTM.row3)) > 0.0001 do throw "暂不支持带剪切的骨骼矩阵。"
        if keepParent and bone.parent != undefined do
        (
            local parentTM = bone.parent.transform
            if abs(length parentTM.row1 - 1) > 0.0001 or abs(length parentTM.row2 - 1) > 0.0001 or abs(length parentTM.row3 - 1) > 0.0001 or (dot (cross parentTM.row1 parentTM.row2) parentTM.row3) < 0 do throw "父级含缩放/镜像，请先在副本中整理父级或关闭保持父级。"
        )
        local savedSelection = selection as array
        local savedStack = modPanel.getCurrentObject()
        local savedLevel = subObjectLevel
        local savedMode = getCommandPanelTaskMode()
        local snapshots = #()
        local processed = #()
        local newBone = undefined
        local oldName = bone.name
        local oldHidden = bone.isHidden
        local failure = undefined
        local ownsHold = false
        try
        (
            for obj in targets where findItem processed obj == 0 do
            (
                append processed obj
                append snapshots (captureSkin obj bone)
            )
            for snapshot in snapshots do format "[MaxZJTools.BoneOverride] 预检 %：全部顶点 %，受影响顶点 %\n" snapshot[1].name snapshot[4].count snapshot[6]
            theHold.Begin()
            ownsHold = true
            with animate off
            (
                newBone = createCleanBone bone
                if keepParent and bone.parent != undefined do
                (
                    local cleanTM = newBone.transform
                    newBone.parent = bone.parent
                    newBone.transform = cleanTM
                )
                for snapshot in snapshots do replaceBoneInSkin snapshot newBone
                -- 所有权重核对完成后才迁移层级、改名和隐藏。
                if keepChildren do for row in children do
                (
                    row[1].parent = newBone
                    row[1].transform = row[2]
                )
                if renameOld do
                (
                    bone.name = uniqueName (oldName + "_OLD")
                    newBone.name = oldName
                )
                if hideOld do bone.isHidden = true
            )
            theHold.Accept "MaxZJTools 单骨骼替换"
            ownsHold = false
        )
        catch
        (
            failure = getCurrentException()
            if ownsHold do
            (
                try
                (
                    theHold.Cancel()
                    ownsHold = false
                    if isValidNode newBone do throw "新骨骼仍存在"
                    if bone.name != oldName or bone.isHidden != oldHidden do throw "旧骨骼名称/可见性未恢复"
                    for row in children do
                        if row[1].parent != bone or row[1].transform != row[2] do throw "子物体层级或变换未恢复"
                    for snapshot in snapshots do
                    (
                        activateSkin snapshot[1] snapshot[2]
                        if skinOps.GetNumberBones snapshot[2] != snapshot[5] do throw "Skin 骨骼数量未恢复"
                        verifyWeights snapshot 0
                    )
                    failure += "\n本批撤销恢复已回读核对；请检查场景后再继续。"
                )
                catch (failure += "\n恢复未能完整验证，请从执行前场景副本恢复：" + getCurrentException())
            )
        )
        if ownsHold do
        (
            try (theHold.Cancel(); ownsHold = false) catch (failure += "\n宿主撤销状态清理失败：" + getCurrentException())
        )
        restoreContext savedSelection savedStack savedLevel savedMode
        if failure != undefined do throw failure
        newBone
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
    
    on btnAutoFind pressed do
    (
        btnAutoFind.enabled = false
        lblFindStatus.text = "扫描全场景 Skin..."
        try
        (
            skinnedObjects = findSkinnedObjects selectedBone
            updateList()
            lblFindStatus.text = "找到 " + (skinnedObjects.count as string) + " 个"
        )
        catch
        (
            skinnedObjects = #()
            updateList()
            lblFindStatus.text = "扫描失败；结果已清空"
            messageBox (getCurrentException()) title:"骨骼扫描失败"
        )
        btnAutoFind.enabled = true
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
    
    on btnExecute pressed do
    (
        if not isValidNode selectedBone do (messageBox "请重新选择骨骼。"; return())
        if skinnedObjects.count == 0 do (messageBox "请添加蒙皮对象。"; return())
        local msg = "静态骨骼修复：" + selectedBone.name + "\n蒙皮对象：\n"
        for obj in skinnedObjects do
        (
            if not isValidNode obj do (messageBox "列表对象已删除，请重新扫描。"; return())
            msg += obj.name + "\n"
        )
        msg += "将创建骨骼并转移 Skin 权重；按选项修改层级、名称和可见性。\n仅支持静态标准控制器；不迁移动画或约束。\n请先另存场景副本。确认继续？"
        if not queryBox msg title:"检查骨骼替换范围" do return()
        btnExecute.enabled = false
        btnAutoFind.enabled = false
        btnAddManual.enabled = false
        btnPickBone.enabled = false
        lblStatus.text = "预检与执行中..."
        pbProgress.value = 0
        try
        (
            local replacement = executeReplacement selectedBone skinnedObjects keepParent:chkKeepParent.checked keepChildren:chkKeepChildren.checked renameOld:chkRename.checked hideOld:chkHideOld.checked
            pbProgress.value = 100
            lblStatus.text = "全部权重回读通过；未保存场景"
            messageBox ("替换完成：" + replacement.name + "\n可通过 Max 撤销本批；请检查变形后自行保存。") title:"骨骼替换结果"
            selectedBone = undefined
            skinnedObjects = #()
            btnPickBone.text = "点击选择骨骼"
            updateList()
        )
        catch
        (
            lblStatus.text = "失败；请查看恢复说明"
            format "[MaxZJTools.BoneOverride] %\n" (getCurrentException())
            messageBox (getCurrentException()) title:"骨骼替换失败"
        )
        btnExecute.enabled = true
        btnAutoFind.enabled = true
        btnAddManual.enabled = true
        btnPickBone.enabled = true
    )
)

if MaxZJTools_Headless != true do createDialog SingleBoneReplacer
