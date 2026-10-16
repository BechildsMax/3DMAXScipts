/* Texture integration regression. Run only in a NEW EMPTY 3ds Max scene.
   Creates its own 2x2 PNG and meshes; does not reset/save/export the scene.
   Report: %TEMP%/AssetsMG-VertexColorWriter-texture-smoke.txt
   This script has NOT been executed until a target host report confirms PASS.
*/
(
    if objects.count != 0 do throw "VertexColorWriter texture smoke requires an empty scene."
    local report = createFile ((getDir #temp) + "\\AssetsMG-VertexColorWriter-texture-smoke.txt")
    local fixtureId = (dotNetClass "System.Guid").NewGuid()
    local fixturePath = (dotNetClass "System.IO.Path").Combine (getDir #temp) ((fixtureId.ToString()) + ".png")
    local createdNodes = #()
    local bitmapImage = undefined
    local beforeMesh = undefined
    local afterMesh = undefined
    local scriptRoot = getFilenamePath (getThisScriptFilename())
    fn check value label report =
    (
        if not value do throw ("FAIL: " + label)
        format "PASS: %\n" label to:report
        flush report
    )
    fn cornerValue obj channel faceIndex corner =
    (
        local sampledMesh = snapshotAsMesh obj
        local value = undefined
        try
        (
            local mapFace = meshop.getMapFace sampledMesh channel faceIndex
            value = meshop.getMapVert sampledMesh channel (mapFace[corner] as integer)
        )
        catch (delete sampledMesh; throw (getCurrentException()))
        delete sampledMesh
        value
    )
    fn nearPoint actual expected =
        (AssetsMG_VCW_CloseEnough actual.x expected.x) and (AssetsMG_VCW_CloseEnough actual.y expected.y) and (AssetsMG_VCW_CloseEnough actual.z expected.z)
    try
    (
        fileIn (scriptRoot + "..\\tools\\AssetsMG_VertexColorWriter.ms")
        bitmapImage = dotNetObject "System.Drawing.Bitmap" 2 2
        local colorClass = dotNetClass "System.Drawing.Color"
        bitmapImage.SetPixel 0 0 (colorClass.FromArgb 255 255 0 0)
        bitmapImage.SetPixel 1 0 (colorClass.FromArgb 128 0 255 0)
        bitmapImage.SetPixel 0 1 (colorClass.FromArgb 64 0 0 255)
        bitmapImage.SetPixel 1 1 (colorClass.FromArgb 0 128 128 128)
        bitmapImage.Save fixturePath (dotNetClass "System.Drawing.Imaging.ImageFormat").Png
        bitmapImage.Dispose()
        bitmapImage = undefined
        AssetsMG_VCW_Panel.SetTextureMode 1 false false false
        check (not AssetsMG_VCW_Panel.CanBake) "No texture prevents writing" report
        check (AssetsMG_VCW_Panel.LoadTextureFile fixturePath) "PNG loads through actual panel and .NET bridge" report
        local texture = AssetsMG_VCW_Panel.LoadedTexture
        local pixel = texture.Sample 0.75 0.25 false false false
        check ((AssetsMG_VCW_CloseEnough pixel.R (128.0/255)) and pixel.A == 0) "Sample RGBA properties cross .NET bridge" report

        local sample = mesh vertices:#([0,0,0],[10,0,0],[10,10,0],[0,10,0]) faces:#([1,2,3],[1,3,4])
        append createdNodes sample
        -- Geometric vertex 1 maps to RED on face 1, BLUE on face 2.
        meshop.setMapSupport sample 1 true
        meshop.setNumMapVerts sample 1 6 keep:false
        local uvValues = #([0.25,0.75,0],[0.75,0.75,0],[0.75,0.25,0],[0.25,0.25,0],[0.75,0.25,0],[0.25,0.75,0])
        for i = 1 to 6 do meshop.setMapVert sample 1 i uvValues[i]
        meshop.setMapFace sample 1 1 [1,2,3]
        meshop.setMapFace sample 1 2 [4,5,6]
        for channel in #(0,-2) do
        (
            meshop.setMapSupport sample channel true
            meshop.setNumMapVerts sample channel 6 keep:false
            for i = 1 to 6 do meshop.setMapVert sample channel i (if channel == 0 then [0.2,0.3,0.4] else [0.6,0.6,0.6])
            meshop.setMapFace sample channel 1 [1,2,3]
            meshop.setMapFace sample channel 2 [4,5,6]
        )
        update sample
        beforeMesh = snapshotAsMesh sample
        local info = AssetsMG_VCW_BakeNode sample textureSource:texture textureColor:false textureBilinear:false mappingHeight:0
        check (info[3] == 0) "UVs within range report no outside corners" report
        check (nearPoint (cornerValue sample 0 1 1) [1,0.3,0.4]) "R texture preserves GB" report
        check (nearPoint (cornerValue sample 0 2 1) [0,0.3,0.4]) "UV seam has independent R values at same geometry vertex" report
        check (AssetsMG_VCW_CloseEnough (cornerValue sample -2 1 1).x 0.6) "Unchecked Alpha preserved" report
        afterMesh = snapshotAsMesh sample
        check (AssetsMG_VCW_Verify beforeMesh afterMesh channels:#(1)) "Source UV and geometry unchanged" report
        delete afterMesh; afterMesh = undefined
        AssetsMG_VCW_BakeNode sample textureSource:texture textureColor:false textureBilinear:false writeChannels:#(false,false,false,true)
        check (nearPoint (cornerValue sample 0 1 1) [1,0.3,0.4]) "Alpha-only texture retains earlier RGB" report
        check (AssetsMG_VCW_CloseEnough (cornerValue sample -2 1 2).x (128.0/255)) "Image Alpha writes map -2" report
        check ((cornerValue sample -2 1 3).x == 0) "Transparent texel writes zero Alpha" report
        AssetsMG_VCW_BakeNode sample textureSource:texture textureColor:false textureBilinear:false writeChannels:#(true,true,true,true)
        check (nearPoint (cornerValue sample 0 1 2) [0,1,0]) "Full RGB texture sampling" report
        check (nearPoint (cornerValue sample 0 2 1) [0,0,1]) "Seam retains blue after full RGBA bake" report
        check (sample.modifiers.count == 3) "Repeated texture writes reuse one adapter and two paste modifiers" report
        undo "VCW texture smoke undo" on
            AssetsMG_VCW_BakeNode sample gradient:false lowRGBA:#(0.42,0,0,1)
        check (AssetsMG_VCW_CloseEnough (cornerValue sample 0 1 1).x 0.42) "Existing fixed mode still works after texture" report
        max undo
        check ((cornerValue sample 0 1 1).x == 1) "Undo restores texture result" report

        local missingUV = mesh vertices:#([0,0,0],[1,0,0],[0,1,0]) faces:#([1,2,3])
        append createdNodes missingUV
        meshop.setMapSupport missingUV 1 false
        local rejected = false
        try (AssetsMG_VCW_BakeNode missingUV textureSource:texture) catch (rejected = true)
        check (rejected and missingUV.modifiers.count == 0) "Missing UV rolls back newly added adapter" report
        local priorCount = sample.modifiers.count
        rejected = false
        try (AssetsMG_VCW_BakeNode sample textureSource:texture uvChannel:0) catch (rejected = true)
        check (rejected and sample.modifiers.count == priorCount) "Channel 0 cannot be used as texture UV input" report
        AssetsMG_VCW_Panel.SetConfiguration true false 1 0 15 (colorClass.FromArgb 0 0 0) (colorClass.FromArgb 255 255 255) 0 1
        AssetsMG_VCW_Panel.SetTextureMode 1 false false false
        select #(sample,missingUV)
        AssetsMG_VCW_OnBake undefined undefined
        check (missingUV.modifiers.count == 0 and sample.modifiers.count == 3) "Mixed batch isolates missing-UV object failure" report
        check (nearPoint (cornerValue sample 0 1 2) [0,1,0]) "Mixed batch keeps valid texture result" report
        destroyDialog AssetsMG_VCW_UI
        check (AssetsMG_VCW_Panel == undefined) "Closing UI releases texture panel" report
        format "RESULT: PASS\n" to:report
    )
    catch (format "RESULT: FAIL | %\n" (getCurrentException()) to:report)
    try (destroyDialog AssetsMG_VCW_UI) catch ()
    if bitmapImage != undefined do bitmapImage.Dispose()
    if beforeMesh != undefined do delete beforeMesh
    if afterMesh != undefined do delete afterMesh
    for obj in createdNodes where isValidNode obj do delete obj
    if doesFileExist fixturePath do deleteFile fixturePath
    close report
)
