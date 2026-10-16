/* AssetsMG integration v1.0.0 / VertexColorWriter feature baseline v1.4.0
   RGB: map channel 0; Alpha: map channel -2. Only checked components change.
   Requires sibling UI and texture sources. All runtime state belongs to AssetsMG.
*/
global AssetsMG_VCW_UI, AssetsMG_VCW_Panel, AssetsMG_VCW_UIAssembly, AssetsMG_VCW_UISource, AssetsMG_VCW_AcceleratorsBefore
global AssetsMG_VCW_CloseEnough, AssetsMG_VCW_HasMap, AssetsMG_VCW_Verify, AssetsMG_VCW_MapHeights, AssetsMG_VCW_BakeNode
global AssetsMG_VCW_PasteChannel, AssetsMG_VCW_SetCornerMap, AssetsMG_VCW_OpenUI, AssetsMG_VCW_UpdateSelection, AssetsMG_VCW_OnBake
global AssetsMG_VCW_MeasureHeight, AssetsMG_VCW_HeightSample, AssetsMG_VCW_OverlayRegistered, AssetsMG_VCW_HeightDrawError
global AssetsMG_VCW_DrawHeightOverlay, AssetsMG_VCW_DrawHeightText, AssetsMG_VCW_StopHeightOverlay, AssetsMG_VCW_OnHeightDisplayChanged
global AssetsMG_VCW_CheckVertexContext, AssetsMG_VCW_CaptureVertexSelection, AssetsMG_VCW_UsedVertexSelection
try (destroyDialog AssetsMG_VCW_UI) catch ()
-- Unregister the OLD function value before redefining it on a script reload.
try (unregisterRedrawViewsCallback AssetsMG_VCW_DrawHeightOverlay) catch ()
AssetsMG_VCW_OverlayRegistered = false
AssetsMG_VCW_HeightSample = undefined
AssetsMG_VCW_HeightDrawError = undefined

