-- Convenience launcher for Script > Run Script / drag-and-drop.
(
    local entryPath = (getFilenamePath (getThisScriptFilename())) + "Entry.ms"
    fileIn entryPath
    AssetsMG_VCW_Open()
)
