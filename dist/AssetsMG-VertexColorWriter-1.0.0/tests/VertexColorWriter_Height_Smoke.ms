/* Run only in a NEW EMPTY 3ds Max scene. No reset, save or export.
   Tests create/delete their own nodes and restore units.
   Report: %TEMP%\AssetsMG-VertexColorWriter-height-smoke.txt
*/
(
    if objects.count != 0 do throw "Height smoke requires an empty scene."
    local report = createFile ((getDir #temp) + "\\AssetsMG-VertexColorWriter-height-smoke.txt")
    local made = #()
    local oldType = units.SystemType
    local oldScale = units.SystemScale
    local scriptRoot = getFilenamePath (getThisScriptFilename())
    fn check value caption report =
    (
        if not value do throw ("FAIL: " + caption)
        format "PASS: %\n" caption to:report
        flush report
    )
    fn rulerCount =
    (
        local count = 0
        for entry in (showregisteredRedrawViewsCallbacks asArray:true) do
            if entry[3] == AssetsMG_VCW_DrawHeightOverlay do count += 1
        count
    )
    try
    (
        units.SystemType = #centimeters
        units.SystemScale = 1
        fileIn (scriptRoot + "..\\tools\\AssetsMG_VertexColorWriter.ms")
        check ((rulerCount()) == 1) "Opening registers exactly one ruler callback" report
        local sample = mesh vertices:#([0,0,0],[10,0,50],[0,20,100]) faces:#([1,2,3])
        append made sample
        local beforeCount = objects.count
        local measurement = AssetsMG_VCW_MeasureHeight sample
        check (AssetsMG_VCW_CloseEnough measurement[4] 1) "100cm mesh is 1m tall" report
        check (objects.count == beforeCount and sample.modifiers.count == 0) "Measuring adds no scene nodes or modifiers" report
        sample.pos = [25,30,50]
        sample.scale = [1,1,2]
        measurement = AssetsMG_VCW_MeasureHeight sample
        check ((AssetsMG_VCW_CloseEnough measurement[4] 2) and (AssetsMG_VCW_CloseEnough measurement[5] 0.5) and (AssetsMG_VCW_CloseEnough measurement[6] 2.5)) "Translation changes endpoints, nonuniform scale changes world height" report
        sample.transform = matrix3 1
        sample.rotation = eulerAngles 90 0 0
        measurement = AssetsMG_VCW_MeasureHeight sample
        check (AssetsMG_VCW_CloseEnough measurement[4] 0.2) "Rotation measures world Z span instead of local Z span" report
        sample.transform = matrix3 1
        local parentNode = dummy()
        append made parentNode
        sample.parent = parentNode
        parentNode.pos = [0,0,100]
        measurement = AssetsMG_VCW_MeasureHeight sample
        check ((AssetsMG_VCW_CloseEnough measurement[5] 1) and (AssetsMG_VCW_CloseEnough measurement[6] 2)) "Parent transform included" report
        sample.parent = undefined
        sample.transform = matrix3 1
        sample.objectOffsetPos = [0,0,25]
        measurement = AssetsMG_VCW_MeasureHeight sample
        check ((AssetsMG_VCW_CloseEnough measurement[5] 0.25) and (AssetsMG_VCW_CloseEnough measurement[6] 1.25)) "Object offset included once" report
        sample.objectOffsetPos = [0,0,0]
        local stretch = XForm()
        addModifier sample stretch
        stretch.gizmo.scale = [1,1,1.5]
        measurement = AssetsMG_VCW_MeasureHeight sample
        check (AssetsMG_VCW_CloseEnough measurement[4] 1.5) "Evaluated modifier result measured" report
        collapseStack sample
        local collapsed = AssetsMG_VCW_MeasureHeight sample
        check (AssetsMG_VCW_CloseEnough collapsed[4] measurement[4]) "Collapse keeps the same height without baking a ruler" report
        select sample
        AssetsMG_VCW_UpdateSelection undefined undefined
        check (AssetsMG_VCW_HeightSample[1] == sample and AssetsMG_VCW_Panel.MappingHeight == 1) "Single selection updates measurement without changing mapping height" report
        check (objects.count == beforeCount + 1) "Ruler refresh adds no exportable scene nodes" report
        AssetsMG_VCW_Panel.ShowHeightRuler = false
        check ((rulerCount()) == 0 and not AssetsMG_VCW_OverlayRegistered) "Disabling ruler unregisters callback" report
        check (AssetsMG_VCW_HeightSample != undefined) "Panel measurement remains available with ruler off" report
        AssetsMG_VCW_Panel.ShowHeightRuler = true
        check ((rulerCount()) == 1) "Re-enabling ruler registers once" report
        select #(sample,parentNode)
        AssetsMG_VCW_UpdateSelection undefined undefined
        check (AssetsMG_VCW_HeightSample == undefined) "Multiple selection clears individual ruler" report
        clearSelection()
        AssetsMG_VCW_UpdateSelection undefined undefined
        check (AssetsMG_VCW_HeightSample == undefined) "Deselect clears measurement cache" report
        local emptyNode = mesh()
        append made emptyNode
        local rejected = false
        try (AssetsMG_VCW_MeasureHeight emptyNode) catch (rejected = true)
        check (rejected and emptyNode.modifiers.count == 0) "Empty geometry handled without modifying it" report
        local flat = mesh vertices:#([0,0,0],[10,0,0],[0,10,0]) faces:#([1,2,3])
        append made flat
        measurement = AssetsMG_VCW_MeasureHeight flat
        check (AssetsMG_VCW_CloseEnough measurement[4] 0) "Flat mesh has zero height" report
        units.SystemType = #meters
        measurement = AssetsMG_VCW_MeasureHeight flat
        check (AssetsMG_VCW_CloseEnough measurement[4] 0) "Zero-height measurement supports meter units" report
        measurement = AssetsMG_VCW_MeasureHeight sample
        check (AssetsMG_VCW_CloseEnough measurement[4] 150) "System unit change updates displayed meters" report
        units.SystemType = #centimeters
        select sample
        AssetsMG_VCW_UpdateSelection undefined undefined
        delete sample
        AssetsMG_VCW_UpdateSelection undefined undefined
        check (AssetsMG_VCW_HeightSample == undefined) "Deleting the measured object clears cache" report
        fileIn (scriptRoot + "..\\tools\\AssetsMG_VertexColorWriter.ms")
        check ((rulerCount()) == 1) "Script reload replaces old callback without duplication" report
        destroyDialog AssetsMG_VCW_UI
        check ((rulerCount()) == 0 and AssetsMG_VCW_HeightSample == undefined) "Closing removes callback and cached node references" report
        format "RESULT: PASS\n" to:report
    )
    catch (format "RESULT: FAIL %\n" (getCurrentException()) to:report)
    try (destroyDialog AssetsMG_VCW_UI) catch ()
    for obj in made where isValidNode obj do delete obj
    units.SystemType = oldType
    units.SystemScale = oldScale
    close report
)
