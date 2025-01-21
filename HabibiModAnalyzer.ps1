param (
    [string]$modsFolder
)

# Function to calculate SHA-1 hash
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
    $hash = [BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()
    return $hash
}

# Function to fetch Modrinth data
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
    return @{ Name = "Unknown mod"; Slug = "" }
}

if (-not (Test-Path $modsFolder -PathType Container)) {
    Write-Host "The provided path is not a directory!" -ForegroundColor Red
    exit 1
}

$fileNames = @()
$modrinthNames = @()
$modrinthLinks = @()

Get-ChildItem -Path $modsFolder -Filter *.jar | ForEach-Object {
    $file = $_
    $hash = Get-FileHashSHA1 -filePath $file.FullName
    $modData = Fetch-ModrinthData -hash $hash

    # Append the data to the arrays
    $fileNames += $file.Name
    $modrinthNames += $modData.Name
    $modrinthLinks += if ($modData.Slug -ne "") { "https://modrinth.com/mod/$($modData.Slug)" } else { "" }

    # Log the data to the console
    Write-Host "FileName: $($file.Name)" -ForegroundColor Cyan
    if ($modData.Slug -ne "") {
		Write-Host "Modrinth: $($modData.Name)" -ForegroundColor Yellow
        Write-Host "Link: https://modrinth.com/mod/$($modData.Slug)" -ForegroundColor Green
    }
    Write-Host "----------"
}

# Prepare the JSON object
$jsonObject = [PSCustomObject]@{
    FileNames = $fileNames
    ModrinthNames = $modrinthNames
    ModrinthLinks = $modrinthLinks
}

# Write the JSON object to a file
try {
    $jsonOutput = $jsonObject | ConvertTo-Json -Depth 3
    Set-Content -Path "index.json" -Value $jsonOutput -Force
    Write-Host "JSON data written to 'index.json'." -ForegroundColor Green
} catch {
    Write-Host "Failed to write JSON data to file. Error: $_" -ForegroundColor Red
}
