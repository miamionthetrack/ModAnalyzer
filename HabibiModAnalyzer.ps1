Write-Host "Habibi Mod Analyzer" -ForegroundColor Yellow
Write-Host "Made by " -ForegroundColor DarkGray -NoNewline
Write-Host "HadronCollision" -ForegroundColor DarkRed
Write-Host ""

Write-Host "Enter path to mods folder: " -ForegroundColor DarkYellow -NoNewline
Write-Host "(press enter for default)" -ForegroundColor DarkGray
$mods = Read-Host "Path"
Write-Host ""

if (-not $mods) {
    $mods = Join-Path -Path $env:APPDATA -ChildPath ".minecraft\mods"
	Write-Host "Press enter to continue with " -ForegroundColor DarkYellow -NoNewline
	Write-Host $mods -ForegroundColor DarkGray
	Read-Host
}

function Get-FileHashSHA1 {
    param (
        [string]$filePath
    )
    $hashAlgorithm = [System.Security.Cryptography.SHA1]::Create()
    $fileStream = [System.IO.File]::OpenRead($filePath)
    try {
        $hashBytes = $hashAlgorithm.ComputeHash($fileStream)
    } finally {
        $fileStream.Close()
    }
    $hash = [BitConverter]::ToString($hashBytes).Replace("-", "")
    return $hash
}

function Fetch-ModrinthData {
    param (
        [string]$hash
    )
    $modrinthApiUrl = "https://api.modrinth.com/v2/version_file/$hash"
    try {
        $response = Invoke-WebRequest -Uri $modrinthApiUrl -Method Get -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $projectId = (ConvertFrom-Json $response.Content).project_id
            $projectResponse = Invoke-WebRequest -Uri "https://api.modrinth.com/v2/project/$projectId" -Method Get -ErrorAction Stop
            if ($projectResponse.StatusCode -eq 200) {
                $projectData = ConvertFrom-Json $projectResponse.Content
                return @{ Name = $projectData.title; Slug = $projectData.slug }
            }
        }
    } catch {
        Write-Host "Unknown Mod" -ForegroundColor Red
    }
    return @{ Name = ""; Slug = "" }
}

if (-not (Test-Path $mods -PathType Container)) {
    Write-Host "Invalid Path." -ForegroundColor Red
    exit 1
}

$fileNames = @()
$modrinthNames = @()
$modrinthLinks = @()
$unknownMods = @()

Get-ChildItem -Path $mods -Filter *.jar | ForEach-Object {
    $file = $_
    $hash = Get-FileHashSHA1 -filePath $file.FullName
    $modData = Fetch-ModrinthData -hash $hash

    $fileNames += $file.Name
    $modrinthNames += $modData.Name
    $modrinthLinks += if ($modData.Slug -ne "") { "https://modrinth.com/mod/$($modData.Slug)" } else { "" }

    Write-Host "FileName: $($file.Name)" -ForegroundColor DarkCyan
    if ($modData.Slug -ne "") {
		Write-Host "Modrinth: $($modData.Name)" -ForegroundColor Green
        Write-Host "Link: https://modrinth.com/mod/$($modData.Slug)" -ForegroundColor DarkGray
    } else {
		$unknownMods += $file.Name
	}
    Write-Host "----------"
}

if ($unknownMods.Count -gt 0) {
    Write-Host ""
    Write-Host "Unknown Mods:" -ForegroundColor Yellow
    $unknownMods | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
}
