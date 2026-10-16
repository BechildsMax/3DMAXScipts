/* Run in a NEW EMPTY scene or an independent 3dsmaxbatch process.
   Creates and deletes only its own test objects; never resets/saves a scene.
   Report: %TEMP%\MaxZJTools-ZHR-v1.2-smoke.txt
*/
(
    if objects.count != 0 do throw "ZHR smoke test requires a new empty scene."
    local report = createFile ((getDir #temp) + "\\MaxZJTools-ZHR-v1.2-smoke.txt")
    local createdNodes = #()
    local oldUnits = units.SystemType
    local oldScale = units.SystemScale
    local scriptRoot = getFilenamePath (getThisScriptFilename())
    fn check value label report =
    (
        if not value do throw ("FAIL: " + label)
        format "PASS: %\n" label to:report
        flush report
    )
    fn sameValues actual expected =
    (
        if actual.count != expected.count do return false
        for i = 1 to actual.count do
            if not (ZHR_CloseEnough actual[i] expected[i]) do return false
        true
    )
    try
    (
        -- Exercise the real menu manager: an existing menu must be replaceable.
        fileIn (scriptRoot + "..\\startup\\MaxZJTools_Init.ms")
        fileIn (scriptRoot + "..\\startup\\MaxZJTools_Init.ms")
        local mainBar = menuMan.getMainMenuBar()
        local toolMenuCount = 0
        local installedMenu = undefined
        for menuIndex = 1 to mainBar.numItems() do
        (
            local installedItem = mainBar.getItem menuIndex
            if installedItem.getTitle() == "MaxZJTools" do
            (
                toolMenuCount += 1
                installedMenu = installedItem.getSubMenu()
            )
        )
        check (toolMenuCount == 1) "Repeated initialization leaves exactly one menu" report
        check (installedMenu.numItems() == 7) "Menu contains all five tools, separator and About" report
        fileIn (scriptRoot + "..\\tools\\ZHeightToVertexRed.ms")
        check VCW_UI.open "Compatibility loader opens VertexColorWriter UI" report
        check (VCW_Panel.MappingHeight == 1.0 and VCW_Panel.IsGradient and VCW_Panel.ClampRange) "Artist defaults: 1m / gradient / clamp" report
        destroyDialog VCW_UI
        local result = ZHR_MapHeights #(0.0,0.25,0.5,1.0)
        check (sameValues result[1] #(0.0,0.25,0.5,1.0)) "Default 1m mapping" report
        result = ZHR_MapHeights #(0.0,0.5,1.0,2.0) mappingHeight:2
        check (sameValues result[1] #(0.0,0.25,0.5,1.0)) "Shared 2m mapping" report
        result = ZHR_MapHeights #(2.0,2.5,3.0) startHeight:2
        check (sameValues result[1] #(0.0,0.5,1.0)) "World origin offset" report
        result = ZHR_MapHeights #(-1.0,0.5,2.0) clampRange:true
        check ((sameValues result[1] #(0.0,0.5,1.0)) and result[2] == 2) "Clamp with outside count" report
        result = ZHR_MapHeights #(-1.0,2.0)
        check (sameValues result[1] #(-1.0,2.0)) "Unclamped data retained" report
        result = ZHR_MapHeights #(4.0,4.5) fromBottom:true startHeight:99
        check (sameValues result[1] #(0.0,0.5)) "Per-object bottom ignores world origin; short object stays gray" report
        local rejected = false
        try (ZHR_MapHeights #(0.0) mappingHeight:0) catch (rejected = true)
        check rejected "Zero mapping height rejected" report

        units.SystemType = #centimeters
        units.SystemScale = 1.0
        local shortBox = box width:10 length:10 height:100 pos:[0,0,50]
        append createdNodes shortBox
        local tallBox = box width:10 length:10 height:200 pos:[20,0,50]
        append createdNodes tallBox
        local first = ZHR_BakeNode shortBox worldSpace:true mappingHeight:2 clampRange:true
        local second = ZHR_BakeNode tallBox worldSpace:true mappingHeight:2 clampRange:true
        check ((ZHR_CloseEnough first[1] 0.25) and (ZHR_CloseEnough second[1] 0.25)) "Different meshes share world-height gray" report
        check ((ZHR_CloseEnough first[2] 0.75) and (ZHR_CloseEnough second[2] 1.0)) "Fixed span, no object-height normalization" report
        first = ZHR_BakeNode shortBox worldSpace:true mappingHeight:2 fromBottom:true clampRange:true
        check ((ZHR_CloseEnough first[1] 0.0) and (ZHR_CloseEnough first[2] 0.5)) "Bottom-relative height" report
        check (shortBox.modifiers.count == 2) "Repeated bake reuses modifier pair" report
        first = ZHR_BakeNode shortBox
        check ((ZHR_CloseEnough first[1] 0.0) and (ZHR_CloseEnough first[2] 1.0)) "Legacy scripted defaults remain local / meters" report

        local sample = mesh vertices:#([0,0,0],[0,0,50],[10,0,100]) faces:#([1,2,3])
        append createdNodes sample
        local originalColors = #([0.2,0.3,0.4],[0.2,0.5,0.6],[0.2,0.7,0.8])
        for channel in #(0,-2) do
        (
            meshop.setMapSupport sample channel true
            meshop.setNumMapVerts sample channel 3
            meshop.setMapFace sample channel 1 [1,2,3]
            for v = 1 to 3 do meshop.setMapVert sample channel v (if channel == 0 then originalColors[v] else [0.6,0.6,0.6])
        )
        update sample
        ZHR_BakeNode sample worldSpace:true mappingHeight:2 clampRange:true
        local readback = snapshotAsMesh sample
        local cf = meshop.getMapFace readback 0 1
        local af = meshop.getMapFace readback -2 1
        for corner = 1 to 3 do
        (
            local c = meshop.getMapVert readback 0 (cf[corner] as integer)
            local a = meshop.getMapVert readback -2 (af[corner] as integer)
            check ((ZHR_CloseEnough c.y originalColors[corner].y) and (ZHR_CloseEnough c.z originalColors[corner].z) and (ZHR_CloseEnough a.x 0.6)) ("G/B/Alpha preserved at corner " + (corner as string)) report
        )
        delete readback
        local emptyNode = mesh()
        append createdNodes emptyNode
        rejected = false
        try (ZHR_BakeNode emptyNode worldSpace:true) catch (rejected = true)
        check (rejected and emptyNode.modifiers.count == 0) "Failed empty mesh bake rolls back adapter" report
        format "RESULT: PASS\n" to:report
    )
    catch (format "RESULT: FAIL %\n" (getCurrentException()) to:report)
    try (destroyDialog VCW_UI) catch ()
    for obj in createdNodes where isValidNode obj do delete obj
    units.SystemType = oldUnits
    units.SystemScale = oldScale
    close report
)
