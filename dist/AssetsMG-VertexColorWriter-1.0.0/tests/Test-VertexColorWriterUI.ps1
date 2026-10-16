# Run with Windows PowerShell 5.1 -STA. Compiles and renders the real shared UI.
param([string]$OutputDirectory = (Join-Path $env:TEMP 'AssetsMG-VertexColorWriter-preview'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$source = Get-Content (Join-Path $PSScriptRoot '..\tools\AssetsMG_VertexColorWriterUI.cs') -Raw -Encoding UTF8
$source += "`n" + (Get-Content (Join-Path $PSScriptRoot '..\tools\AssetsMG_VertexColorWriterTexture.cs') -Raw -Encoding UTF8)
Add-Type -TypeDefinition $source -ReferencedAssemblies System.Drawing,System.Windows.Forms -Language CSharp
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
function Assert-True($condition, $message) { if (-not $condition) { throw $message }; Write-Output "PASS: $message" }
$form = New-Object System.Windows.Forms.Form
$panel = New-Object AssetsMG.Tools.VertexColorWriter.WriterPanel
try {
    Assert-True (-not $panel.LoadToolIcon((Join-Path $OutputDirectory 'missing-icons'))) 'Missing optional icon leaves the built-in glyph usable'
    Assert-True ($panel.LoadToolIcon((Join-Path $PSScriptRoot '..\icons')) -and $panel.HasToolIcon) 'Packaged tool icon loads'
    $form.ClientSize = New-Object System.Drawing.Size(860,808)
    $form.Controls.Add($panel)
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $form.Location = New-Object System.Drawing.Point(-10000,-10000)
    $form.ShowInTaskbar = $false
    $form.Show()
    [System.Windows.Forms.Application]::DoEvents()
    $form.PerformLayout()
    $panel.PerformLayout()
    Assert-True ($panel.Font.Size -eq 12) 'Body text is 12 pt'
    Assert-True ($panel.IsGradient -and $panel.WriteR -and -not $panel.WriteA -and $panel.MappingHeight -eq 1) 'Default is 1m height gradient, R only'
    $panel.SetSelection(3,1)
    Assert-True $panel.CanBake 'Selecting models enables write'
    Assert-True $panel.ShowHeightRuler 'Viewport height ruler defaults on'
    $panel.SetSelection(1,0)
    $panel.SetHeightMeasurement('HeightSample',1.25,0.5,1.75)
    Assert-True ($panel.HeightReadout -match '1\.250.*0\.500.*1\.750') 'Measured height and world Z endpoints are readable in meters'
    Assert-True ($panel.MappingHeight -eq 1) 'Measuring a 1.25m model does not change the 1m mapping height'
    $script:heightToggleEvents = 0
    $panel.add_HeightDisplayChanged({ $script:heightToggleEvents++ })
    $panel.ShowHeightRuler = $false
    $panel.ShowHeightRuler = $true
    Assert-True ($script:heightToggleEvents -eq 2) 'Height display toggle notifies the host on both transitions'
    $panel.SetMeasurementCost(350)
    Assert-True ($panel.RefreshInterval -eq 1400) 'Dense mesh measurements throttle polling'
    $panel.SetMeasurementCost(0)
    Assert-True ($panel.RefreshInterval -eq 500) 'Light measurements restore normal refresh rate'
    $bitmap = New-Object System.Drawing.Bitmap(860,808)
    try { $panel.DrawToBitmap($bitmap,(New-Object System.Drawing.Rectangle(0,0,860,808))); $bitmap.Save((Join-Path $OutputDirectory 'default.png')) } finally { $bitmap.Dispose() }
    $panel.SetConfiguration($true,$true,2.0,0.0,15,[System.Drawing.Color]::FromArgb(34,112,220),[System.Drawing.Color]::FromArgb(255,158,44),0.2,1.0)
    Assert-True ($panel.WriteR -and $panel.WriteG -and $panel.WriteB -and $panel.WriteA -and $panel.FromBottom) 'RGBA and bottom-relative gradient configured'
    Assert-True (-not $panel.StartInputEnabled) 'Bottom alignment disables absolute start height'
    Assert-True ([Math]::Abs($panel.LowR - 34.0/255) -lt 0.0001 -and $panel.LowA -eq 0.2) 'Color and Alpha settings round-trip'
    $bitmap = New-Object System.Drawing.Bitmap(860,808)
    try { $panel.DrawToBitmap($bitmap,(New-Object System.Drawing.Rectangle(0,0,860,808))); $bitmap.Save((Join-Path $OutputDirectory 'rgba-gradient.png')) } finally { $bitmap.Dispose() }
    $panel.SetConfiguration($false,$false,1.0,0.0,15,[System.Drawing.Color]::FromArgb(54,158,104),[System.Drawing.Color]::White,0.65,1)
    Assert-True (-not $panel.IsGradient -and $panel.LowA -eq 0.65) 'Fixed color mode settings'
    Assert-True (-not $panel.HeightInputsEnabled -and -not $panel.StartInputEnabled) 'Fixed fill disables irrelevant height controls'
    $bitmap = New-Object System.Drawing.Bitmap(860,808)
    try { $panel.DrawToBitmap($bitmap,(New-Object System.Drawing.Rectangle(0,0,860,808))); $bitmap.Save((Join-Path $OutputDirectory 'solid-color.png')) } finally { $bitmap.Dispose() }
    $panel.SetBusy($true)
    Assert-True (-not $panel.CanBake) 'Busy state prevents duplicate writes'
    Assert-True $panel.IsBusy 'Host can suspend ruler drawing during a write'
    $panel.SetBusy($false)
    $panel.SetResult('完成：成功 3，失败 0。','UI smoke report')
    Assert-True (-not $panel.IsDisposed) 'Busy and result updates keep the UI usable'
    $panel.SetTextureMode(1,$true,$true,$false)
    Assert-True ($panel.IsTexture -and -not $panel.IsGradient -and -not $panel.HeightInputsEnabled) 'Texture mode disables height mapping'
    Assert-True (-not $panel.CanBake -and $panel.LoadedTexture -eq $null) 'Texture mode requires a valid image'
    Assert-True ($panel.UVChannel -eq 1 -and $panel.TextureIsColor -and $panel.TextureBilinear -and -not $panel.TextureRepeat) 'Texture defaults: UV1, sRGB, bilinear, clamp'
    $fixturePath = Join-Path $OutputDirectory 'ui-texture.png'
    $fixture = New-Object System.Drawing.Bitmap(64,64)
    try {
        for ($y=0; $y -lt 64; $y++) { for ($x=0; $x -lt 64; $x++) {
            $fixture.SetPixel($x,$y,[Drawing.Color]::FromArgb(255,$x*4,$y*4,180))
        } }
        $fixture.Save($fixturePath,[Drawing.Imaging.ImageFormat]::Png)
    } finally { $fixture.Dispose() }
    Assert-True ($panel.LoadTextureFile($fixturePath) -and $panel.CanBake) 'Loading a valid texture enables writing'
    Assert-True ($panel.WriteR -and $panel.WriteG -and $panel.WriteB -and $panel.WriteA) 'Switching to texture retains channel selection'
    Assert-True ($panel.HeightReadout -match '1\.250') 'Texture mode retains independent model height readout'
    [System.Windows.Forms.Application]::DoEvents()
    $bitmap = New-Object System.Drawing.Bitmap(860,808)
    try { $panel.DrawToBitmap($bitmap,(New-Object System.Drawing.Rectangle(0,0,860,808))); $bitmap.Save((Join-Path $OutputDirectory 'texture.png')) } finally { $bitmap.Dispose() }
    $panel.SetTextureMode(2,$false,$false,$true)
    Assert-True ($panel.UVChannel -eq 2 -and -not $panel.TextureIsColor -and -not $panel.TextureBilinear -and $panel.TextureRepeat) 'Mask/nearest/repeat settings round-trip'
    Assert-True (-not $panel.LoadTextureFile((Join-Path $OutputDirectory 'missing.png')) -and -not $panel.CanBake -and $panel.LoadedTexture -eq $null) 'Failed load clears previous texture and prevents stale writes'
    $panel.SetConfiguration($false,$false,1,0,0,[System.Drawing.Color]::Black,[System.Drawing.Color]::White,0,1)
    Assert-True (-not $panel.CanBake) 'No checked channels disables write'
    $panel.SetConfiguration($true,$false,1,0,1,[System.Drawing.Color]::Black,[System.Drawing.Color]::White,0,1)
    Assert-True ($panel.IsGradient -and -not $panel.IsTexture -and $panel.CanBake) 'Returning to height mode works without a texture'
    Assert-True (-not $panel.SelectedVerticesOnly) 'Whole-model scope stays the default'
    $script:scopeRefreshEvents = 0
    $panel.add_SelectionRefreshRequested({ $script:scopeRefreshEvents++ })
    $panel.SelectedVerticesOnly = $true
    Assert-True (-not $panel.CanBake -and $script:scopeRefreshEvents -eq 1) 'Selected scope requests fresh host state and blocks missing context'
    $panel.SetVertexSelection(0,120,$true,'')
    Assert-True (-not $panel.CanBake) 'Empty vertex selection never falls back to whole-model fill'
    $panel.SetVertexSelection(8,120,$true,'')
    Assert-True ($panel.CanBake -and $panel.VertexReadout -match '8 / 120') 'Selected vertices enable write with a readable count'
    $panel.SetVertexSelection(8,120,$false,'请进入顶点模式')
    Assert-True (-not $panel.CanBake) 'Stored vertex flags outside vertex mode cannot be written'
    $panel.SetVertexSelection(8,120,$true,'')
    $panel.SetSelection(2,0)
    Assert-True (-not $panel.CanBake) 'Selected scope rejects multiple models'
    $panel.SetSelection(1,1)
    Assert-True (-not $panel.CanBake) 'Selected scope rejects a mixed object selection'
    $panel.SetSelection(1,0)
    $panel.SetConfiguration($false,$false,1,0,15,[System.Drawing.Color]::FromArgb(54,158,104),[System.Drawing.Color]::White,0.65,1)
    Assert-True ($panel.CanBake -and $panel.SelectedVerticesOnly -and -not $panel.IsGradient) 'Fixed RGBA fill keeps selected scope'
    [System.Windows.Forms.Application]::DoEvents()
    $bitmap = New-Object System.Drawing.Bitmap(860,808)
    try { $panel.DrawToBitmap($bitmap,(New-Object System.Drawing.Rectangle(0,0,860,808))); $bitmap.Save((Join-Path $OutputDirectory 'selected-vertices.png')) } finally { $bitmap.Dispose() }
    $panel.SetTextureMode(1,$true,$true,$false)
    Assert-True (-not $panel.CanBake -and $panel.SelectedVerticesOnly) 'Selected texture scope still requires an image'
    Assert-True ($panel.LoadTextureFile($fixturePath) -and $panel.CanBake -and $panel.SelectedVerticesOnly) 'Texture writing supports the selected scope'
    $panel.SetBusy($true)
    Assert-True (-not $panel.CanBake) 'Selected scope cannot write while busy'
    $panel.SetBusy($false)
    $panel.SetSelection(2,0)
    $panel.SelectedVerticesOnly = $false
    Assert-True $panel.CanBake 'Returning to whole-model scope restores batch writing'
    $panel.SetSelection(0,2)
    Assert-True (-not $panel.CanBake) 'Non-geometry-only selection disables write'
    $panel.SetHeightUnavailable('请选择一个模型查看高度')
    Assert-True ($panel.HeightReadout -notmatch '1\.250') 'Clearing selection removes stale measurement text'
} finally { $form.Dispose() }
Assert-True $panel.IsDisposed 'Panel cleanup disposes the control'
Write-Output 'RESULT: PASS (UI only; no MAXScript or mesh execution)'
