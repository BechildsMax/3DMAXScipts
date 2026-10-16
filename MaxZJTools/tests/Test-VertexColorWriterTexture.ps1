# Executes the production decoder/sampler without 3ds Max. Windows PowerShell 5.1.
param([string]$OutputDirectory = (Join-Path $env:TEMP 'VertexColorWriter-texture-tests'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$source = Get-Content (Join-Path $PSScriptRoot '..\tools\VertexColorWriterTexture.cs') -Raw -Encoding UTF8
Add-Type -TypeDefinition $source -ReferencedAssemblies System.Drawing -Language CSharp
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$script:checks = 0
function Assert-True($condition, $message) { if (-not $condition) { throw $message }; $script:checks++; "PASS: $message" }
function Assert-Sample($sample, $rgba, $message) {
    $actual = @($sample.R,$sample.G,$sample.B,$sample.A)
    $ok = $true
    for ($i = 0; $i -lt 4; $i++) { if ([Math]::Abs($actual[$i] - $rgba[$i]) -gt 0.0000001) { $ok = $false } }
    Assert-True $ok "$message (RGBA $actual)"
}
function Assert-Reject($action, $message) {
    $rejected = $false
    try { & $action | Out-Null } catch { $rejected = $true }
    Assert-True $rejected $message
}
function Write-Tga($path, [int]$width, [int]$height, [int]$type, [int]$depth, [int]$descriptor, [byte[]]$pixels) {
    [byte[]]$header = New-Object byte[] 18
    $header[2] = $type
    $header[12] = $width -band 255; $header[13] = $width -shr 8
    $header[14] = $height -band 255; $header[15] = $height -shr 8
    $header[16] = $depth; $header[17] = $descriptor
    [IO.File]::WriteAllBytes($path, [byte[]]($header + $pixels))
}
$pngPath = Join-Path $OutputDirectory 'corners.png'
$bitmap = New-Object System.Drawing.Bitmap(2,2)
try {
    # top-left red/opaque, top-right green/half alpha, bottom-left blue/quarter,
    # bottom-right middle gray/transparent with nonzero hidden RGB.
    $bitmap.SetPixel(0,0,[Drawing.Color]::FromArgb(255,255,0,0))
    $bitmap.SetPixel(1,0,[Drawing.Color]::FromArgb(128,0,255,0))
    $bitmap.SetPixel(0,1,[Drawing.Color]::FromArgb(64,0,0,255))
    $bitmap.SetPixel(1,1,[Drawing.Color]::FromArgb(0,128,128,128))
    $bitmap.Save($pngPath,[Drawing.Imaging.ImageFormat]::Png)
} finally { $bitmap.Dispose() }
$texture = [MaxZJTools.VertexColorWriter.TextureSource]::Load($pngPath)
Assert-True ($texture.Width -eq 2 -and $texture.Height -eq 2) 'PNG dimensions decoded'
Assert-Sample ($texture.Sample(.25,.75,$false,$false,$false)) @(1,0,0,1) 'Top-left texel uses bottom-left UV convention'
Assert-Sample ($texture.Sample(.75,.75,$false,$false,$false)) @(0,1,0,(128.0/255)) 'Top-right texel and Alpha'
Assert-Sample ($texture.Sample(.25,.25,$false,$true,$false)) @(0,0,1,(64.0/255)) 'Bottom-left texel center is unchanged by bilinear'
$gray = 128.0/255
Assert-Sample ($texture.Sample(.75,.25,$false,$false,$false)) @($gray,$gray,$gray,0) 'Transparent PNG retains hidden RGB'
$linearGray = [Math]::Pow(($gray+.055)/1.055,2.4)
Assert-Sample ($texture.Sample(.75,.25,$true,$false,$false)) @($linearGray,$linearGray,$linearGray,0) 'Color mode converts sRGB; mask mode above retains bytes'
$average = (1+$gray)/4
Assert-Sample ($texture.Sample(.5,.5,$false,$true,$false)) @($average,$average,$average,(447.0/1020)) 'Bilinear averages four raw texels and Alpha'
$averageLinear = (1+$linearGray)/4
Assert-Sample ($texture.Sample(.5,.5,$true,$true,$false)) @($averageLinear,$averageLinear,$averageLinear,(447.0/1020)) 'sRGB conversion precedes interpolation; Alpha stays linear'
Assert-Sample ($texture.Sample(-20,20,$false,$true,$false)) @(1,0,0,1) 'Clamp outside UV uses nearest edge'
Assert-Sample ($texture.Sample(-.25,1.75,$false,$false,$true)) @(0,1,0,(128.0/255)) 'Repeat handles negative and positive tiles'
Assert-Sample ($texture.Sample(0,.75,$false,$true,$true)) @(.5,.5,0,(383.0/510)) 'Bilinear repeat blends across tile edge'
Assert-Sample ($texture.Sample(1,1,$false,$false,$false)) @(0,1,0,(128.0/255)) 'Clamp exact upper UV boundary'
Assert-Sample ($texture.Sample(0,0,$false,$false,$false)) @(0,0,1,(64.0/255)) 'Clamp exact lower UV boundary'
Assert-Reject { $texture.Sample([double]::NaN,0,$false,$false,$false) } 'NaN UV rejected'
Assert-Reject { $texture.Sample(0,[double]::PositiveInfinity,$false,$false,$false) } 'Infinite UV rejected'
$file = [IO.File]::Open($pngPath,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
$file.Dispose()
Assert-True $true 'Loaded image does not keep a file lock'
$opaqueBitmap = New-Object System.Drawing.Bitmap(2,2,([Drawing.Imaging.PixelFormat]::Format24bppRgb))
try {
    for ($y=0; $y -lt 2; $y++) { for ($x=0; $x -lt 2; $x++) { $opaqueBitmap.SetPixel($x,$y,[Drawing.Color]::FromArgb(128,128,128)) } }
    $bmpPath = Join-Path $OutputDirectory 'opaque.bmp'
    $jpgPath = Join-Path $OutputDirectory 'opaque.jpg'
    $opaqueBitmap.Save($bmpPath,[Drawing.Imaging.ImageFormat]::Bmp)
    $opaqueBitmap.Save($jpgPath,[Drawing.Imaging.ImageFormat]::Jpeg)
} finally { $opaqueBitmap.Dispose() }
$bmpTexture = [MaxZJTools.VertexColorWriter.TextureSource]::Load($bmpPath)
Assert-Sample ($bmpTexture.Sample(.5,.5,$false,$false,$false)) @($gray,$gray,$gray,1) '24-bit BMP colors and implicit opaque Alpha'
$jpgTexture = [MaxZJTools.VertexColorWriter.TextureSource]::Load($jpgPath)
Assert-Sample ($jpgTexture.Sample(.5,.5,$false,$false,$false)) @($gray,$gray,$gray,1) 'JPEG decoding and implicit opaque Alpha'
$indexed = New-Object System.Drawing.Bitmap(2,1,([Drawing.Imaging.PixelFormat]::Format8bppIndexed))
try {
    $palette = $indexed.Palette
    $palette.Entries[0] = [Drawing.Color]::FromArgb(255,255,0,0)
    $palette.Entries[1] = [Drawing.Color]::FromArgb(255,0,255,0)
    $indexed.Palette = $palette
    $locked = $indexed.LockBits((New-Object Drawing.Rectangle(0,0,2,1)),[Drawing.Imaging.ImageLockMode]::WriteOnly,[Drawing.Imaging.PixelFormat]::Format8bppIndexed)
    try { [Runtime.InteropServices.Marshal]::Copy([byte[]](0,1),0,$locked.Scan0,2) } finally { $indexed.UnlockBits($locked) }
    $indexedPath = Join-Path $OutputDirectory 'indexed.png'
    $indexed.Save($indexedPath,[Drawing.Imaging.ImageFormat]::Png)
} finally { $indexed.Dispose() }
$indexedTexture = [MaxZJTools.VertexColorWriter.TextureSource]::Load($indexedPath)
Assert-Sample ($indexedTexture.Sample(.75,.5,$false,$false,$false)) @(0,1,0,1) 'Indexed PNG palette expands to RGB'
$thumb = $texture.CreateThumbnail()
try { Assert-True ($thumb.GetPixel(1,1).R -eq 128 -and $thumb.GetPixel(1,1).A -eq 0) 'Thumbnail retains source alpha and color' } finally { $thumb.Dispose() }

$tgaPath = Join-Path $OutputDirectory 'sample.tga'
# Source canonical colors are top-left red, top-right green, bottom-left blue, bottom-right white.
$canonical = @([byte[]](0,0,255),[byte[]](0,255,0),[byte[]](255,0,0),[byte[]](255,255,255))
foreach ($descriptor in @(0,16,32,48)) {
    $data = [Collections.Generic.List[byte]]::new()
    for ($y=0; $y -lt 2; $y++) { for ($x=0; $x -lt 2; $x++) {
        $sx = if ($descriptor -band 16) { 1-$x } else { $x }
        $sy = if ($descriptor -band 32) { $y } else { 1-$y }
        $data.AddRange([byte[]]$canonical[$sy*2+$sx])
    } }
    Write-Tga $tgaPath 2 2 2 24 $descriptor $data.ToArray()
    $tga = [MaxZJTools.VertexColorWriter.TextureSource]::Load($tgaPath)
    Assert-Sample ($tga.Sample(.25,.75,$false,$false,$false)) @(1,0,0,1) "TGA origin $descriptor top-left"
    Assert-Sample ($tga.Sample(.75,.25,$false,$false,$false)) @(1,1,1,1) "TGA origin $descriptor bottom-right"
}
Write-Tga $tgaPath 2 1 10 32 40 ([byte[]](129,30,20,10,128))
$tga = [MaxZJTools.VertexColorWriter.TextureSource]::Load($tgaPath)
Assert-Sample ($tga.Sample(.75,.5,$false,$false,$false)) @((10.0/255),(20.0/255),(30.0/255),(128.0/255)) 'TGA repeated RLE packet with straight Alpha'
Write-Tga $tgaPath 2 1 10 24 32 ([byte[]](1,0,0,255,0,255,0))
$tga = [MaxZJTools.VertexColorWriter.TextureSource]::Load($tgaPath)
Assert-Sample ($tga.Sample(.75,.5,$false,$false,$false)) @(0,1,0,1) 'TGA raw RLE packet'
Write-Tga $tgaPath 1 1 2 32 32 ([byte[]](30,20,10,0))
$tga = [MaxZJTools.VertexColorWriter.TextureSource]::Load($tgaPath)
Assert-Sample ($tga.Sample(-2,3,$false,$true,$true)) @((10.0/255),(20.0/255),(30.0/255),1) 'TGA padding is opaque; 1x1 repeat and bilinear work'
Write-Tga $tgaPath 1 1 3 8 32 ([byte[]](10))
$tga = [MaxZJTools.VertexColorWriter.TextureSource]::Load($tgaPath)
Assert-Sample ($tga.Sample(.5,.5,$true,$true,$false)) @((10.0/255/12.92),(10.0/255/12.92),(10.0/255/12.92),1) 'Grayscale TGA and low-end sRGB transfer'
Write-Tga $tgaPath 1 1 10 24 32 ([byte[]](129,0,0,0))
Assert-Reject { [MaxZJTools.VertexColorWriter.TextureSource]::Load($tgaPath) } 'RLE overrun rejected'
Write-Tga $tgaPath 1 1 2 24 32 ([byte[]](0,0))
Assert-Reject { [MaxZJTools.VertexColorWriter.TextureSource]::Load($tgaPath) } 'Truncated pixels rejected'
Write-Tga $tgaPath 1 1 2 16 32 ([byte[]](0,0))
Assert-Reject { [MaxZJTools.VertexColorWriter.TextureSource]::Load($tgaPath) } 'Unsupported TGA depth rejected'
Write-Tga $tgaPath 8192 8192 2 24 32 ([byte[]]@())
Assert-Reject { [MaxZJTools.VertexColorWriter.TextureSource]::Load($tgaPath) } 'Texture size budget checked before pixel allocation'
Write-Tga $tgaPath 1 1 2 32 40 ([byte[]](0,0,255,128))
$extension = New-Object byte[] 495
$extension[0] = 239; $extension[1] = 1; $extension[494] = 4
$footer = [byte[]](@(22,0,0,0,0,0,0,0) + [Text.Encoding]::ASCII.GetBytes("TRUEVISION-XFILE.`0"))
[IO.File]::WriteAllBytes($tgaPath,[byte[]]([IO.File]::ReadAllBytes($tgaPath) + $extension + $footer))
Assert-Reject { [MaxZJTools.VertexColorWriter.TextureSource]::Load($tgaPath) } 'Premultiplied TGA Alpha rejected'
$extension[494] = 0
Write-Tga $tgaPath 1 1 2 32 40 ([byte[]](0,0,255,0))
[IO.File]::WriteAllBytes($tgaPath,[byte[]]([IO.File]::ReadAllBytes($tgaPath) + $extension + $footer))
$tga = [MaxZJTools.VertexColorWriter.TextureSource]::Load($tgaPath)
Assert-Sample ($tga.Sample(.5,.5,$false,$false,$false)) @(1,0,0,1) 'TGA extension with no useful Alpha is opaque'
Assert-Reject { [MaxZJTools.VertexColorWriter.TextureSource]::Load((Join-Path $OutputDirectory 'missing.png')) } 'Missing image rejected'
Assert-Reject { [MaxZJTools.VertexColorWriter.TextureSource]::Load((Join-Path $OutputDirectory 'unsupported.exr')) } 'Unsupported image format rejected'
$header16 = New-Object byte[] 25
$header16[0]=137; $header16[1]=80; $header16[2]=78; $header16[3]=71; $header16[24]=16
$png16 = Join-Path $OutputDirectory 'sixteen-bit.png'
[IO.File]::WriteAllBytes($png16,$header16)
Assert-Reject { [MaxZJTools.VertexColorWriter.TextureSource]::Load($png16) } '16-bit PNG is explicitly rejected'
"RESULT: PASS ($script:checks decoder/sampler checks; no MAXScript execution)"
