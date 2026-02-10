# Get format version parameter (required; this script only updates versioned folders like v2/)
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(2, 2147483647)]
    [int]$FormatVersion
)

$ErrorActionPreference = "Stop"

# Determine base path based on format version
$basePath = "v$FormatVersion"
$baseUrlPath = "v$FormatVersion/"

# Resolve repo root relative to this script so it works no matter the current working directory
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$basePathAbs = Join-Path $repoRoot $basePath

$manifestPath = Join-Path $basePathAbs "manifest.json"
$dataDir = Join-Path $basePathAbs "data"
$configDir = Join-Path $basePathAbs "config"

if (!(Test-Path $manifestPath)) { throw "manifest.json not found at $manifestPath" }
if (!(Test-Path $dataDir)) { throw "data directory not found at $dataDir" }
if (!(Test-Path $configDir)) { throw "config directory not found at $configDir" }

Write-Host "Updating manifest for format version $FormatVersion"
Write-Host "Working in: $basePathAbs"

# Load manifest
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

# Ensure csvData + files exists
if (-not $manifest.csvData) {
    $manifest | Add-Member -MemberType NoteProperty -Name csvData -Value ([pscustomobject]@{})
}
if (-not $manifest.csvData.files) {
    $manifest.csvData | Add-Member -MemberType NoteProperty -Name files -Value @{}
}

# Ensure config + files exists
if (-not $manifest.config) {
    $manifest | Add-Member -MemberType NoteProperty -Name config -Value ([pscustomobject]@{})
}
if (-not $manifest.config.files) {
    $manifest.config | Add-Member -MemberType NoteProperty -Name files -Value @{}
}

# Hash all data/*.txt into csvData.files
$dataFiles = Get-ChildItem $dataDir -Filter *.txt
$csvHashMap = @{}

foreach ($file in $dataFiles) {
    $hash = (Get-FileHash $file.FullName -Algorithm SHA256).Hash.ToLower()
    $csvHashMap[$file.Name] = "sha256:$hash"
    Write-Host "Hashed data/$($file.Name)"
}
$manifest.csvData.files = $csvHashMap

# Update csvData baseUrl to point to correct format folder
if (-not $manifest.csvData.baseUrl) {
    $manifest.csvData | Add-Member -MemberType NoteProperty -Name baseUrl -Value ""
}
$manifest.csvData.baseUrl = "https://nrpriore.github.io/tt2-raid-data/$baseUrlPath" + "data/"

# Hash all config/*.json into config.files
$configFiles = Get-ChildItem $configDir -Filter *.json
$configHashMap = @{}

foreach ($file in $configFiles) {
    $hash = (Get-FileHash $file.FullName -Algorithm SHA256).Hash.ToLower()
    $configHashMap[$file.Name] = "sha256:$hash"
    Write-Host "Hashed config/$($file.Name)"
}
$manifest.config.files = $configHashMap

# Update config baseUrl to point to correct format folder
if (-not $manifest.config.baseUrl) {
    $manifest.config | Add-Member -MemberType NoteProperty -Name baseUrl -Value ""
}
$manifest.config.baseUrl = "https://nrpriore.github.io/tt2-raid-data/$baseUrlPath" + "config/"

# Bump dataVersion with UTC date+time (minute precision)
$manifest.dataVersion = (Get-Date).ToUniversalTime().ToString("yyyy.MM.dd-HH.mm")

# Write manifest back
# Use jq for consistent formatting (matches zsh script behavior)
$jsonContent = $manifest | ConvertTo-Json -Depth 20
# Use temp file to avoid PowerShell pipe encoding issues
$tempFile = [System.IO.Path]::GetTempFileName()
try {
    # Write JSON to temp file (with newlines preserved)
    [System.IO.File]::WriteAllText($tempFile, $jsonContent, [System.Text.Encoding]::UTF8)
    # Format with jq - capture as array and join to preserve newlines
    $formatted = & jq . $tempFile | Out-String
    [System.IO.File]::WriteAllText($manifestPath, $formatted, [System.Text.Encoding]::UTF8)
} finally {
    Remove-Item $tempFile -ErrorAction SilentlyContinue
}

Write-Host "manifest.json updated successfully"
Write-Host ("dataVersion set to " + $manifest.dataVersion)
