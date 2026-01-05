-- RenameTools.ms
-- 3D Max 节点批量重命名工具 (增强版)
-- 作者: MaxZJTools
-- 功能: 批量重命名场景中的对象、材质、骨骼等
-- 版本: 1.2.0
-- 日期: 2026-01-05

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
            button btnUndo "撤销" width:200 height:35
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
        
        -- 获取要处理的对象
        fn getObjectsToRename =
        (
            local objArray = #()
            
            if chkObjects.checked then
            (
                case renameMode.state of
                (
                    1: -- 选中对象
                    (
                        objArray = selection as array
                    )
                    2: -- 所有对象
                    (
                        objArray = objects as array
                    )
                    3: -- 按类型
                    (
                        case objTypeList.selection of
                        (
                            1: objArray = for obj in geometry collect obj
                            2: objArray = for obj in lights collect obj
                            3: objArray = for obj in cameras collect obj
                            4: objArray = for obj in helpers collect obj
                            5: objArray = for obj in shapes collect obj
                            6: objArray = getAllBones()
                        )
                    )
                )
            )
            
            return objArray
        )
        
        -- 获取要处理的材质
        fn getMaterialsToRename =
        (
            local matArray = #()
            
            if chkMaterials.checked then
            (
                -- 获取场景中所有材质
                for i = 1 to sceneMaterials.count do
                (
                    append matArray sceneMaterials[i]
                )
                
                -- 如果是选中对象模式，只获取选中对象的材质
                if renameMode.state == 1 and selection.count > 0 then
                (
                    matArray = #()
                    for obj in selection do
                    (
                        if obj.material != undefined then
                        (
                            -- 处理多维材质
                            if classOf obj.material == MultiMaterial then
                            (
                                for subMat in obj.material.materialList do
                                (
                                    if subMat != undefined and findItem matArray subMat == 0 do
                                        append matArray subMat
                                )
                            )
                            else
                            (
                                if findItem matArray obj.material == 0 do
                                    append matArray obj.material
                            )
                        )
                    )
                )
            )
            
            return matArray
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
        
        -- 预览重命名
        fn previewRename =
        (
            local previewArray = #()
            local totalCount = 0
            local currentIndex = 1
            
            -- 处理对象
            if chkObjects.checked then
            (
                local objs = getObjectsToRename()
                if objs.count > 0 then
                (
                    append previewArray "--- 对象 ---"
                    for obj in objs do
                    (
                        local oldName = obj.name
                        local newName = generateNewName oldName currentIndex
                        append previewArray (oldName + " -> " + newName)
                        currentIndex += 1
                        totalCount += 1
                    )
                )
            )
            
            -- 处理材质
            if chkMaterials.checked then
            (
                local mats = getMaterialsToRename()
                if mats.count > 0 then
                (
                    if previewArray.count > 0 do append previewArray ""
                    append previewArray "--- 材质 ---"
                    for mat in mats do
                    (
                        local oldName = mat.name
                        local newName = generateNewName oldName currentIndex
                        append previewArray (oldName + " -> " + newName)
                        currentIndex += 1
                        totalCount += 1
                    )
                )
            )
            
            -- 处理骨骼
            if chkBones.checked then
            (
                local bones = getBonesToRename()
                if bones.count > 0 then
                (
                    if previewArray.count > 0 do append previewArray ""
                    append previewArray "--- 骨骼节点 ---"
                    for bone in bones do
                    (
                        local oldName = bone.name
                        local newName = generateNewName oldName currentIndex
                        append previewArray (oldName + " -> " + newName)
                        currentIndex += 1
                        totalCount += 1
                    )
                )
            )
            
            if previewArray.count == 0 then
            (
                previewArray = #("没有找到要重命名的项目")
                totalCount = 0
            )
            
            previewList.items = previewArray
            lblCount.text = "总计: " + totalCount as string + " 项"
        )
        
        -- 预览按钮
        on btnPreview pressed do
        (
            previewRename()
        )
        
        -- 应用重命名
        on btnApply pressed do
        (
            local totalRenamed = 0
            local currentIndex = 1
            
            undo "批量重命名" on
            (
                -- 重命名对象
                if chkObjects.checked then
                (
                    local objs = getObjectsToRename()
                    for obj in objs do
                    (
                        obj.name = generateNewName obj.name currentIndex
                        currentIndex += 1
                        totalRenamed += 1
                    )
                )
                
                -- 重命名材质
                if chkMaterials.checked then
                (
                    local mats = getMaterialsToRename()
                    for mat in mats do
                    (
                        mat.name = generateNewName mat.name currentIndex
                        currentIndex += 1
                        totalRenamed += 1
                    )
                )
                
                -- 重命名骨骼
                if chkBones.checked then
                (
                    local bones = getBonesToRename()
                    for bone in bones do
                    (
                        bone.name = generateNewName bone.name currentIndex
                        currentIndex += 1
                        totalRenamed += 1
                    )
                )
            )
            
            if totalRenamed > 0 then
            (
                messageBox ("成功重命名 " + totalRenamed as string + " 项！") title:"完成"
                previewRename()
            )
            else
            (
                messageBox "没有找到要重命名的项目！" title:"提示"
            )
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
    createDialog renameNodesRollout
)
