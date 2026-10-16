/* AssetsMG VertexColorWriter integration v1.0.0.
   Loading this entry only defines Open/Close; it does not open a window,
   install a startup script, register a macro or change another package's menu.
*/
global AssetsMG_VCW_PackageRoot = getFilenamePath (getThisScriptFilename())
global AssetsMG_VCW_Open, AssetsMG_VCW_Close
global AssetsMG_VCW_UI
fn AssetsMG_VCW_Open =
(
    local toolPath = AssetsMG_VCW_PackageRoot + "tools\\AssetsMG_VertexColorWriter.ms"
    if not (doesFileExist toolPath) do throw ("AssetsMG VertexColorWriter 文件缺失：\n" + toolPath)
    fileIn toolPath
    true
)
fn AssetsMG_VCW_Close =
(
    if AssetsMG_VCW_UI != undefined do try (destroyDialog AssetsMG_VCW_UI) catch ()
    true
)
