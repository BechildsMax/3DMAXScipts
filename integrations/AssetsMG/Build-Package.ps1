# Generate an isolated integration copy; never edit MaxZJTools in place.
# Windows PowerShell 5.1. Run from any directory.
param([switch]$Archive)
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$sourceRoot = Join-Path $repoRoot 'MaxZJTools'
$packageRoot = Join-Path $repoRoot 'dist\AssetsMG-VertexColorWriter-1.0.0'
$utf8Bom = New-Object Text.UTF8Encoding($true)
function Write-PackageText([string]$relative, [string]$text) {
    $path = Join-Path $packageRoot $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
    [IO.File]::WriteAllText($path, ($text -replace '\r?\n', "`r`n"), $utf8Bom)
}
function Replace-Required([string]$text, [string]$old, [string]$new) {
    if (-not $text.Contains($old)) { throw ('Source changed; inspect packaging rule: ' + $old) }
    $text.Replace($old,$new)
}
function Convert-Names([string]$text) {
    $text = $text.Replace('MaxZJTools.VertexColorWriter','AssetsMG.Tools.VertexColorWriter')
    $text = [regex]::Replace($text,'\bVCW_', 'AssetsMG_VCW_')
    $text = $text.Replace('VCW - ', 'AssetsMG VCW - ').Replace('__VCW_TEMP__','__AssetsMG_VCW_TEMP__')
    $text = $text.Replace('[VertexColorWriter]', '[AssetsMG.VertexColorWriter]')
    $text = $text.Replace('undo "VertexColorWriter"', 'undo "AssetsMG VertexColorWriter"')
    $text = $text.Replace('VertexColorWriterUI.cs','AssetsMG_VertexColorWriterUI.cs')
    $text = $text.Replace('VertexColorWriterTexture.cs','AssetsMG_VertexColorWriterTexture.cs')
    $text = $text.Replace('VertexColorWriter.ms','AssetsMG_VertexColorWriter.ms')
    $text
}
$sourceFiles = @('tools\VertexColorWriter.ms','tools\VertexColorWriterUI.cs','tools\VertexColorWriterTexture.cs','tools\VertexColorWriter-使用说明.txt','tests\Test-VertexColorWriterUI.ps1','tests\Test-VertexColorWriterTexture.ps1','tests\VertexColorWriter_Selection_Smoke.ms','tests\VertexColorWriter_Texture_Smoke.ms','tests\VertexColorWriter_Height_Smoke.ms')
$sourceHashes = [ordered]@{}
foreach ($relative in $sourceFiles) { $sourceHashes[$relative] = (Get-FileHash -LiteralPath (Join-Path $sourceRoot $relative) -Algorithm SHA256).Hash }

$core = [IO.File]::ReadAllText((Join-Path $sourceRoot 'tools\VertexColorWriter.ms'))
$core = Replace-Required $core '/* VertexColorWriter v1.4.0 / MaxZJTools v1.7.0' '/* AssetsMG integration v1.0.0 / VertexColorWriter feature baseline v1.4.0'
$core = Replace-Required $core '   Requires sibling VertexColorWriterUI.cs and VertexColorWriterTexture.cs; retains ZHR entry points.' '   Requires sibling UI and texture sources. All runtime state belongs to AssetsMG.'
$core = Replace-Required $core "global ZHR_UI, ZHR_CloseEnough, ZHR_Verify, ZHR_MapHeights, ZHR_BakeNode`r`n" ''
$core = Replace-Required $core "try (destroyDialog ZHR_UI) catch ()`r`n" ''
$aliasStart = $core.IndexOf('-- Compatibility for old scripted callers;')
$aliasEnd = $core.IndexOf('-- Read-only: temporary mesh VALUE,', $aliasStart)
if ($aliasStart -lt 0 -or $aliasEnd -lt 0) { throw 'Cannot locate legacy alias block.' }
$core = $core.Remove($aliasStart,$aliasEnd-$aliasStart)
$core = Replace-Required $core ' or md.name == "ZHR - Z Height to R"' ''
$core = Replace-Required $core ' or md.name == "ZHR - Mesh Adapter"' ''
$core = Replace-Required $core ' or oldMods[prefixIndex].name == "ZHR - Mesh Adapter"' ''
$core = Convert-Names $core
$core = Replace-Required $core 'rollout AssetsMG_VCW_UI "定点色写入工具  |  VertexColorWriter"' 'rollout AssetsMG_VCW_UI "定点色写入工具  |  AssetsMG · VertexColorWriter"'
Write-PackageText 'tools\AssetsMG_VertexColorWriter.ms' $core

