# Independent source/resource/type isolation checks. No 3ds Max execution.
param([string]$OriginalToolRoot = '')
$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -LiteralPath (Join-Path $packageRoot 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
function Assert-Package($value,[string]$caption) { if (-not $value) { throw $caption }; Write-Output ('PASS: ' + $caption) }
Assert-Package ($manifest.packageId -eq 'AssetsMG.VertexColorWriter') 'Package identity'
$expected = @('Entry.ms','Launch.ms','README.txt','已知问题-颜色显示.txt','manifest.json','SHA256SUMS.txt','tools/AssetsMG_VertexColorWriter.ms','tools/AssetsMG_VertexColorWriterUI.cs','tools/AssetsMG_VertexColorWriterTexture.cs','icons/AssetsMG_VertexColorWriter.png','tests/Test-Package.ps1','tests/AssetsMG_Coexistence_Smoke.ms','tests/Test-VertexColorWriterUI.ps1','tests/Test-VertexColorWriterTexture.ps1','tests/VertexColorWriter_Selection_Smoke.ms','tests/VertexColorWriter_Texture_Smoke.ms','tests/VertexColorWriter_Height_Smoke.ms')
foreach ($theme in @('Dark','Light')) { foreach ($size in @(16,24,30,32,36,48,64)) { $expected += "icons/$theme/AssetsMG/VertexColorWriter_$size.png" } }
$actual = @(Get-ChildItem -LiteralPath $packageRoot -Recurse -File | ForEach-Object { $_.FullName.Substring($packageRoot.Length+1).Replace('\','/') })
Assert-Package (@(Compare-Object $expected $actual).Count -eq 0) 'Exactly the intended runtime, icons, docs and tests; no original installer'
$hashLines = @(Get-Content -LiteralPath (Join-Path $packageRoot 'SHA256SUMS.txt') -Encoding UTF8)
Assert-Package ($hashLines.Count -eq $actual.Count-1) 'Hash manifest covers every payload file'
foreach ($line in $hashLines) {
    if ($line -notmatch '^([0-9A-F]{64})  (.+)$') { throw 'Invalid hash manifest line.' }
    $wantedHash = $Matches[1]; $relative = $Matches[2]
    if ($relative -notin $expected) { throw ('Unexpected manifest path: ' + $relative) }
    if ((Get-FileHash -LiteralPath (Join-Path $packageRoot $relative) -Algorithm SHA256).Hash -ne $wantedHash) { throw ('Hash mismatch: ' + $relative) }
}
Write-Output 'PASS: All package hashes'
$runtimeText = foreach ($relative in @('Entry.ms','Launch.ms','tools/AssetsMG_VertexColorWriter.ms','tools/AssetsMG_VertexColorWriterUI.cs','tools/AssetsMG_VertexColorWriterTexture.cs')) {
    [IO.File]::ReadAllText((Join-Path $packageRoot $relative))
}
$runtime = $runtimeText -join "`n"
Assert-Package ($runtime -notmatch '\b(?:VCW_|ZHR_)\w*|MaxZJTools|"VCW - |"ZHR - |__VCW_TEMP__') 'No original runtime globals, aliases, modifier tags, paths or namespace'
Assert-Package ($runtime -notmatch '(?i)\bmacroscript\b\s+\w+|menuMan\.|#userIcons|MaxZJTools_Init') 'Runtime does not register original menus/macros or install user icons'
Assert-Package ($runtime -match 'AssetsMG.Tools.VertexColorWriter.WriterPanel' -and $runtime -match 'Dark", "AssetsMG"') 'C# construction and icon lookup use isolated identities'
$entry = [IO.File]::ReadAllText((Join-Path $packageRoot 'Entry.ms'))
Assert-Package ($entry -notmatch '(?m)^AssetsMG_VCW_Open\(\)') 'Entry import is passive'
$keywords = @('about','and','animate','as','at','attributes','by','case','catch','collect','continue','coordsys','do','else','exit','fn','for','from','function','global','if','in','local','macroscript','mapped','max','not','of','off','on','or','parameters','persistent','plugin','rcmenu','return','rollout','set','struct','then','throw','to','tool','try','undo','utility','when','where','while','with')
foreach ($file in (Get-ChildItem -LiteralPath $packageRoot -Recurse -Filter '*.ms')) {
    $source = [IO.File]::ReadAllText($file.FullName)
    $clean = [regex]::Replace($source,'(?s)/\*.*?\*/|@?"(?:\\.|[^"\\])*"|--[^\r\n]*',' ')
    foreach ($match in [regex]::Matches($clean,'(?i)\b(?:local|global|fn|function|for|macroscript|rollout)\s+([a-z_]\w*)')) {
        if ($match.Groups[1].Value -in $keywords) { throw ('Reserved declaration in ' + $file.Name) }
    }
    $stack = New-Object 'System.Collections.Generic.Stack[char]'
    foreach ($character in $clean.ToCharArray()) {
        if ($character -in @('(', '[', '{')) { $stack.Push($character) }
        elseif ($character -in @(')',']','}')) {
            $wanted = switch ($character) { ')' {'('} ']' {'['} '}' {'{'} }
            if ($stack.Count -eq 0 -or $stack.Pop() -ne $wanted) { throw ('Delimiter mismatch in ' + $file.Name) }
        }
    }
    if ($stack.Count -ne 0) { throw ('Unclosed delimiter in ' + $file.Name) }
}
Write-Output 'PASS: Targeted MAXScript delimiter/keyword checks (not host compilation)'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
$source = [IO.File]::ReadAllText((Join-Path $packageRoot 'tools/AssetsMG_VertexColorWriterUI.cs')) + "`n" + [IO.File]::ReadAllText((Join-Path $packageRoot 'tools/AssetsMG_VertexColorWriterTexture.cs'))
Add-Type -TypeDefinition $source -ReferencedAssemblies System.Drawing,System.Windows.Forms -Language CSharp
$panel = New-Object AssetsMG.Tools.VertexColorWriter.WriterPanel
$original = $null
try {
    Assert-Package ($panel.LoadToolIcon((Join-Path $packageRoot 'icons'))) 'Independent AssetsMG icon loads'
    Assert-Package ($panel.IsGradient -and $panel.WriteR -and $panel.MappingHeight -eq 1) 'Original tool defaults retained'
    if ($OriginalToolRoot.Length -gt 0) {
        $originalSource = [IO.File]::ReadAllText((Join-Path $OriginalToolRoot 'tools/VertexColorWriterUI.cs')) + "`n" + [IO.File]::ReadAllText((Join-Path $OriginalToolRoot 'tools/VertexColorWriterTexture.cs'))
        Add-Type -TypeDefinition $originalSource -ReferencedAssemblies System.Drawing,System.Windows.Forms -Language CSharp
        $original = New-Object MaxZJTools.VertexColorWriter.WriterPanel
        Assert-Package ($original.GetType().FullName -ne $panel.GetType().FullName) 'Both C# namespaces compile and instantiate in one process'
        $panel.SelectedVerticesOnly = $true
        Assert-Package (-not $original.SelectedVerticesOnly) 'Panel settings are independent'
        $panel.Dispose()
        Assert-Package (-not $original.IsDisposed) 'Disposing AssetsMG leaves original C# panel alive'
        foreach ($property in $manifest.sourceHashes.PSObject.Properties) {
            if ((Get-FileHash -LiteralPath (Join-Path $OriginalToolRoot $property.Name) -Algorithm SHA256).Hash -ne $property.Value) { throw ('Original source hash changed: ' + $property.Name) }
        }
        Write-Output 'PASS: Original MaxZJTools source hashes unchanged'
    }
} finally { $panel.Dispose(); if ($null -ne $original) { $original.Dispose() } }
Write-Output 'RESULT: PASS (independent checks only; MAXScript/Max scene coexistence pending)'
