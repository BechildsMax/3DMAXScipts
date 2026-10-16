# Targeted static regressions; this is not a MAXScript parser or host test.
param([string]$ToolRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
# Autodesk MAXScript Language Reserved Keywords; compared case-insensitively.
$keywords = @('about','and','animate','as','at','attributes','by','case','catch','collect','continue','coordsys','do','else','exit','fn','for','from','function','global','if','in','local','macroscript','mapped','max','not','of','off','on','or','parameters','persistent','plugin','rcmenu','return','rollout','set','struct','then','throw','to','tool','try','undo','utility','when','where','while','with')
$paths = @('tools\ZHeightToVertexRed.ms','tools\VertexColorWriter.ms','startup\MaxZJTools_Init.ms','tests\ZHeightToVertexRed_Smoke.ms','tests\VertexColorWriter_Smoke.ms','tests\VertexColorWriter_Height_Smoke.ms','tests\VertexColorWriter_Texture_Smoke.ms','tests\VertexColorWriter_Selection_Smoke.ms')
$failures = [System.Collections.Generic.List[string]]::new()
foreach ($relative in $paths) {
    $source = Get-Content -LiteralPath (Join-Path $ToolRoot $relative) -Raw -Encoding UTF8
    # Preserve character positions and line numbers when masking comments/strings.
    $clean = [regex]::Replace($source, '(?s)/\*.*?\*/|@?"(?:\\.|[^"\\])*"|--[^\r\n]*', { param($match) [regex]::Replace($match.Value, '[^\r\n]', ' ') })
    foreach ($declaration in [regex]::Matches($clean, '(?i)\b(?:local|global|fn|function|for|macroscript|rollout)\s+([a-z_]\w*)')) {
        $identifier = $declaration.Groups[1].Value
        if ($identifier -in $keywords) {
            $lineNumber = ($clean.Substring(0, $declaration.Index) -split "`n").Count
            $failures.Add("${relative}:${lineNumber}: reserved keyword used as identifier: $identifier")
        }
    }
    $stack = [System.Collections.Generic.Stack[char]]::new()
    foreach ($character in $clean.ToCharArray()) {
        if ($character -in @('(', '[', '{')) { $stack.Push($character) }
        elseif ($character -in @(')', ']', '}')) {
            $expected = switch ($character) { ')' {'('} ']' {'['} '}' {'{'} }
            if ($stack.Count -eq 0 -or $stack.Pop() -ne $expected) { throw "Delimiter mismatch: $relative" }
        }
    }
    if ($stack.Count -ne 0) { $failures.Add("Unclosed delimiter: $relative") }
    # Regression: removeItem takes an interface; use removeItemByPosition for an index.
    if ($clean -match '(?i)\.removeItem\s+(?:foundIndex|\d+)\b') {
        $failures.Add("${relative}: menu index passed to removeItem")
    }
}
if ($failures.Count -gt 0) { throw ($failures -join "`n") }
'PASS: targeted reserved-name, delimiter and menu-argument regressions (target files).'
'Host compilation, UI and mesh results still require 3ds Max.'
