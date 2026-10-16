/* Run manually in a NEW EMPTY scene, with both tool windows closed.
   Set AssetsMG_VCW_TestOriginalPath to the original VertexColorWriter.ms path first.
   Does not install menus, reset/save or export a scene. NOT executed off-host.
   Report: %TEMP%/AssetsMG-VertexColorWriter-coexistence.txt
*/
global AssetsMG_VCW_TestOriginalPath
global VCW_UI, VCW_Panel, VCW_BakeNode, VCW_DrawHeightOverlay
global AssetsMG_VCW_UI, AssetsMG_VCW_Panel
(
    if objects.count != 0 do throw "Coexistence smoke requires an empty scene."
    if AssetsMG_VCW_TestOriginalPath == undefined do throw "Set AssetsMG_VCW_TestOriginalPath first."
    if not (doesFileExist AssetsMG_VCW_TestOriginalPath) do throw "Original tool script path is invalid."
    if VCW_UI != undefined do if VCW_UI.open do throw "Close the original tool before running this test."
    if AssetsMG_VCW_UI != undefined do if AssetsMG_VCW_UI.open do throw "Close the integration tool before running this test."
    local report = createFile ((getDir #temp) + "\\AssetsMG-VertexColorWriter-coexistence.txt")
    local originalPanel = undefined
    local isolatedPanel = undefined
    local createdNode = undefined
    local entryPath = (getFilenamePath (getThisScriptFilename())) + "..\\Entry.ms"
    fn check value caption report =
    (
        if not value do throw ("FAIL: " + caption)
        format "PASS: %\n" caption to:report
        flush report
    )
    fn callbackCount callbackValue =
    (
        local found = 0
        for item in (showregisteredRedrawViewsCallbacks asArray:true) do if item[3] == callbackValue do found += 1
        found
    )
    try
    (
        fileIn AssetsMG_VCW_TestOriginalPath
        originalPanel = VCW_Panel
        local originalBake = VCW_BakeNode
        local originalDraw = VCW_DrawHeightOverlay
        fileIn entryPath
        check (VCW_UI.open and VCW_Panel == originalPanel) "Passive integration entry leaves original window intact" report
        AssetsMG_VCW_Open()
        check (VCW_UI.open and AssetsMG_VCW_UI.open) "Both tool windows coexist" report
        check (VCW_Panel == originalPanel and VCW_BakeNode == originalBake and VCW_DrawHeightOverlay == originalDraw) "Original globals and callbacks retain their function values" report
        check ((callbackCount originalDraw) == 1 and (callbackCount AssetsMG_VCW_DrawHeightOverlay) == 1) "Each version owns one ruler callback" report
        AssetsMG_VCW_Open()
        check (VCW_Panel == originalPanel and not originalPanel.IsDisposed) "Reloading integration preserves original panel" report
        check ((callbackCount AssetsMG_VCW_DrawHeightOverlay) == 1) "Reloading integration does not duplicate its callback" report
        isolatedPanel = AssetsMG_VCW_Panel
        fileIn AssetsMG_VCW_TestOriginalPath
        check (AssetsMG_VCW_Panel == isolatedPanel and not isolatedPanel.IsDisposed) "Reloading original preserves integration panel" report
        createdNode = mesh vertices:#([0,0,0],[10,0,0],[0,10,0]) faces:#([1,2,3])
        VCW_BakeNode createdNode gradient:false lowRGBA:#(0.2,0,0,1)
        local originalModifiers = for md in createdNode.modifiers collect md
        AssetsMG_VCW_BakeNode createdNode gradient:false lowRGBA:#(0.7,0,0,1)
        for md in originalModifiers do check ((findItem (for current in createdNode.modifiers collect current) md) > 0) "Integration keeps original-owned modifier" report
        local integrationModifiers = for md in createdNode.modifiers where matchPattern md.name pattern:"AssetsMG VCW - *" collect md
        check (integrationModifiers.count == 2) "Integration creates its own adapter and RGB modifier" report
        VCW_BakeNode createdNode gradient:false lowRGBA:#(0.3,0,0,1)
        for md in integrationModifiers do check ((findItem (for current in createdNode.modifiers collect current) md) > 0) "Original keeps integration-owned modifier" report
        AssetsMG_VCW_Close()
        AssetsMG_VCW_Close()
        check (VCW_UI.open and (callbackCount VCW_DrawHeightOverlay) == 1) "Closing integration twice leaves original and its ruler alive" report
        check ((callbackCount AssetsMG_VCW_DrawHeightOverlay) == 0) "Closing integration unregisters its ruler" report
        AssetsMG_VCW_Open()
        destroyDialog VCW_UI
        check (AssetsMG_VCW_UI.open and not AssetsMG_VCW_Panel.IsDisposed) "Closing original leaves integration open" report
        format "RESULT: PASS\n" to:report
    )
    catch (format "RESULT: FAIL %\n" (getCurrentException()) to:report)
    if createdNode != undefined do if isValidNode createdNode do delete createdNode
    try (destroyDialog VCW_UI) catch ()
    try (AssetsMG_VCW_Close()) catch ()
    close report
)
