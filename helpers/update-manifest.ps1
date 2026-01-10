$ErrorActionPreference = "Stop"

$manifestPath = "manifest.json"
$dataDir = "data"
$configDir = "config"

if (!(Test-Path $manifestPath)) { throw "manifest.json not found" }
if (!(Test-Path $dataDir)) { throw "data directory not found" }
if (!(Test-Path $configDir)) { throw "config directory not found" }

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

# Hash all config/*.json into config.files
$configFiles = Get-ChildItem $configDir -Filter *.json
$configHashMap = @{}

foreach ($file in $configFiles) {
    $hash = (Get-FileHash $file.FullName -Algorithm SHA256).Hash.ToLower()
    $configHashMap[$file.Name] = "sha256:$hash"
    Write-Host "Hashed config/$($file.Name)"
}
$manifest.config.files = $configHashMap

# Bump dataVersion with UTC date+time (minute precision)
$manifest.dataVersion = (Get-Date).ToUniversalTime().ToString("yyyy.MM.dd-HH.mm")

# Write manifest back
$manifest | ConvertTo-Json -Depth 20 | Out-File $manifestPath -Encoding utf8

Write-Host "manifest.json updated successfully"
Write-Host ("dataVersion set to " + $manifest.dataVersion)
