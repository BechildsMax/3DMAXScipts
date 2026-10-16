/* VertexColorWriter host regression. Run only in a NEW EMPTY scene.
   No scene reset/save; creates and deletes its own objects, restores units.
   Report: %TEMP%\VertexColorWriter-smoke.txt
*/
(
    if objects.count != 0 do throw "VertexColorWriter smoke requires an empty scene."
    local report = createFile ((getDir #temp) + "\\VertexColorWriter-smoke.txt")
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
    fn assertChannels obj expectedRGB expectedAlpha report label =
    (
        local readback = snapshotAsMesh obj
        try
        (
            local rgbFace = if expectedRGB != undefined then (meshop.getMapFace readback 0 1) else undefined
            local alphaFace = if expectedAlpha != undefined then (meshop.getMapFace readback -2 1) else undefined
            if expectedRGB == undefined do check (not (VCW_HasMap readback 0)) (label + " leaves absent RGB absent") report
            for corner = 1 to 3 do
            (
                if expectedRGB != undefined do
                (
                    local actualColor = meshop.getMapVert readback 0 (rgbFace[corner] as integer)
                    local wantedColor = expectedRGB[corner]
                    check ((VCW_CloseEnough actualColor.x wantedColor.x) and (VCW_CloseEnough actualColor.y wantedColor.y) and (VCW_CloseEnough actualColor.z wantedColor.z)) (label + " RGB " + (corner as string)) report
                )
                if expectedAlpha != undefined do
                (
                    local actualAlpha = meshop.getMapVert readback -2 (alphaFace[corner] as integer)
                    check (VCW_CloseEnough actualAlpha.x expectedAlpha[corner]) (label + " Alpha " + (corner as string)) report
                )
            )
        )
        catch (delete readback; throw (getCurrentException()))
        delete readback
    )
    try
    (
        fileIn (scriptRoot + "..\\startup\\MaxZJTools_Init.ms")
        fileIn (scriptRoot + "..\\startup\\MaxZJTools_Init.ms")
        local bar = menuMan.getMainMenuBar()
        local menuCount = 0
        for i = 1 to bar.numItems() do if (bar.getItem i).getTitle() == "MaxZJTools" do menuCount += 1
        check (menuCount == 1) "Menu reload is idempotent" report
        macros.run "MaxZJTools" "MaxZJTools_VertexColorWriter"
        check VCW_UI.open "Renamed menu opens new UI" report
        check (VCW_Panel.MappingHeight == 1 and VCW_Panel.WriteR and not VCW_Panel.WriteA) "R-only 1m defaults" report
        destroyDialog VCW_UI
        macros.run "MaxZJTools" "MaxZJTools_ZHeightToVertexRed"
        check VCW_UI.open "Old macro redirects to new UI" report
        destroyDialog VCW_UI
        units.SystemType = #centimeters
        units.SystemScale = 1
        local sample = mesh vertices:#([0,0,0],[10,0,50],[0,10,100]) faces:#([1,2,3])
        append createdNodes sample
        for channel in #(0,-2) do
        (
            meshop.setMapSupport sample channel true
            meshop.setNumMapVerts sample channel 3
            meshop.setMapFace sample channel 1 [1,2,3]
            for v = 1 to 3 do meshop.setMapVert sample channel v (if channel == 0 then [0.2,0.3,0.4] else [0.6,0.6,0.6])
        )
        update sample
        VCW_BakeNode sample
        assertChannels sample #([0,0.3,0.4],[0.5,0.3,0.4],[1,0.3,0.4]) #(0.6,0.6,0.6) report "R gradient preserves GBA"
        VCW_BakeNode sample gradient:false writeChannels:#(false,false,false,true) lowRGBA:#(0,0,0,0.25)
        assertChannels sample #([0,0.3,0.4],[0.5,0.3,0.4],[1,0.3,0.4]) #(0.25,0.25,0.25) report "Alpha-only retains previous RGB bake"
        check (sample.modifiers.count == 3) "RGB plus Alpha use one adapter" report
        VCW_BakeNode sample gradient:false writeChannels:#(false,true,false,false) lowRGBA:#(0.9,0.75,0.8,0.2)
        assertChannels sample #([0,0.75,0.4],[0.5,0.75,0.4],[1,0.75,0.4]) #(0.25,0.25,0.25) report "G-only retains RBA"
        VCW_BakeNode sample writeChannels:#(true,true,true,true) lowRGBA:#(1,0,0,0.2) highRGBA:#(0,0,1,0.8)
        assertChannels sample #([1,0,0],[0.5,0,0.5],[0,0,1]) #(0.2,0.5,0.8) report "RGBA height color gradient"
        check (sample.modifiers.count == 3) "Repeated RGBA does not grow stack" report
        undo "VCW smoke undo" on
            VCW_BakeNode sample gradient:false mappingHeight:0 writeChannels:#(true,true,true,true) lowRGBA:#(0.25,0.5,0.75,0.4)
        assertChannels sample #([0.25,0.5,0.75],[0.25,0.5,0.75],[0.25,0.5,0.75]) #(0.4,0.4,0.4) report "Fixed RGBA ignores height settings"
        max undo
        assertChannels sample #([1,0,0],[0.5,0,0.5],[0,0,1]) #(0.2,0.5,0.8) report "Undo restores previous gradient"
        local fresh = mesh vertices:#([0,0,0],[10,0,50],[0,10,100]) faces:#([1,2,3])
        append createdNodes fresh
        -- A fresh mesh may have channel 0 initialized by a host default; make absence explicit.
        meshop.setMapSupport fresh 0 false
        VCW_BakeNode fresh gradient:false writeChannels:#(false,false,false,true) lowRGBA:#(0,0,0,0.42)
        assertChannels fresh undefined #(0.42,0.42,0.42) report "Alpha-only new channel"
        local priorCount = sample.modifiers.count
        local rejected = false
        try (VCW_BakeNode sample writeChannels:#(false,false,false,false)) catch (rejected = true)
        check (rejected and sample.modifiers.count == priorCount) "Empty channel mask rejected before mutation" report
        local emptyNode = mesh()
        append createdNodes emptyNode
        rejected = false
        try (VCW_BakeNode emptyNode) catch (rejected = true)
        check (rejected and emptyNode.modifiers.count == 0) "Failed bake removes new adapter" report
        format "RESULT: PASS\n" to:report
    )
    catch (format "RESULT: FAIL %\n" (getCurrentException()) to:report)
    try (destroyDialog VCW_UI) catch ()
    for obj in createdNodes where isValidNode obj do delete obj
    units.SystemType = oldUnits
    units.SystemScale = oldScale
    close report
)
