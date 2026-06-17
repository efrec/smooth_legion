# Convert our bespoke tweakdef to a player-friendly version
# and then minify it and get its URL-safe base64 encoding

#-- Config ---------------------------------------------------------------------

$lobbymsg = "SHORT LEGION"

$base_dir = 'D:\vscode\proj\beyond-all-reason\smooth_legion'
$tweakdef = 'tweakdef.lua'
$encoding = 'tweakdef_encoding.txt'
$minified = 'tweakdef_minified.lua'
$min_code = 'tweakdef_minified_encoding.txt'
$too_long = 'tweakdef_minified_encoding_too_long.txt'
$template = 'template.md'
$git_gist = 'gist.md'

$substitutions = @{
	# Sets a lobby message for the tweak. It should be short but must be unique and descriptive enough:
    '(?sm)\A--[\s\S]+?(?=^local)'                                          = "--$lobbymsg`n"
	# Remove testing code used for Rapid Iteration Development (writing shit code and then running it):
    '(?sm)^-- Tests[\s\S]+?(?=^-- Initialize)'                                  = ''
    '(?sm)^\s*no(?:unit|weapon)\(\w*\)\r\n'                                      = ''
	# Remove the rest of the tweakdefs => tweakunits conversion code. Should just remove this entirely:
    'local units = \{\}\r?\n'                                              = ''
    '(?sm)\r?\nlocal function (deep|diff|dumb_equal)[\s\S\r\n]+?^end\r?\n' = ''
    '(?sm)^\tif unitDef and not units[\s\S\r\n]+?\tend\r?\n'               = ''
    '(?sm)[- \r\n]+Convert to tweakunits.+\r?\n\z'                         = ''
}

$inserts = @{
    tweakdefs  = '<!-- tweakdefs_readable -->'
    tweakunits = '<!-- tweakunits_readable -->' # We are still copying this by hand from infolog.txt.
    encoding   = '<!-- tweakdefs_encoding -->'
}

#-- Code -----------------------------------------------------------------------

$tweakdef_content = Get-Content -Path $base_dir\$tweakdef -Raw | Out-String

$encoding_content = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes([string] $tweakdef_content))
$encoding_content = $encoding_content.TrimEnd('=') -replace '\+', '-' -replace '/', '_'

Set-Content -Path $base_dir\$encoding -Value $encoding_content -NoNewline -Force -EA 0

# User-facing tweakdefs have unnecessary utility code removed.
$substitutions.GetEnumerator() | ForEach-Object {
    $tweakdef_content = $tweakdef_content -replace $_.Key, $_.Value
}

$friendly_content = $tweakdef_content

# The tweakdefs code is minified before encoding to be as small as possible.
if (-not (Get-Command luamin -EA 0)) {
    npm install -g luamin
}
$tweakdef_content = luamin -c $tweakdef_content

$minified_content = $tweakdef_content
Set-Content -Path $base_dir\$minified -Value $minified_content -NoNewline -Force -EA 0

$tweakdef_content = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes([string] $tweakdef_content))
$tweakdef_content = $tweakdef_content.TrimEnd('=') -replace '\+', '-' -replace '/', '_'

$min_code_content = $tweakdef_content

Set-Content -Path $base_dir\$min_code -Value $min_code_content -NoNewline -Force -EA 0

if (Test-Path $base_dir\$too_long) { Remove-Item $base_dir\$too_long -Force }
if ($min_code_content.Length -gt 16000) {
	Write-Warning -Message "Minified, encoded tweak ($min_code) is too long for online."
	Set-Content -Path $base_dir\$too_long -Value "$min_code is too long for online."
}

# The gist contains portions of all the previous in a markdown document.
$markdown = Get-Content -Path $base_dir\$template -Raw | Out-String

$markdown = [regex]::Replace($markdown, $inserts.tweakdefs, ('```lua', $friendly_content, '```' -join "`n"))
$markdown = [regex]::Replace($markdown, $inserts.encoding, ('>', $min_code_content -join ' '))

Set-Content -Path $base_dir\$git_gist -Value $markdown -NoNewline -Force -EA 0