fn AssetsMG_VCW_CloseEnough a b = ((abs (a - b)) <= (0.000001 * (amax #(1.0, abs a, abs b))))
fn AssetsMG_VCW_HasMap source channel =
(
    (meshop.getMapSupport source channel) and ((meshop.getNumMapVerts source channel) > 0)
)
fn AssetsMG_VCW_Verify expected actual channels:#(0,-2) =
(
    if expected.numverts != actual.numverts or expected.numfaces != actual.numfaces do throw "几何拓扑发生变化。"
    for v = 1 to expected.numverts do
    (
        local a = getVert expected v
        local b = getVert actual v
        if not ((AssetsMG_VCW_CloseEnough a.x b.x) and (AssetsMG_VCW_CloseEnough a.y b.y) and (AssetsMG_VCW_CloseEnough a.z b.z)) do throw "顶点位置发生变化。"
    )
    for f = 1 to expected.numfaces do if (getFace expected f) != (getFace actual f) do throw "面顺序发生变化。"
    for channel in channels do
    (
        local expectedMap = AssetsMG_VCW_HasMap expected channel
        if expectedMap != (AssetsMG_VCW_HasMap actual channel) do throw ("映射通道状态不一致：" + (channel as string))
        if expectedMap do
        (
            local actualCount = meshop.getNumMapVerts actual channel
            for f = 1 to expected.numfaces do
            (
                local ef = meshop.getMapFace expected channel f
                local af = meshop.getMapFace actual channel f
                for corner = 1 to 3 do
                (
                    local actualIndex = af[corner] as integer
                    if actualIndex < 1 or actualIndex > actualCount do throw "映射顶点索引无效。"
                    local a = meshop.getMapVert expected channel (ef[corner] as integer)
                    local b = meshop.getMapVert actual channel actualIndex
                    if not ((AssetsMG_VCW_CloseEnough a.x b.x) and (AssetsMG_VCW_CloseEnough a.y b.y) and (AssetsMG_VCW_CloseEnough a.z b.z)) do throw ("映射回读不一致，通道：" + (channel as string))
                )
            )
        )
    )
    true
)
fn AssetsMG_VCW_MapHeights values mappingHeight:1.0 startHeight:0.0 fromBottom:false clampRange:false =
(
    if mappingHeight <= 0 do throw "映射高度必须大于 0。"
    if values.count == 0 do throw "模型没有可映射的顶点。"
    local origin = if fromBottom then (amin values) else startHeight
    local mappedHeights = #()
    mappedHeights.count = values.count
    local outside = 0
    for v = 1 to values.count do
    (
        local factor = (values[v] - origin) / mappingHeight
        if factor < 0.0 or factor > 1.0 do outside += 1
        if clampRange do factor = amax 0.0 (amin 1.0 factor)
        mappedHeights[v] = factor
    )
    #(mappedHeights, outside)
)
fn AssetsMG_VCW_SetCornerMap source channel cornerValues =
(
    meshop.setMapSupport source channel true
    meshop.setNumMapVerts source channel cornerValues.count keep:false
    -- setMapSupport allocates face records for 0 and negative channels too.
    for i = 1 to cornerValues.count do meshop.setMapVert source channel i cornerValues[i]
    for f = 1 to source.numfaces do
    (
        local offset = (f - 1) * 3
        meshop.setMapFace source channel f [offset + 1, offset + 2, offset + 3]
    )
)
fn AssetsMG_VCW_PasteChannel sourceNode target channel modifierName =
(
    ChannelInfo.CopyChannel sourceNode 3 channel
    local previousCount = target.modifiers.count
    ChannelInfo.PasteChannel target 3 channel
    if target.modifiers.count != previousCount + 1 do throw "未能建立颜色写入修改器。"
    local pastedModifier = target.modifiers[1]
    if classOf pastedModifier != UVW_Mapping_Paste do throw "颜色写入返回了意外的修改器。"
    pastedModifier.name = modifierName
    pastedModifier
)
-- Selection is captured from the evaluated mesh BEFORE leaving vertex mode.
-- Reject intervening modifiers: upstream indices need not match the final mesh.
fn AssetsMG_VCW_CheckVertexContext obj =
(
    if selection.count != 1 or selection[1] != obj do throw "选中顶点模式需要单选一个几何模型。"
    if subObjectLevel != 1 do throw "请进入顶点子对象模式，并选中要填充的点。"
    local current = modPanel.getCurrentObject()
    if current == undefined do throw "请在修改面板中选择可编辑网格或可编辑多边形。"
    local supported = (classOf current == Editable_Mesh) or (classOf current == Editable_Poly) or (classOf current == Edit_Mesh) or (classOf current == Edit_Poly)
    if not supported do throw "请在 Editable Mesh / Poly 或 Edit Mesh / Poly 的顶点层级选点。"
    local foundCurrent = current == obj.baseObject
    for md in obj.modifiers do
    (
        if md == current then (foundCurrent = true; exit)
        local toolPaste = classOf md == UVW_Mapping_Paste and (md.name == "AssetsMG VCW - RGB" or md.name == "AssetsMG VCW - Alpha")
        local toolAdapter = false
        if classOf md == Turn_to_Mesh do
            toolAdapter = (md.name == "AssetsMG VCW - Mesh Adapter") and md.selectionConversion == 0 and md.selectionLevel == 0
        if not (toolPaste or toolAdapter) do throw "选点层上方还有其他修改器。请在栈顶添加 Edit Poly / Edit Mesh 后选点，避免顶点对应错误。"
    )
    if not foundCurrent do throw "当前修改面板与选中模型不一致，请重新选择模型。"
    true
)
fn AssetsMG_VCW_UsedVertexSelection source =
(
    local selectedVertices = copy (getVertSelection source)
    local usedVertices = #{}
    for f = 1 to source.numfaces do
    (
        local faceVerts = getFace source f
        for corner = 1 to 3 do usedVertices[faceVerts[corner] as integer] = true
    )
    -- Isolated vertices have no map-face corners and cannot store these colors.
    selectedVertices * usedVertices
)
fn AssetsMG_VCW_CaptureVertexSelection obj =
(
    AssetsMG_VCW_CheckVertexContext obj
    local captured = snapshotAsMesh obj
    local failure = undefined
    try
    (
        if (AssetsMG_VCW_UsedVertexSelection captured).numberSet == 0 do throw "没有选中可写入的顶点。请选择至少一个连接网格面的顶点。"
    )
    catch (failure = getCurrentException())
    if failure != undefined do (delete captured; throw failure)
    captured -- Caller owns this temporary mesh value; it is never a scene node.
)
fn AssetsMG_VCW_BakeNode obj gradient:true writeChannels:#(true,false,false,false) lowRGBA:#(0.0,0.0,0.0,0.0) highRGBA:#(1.0,1.0,1.0,1.0) worldSpace:true meters:true preview:false mappingHeight:1.0 startHeight:0.0 fromBottom:false clampRange:true textureSource:undefined uvChannel:1 textureColor:true textureBilinear:true textureRepeat:false selectedOnly:false selectionSnapshot:undefined =
(
    if not (isValidNode obj) do throw "场景对象已失效。"
    if (superClassOf obj) != GeometryClass do throw "请选择几何模型。"
    if writeChannels.count != 4 or lowRGBA.count != 4 or highRGBA.count != 4 do throw "RGBA 参数需要四个分量。"
    local writeRGB = writeChannels[1] or writeChannels[2] or writeChannels[3]
    local writeAlpha = writeChannels[4]
    local useTexture = textureSource != undefined
    local useHeight = gradient and not useTexture
    if not (writeRGB or writeAlpha) do throw "请至少勾选一个写入通道。"
    if useHeight and mappingHeight <= 0 do throw "映射高度必须大于 0。"
    if useTexture do
        if uvChannel < 1 or uvChannel > 99 or uvChannel != (uvChannel as integer) do throw "UV 通道必须是 1–99 的整数。"
    for md in obj.modifiers where (superClassOf md) == SpacewarpModifier do throw "暂不支持世界空间修改器，请使用导出副本。"
    local divisor = if useHeight and meters then (units.decodeValue "1m") else 1.0
    if divisor <= 0 do throw "场景单位比例无效。"
    local affectedVertices = undefined
    if selectedOnly do
    (
        if selectionSnapshot == undefined do throw "选中顶点模式缺少写入前的选择快照；已取消写入。"
        affectedVertices = AssetsMG_VCW_UsedVertexSelection selectionSnapshot
        if affectedVertices.numberSet == 0 do throw "没有选中可写入的顶点；已取消写入。"
    )
    local oldMods = for md in obj.modifiers collect md
    local sourceMesh = undefined
    local verifyMesh = undefined
    local tempNode = undefined
    local failure = undefined
    local result = undefined
    try
    (
        -- Reuse only a contiguous tool-owned stack prefix. Keep an old paste
        -- when its channel is unchecked, so Alpha-only rebakes retain RGB.
        local prefixIndex = 1
        local previousRGB = undefined
        local previousAlpha = undefined
        while prefixIndex <= oldMods.count do
        (
            local md = oldMods[prefixIndex]
            if classOf md != UVW_Mapping_Paste then exit
            if (md.name == "AssetsMG VCW - RGB") and previousRGB == undefined then previousRGB = md
            else if md.name == "AssetsMG VCW - Alpha" and previousAlpha == undefined then previousAlpha = md
            else exit
            prefixIndex += 1
        )
        local reuseAdapter = false
        if prefixIndex <= oldMods.count do
            reuseAdapter = (classOf oldMods[prefixIndex] == Turn_to_Mesh) and (oldMods[prefixIndex].name == "AssetsMG VCW - Mesh Adapter")
        if not reuseAdapter do
        (
            previousRGB = undefined
            previousAlpha = undefined
            local adapter = Turn_to_Mesh()
            adapter.name = "AssetsMG VCW - Mesh Adapter"
            adapter.selectionConversion = 0
            adapter.selectionLevel = 0
            addModifier obj adapter
        )
        sourceMesh = snapshotAsMesh obj
        if sourceMesh.numverts == 0 or sourceMesh.numfaces == 0 do throw "模型没有可处理的网格面。"
        if selectedOnly then
            AssetsMG_VCW_Verify selectionSnapshot sourceMesh channels:#()
        else affectedVertices = #{1..sourceMesh.numverts}
        local factors = for v = 1 to sourceMesh.numverts collect 0.0
        local outside = 0
        if useHeight do
        (
            local objectTM = obj.objectTransform
            for v = 1 to sourceMesh.numverts do
            (
                local p = getVert sourceMesh v
                if worldSpace do p = p * objectTM
                factors[v] = p.z / divisor
            )
            -- Bottom alignment always uses the WHOLE model, even for a partial fill.
            local mapping = AssetsMG_VCW_MapHeights factors mappingHeight:mappingHeight startHeight:startHeight fromBottom:fromBottom clampRange:false
            factors = mapping[1]
            for v in affectedVertices where factors[v] < 0.0 or factors[v] > 1.0 do outside += 1
            if clampRange do for v = 1 to factors.count do factors[v] = amax 0.0 (amin 1.0 factors[v])
        )
        local textureSamples = #()
        if useTexture do
        (
            if not (AssetsMG_VCW_HasMap sourceMesh uvChannel) do throw ("模型缺少 UV 通道 " + (uvChannel as string) + "，请先展开 UV。")
            if (meshop.getNumMapFaces sourceMesh uvChannel) != sourceMesh.numfaces do throw "UV 面数量与模型不一致。"
            local uvCount = meshop.getNumMapVerts sourceMesh uvChannel
            textureSamples.count = sourceMesh.numfaces * 3
            -- Sample face corners, not geometry vertices: UV seams may have different colors.
            -- Cache per UV vertex so shared coordinates cross the .NET boundary only once.
            local sampledUV = #()
            sampledUV.count = uvCount
            for f = 1 to sourceMesh.numfaces do
            (
                local uvFace = meshop.getMapFace sourceMesh uvChannel f
                local geometryFace = getFace sourceMesh f
                for corner = 1 to 3 where affectedVertices[geometryFace[corner] as integer] do
                (
                    local uvIndex = uvFace[corner] as integer
                    if uvIndex < 1 or uvIndex > uvCount do throw "UV 顶点索引无效。"
                    local uv = meshop.getMapVert sourceMesh uvChannel uvIndex
                    if uv.x < 0 or uv.x > 1 or uv.y < 0 or uv.y > 1 do outside += 1
                    if sampledUV[uvIndex] == undefined do
                    (
                        local pixel = textureSource.Sample uv.x uv.y textureColor textureBilinear textureRepeat
                        sampledUV[uvIndex] = #(pixel.R as float, pixel.G as float, pixel.B as float, pixel.A as float)
                    )
                    textureSamples[(f - 1) * 3 + corner] = sampledUV[uvIndex]
                )
            )
        )
        if writeRGB do
        (
            local oldColorCount = if AssetsMG_VCW_HasMap sourceMesh 0 then (meshop.getNumMapVerts sourceMesh 0) else 0
            local cornerColors = #()
            cornerColors.count = sourceMesh.numfaces * 3
            for f = 1 to sourceMesh.numfaces do
            (
                local geometryFace = getFace sourceMesh f
                local colorFace = if oldColorCount > 0 then (meshop.getMapFace sourceMesh 0 f) else [0,0,0]
                for corner = 1 to 3 do
                (
                    local c = [0.0,0.0,0.0]
                    if oldColorCount > 0 do
                    (
                        local oldIndex = colorFace[corner] as integer
                        if oldIndex < 1 or oldIndex > oldColorCount do throw "原有顶点色索引无效。"
                        c = meshop.getMapVert sourceMesh 0 oldIndex
                    )
                    local factor = factors[geometryFace[corner] as integer]
                    if affectedVertices[geometryFace[corner] as integer] do
                        for component = 1 to 3 where writeChannels[component] do
                            c[component] = if useTexture then textureSamples[(f - 1) * 3 + corner][component] else (lowRGBA[component] + (highRGBA[component] - lowRGBA[component]) * factor)
                    cornerColors[(f - 1) * 3 + corner] = c
                )
            )
            AssetsMG_VCW_SetCornerMap sourceMesh 0 cornerColors
        )
        if writeAlpha do
        (
            local oldAlphaCount = if AssetsMG_VCW_HasMap sourceMesh -2 then (meshop.getNumMapVerts sourceMesh -2) else 0
            local cornerAlpha = #()
            cornerAlpha.count = sourceMesh.numfaces * 3
            for f = 1 to sourceMesh.numfaces do
            (
                local geometryFace = getFace sourceMesh f
                local alphaFace = if oldAlphaCount > 0 then (meshop.getMapFace sourceMesh -2 f) else [0,0,0]
                for corner = 1 to 3 do
                (
                    local alphaColor = [1.0,1.0,1.0]
                    if affectedVertices[geometryFace[corner] as integer] then
                    (
                        local factor = factors[geometryFace[corner] as integer]
                        local alphaValue = if useTexture then textureSamples[(f - 1) * 3 + corner][4] else (lowRGBA[4] + (highRGBA[4] - lowRGBA[4]) * factor)
                        alphaColor = [alphaValue,alphaValue,alphaValue]
                    )
                    else if oldAlphaCount > 0 do
                    (
                        local oldIndex = alphaFace[corner] as integer
                        if oldIndex < 1 or oldIndex > oldAlphaCount do throw "原有顶点 Alpha 索引无效。"
                        alphaColor = meshop.getMapVert sourceMesh -2 oldIndex
                    )
                    cornerAlpha[(f - 1) * 3 + corner] = alphaColor
                )
            )
            AssetsMG_VCW_SetCornerMap sourceMesh -2 cornerAlpha
        )
        tempNode = mesh name:(uniqueName "__AssetsMG_VCW_TEMP__") mesh:sourceMesh
        tempNode.isHidden = true
        if writeRGB do AssetsMG_VCW_PasteChannel tempNode obj 0 "AssetsMG VCW - RGB"
        if writeAlpha do AssetsMG_VCW_PasteChannel tempNode obj -2 "AssetsMG VCW - Alpha"
        verifyMesh = snapshotAsMesh obj
        AssetsMG_VCW_Verify sourceMesh verifyMesh channels:(if useTexture then #(0,-2,uvChannel) else #(0,-2))
        result = #(amin factors, amax factors, outside, sourceMesh.numverts, affectedVertices.numberSet)
        -- Each new paste stores the whole channel, including preserved components.
        if previousRGB != undefined and writeRGB do deleteModifier obj previousRGB
        if previousAlpha != undefined and writeAlpha do deleteModifier obj previousAlpha
    )
    catch (failure = getCurrentException())
    if tempNode != undefined do (if isValidNode tempNode do delete tempNode)
    if sourceMesh != undefined do delete sourceMesh
    if verifyMesh != undefined do delete verifyMesh
    if failure != undefined do
    (
        for k = obj.modifiers.count to 1 by -1 do
            if (findItem oldMods obj.modifiers[k]) == 0 do deleteModifier obj k
        throw failure
    )
    if preview do try (obj.vertexColorType = #color; obj.showVertexColors = true) catch ()
    result
)

-- Read-only: temporary mesh VALUE, never a scene node or modifier.
-- Append vertex counts/context to the height sample; evaluate the mesh only once per poll.
fn AssetsMG_VCW_MeasureHeight obj =
(
    if not (isValidNode obj) do throw "对象已失效"
    if (superClassOf obj) != GeometryClass do throw "请单选一个几何模型"
    for md in obj.modifiers where (superClassOf md) == SpacewarpModifier do throw "暂不测量世界空间修改器"
    local divisor = units.decodeValue "1m"
    if divisor <= 0 do throw "场景单位比例无效"
    local measuredMesh = undefined
    local measurement = undefined
    local failure = undefined
    try
    (
        measuredMesh = snapshotAsMesh obj
        if measuredMesh.numverts == 0 do throw "模型没有网格顶点"
        local objectTM = obj.objectTransform
        local firstPoint = (getVert measuredMesh 1) * objectTM
        local lower = copy firstPoint
        local upper = copy firstPoint
        for v = 2 to measuredMesh.numverts do
        (
            local p = (getVert measuredMesh v) * objectTM
            lower.x = amin lower.x p.x; lower.y = amin lower.y p.y; lower.z = amin lower.z p.z
            upper.x = amax upper.x p.x; upper.y = amax upper.y p.y; upper.z = amax upper.z p.z
        )
        local vertexCount = 0
        local vertexContextValid = false
        local vertexReason = ""
        try
        (
            AssetsMG_VCW_CheckVertexContext obj
            vertexCount = (AssetsMG_VCW_UsedVertexSelection measuredMesh).numberSet
            vertexContextValid = true
        )
        catch (vertexReason = getCurrentException())
        measurement = #(obj, lower, upper, (upper.z - lower.z) / divisor, lower.z / divisor, upper.z / divisor, vertexCount, measuredMesh.numverts, vertexContextValid, vertexReason)
    )
    catch (failure = getCurrentException())
    if measuredMesh != undefined do delete measuredMesh
    if failure != undefined do throw failure
    measurement
)
fn AssetsMG_VCW_StopHeightOverlay =
(
    if AssetsMG_VCW_OverlayRegistered == true do unregisterRedrawViewsCallback AssetsMG_VCW_DrawHeightOverlay
    AssetsMG_VCW_OverlayRegistered = false
    AssetsMG_VCW_HeightSample = undefined
    AssetsMG_VCW_HeightDrawError = undefined
    redrawViews()
)
fn AssetsMG_VCW_DrawHeightText worldPoint caption ink =
(
    -- wText clips text at the viewport edge; use pixel coordinates consistently.
    local screenPoint = gw.wTransPoint worldPoint applyUIScaling:false
    screenPoint.x += 12
    screenPoint.z = 0
    gw.wText (screenPoint + [1,1,0]) caption color:black applyUIScaling:false
    gw.wText screenPoint caption color:ink applyUIScaling:false
)
fn AssetsMG_VCW_DrawHeightOverlay =
(
    -- Draw cached bounds only. Mesh evaluation must NEVER occur per redraw.
    if AssetsMG_VCW_Panel == undefined or AssetsMG_VCW_HeightSample == undefined do return false
    if AssetsMG_VCW_Panel.IsDisposed or not AssetsMG_VCW_Panel.ShowHeightRuler or AssetsMG_VCW_Panel.IsBusy do return false
    local sample = AssetsMG_VCW_HeightSample
    local obj = sample[1]
    if not (isValidNode obj) do return false
    if selection.count != 1 do return false
    if selection[1] != obj or obj.isHiddenInVpt do return false
    local savedLimits = undefined
    try
    (
        local lower = sample[2]
        local upper = sample[3]
        local viewTM = viewport.getTM()
        local viewRight = (inverse viewTM).row1
        viewRight.z = 0
        if (length viewRight) < 0.0001 then viewRight = [1,0,0] else viewRight = normalize viewRight
        local halfSize = (upper - lower) * 0.5
        local sideDistance = (abs viewRight.x) * halfSize.x + (abs viewRight.y) * halfSize.y
        local gap = amax (units.decodeValue "0.02m") ((amax #(halfSize.x, halfSize.y, halfSize.z)) * 0.15)
        local anchor = (lower + upper) * 0.5 + viewRight * (sideDistance + gap)
        local bottomPoint = [anchor.x,anchor.y,lower.z]
        local topPoint = [anchor.x,anchor.y,upper.z]
        if (gw.isPerspectiveView()) and (((bottomPoint * viewTM).z >= 0) or ((topPoint * viewTM).z >= 0)) do return false
        gw.setTransform (matrix3 1)
        savedLimits = gw.getRndLimits()
        gw.setRndLimits (for limit in savedLimits where limit != #zBuffer collect limit)
        local ink = color 255 218 112
        gw.setColor #line ink
        gw.polyline #(bottomPoint,topPoint) false
        local tick = viewRight * gap * 0.4
        gw.polyline #((bottomPoint - tick),(bottomPoint + tick)) false
        gw.polyline #((topPoint - tick),(topPoint + tick)) false
        local lowScreen = gw.wTransPoint bottomPoint applyUIScaling:false
        local highScreen = gw.wTransPoint topPoint applyUIScaling:false
        local screenSpan = length [highScreen.x-lowScreen.x,highScreen.y-lowScreen.y,0]
        AssetsMG_VCW_DrawHeightText anchor ("高度 " + (formattedPrint sample[4] format:".3f") + " m") ink
        -- Top/bottom views and very small objects cannot fit three labels.
        if screenSpan > 90 do
        (
            AssetsMG_VCW_DrawHeightText topPoint ("顶部 " + (formattedPrint sample[6] format:".3f") + " m") white
            AssetsMG_VCW_DrawHeightText bottomPoint ("底部 " + (formattedPrint sample[5] format:".3f") + " m") white
        )
        gw.enlargeUpdateRect #whole
        gw.updateScreen()
        if AssetsMG_VCW_HeightDrawError != undefined do AssetsMG_VCW_Panel.SetRulerError ""
        AssetsMG_VCW_HeightDrawError = undefined
    )
    catch
    (
        local failure = getCurrentException()
        if failure != AssetsMG_VCW_HeightDrawError do
        (
            format "[AssetsMG.VertexColorWriter] Height ruler: %\n" failure
            AssetsMG_VCW_Panel.SetRulerError failure
        )
        AssetsMG_VCW_HeightDrawError = failure
    )
    if savedLimits != undefined do gw.setRndLimits savedLimits
    true
)
fn AssetsMG_VCW_UpdateSelection sender args =
(
    if AssetsMG_VCW_Panel != undefined do
    (
        if AssetsMG_VCW_Panel.IsDisposed or AssetsMG_VCW_Panel.IsBusy do return false
        local modelCount = 0
        for obj in selection where (superClassOf obj) == GeometryClass do modelCount += 1
        AssetsMG_VCW_Panel.SetSelection modelCount (selection.count - modelCount)
        local previousSample = AssetsMG_VCW_HeightSample
        AssetsMG_VCW_HeightSample = undefined
        if selection.count == 1 and modelCount == 1 then
        (
            local startedAt = timeStamp()
            try
            (
                local sample = AssetsMG_VCW_MeasureHeight selection[1]
                AssetsMG_VCW_HeightSample = sample
                AssetsMG_VCW_Panel.SetHeightMeasurement sample[1].name sample[4] sample[5] sample[6]
                AssetsMG_VCW_Panel.SetVertexSelection sample[7] sample[8] sample[9] sample[10]
            )
            catch
            (
                AssetsMG_VCW_HeightSample = undefined
                AssetsMG_VCW_Panel.SetHeightUnavailable ("无法测量：" + (getCurrentException()))
                AssetsMG_VCW_Panel.SetVertexSelection 0 0 false (getCurrentException())
            )
            AssetsMG_VCW_Panel.SetMeasurementCost (amax 0 (timeStamp() - startedAt))
        )
        else
        (
            AssetsMG_VCW_Panel.SetHeightUnavailable (if selection.count > 1 then "已多选，请单选查看高度" else "请选择一个模型查看高度")
            AssetsMG_VCW_Panel.SetMeasurementCost 0
            AssetsMG_VCW_Panel.SetVertexSelection 0 0 false "请单选一个模型，进入顶点模式并选点。"
        )
        local needsRedraw = (previousSample == undefined) != (AssetsMG_VCW_HeightSample == undefined)
        if previousSample != undefined and AssetsMG_VCW_HeightSample != undefined do
            needsRedraw = previousSample[1] != AssetsMG_VCW_HeightSample[1] or previousSample[2] != AssetsMG_VCW_HeightSample[2] or previousSample[3] != AssetsMG_VCW_HeightSample[3] or previousSample[4] != AssetsMG_VCW_HeightSample[4] or previousSample[5] != AssetsMG_VCW_HeightSample[5] or previousSample[6] != AssetsMG_VCW_HeightSample[6]
        if needsRedraw and AssetsMG_VCW_OverlayRegistered do redrawViews()
    )
)
fn AssetsMG_VCW_OnHeightDisplayChanged sender args =
(
    if AssetsMG_VCW_Panel == undefined do return false
    AssetsMG_VCW_HeightDrawError = undefined
    AssetsMG_VCW_Panel.SetRulerError ""
    if AssetsMG_VCW_Panel.ShowHeightRuler then
    (
        if not AssetsMG_VCW_OverlayRegistered do
        (
            registerRedrawViewsCallback AssetsMG_VCW_DrawHeightOverlay
            AssetsMG_VCW_OverlayRegistered = true
        )
        AssetsMG_VCW_UpdateSelection undefined undefined
        redrawViews()
    )
    else
    (
        AssetsMG_VCW_StopHeightOverlay()
        AssetsMG_VCW_UpdateSelection undefined undefined
    )
)
fn AssetsMG_VCW_OnBake sender args =
(
    local chosen = selection as array
    local targets = for obj in chosen where (isValidNode obj) and ((superClassOf obj) == GeometryClass) collect obj
    local channels = #(AssetsMG_VCW_Panel.WriteR,AssetsMG_VCW_Panel.WriteG,AssetsMG_VCW_Panel.WriteB,AssetsMG_VCW_Panel.WriteA)
    local useTexture = AssetsMG_VCW_Panel.IsTexture
    local textureSource = if useTexture then AssetsMG_VCW_Panel.LoadedTexture else undefined
    if useTexture and textureSource == undefined do
    (
        AssetsMG_VCW_Panel.SetResult "请先读取有效贴图。" "没有写入任何对象。"
        return false
    )
    if targets.count == 0 then AssetsMG_VCW_Panel.SetResult "请先选择模型。" "没有写入任何对象。"
    else
    (
        local selectedOnly = AssetsMG_VCW_Panel.SelectedVerticesOnly
        local selectionSnapshot = undefined
        -- Capture before changing subObjectLevel, adding adapters or pasting channels.
        if selectedOnly do
        (
            try (selectionSnapshot = AssetsMG_VCW_CaptureVertexSelection targets[1])
            catch
            (
                local failure = getCurrentException()
                AssetsMG_VCW_Panel.SetResult failure ("没有写入任何对象。\n" + failure)
                AssetsMG_VCW_UpdateSelection undefined undefined
                return false
            )
        )
        local useGradient = AssetsMG_VCW_Panel.IsGradient
        local uvChannel = AssetsMG_VCW_Panel.UVChannel
        local textureColor = AssetsMG_VCW_Panel.TextureIsColor
        local textureBilinear = AssetsMG_VCW_Panel.TextureBilinear
        local textureRepeat = AssetsMG_VCW_Panel.TextureRepeat
        local span = AssetsMG_VCW_Panel.MappingHeight
        local startAt = AssetsMG_VCW_Panel.StartHeight
        local useBottom = AssetsMG_VCW_Panel.FromBottom
        local useClamp = AssetsMG_VCW_Panel.ClampRange
        local showRGB = AssetsMG_VCW_Panel.ShowColors
        local lowRGBA = #(AssetsMG_VCW_Panel.LowR,AssetsMG_VCW_Panel.LowG,AssetsMG_VCW_Panel.LowB,AssetsMG_VCW_Panel.LowA)
        local highRGBA = #(AssetsMG_VCW_Panel.HighR,AssetsMG_VCW_Panel.HighG,AssetsMG_VCW_Panel.HighB,AssetsMG_VCW_Panel.HighA)
        local successCount = 0
        local failedCount = 0
        local outsideCount = 0
        local writtenCount = 0
        local oldSubLevel = subObjectLevel
        local oldStackObject = modPanel.getCurrentObject()
        local report = "模式：" + (if useTexture then "贴图写入" else if useGradient then "高度渐变" else "固定颜色") + "\n写入通道："
        local channelNames = #("R","G","B","A")
        for i = 1 to 4 where channels[i] do report += channelNames[i] + " "
        report += "\n写入范围：" + (if selectedOnly then "选中顶点（连接网格面的硬选择；未选顶点保留）" else "整个模型")
        if useTexture then
            report += "\n贴图：" + textureSource.FilePath + "\nUV 通道：" + (uvChannel as string) + "；用途：" + (if textureColor then "颜色 sRGB 转线性" else "遮罩原值") + "；采样：" + (if textureBilinear then "双线性" else "最近点") + "；越界：" + (if textureRepeat then "平铺" else "截取")
        else report += "\n底部/填充 RGBA：" + (lowRGBA as string) + "\n顶部 RGBA：" + (highRGBA as string)
        if useGradient do report += "\n映射高度（米）：" + (span as string) + "；起始高度（米）：" + (startAt as string) + "；各自底部：" + (useBottom as string) + "；限制范围：" + (useClamp as string)
        report += "\n\n"
        local summary = ""
        AssetsMG_VCW_Panel.SetBusy true
        try
        (
            subObjectLevel = 0
            undo "AssetsMG VertexColorWriter" on
            (
                with redraw off
                (
                    for obj in targets do
                    (
                        try
                        (
                            local info = AssetsMG_VCW_BakeNode obj gradient:useGradient writeChannels:channels lowRGBA:lowRGBA highRGBA:highRGBA mappingHeight:span startHeight:startAt fromBottom:useBottom clampRange:useClamp preview:showRGB textureSource:textureSource uvChannel:uvChannel textureColor:textureColor textureBilinear:textureBilinear textureRepeat:textureRepeat selectedOnly:selectedOnly selectionSnapshot:selectionSnapshot
                            successCount += 1
                            outsideCount += info[3]
                            writtenCount += info[5]
                            report += "成功 | " + obj.name + " | 写入顶点 " + (info[5] as string) + " / " + (info[4] as string) + "\n"
                        )
                        catch
                        (
                            failedCount += 1
                            report += "失败 | " + obj.name + " | " + (getCurrentException()) + "\n"
                        )
                    )
                )
            )
            summary = "完成：成功 " + (successCount as string) + "，失败 " + (failedCount as string) + "。"
            if selectedOnly and successCount > 0 do summary = "已写入 " + (writtenCount as string) + " 个选中顶点，其他顶点保持原值。"
            if outsideCount > 0 do report += (if useTexture then "\nUV 越界面角：" else "\n高度范围外顶点：") + (outsideCount as string) + "\n"
        )
        catch (summary = "执行中断，已完成修改可 Ctrl+Z 撤销。"; report += "\n" + (getCurrentException()))
        if selectionSnapshot != undefined do delete selectionSnapshot
        try (select (for obj in chosen where isValidNode obj collect obj)) catch ()
        if chosen.count == 1 and oldStackObject != undefined do
            try (modPanel.setCurrentObject oldStackObject node:chosen[1]) catch ()
        try (subObjectLevel = oldSubLevel) catch ()
        format "[AssetsMG.VertexColorWriter]\n%\n%\n" report summary
        AssetsMG_VCW_Panel.SetBusy false
        AssetsMG_VCW_Panel.SetResult summary (report + "\n" + summary)
        AssetsMG_VCW_UpdateSelection undefined undefined
        redrawViews()
    )
)

rollout AssetsMG_VCW_UI "定点色写入工具  |  AssetsMG · VertexColorWriter" width:860 height:808
(
    dotNetControl uiHost "System.Windows.Forms.Panel" pos:[0,0] width:860 height:808
    on AssetsMG_VCW_UI open do
    (
        AssetsMG_VCW_Panel = AssetsMG_VCW_UIAssembly.CreateInstance "AssetsMG.Tools.VertexColorWriter.WriterPanel"
        uiHost.Controls.Add AssetsMG_VCW_Panel
        dotNet.setLifeTimeControl AssetsMG_VCW_Panel #dotnet
        dotNet.addEventHandler AssetsMG_VCW_Panel "BakeRequested" AssetsMG_VCW_OnBake
        dotNet.addEventHandler AssetsMG_VCW_Panel "SelectionRefreshRequested" AssetsMG_VCW_UpdateSelection
        dotNet.addEventHandler AssetsMG_VCW_Panel "HeightDisplayChanged" AssetsMG_VCW_OnHeightDisplayChanged
        AssetsMG_VCW_OnHeightDisplayChanged undefined undefined
        AssetsMG_VCW_Panel.StartRefresh()
    )
    on uiHost Enter do
    (
        if AssetsMG_VCW_AcceleratorsBefore == undefined do AssetsMG_VCW_AcceleratorsBefore = enableAccelerators
        enableAccelerators = false
    )
    on uiHost Leave do
    (
        if AssetsMG_VCW_AcceleratorsBefore != undefined do enableAccelerators = AssetsMG_VCW_AcceleratorsBefore
        AssetsMG_VCW_AcceleratorsBefore = undefined
    )
    on AssetsMG_VCW_UI close do
    (
        AssetsMG_VCW_StopHeightOverlay()
        if AssetsMG_VCW_Panel != undefined do
        (
            dotNet.removeAllEventHandlers AssetsMG_VCW_Panel
            AssetsMG_VCW_Panel.Dispose()
            AssetsMG_VCW_Panel = undefined
        )
        if AssetsMG_VCW_AcceleratorsBefore != undefined do enableAccelerators = AssetsMG_VCW_AcceleratorsBefore
        AssetsMG_VCW_AcceleratorsBefore = undefined
    )
)
fn AssetsMG_VCW_OpenUI uiPath =
(
    if not (doesFileExist uiPath) do throw ("缺少界面文件，请保留完整工具包：\n" + uiPath)
    local texturePath = (getFilenamePath uiPath) + "AssetsMG_VertexColorWriterTexture.cs"
    if not (doesFileExist texturePath) do throw ("缺少贴图读取文件，请保留完整工具包：\n" + texturePath)
    local source = (dotNetClass "System.IO.File").ReadAllText uiPath
    source += "\n" + (dotNetClass "System.IO.File").ReadAllText texturePath
    if AssetsMG_VCW_UIAssembly == undefined or AssetsMG_VCW_UISource != source do
    (
        local assembly = undefined
        local modernCompiler = try (dotNetClass "CSharpUtilities.CSharpCompilationHelper") catch (undefined)
        if modernCompiler != undefined then
            assembly = modernCompiler.Compile source #()
        else
        (
            local provider = dotNetObject "Microsoft.CSharp.CSharpCodeProvider"
            local compileOptions = dotNetObject "System.CodeDom.Compiler.CompilerParameters"
            compileOptions.GenerateInMemory = true
            for dependency in #("System.dll","System.Drawing.dll","System.Windows.Forms.dll") do compileOptions.ReferencedAssemblies.Add dependency
            local compiled = provider.CompileAssemblyFromSource compileOptions #(source)
            provider.Dispose()
            if compiled.Errors.HasErrors do
            (
                local message = "界面编译失败：\n"
                local errorList = compiled.Errors.GetEnumerator()
                while errorList.MoveNext() do message += (errorList.Current.ToString()) + "\n"
                throw message
            )
            assembly = compiled.CompiledAssembly
        )
        AssetsMG_VCW_UIAssembly = assembly
        AssetsMG_VCW_UISource = source
    )
    createDialog AssetsMG_VCW_UI style:#(#style_titlebar,#style_sysmenu)
    if not (AssetsMG_VCW_Panel.LoadToolIcon ((getFilenamePath uiPath) + "..\\icons\\")) do
        format "[AssetsMG.VertexColorWriter] Optional tool icon unavailable; using built-in write glyph.\n"
)
AssetsMG_VCW_OpenUI ((getFilenamePath (getThisScriptFilename())) + "AssetsMG_VertexColorWriterUI.cs")
