/* Run in a NEW EMPTY scene or an isolated 3dsmaxbatch process.
   Does not reset/save a scene or install the package. Creates only fixtures.
   Report: %TEMP%/MaxZJTools-LegacyTools-smoke.txt. PASS requires ALL PASS footer.
*/
(
    if objects.count != 0 do throw "Legacy smoke requires an empty scene."
    local root = getFilenamePath (getThisScriptFilename())
    local report = createFile ((getDir #temp) + "\\MaxZJTools-LegacyTools-smoke.txt")
    local nodes = #()
    local bitmapFile = undefined
    local bitmapValue = undefined
    local failure = undefined
    local oldTime = sliderTime
    global MaxZJTools_Headless
    local oldHeadless = MaxZJTools_Headless
    MaxZJTools_Headless = true
    fn check result label stream =
    (
        if not result do throw ("FAIL: " + label)
        format "PASS: %\n" label to:stream
        flush stream
    )
    try
    (
        format "Host: %\n" (maxVersion()) to:report
        for name in #("RenameTools.ms","MeshChecker.ms","ReSetTexturesPath.ms","BoneOverride.ms") do
        (
            fileIn (root + "..\\tools\\" + name)
            check true ("Load " + name) report
        )
        -- Create only the two UI-backed parameter sets; no scan runs on opening textures.
        createDialog renameNodesRollout pos:[-10000,-10000]
        createDialog reSetTexturesRollout pos:[-10000,-10000]
        local a = box name:"MZJ_Test_A"
        local b = box name:"MZJ_Test_B"
        append nodes a
        append nodes b
        local mat = standardMaterial name:"MZJ_Test_Material"
        a.material = mat
        clearSelection()
        renameNodesRollout.chkObjects.checked = false
        renameNodesRollout.chkMaterials.checked = true
        check ((renameNodesRollout.getMaterialsToRename()).count == 0) "Empty selection collects no scene materials" report
        check (renameNodesRollout.previewRename()) "Empty preview accepted as empty" report
        local emptyResult = renameNodesRollout.applyPreview()
        check (emptyResult[1] == 0 and mat.name == "MZJ_Test_Material") "Empty apply changes nothing" report
        local bone = BoneSys.createBone [0,0,0] [10,0,0] [0,0,1]
        append nodes bone
        bone.name = "MZJ_Test_Bone"
        select bone
        renameNodesRollout.chkMaterials.checked = false
        renameNodesRollout.chkObjects.checked = true
        renameNodesRollout.chkBones.checked = true
        renameNodesRollout.prefixText.text = "P_"
        check ((renameNodesRollout.buildPlan()).count == 1) "Object/bone target deduplicated" report
        check (renameNodesRollout.previewRename()) "Rename preview succeeds" report
        select a
        local rejected = false
        try (renameNodesRollout.applyPreview()) catch (rejected = true)
        check rejected "Selection drift blocks rename" report
        check (bone.name == "MZJ_Test_Bone" and a.name == "MZJ_Test_A") "Stale preview performs no writes" report
        select bone
        check (renameNodesRollout.previewRename()) "Fresh rename preview" report
        local renamed = renameNodesRollout.applyPreview()
        check (renamed[1] == 1 and bone.name == "P_MZJ_Test_Bone") "Bone renamed exactly once" report
        max undo
        check (bone.name == "MZJ_Test_Bone") "Rename Undo restores original name" report
        renameNodesRollout.prefixText.text = ""
        renameNodesRollout.renameMethod.state = 4
        renameNodesRollout.baseName.text = "Conflict"
        renameNodesRollout.startNumber.value = 1
        renameNodesRollout.digitCount.value = 3
        b.name = "Conflict_001"
        check (not renameNodesRollout.previewRename()) "Existing out-of-scope name blocks preview" report

        -- XYZ subcontrollers at different times must be inspected and removed by the same traversal.
        a.position.controller = Position_XYZ()
        with animate on
        (
            at time 0 a.position = [0,0,0]
            at time 10 a.position = [10,20,30]
        )
        local tracks = meshCheckerRollout.objectTracks a
        check (tracks.count >= 3) "XYZ child tracks discovered" report
        local total = 0
        for track in tracks do total += track[2].count
        local cleared
        undo "Legacy smoke clear" on (cleared = meshCheckerRollout.clearTracks tracks #(a))
        check (cleared[1] == total and cleared[2].count == 0 and (meshCheckerRollout.objectTracks a).count == 0) "All scanned child keys removed and checked" report
        max undo
        check (meshCheckerRollout.sameTracks tracks (meshCheckerRollout.objectTracks a)) "Animation Undo restores tracks and times" report
        b.position.controller = a.position.controller
        rejected = false
        try (meshCheckerRollout.clearTracks tracks #(a)) catch (rejected = true)
        check rejected "Shared controller outside scope blocks deletion" report
        check (meshCheckerRollout.sameTracks tracks (meshCheckerRollout.objectTracks a)) "Shared-track rejection keeps keys" report
        b.position.controller = Position_XYZ()

        -- One bitmap reused by two submaterials: one identity and one write.
        local guid = (dotNetClass "System.Guid").NewGuid()
        local tempName = "MZJ_Legacy_" + guid.ToString()
        bitmapFile = (getDir #temp) + "\\" + tempName + ".png"
        bitmapValue = bitmap 2 2 color:red filename:bitmapFile
        save bitmapValue
        close bitmapValue
        bitmapValue = undefined
        local tex = bitmapTexture filename:((getDir #temp) + "\\missing_" + tempName + ".png")
        local sub1 = standardMaterial diffuseMap:tex
        local sub2 = standardMaterial diffuseMap:tex
        local multi = multimaterial numsubs:2
        multi[1] = sub1
        multi[2] = sub2
        a.material = multi
        local maps = reSetTexturesRollout.getAllBitmapTextures()
        check (maps.count == 1 and maps[1] == tex) "Submaterials scanned; shared bitmap deduplicated" report
        reSetTexturesRollout.txtOldPrefix.text = "missing_"
        reSetTexturesRollout.txtNewPrefix.text = ""
        local plan = reSetTexturesRollout.buildPathPlan #prefix #(tex,tex)
        check (plan.count == 1 and plan[1][4] == "可修改") "Existing destination proposed once" report
        local applied = reSetTexturesRollout.applyPathPlan plan
        check (applied[1] == 1 and applied[2] == 1 and tex.filename == bitmapFile) "Path changed and destination found" report
        max undo
        check (tex.filename == plan[1][2]) "Bitmap reference Undo restores old path" report
        reSetTexturesRollout.txtNewPrefix.text = "not_existing_"
        local missingPlan = reSetTexturesRollout.buildPathPlan #prefix #(tex)
        local missingResult = reSetTexturesRollout.applyPathPlan missingPlan
        check (missingResult[1] == 0 and missingResult[3] == 1 and tex.filename == plan[1][2]) "Missing destination skipped without mutation" report

        -- Invalid type and preflight failure must leave no new bone or hierarchy edits.
        rejected = false
        try (SingleBoneReplacer.executeReplacement a #(b)) catch (rejected = true)
        check rejected "Non-bone input rejected" report
        local countBefore = objects.count
        local originalBoneName = bone.name
        rejected = false
        try (SingleBoneReplacer.executeReplacement bone #(b)) catch (rejected = true)
        check rejected "Missing Skin rejected in preflight" report
        check (objects.count == countBefore and bone.name == originalBoneName and not bone.isHidden) "Preflight rejection leaves scene intact" report
        -- Real Skin success and Undo (all vertices, including small/other influences).
        local meshNode = convertToMesh (box width:2 length:2 height:2)
        append nodes meshNode
        local otherBone = BoneSys.createBone [0,5,0] [10,5,0] [0,0,1]
        append nodes otherBone
        local skinMod = Skin()
        addModifier meshNode skinMod
        SingleBoneReplacer.activateSkin meshNode skinMod
        skinOps.addBone skinMod bone 0
        skinOps.addBone skinMod otherBone 0
        local id1 = SingleBoneReplacer.boneID skinMod bone.name
        local id2 = SingleBoneReplacer.boneID skinMod otherBone.name
        for v = 1 to skinOps.GetNumberVertices skinMod do
            skinOps.ReplaceVertexWeights skinMod v #(id1,id2) #(0.00005,0.99995)
        local before = SingleBoneReplacer.captureSkin meshNode bone
        local replacement = SingleBoneReplacer.executeReplacement bone #(meshNode)
        append nodes replacement
        local newID = SingleBoneReplacer.boneID skinMod replacement.name
        check (SingleBoneReplacer.verifyWeights before newID) "Bone transfer preserves all weights, including tiny influences" report
        check (bone.isHidden and replacement.name == originalBoneName) "Final name/visibility applied after verification" report
        max undo
        check (not isValidNode replacement and bone.name == originalBoneName and not bone.isHidden) "Bone Undo restores identity and removes replacement" report
        check (SingleBoneReplacer.verifyWeights before 0) "Bone Undo restores every vertex weight" report
        format "ALL PASS\n" to:report
    )
    catch
    (
        failure = getCurrentException()
        format "FAIL: %\n" failure to:report
    )
    try (destroyDialog renameNodesRollout) catch ()
    try (destroyDialog reSetTexturesRollout) catch ()
    try (closeRolloutFloater meshCheckerDialog) catch ()
    try (destroyDialog SingleBoneReplacer) catch ()
    with undo off (for node in nodes where isValidNode node do delete node)
    if bitmapValue != undefined do close bitmapValue
    if bitmapFile != undefined and doesFileExist bitmapFile do deleteFile bitmapFile
    sliderTime = oldTime
    MaxZJTools_Headless = oldHeadless
    close report
    if failure != undefined do throw failure
)
