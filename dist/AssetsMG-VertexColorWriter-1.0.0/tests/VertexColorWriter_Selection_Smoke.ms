/* Selected-vertex regression. Run manually in a NEW EMPTY 3ds Max scene.
   Not executed until the target host reports PASS. Does not reset/save/export.
   Report: %TEMP%/AssetsMG-VertexColorWriter-selection-smoke.txt
*/
(
    if objects.count != 0 do throw "Selection smoke requires an empty scene."
    local report = createFile ((getDir #temp) + "\\AssetsMG-VertexColorWriter-selection-smoke.txt")
    local scriptRoot = getFilenamePath (getThisScriptFilename())
    local createdNodes = #()
    local heldMeshes = #()
    local imageBitmap = undefined
    local fixtureId = (dotNetClass "System.Guid").NewGuid()
    local fixturePath = (getDir #temp) + "\\VCW-selection-" + (fixtureId.ToString()) + ".png"
    local oldUnits = units.SystemType
    local oldScale = units.SystemScale
    fn check value label report =
    (
        if not value do throw ("FAIL: " + label)
        format "PASS: %\n" label to:report
        flush report
    )
    fn nearPoint a b = (AssetsMG_VCW_CloseEnough a.x b.x) and (AssetsMG_VCW_CloseEnough a.y b.y) and (AssetsMG_VCW_CloseEnough a.z b.z)
    fn cornerValue source channel faceIndex corner =
    (
        local mf = meshop.getMapFace source channel faceIndex
        meshop.getMapVert source channel (mf[corner] as integer)
    )
    fn checkUnselected beforeMesh afterMesh vertexMask report label =
    (
        for f = 1 to beforeMesh.numfaces do
        (
            local gf = getFace beforeMesh f
            for c = 1 to 3 where not vertexMask[gf[c] as integer] do
                for channel in #(0,-2) do
                    check (nearPoint (cornerValue beforeMesh channel f c) (cornerValue afterMesh channel f c)) (label + " preserves unselected face/corner/channel " + (f as string) + "/" + (c as string) + "/" + (channel as string)) report
        )
    )
    try
    (
        fileIn (scriptRoot + "..\\tools\\AssetsMG_VertexColorWriter.ms")
        units.SystemType = #centimeters
        units.SystemScale = 1
        local sample = mesh vertices:#([0,0,0],[10,0,50],[10,10,100],[0,10,50]) faces:#([1,2,3],[1,3,4])
        append createdNodes sample
        for channel in #(0,-2,1) do
        (
            meshop.setMapSupport sample channel true
            meshop.setNumMapVerts sample channel 6 keep:false
            meshop.setMapFace sample channel 1 [1,2,3]
            meshop.setMapFace sample channel 2 [4,5,6]
            for v = 1 to 6 do meshop.setMapVert sample channel v [v * 0.1, v * 0.1 + 0.05, 0.75]
        )
        -- Two UV seam corners at geometry vertex 1 sample different pixels.
        meshop.setMapVert sample 1 1 [0.25,0.75,0]
        meshop.setMapVert sample 1 4 [0.25,0.25,0]
        update sample
        local beforeMesh = snapshotAsMesh sample
        append heldMeshes beforeMesh
        setVertSelection beforeMesh #{1}
        local info = AssetsMG_VCW_BakeNode sample gradient:false selectedOnly:true selectionSnapshot:beforeMesh writeChannels:#(true,false,false,true) lowRGBA:#(0.9,0.8,0.7,0.25)
        local afterMesh = snapshotAsMesh sample
        append heldMeshes afterMesh
        check (info[5] == 1 and info[4] == 4) "One geometry vertex counted once across two face corners" report
        checkUnselected beforeMesh afterMesh #{1} report "Fixed RA fill"
        check (nearPoint (cornerValue afterMesh 0 1 1) [0.9,0.15,0.75]) "Selected corner keeps GB" report
        check (nearPoint (cornerValue afterMesh 0 2 1) [0.9,0.45,0.75]) "Selected seam keeps distinct GB" report
        check (nearPoint (cornerValue afterMesh -2 2 1) [0.25,0.25,0.25]) "Selected Alpha writes all scalar coordinates" report
        check (AssetsMG_VCW_Verify beforeMesh afterMesh channels:#(1)) "Partial fill preserves geometry and UV" report

        -- A second region must preserve the first region and reuse the tool stack.
        setVertSelection afterMesh #{2}
        undo "VCW selected fill undo" on
            AssetsMG_VCW_BakeNode sample gradient:false selectedOnly:true selectionSnapshot:afterMesh writeChannels:#(false,true,false,false) lowRGBA:#(0,0.8,0,0)
        local secondMesh = snapshotAsMesh sample
        append heldMeshes secondMesh
        checkUnselected afterMesh secondMesh #{2} report "Second-region G fill"
        check (AssetsMG_VCW_CloseEnough (cornerValue secondMesh 0 1 2).y 0.8) "Second region receives new G" report
        check (sample.modifiers.count == 3) "Repeated partial fills reuse one adapter and two paste modifiers" report
        max undo
        local undoMesh = snapshotAsMesh sample
        append heldMeshes undoMesh
        check (AssetsMG_VCW_Verify afterMesh undoMesh) "Undo restores previous partial RGB and Alpha" report

        -- Selected vertex 2 is 0.5m above the WHOLE object's bottom, not its own minimum.
        setVertSelection undoMesh #{2}
        info = AssetsMG_VCW_BakeNode sample selectedOnly:true selectionSnapshot:undoMesh fromBottom:true mappingHeight:1.0
        local gradientMesh = snapshotAsMesh sample
        append heldMeshes gradientMesh
        check (AssetsMG_VCW_CloseEnough (cornerValue gradientMesh 0 1 2).x 0.5) "Partial height fill retains the whole-model bottom origin" report
        checkUnselected undoMesh gradientMesh #{2} report "Height fill"
        setVertSelection gradientMesh #{1}
        info = AssetsMG_VCW_BakeNode sample selectedOnly:true selectionSnapshot:gradientMesh mappingHeight:0.25
        check (info[3] == 0) "Height outside count excludes unselected vertices" report

        local currentMesh = snapshotAsMesh sample
        append heldMeshes currentMesh
        local priorCount = sample.modifiers.count
        local rejected = false
        setVertSelection currentMesh #{}
        try (AssetsMG_VCW_BakeNode sample selectedOnly:true selectionSnapshot:currentMesh) catch (rejected = true)
        check (rejected and sample.modifiers.count == priorCount) "Empty mask rejected without adding modifiers" report
        rejected = false
        try (AssetsMG_VCW_BakeNode sample selectedOnly:true) catch (rejected = true)
        check (rejected and sample.modifiers.count == priorCount) "Missing selection snapshot cannot fall back to full fill" report
        setVertSelection currentMesh #{1}
        setVert currentMesh 1 [1,2,3]
        rejected = false
        try (AssetsMG_VCW_BakeNode sample selectedOnly:true selectionSnapshot:currentMesh) catch (rejected = true)
        check (rejected and sample.modifiers.count == priorCount) "Changed geometry rejects stale vertex indices" report

        -- No existing map: unselected RGB starts black, unselected Alpha stays opaque.
        local fresh = mesh vertices:#([0,0,0],[10,0,0],[0,10,0]) faces:#([1,2,3])
        append createdNodes fresh
        meshop.setMapSupport fresh 0 false
        meshop.setMapSupport fresh -2 false
        local freshSelection = snapshotAsMesh fresh
        append heldMeshes freshSelection
        setVertSelection freshSelection #{1}
        AssetsMG_VCW_BakeNode fresh gradient:false selectedOnly:true selectionSnapshot:freshSelection writeChannels:#(true,false,false,true) lowRGBA:#(0.7,0,0,0.3)
        local freshResult = snapshotAsMesh fresh
        append heldMeshes freshResult
        check (nearPoint (cornerValue freshResult 0 1 2) [0,0,0]) "Unselected new RGB initializes to zero" report
        check (nearPoint (cornerValue freshResult -2 1 2) [1,1,1]) "Unselected new Alpha initializes opaque" report
        setVertSelection freshResult #{3}
        AssetsMG_VCW_BakeNode fresh gradient:false selectedOnly:true selectionSnapshot:freshResult writeChannels:#(false,false,false,true) lowRGBA:#(0,0,0,0.6)
        local alphaOnlyResult = snapshotAsMesh fresh
        append heldMeshes alphaOnlyResult
        check (AssetsMG_VCW_Verify freshResult alphaOnlyResult channels:#(0)) "Partial Alpha-only fill retains all prior RGB" report
        checkUnselected freshResult alphaOnlyResult #{3} report "Alpha-only fill"
        check (AssetsMG_VCW_CloseEnough (cornerValue alphaOnlyResult -2 1 3).x 0.6) "Alpha-only fill changes the selected point" report

        -- Texture sampling stays per face corner inside the selected geometry mask.
        imageBitmap = dotNetObject "System.Drawing.Bitmap" 2 2
        local colorClass = dotNetClass "System.Drawing.Color"
        imageBitmap.SetPixel 0 0 (colorClass.FromArgb 255 255 0 0)
        imageBitmap.SetPixel 1 0 (colorClass.FromArgb 255 0 255 0)
        imageBitmap.SetPixel 0 1 (colorClass.FromArgb 64 0 0 255)
        imageBitmap.SetPixel 1 1 (colorClass.FromArgb 255 255 255 255)
        imageBitmap.Save fixturePath (dotNetClass "System.Drawing.Imaging.ImageFormat").Png
        imageBitmap.Dispose()
        imageBitmap = undefined
        check (AssetsMG_VCW_Panel.LoadTextureFile fixturePath) "Selection fixture texture loaded" report
        local textureBefore = snapshotAsMesh sample
        append heldMeshes textureBefore
        setVertSelection textureBefore #{1}
        AssetsMG_VCW_BakeNode sample textureSource:AssetsMG_VCW_Panel.LoadedTexture textureColor:false textureBilinear:false selectedOnly:true selectionSnapshot:textureBefore writeChannels:#(true,true,true,true)
        local textureAfter = snapshotAsMesh sample
        append heldMeshes textureAfter
        checkUnselected textureBefore textureAfter #{1} report "Texture fill"
        check (nearPoint (cornerValue textureAfter 0 1 1) [1,0,0]) "Selected UV seam samples red on first face" report
        check (nearPoint (cornerValue textureAfter 0 2 1) [0,0,1]) "Selected UV seam samples blue on second face" report
        check (AssetsMG_VCW_CloseEnough (cornerValue textureAfter -2 2 1).x (64.0/255)) "Selected texture Alpha follows its UV corner" report

        -- Real Modify panel path: capture before exiting vertex mode and restore it.
        select fresh
        max modify mode
        modPanel.setCurrentObject fresh.baseObject node:fresh
        subObjectLevel = 1
        setVertSelection fresh #{2}
        update fresh
        AssetsMG_VCW_Panel.SelectedVerticesOnly = true
        AssetsMG_VCW_Panel.SetConfiguration false false 1 0 1 (colorClass.FromArgb 255 0 0) (colorClass.FromArgb 255 255 255) 0 1
        AssetsMG_VCW_UpdateSelection undefined undefined
        check AssetsMG_VCW_Panel.CanBake "Editable Mesh selection is available through the actual UI path" report
        AssetsMG_VCW_OnBake undefined undefined
        check (subObjectLevel == 1 and modPanel.getCurrentObject() == fresh.baseObject) "Bake restores the active stack object and vertex mode" report
        local uiMesh = snapshotAsMesh fresh
        append heldMeshes uiMesh
        check (AssetsMG_VCW_CloseEnough (cornerValue uiMesh 0 1 2).x 1) "UI bakes captured vertex 2, not the whole mesh" report
        check (AssetsMG_VCW_CloseEnough (cornerValue uiMesh 0 1 3).x 0) "UI leaves unselected vertex 3 unchanged" report
        subObjectLevel = 0
        AssetsMG_VCW_UpdateSelection undefined undefined
        check (not AssetsMG_VCW_Panel.CanBake) "Object mode disables selected fill even with stored vertex flags" report

        local polyNode = copy fresh
        append createdNodes polyNode
        convertToPoly polyNode
        select polyNode
        modPanel.setCurrentObject polyNode.baseObject node:polyNode
        subObjectLevel = 1
        polyop.setVertSelection polyNode #{1}
        local polySelection = AssetsMG_VCW_CaptureVertexSelection polyNode
        append heldMeshes polySelection
        check ((AssetsMG_VCW_UsedVertexSelection polySelection).numberSet == 1) "Editable Poly selection survives snapshot triangulation" report
        subObjectLevel = 0
        local editPoly = Edit_Poly()
        addModifier polyNode editPoly
        modPanel.setCurrentObject editPoly node:polyNode
        subObjectLevel = 1
        editPoly.SetSelection #Vertex #{2} node:polyNode
        local editSelection = AssetsMG_VCW_CaptureVertexSelection polyNode
        append heldMeshes editSelection
        check ((AssetsMG_VCW_UsedVertexSelection editSelection).numberSet == 1) "Top Edit Poly selection is captured" report
        subObjectLevel = 0
        addModifier polyNode (TurboSmooth iterations:1)
        modPanel.setCurrentObject editPoly node:polyNode
        subObjectLevel = 1
        rejected = false
        try (AssetsMG_VCW_CheckVertexContext polyNode) catch (rejected = true)
        check rejected "Modifier above the selection level blocks unsafe vertex correspondence" report
        format "RESULT: PASS\n" to:report
    )
    catch (format "RESULT: FAIL %\n" (getCurrentException()) to:report)
    try (subObjectLevel = 0) catch ()
    try (destroyDialog AssetsMG_VCW_UI) catch ()
    for item in heldMeshes do try (delete item) catch ()
    if imageBitmap != undefined do imageBitmap.Dispose()
    for obj in createdNodes where isValidNode obj do delete obj
    if doesFileExist fixturePath do deleteFile fixturePath
    units.SystemType = oldUnits
    units.SystemScale = oldScale
    close report
)