foreach ($name in @('UI','Texture')) {
    $source = [IO.File]::ReadAllText((Join-Path $sourceRoot ("tools\VertexColorWriter$name.cs")))
    $source = Convert-Names $source
    if ($name -eq 'UI') { $source = Replace-Required $source '"Dark", "MaxZJTools",' '"Dark", "AssetsMG",' }
    Write-PackageText ("tools\AssetsMG_VertexColorWriter$name.cs") $source
}
foreach ($theme in @('Dark','Light')) {
    $destination = Join-Path $packageRoot ("icons\$theme\AssetsMG")
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    foreach ($size in @(16,24,30,32,36,48,64)) {
        Copy-Item -LiteralPath (Join-Path $sourceRoot ("icons\$theme\MaxZJTools\VertexColorWriter_$size.png")) -Destination $destination -Force
    }
}
Copy-Item -LiteralPath (Join-Path $sourceRoot 'icons\VertexColorWriter.png') -Destination (Join-Path $packageRoot 'icons\AssetsMG_VertexColorWriter.png') -Force
foreach ($name in @('Entry.ms','Launch.ms','README.template.txt','Test-Package.ps1','AssetsMG_Coexistence_Smoke.ms')) {
    $template = [IO.File]::ReadAllText((Join-Path $PSScriptRoot $name))
    if ($name -eq 'README.template.txt') {
        $usage = [IO.File]::ReadAllText((Join-Path $sourceRoot 'tools\VertexColorWriter-使用说明.txt'))
        $start = $usage.IndexOf('### 用途')
        $end = $usage.IndexOf('# 安装与使用',$start)
        if ($start -lt 0 -or $end -lt 0) { throw 'Cannot extract feature/parameter documentation.' }
        $usage = $usage.Substring($start,$end-$start).Trim()
        $usage = $usage.Replace('VCW - ', 'AssetsMG VCW - ')
        $usage = $usage.Replace('也识别原 ZHR 修改器对。中间插入其他修改器后，将新增一组，保留其下方原栈。','只识别本集成版的修改器。中间插入其他修改器后，将新增一组，保留其下方原栈。')
        $usage = $usage.Replace('保留完整工具包 重载菜单并打开面板','保留完整集成包 加载 AssetsMG 入口并打开面板')
        $template = Replace-Required $template '{{FEATURES}}' $usage
        Write-PackageText 'README.txt' $template
    } elseif ($name -eq 'Test-Package.ps1' -or $name -eq 'AssetsMG_Coexistence_Smoke.ms') {
        Write-PackageText ('tests\' + $name) $template
    } else { Write-PackageText $name $template }
}
foreach ($name in @('Test-VertexColorWriterUI.ps1','Test-VertexColorWriterTexture.ps1','VertexColorWriter_Selection_Smoke.ms','VertexColorWriter_Texture_Smoke.ms','VertexColorWriter_Height_Smoke.ms')) {
    $source = [IO.File]::ReadAllText((Join-Path $sourceRoot ('tests\' + $name)))
    $source = Convert-Names $source
    $source = $source.Replace('VertexColorWriter-preview','AssetsMG-VertexColorWriter-preview').Replace('VertexColorWriter-texture-tests','AssetsMG-VertexColorWriter-texture-tests')
    $source = $source.Replace('VertexColorWriter-selection-smoke.txt','AssetsMG-VertexColorWriter-selection-smoke.txt').Replace('VertexColorWriter-texture-smoke.txt','AssetsMG-VertexColorWriter-texture-smoke.txt').Replace('VertexColorWriter-height-smoke.txt','AssetsMG-VertexColorWriter-height-smoke.txt')
    Write-PackageText ('tests\' + $name) $source
}
Copy-Item -LiteralPath (Join-Path $sourceRoot 'bugs\2026-10-13-vcw-color-display.txt') -Destination (Join-Path $packageRoot '已知问题-颜色显示.txt') -Force
$manifest = [ordered]@{
    packageId = 'AssetsMG.VertexColorWriter'; packageVersion = '1.0.0'; toolFeatureVersion = '1.4.0'
    sourcePackageVersion = 'MaxZJTools 1.7.0'; created = '2026-10-13'; targetHost = '3ds Max 2022'
    namespace = 'AssetsMG.Tools.VertexColorWriter'; maxscriptPrefix = 'AssetsMG_VCW_'
    entry = 'Entry.ms'; launch = 'Launch.ms'; sourceHashes = $sourceHashes
    validation = [ordered]@{
        independentDate = '2026-10-13'; uiChecks = 44; textureChecks = 41
        typeIsolation = 'Two C# namespaces instantiated together; state/disposal isolation passed.'
        host = '3ds Max coexistence, mesh/Undo/export pending; no host PASS evidence.'
    }
}
Write-PackageText 'manifest.json' ($manifest | ConvertTo-Json -Depth 5)
$manifestFiles = Get-ChildItem -LiteralPath $packageRoot -Recurse -File | Where-Object { $_.Name -ne 'SHA256SUMS.txt' }
$hashLines = foreach ($file in $manifestFiles) { (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash + '  ' + $file.FullName.Substring($packageRoot.Length+1).Replace('\','/') }
Write-PackageText 'SHA256SUMS.txt' ($hashLines -join "`r`n")
foreach ($relative in $sourceFiles) {
    if ((Get-FileHash -LiteralPath (Join-Path $sourceRoot $relative) -Algorithm SHA256).Hash -ne $sourceHashes[$relative]) { throw ('Original source changed: ' + $relative) }
}
if ($Archive) {
    & (Join-Path $packageRoot 'tests\Test-Package.ps1') -OriginalToolRoot $sourceRoot
    if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { throw 'Validation process failed.' }
    $zipPath = $packageRoot + '.zip'
    Compress-Archive -LiteralPath $packageRoot -DestinationPath $zipPath -Force
    Write-Output ('ZIP: ' + $zipPath)
}
Write-Output ('PACKAGE: ' + $packageRoot)
Write-Output 'Original MaxZJTools inputs unchanged (SHA-256 verified).'
