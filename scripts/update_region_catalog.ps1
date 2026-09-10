# Regenerate the bundled catalog from KMA's public Weather Nuri region selector.
# No credentials, user locations or weather API quota are used.
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskOutput = Join-Path $taskRoot 'weather_care_app/assets/data/kma_regions.json'
$taskEndpoint = 'https://www.weather.go.kr/w/rest/zone/dong.do'
$taskRows = [System.Collections.Generic.List[object]]::new()
$taskSeen = [System.Collections.Generic.HashSet[string]]::new()

function Get-RegionRows([string]$type, [string]$wide = '', [string]$city = '') {
    $uri = "${taskEndpoint}?type=${type}&wideCode=${wide}&cityCode=${city}&keyword=&keywordStart=&keywordEnd="
    $response = Invoke-WebRequest $uri -TimeoutSec 30
    $rows = $response.Content | ConvertFrom-Json
    if (-not $rows -or $rows -is [string]) { throw "Invalid region response: $type/$wide/$city" }
    return $rows
}
function Add-RegionRow($row, [string]$parent, [int]$level) {
    if ($row.code -notmatch '^\d{10}$' -or [string]::IsNullOrWhiteSpace($row.name) -or
        [int]$row.level -ne $level -or [int]$row.x -lt 1 -or [int]$row.x -gt 149 -or
        [int]$row.y -lt 1 -or [int]$row.y -gt 253) { throw "Invalid region: $($row.code)" }
    # The official list can reuse a code for distinct dong names/grids. Preserve
    # each row; code alone is not a safe selection identity (e.g. 2815555000).
    $identity = if ($level -lt 3) { $row.code } else { "$($row.code)|$($row.name)|$($row.x)|$($row.y)" }
    if (-not $taskSeen.Add($identity)) { throw "Duplicate region identity: $identity" }
    $taskRows.Add(@($row.code, $parent, $row.name, [int]$row.x, [int]$row.y))
}

$taskProvinces = @(Get-RegionRows 'WIDE')
foreach ($province in $taskProvinces) {
    Add-RegionRow $province '' 1
    $cities = @(Get-RegionRows 'CITY' $province.code)
    foreach ($city in $cities) {
        Add-RegionRow $city $province.code 2
        $dongs = @(Get-RegionRows 'DONG' $province.code $city.code)
        foreach ($dong in $dongs) { Add-RegionRow $dong $city.code 3 }
    }
    Write-Output "$($province.name): $($cities.Count) city/county/district entries"
}
if ($taskProvinces.Count -lt 16 -or $taskRows.Count -lt 3500) { throw 'Incomplete national catalog' }
$catalog = [ordered]@{
    source = '기상청 날씨누리 행정동 검색 지역·예보 격자 목록'
    sourceUrl = 'https://www.weather.go.kr/w/index.do'
    endpoint = $taskEndpoint
    retrievedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    columns = @('code', 'parentCode', 'name', 'nx', 'ny')
    regions = $taskRows.ToArray()
}
# Generated data, never hand-edit rows. Only replace the asset after a complete fetch.
New-Item -ItemType Directory -Force (Split-Path $taskOutput -Parent) | Out-Null
$catalog | ConvertTo-Json -Depth 5 -Compress | Set-Content -LiteralPath $taskOutput -Encoding utf8NoBOM
Write-Output "Saved $($taskRows.Count) regions to $taskOutput"
