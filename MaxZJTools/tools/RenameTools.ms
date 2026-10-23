-- RenameTools.ms
-- 3D Max 节点批量重命名工具 (增强版)
-- 作者: MaxZJTools
-- 功能: 批量重命名场景中的对象、材质、骨骼等
-- 版本: 1.2.1
-- 日期: 2026-10-23

global renameNodesRollout
global MaxZJTools_Headless
try (destroyDialog renameNodesRollout) catch ()
(
    -- 创建主界面
    rollout renameNodesRollout "节点批量重命名工具" width:450 height:650
    (
        group "重命名目标"
        (
            checkbox chkObjects "模型对象" checked:true across:3
            checkbox chkMaterials "材质" checked:false
            checkbox chkBones "骨骼节点" checked:false
        )
        
        group "对象选择范围"
        (
            radioButtons renameMode labels:#("选中对象", "所有对象", "按类型") default:1
            
            dropDownList objTypeList "对象类型:" items:#("几何体", "灯光", "相机", "辅助对象", "形状", "所有骨骼") enabled:false
        )
        
        group "重命名方法"
        (
            radioButtons renameMethod labels:#("前缀", "后缀", "替换", "序列重命名") default:1 columns:2
            
            editText prefixText "前缀:" text:"" enabled:true
            editText suffixText "后缀:" text:"" enabled:false
            editText findText "查找:" text:"" enabled:false
            editText replaceText "替换为:" text:"" enabled:false
            editText baseName "基础名称:" text:"Object" enabled:false
            spinner startNumber "起始数字:" range:[0,9999,1] type:#integer enabled:false
            spinner digitCount "数字位数:" range:[1,5,3] type:#integer enabled:false
        )
        
        group "预览"
        (
            listBox previewList "重命名预览:" height:8
            label lblCount "总计: 0 项" align:#left
        )
        
        group "操作"
        (
            button btnPreview "预览" width:200 height:35 across:2
            button btnApply "应用重命名" width:200 height:35
            button btnRefresh "刷新列表" width:200 height:35 across:2
            button btnUndo "撤销 Max 上一步" width:200 height:35
        )
        
        -- 当重命名模式改变时
        on renameMode changed state do
        (
            objTypeList.enabled = (state == 3)
        )
        
        -- 当重命名方法改变时
        on renameMethod changed state do
        (
            prefixText.enabled = (state == 1)
            suffixText.enabled = (state == 2)
            findText.enabled = (state == 3)
            replaceText.enabled = (state == 3)
            baseName.enabled = (state == 4)
            startNumber.enabled = (state == 4)
            digitCount.enabled = (state == 4)
        )
        
        -- 判断对象是否为骨骼
        fn isBone obj =
        (
            return (classOf obj == BoneGeometry or classOf obj == Biped_Object or superClassOf obj == helper and matchPattern obj.name pattern:"*Bone*")
        )
        
        -- 获取所有骨骼
        fn getAllBones =
        (
            local boneArray = #()
            for obj in objects do
            (
                if isBone obj do
                    append boneArray obj
            )
            return boneArray
        )
        
        -- 范围与目标类别分离，材质“按类型”不依赖模型对象复选框。
        fn getScopeNodes =
        (
            case renameMode.state of
            (
                1: (selection as array)
                2: (objects as array)
                3: (case objTypeList.selection of
                (
                    1: (geometry as array)
                    2: (lights as array)
                    3: (cameras as array)
                    4: (helpers as array)
                    5: (shapes as array)
                    6: (getAllBones())
                    default: #()
                ))
            )
        )
        fn getObjectsToRename = (if chkObjects.checked then getScopeNodes() else #())

        -- 获取要处理的材质
        fn getMaterialsToRename =
        (
            local matArray = #()
            if chkMaterials.checked do
            (
                if renameMode.state == 2 then
                    matArray = sceneMaterials as array
                else
                    for obj in getScopeNodes() where isValidNode obj do
                    (
                        if obj.material != undefined do
                        (
                            if classOf obj.material == MultiMaterial then
                            (
                                for subMat in obj.material.materialList where subMat != undefined do appendIfUnique matArray subMat
                            )
                            else appendIfUnique matArray obj.material
                        )
                    )
            )
            matArray
        )

        -- 获取要处理的骨骼
        fn getBonesToRename =
        (
            local boneArray = #()
            
            if chkBones.checked then
            (
                case renameMode.state of
                (
                    1: -- 选中对象
                    (
                        for obj in selection do
                        (
                            if isBone obj do
                                append boneArray obj
                        )
                    )
                    2: -- 所有骨骼
                    (
                        boneArray = getAllBones()
                    )
                    3: -- 按类型
                    (
                        if objTypeList.selection == 6 do
                            boneArray = getAllBones()
                    )
                )
            )
            
            return boneArray
        )
        
        -- 生成新名称
        fn generateNewName oldName index =
        (
            local newName = oldName
            
            case renameMethod.state of
            (
                1: -- 前缀
                (
                    newName = prefixText.text + oldName
                )
                2: -- 后缀
                (
                    newName = oldName + suffixText.text
                )
                3: -- 替换
                (
                    if findText.text != "" do
                    (
                        newName = substituteString oldName findText.text replaceText.text
                    )
                )
                4: -- 序列重命名
                (
                    local numStr = (startNumber.value + index - 1) as string
                    while numStr.count < digitCount.value do
                        numStr = "0" + numStr
                    newName = baseName.text + "_" + numStr
                )
            )
            
            return newName
        )
        
        -- 每行保存引用、旧名、新名和类别；执行只使用已检查的清单。
        local renamePlan = #()
        local previewSettings = #()
        fn settingsSnapshot =
        (
            #(chkObjects.checked, chkMaterials.checked, chkBones.checked, renameMode.state,
              objTypeList.selection, renameMethod.state, prefixText.text, suffixText.text,
              findText.text, replaceText.text, baseName.text, startNumber.value, digitCount.value)
        )
        fn buildPlan =
        (
            local targets = #()
            local kinds = #()
            for obj in getObjectsToRename() do (appendIfUnique targets obj)
            for obj in targets do append kinds #node
            for mat in getMaterialsToRename() where findItem targets mat == 0 do
            (
                append targets mat
                append kinds #material
            )
            for bone in getBonesToRename() where findItem targets bone == 0 do
            (
                append targets bone
                append kinds #node
            )
            for i = 1 to targets.count collect #(targets[i], targets[i].name, generateNewName targets[i].name i, kinds[i])
        )
        fn validatePlan plan =
        (
            local targets = for row in plan collect row[1]
            local knownMaterials = #()
            fn visitMaterial mat visited =
            (
                if mat != undefined and findItem visited mat == 0 do
                (
                    append visited mat
                    for i = 1 to getNumSubMtls mat do visitMaterial (getSubMtl mat i) visited
                )
            )
            for mat in sceneMaterials do visitMaterial mat knownMaterials
            for i = 1 to plan.count do
            (
                local row = plan[i]
                if row[4] == #node and not isValidNode row[1] do throw "预览对象已删除，请刷新。"
                if row[1].name != row[2] do throw "对象名称已变化，请刷新。"
                if trimRight (trimLeft row[3]) == "" do throw "新名称不能为空或仅为空格。"
                -- 保留原本未改名的重复项；改变名称时不制造新的同类重名。
                if row[3] != row[2] do
                (
                    for j = 1 to plan.count where j != i and plan[j][4] == row[4] do
                        if toLower plan[j][3] == toLower row[3] do throw ("清单内重名：" + row[3])
                    local candidates = if row[4] == #node then (objects as array) else knownMaterials
                    for other in candidates where findItem targets other == 0 do
                        if toLower other.name == toLower row[3] do throw ("与范围外对象重名：" + row[3])
                )
            )
            true
        )
        fn previewRename =
        (
            renamePlan = #()
            previewSettings = #()
            try
            (
                local plan = buildPlan()
                validatePlan plan
                renamePlan = plan
                previewSettings = settingsSnapshot()
                previewList.items = if plan.count == 0 then #("没有目标：空选择不会修改场景材质") else (for row in plan collect (row[2] + " -> " + row[3]))
                lblCount.text = "总计: " + (plan.count as string) + " 项（已去重）"
                true
            )
            catch
            (
                previewList.items = #("预览阻断：" + getCurrentException())
                lblCount.text = "请解决冲突后重新预览"
                false
            )
        )
        fn applyPreview =
        (
            local currentSettings = settingsSnapshot()
            if previewSettings.count != currentSettings.count do throw "请先预览。"
            for i = 1 to currentSettings.count do
                if currentSettings[i] != previewSettings[i] do throw "参数已变化，请重新预览。"
            local fresh = buildPlan()
            if fresh.count != renamePlan.count do throw "目标范围已变化，请重新预览。"
            for i = 1 to fresh.count do
                for j = 1 to 4 do
                    if fresh[i][j] != renamePlan[i][j] do throw "目标或名称已变化，请重新预览。"
            validatePlan renamePlan
            local changed = 0
            local failures = #()
            local skipped = 0
            undo "MaxZJTools 批量重命名" on
            (
                for row in renamePlan do
                (
                    if row[2] == row[3] then skipped += 1
                    else try
                    (
                        row[1].name = row[3]
                        if row[1].name != row[3] do throw "名称回读不一致"
                        changed += 1
                    )
                    catch (append failures (row[2] + ": " + getCurrentException()))
                )
            )
            previewSettings = #()
            renamePlan = #()
            for reason in failures do format "[MaxZJTools.RenameTools 1.2.1] %\n" reason
            #(changed, failures, skipped)
        )
        on btnPreview pressed do previewRename()
        on btnApply pressed do
        (
            try
            (
                local result = applyPreview()
                local msg = "已改名: " + (result[1] as string) + "；失败: " + (result[2].count as string) + "；未变化: " + (result[3] as string)
                previewList.items = #(msg, "本批已结束；继续操作请重新预览。失败详情见 Listener。")
                lblCount.text = msg
                messageBox (msg + "\n已完成修改可通过 Max 撤销；本工具不保存场景。") title:"重命名结果"
            )
            catch (messageBox (getCurrentException()) title:"未执行重命名")
        )

        -- 刷新列表
        on btnRefresh pressed do
        (
            previewRename()
        )
        
        -- 撤销按钮
        on btnUndo pressed do
        (
            max undo
            previewRename()
        )
        
        -- 复选框改变时更新预览
        on chkObjects changed state do previewRename()
        on chkMaterials changed state do previewRename()
        on chkBones changed state do previewRename()
        
        -- 对话框打开时
        on renameNodesRollout open do
        (
            previewRename()
        )
    )
    
    -- 创建并显示对话框
    if MaxZJTools_Headless != true do createDialog renameNodesRollout
)
