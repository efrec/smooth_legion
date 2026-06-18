# Convert our bespoke tweakdef to a player-friendly version
# and then minify it and get its URL-safe base64 encoding

if (-not (Get-Command luamin -EA 0)) { npm install -g luamin }

#-- Config ---------------------------------------------------------------------

$lobbymsg = 'SMOOTH LEGION'
$base_dir = 'D:\vscode\proj\beyond-all-reason\smooth_legion'
$tweakdef = 'tweakdef.lua'
$encoding = 'tweakdef_encoding.txt'
$minified = 'tweakdef_minified.lua'
$min_code = 'tweakdef_minified_encoding.txt'
$too_long = 'tweakdef_minified_encoding_too_long.txt'
$template = 'template.md'
$git_gist = 'gist.md'
$git_repo = 'smooth_legion'

$substitutions = @{
	# Sets a lobby message for the tweak. It should be short but must be unique and descriptive enough:
	'(?sm)\A--[\s\S]+?(?=^local)'                                          = "--$lobbymsg`n"
	# Remove testing code used for Rapid Iteration Development (writing shit code and then running it):
	'(?sm)^-- Tests[\s\S]+?(?=^-- Initialize)'                             = ''
	'(?sm)^\s*no(?:unit|weapon|refdef)\([^\)]*\)\r\n'                      = ''
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

Set-Location -Path $base_dir # You're not in $PSScriptRoot, so mind yourself.

$tweakdef_content = Get-Content -Path $base_dir\$tweakdef -Raw | Out-String

# We use a base64 encoding with URL safety and trailing characters trimmed.
$encoding_content = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes([string] $tweakdef_content))
$encoding_content = $encoding_content.TrimEnd('=') -replace '\+', '-' -replace '/', '_'
Set-Content -Path $base_dir\$encoding -Value $encoding_content -NoNewline -Force -EA 0

# User-facing tweakdefs have unnecessary utility code removed.
$friendly_content = $tweakdef_content
$substitutions.GetEnumerator() | ForEach-Object {
	$friendly_content = $friendly_content -replace $_.Key, $_.Value
}

# The tweakdefs code is minified before encoding to be as small as possible.
$minified_content = luamin -c $friendly_content
Set-Content -Path $base_dir\$minified -Value $minified_content -NoNewline -Force -EA 0
$min_code_content = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes([string] $minified_content))
$min_code_content = $min_code_content.TrimEnd('=') -replace '\+', '-' -replace '/', '_'
Set-Content -Path $base_dir\$min_code -Value $min_code_content -NoNewline -Force -EA 0

# Be extremely loud about over-long encoded tweakdefs.
if (Test-Path $base_dir\$too_long) { Remove-Item $base_dir\$too_long -Force }
if ($min_code_content.Length -gt 16000) {
	Write-Warning -Message "Minified, encoded tweak ($min_code) is too long for online."
	Set-Content -Path $base_dir\$too_long -Value "$min_code is too long for online."
}
else { Out-Host -InputObject "Minified, encoded tweak is $($min_code_content.Length) characters." }

# The gist contains portions of code and encoded-code in a markdown document.
$markdown = Get-Content -Path $base_dir\$template -Raw | Out-String
$markdown = [regex]::Replace($markdown, $inserts.tweakdefs, ('```lua', $friendly_content, '```' -join "`n"))
$markdown = [regex]::Replace($markdown, $inserts.encoding, ('>', $min_code_content -join ' '))
Set-Content -Path $base_dir\$git_gist -Value $markdown -NoNewline -Force -EA 0

# Autosync to git requires that the tweak is even smaller in size than normal.
if ($git_repo -ieq (Split-Path -Leaf (git rev-parse --show-toplevel)) -and $min_code_content.Length -le 12000) {
	git add .
	git commit -m "$($min_code_content.Length) characters"
	git push origin main
}
