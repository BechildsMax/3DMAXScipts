# Packaging only: resize the original generated PNGs without changing their artwork/alpha.
# Windows PowerShell 5.1; no third-party dependencies. Run from any working directory.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
function Save-IconSize([Drawing.Image]$source, [int]$size, [string]$path) {
    $bitmap = New-Object Drawing.Bitmap($size,$size,([Drawing.Imaging.PixelFormat]::Format32bppArgb))
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
            $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.Clear([Drawing.Color]::Transparent)
            $graphics.DrawImage($source,(New-Object Drawing.Rectangle(0,0,$size,$size)),0,0,$source.Width,$source.Height,[Drawing.GraphicsUnit]::Pixel)
        } finally { $graphics.Dispose() }
        $bitmap.Save($path,[Drawing.Imaging.ImageFormat]::Png)
    } finally { $bitmap.Dispose() }
}
foreach ($theme in @('Dark','Light')) {
    $sourcePath = Join-Path $PSScriptRoot ('source/VertexColorWriter-' + $theme.ToLowerInvariant() + '.png')
    $target = Join-Path $PSScriptRoot ($theme + '/MaxZJTools')
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    $source = [Drawing.Image]::FromFile($sourcePath)
    try {
        foreach ($size in @(16,24,30,32,36,48,64)) {
            Save-IconSize $source $size (Join-Path $target "VertexColorWriter_$size.png")
        }
        if ($theme -eq 'Dark') { Save-IconSize $source 512 (Join-Path $PSScriptRoot 'VertexColorWriter.png') }
    } finally { $source.Dispose() }
}
'Packaged 14 toolbar PNGs plus the 512px library icon.'
