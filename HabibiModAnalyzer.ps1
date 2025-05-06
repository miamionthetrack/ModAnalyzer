Clear-Host
Write-Host "Habibi Mod Analyzer" -ForegroundColor Yellow
Write-Host "Made by " -ForegroundColor DarkGray -NoNewline
Write-Host "HadronCollision & Miami"
Write-Host ""

Write-Host "Enter path to mods folder: " -ForegroundColor DarkYellow -NoNewline
Write-Host "(Press enter for default)" -ForegroundColor DarkGray
$mods = Read-Host "Path"
Write-Host ""

if (-not $mods) {
    $mods = "$env:USERPROFILE\AppData\Roaming\.minecraft\mods"
    Write-Host "Press enter to continue with " -ForegroundColor DarkYellow -NoNewline
    Write-Host $mods -ForegroundColor DarkGray
    Read-Host
}

if (-not (Test-Path $mods -PathType Container)) {
    Write-Host "Invalid Path." -ForegroundColor Red
    exit 1
}

$process = Get-Process javaw -ErrorAction SilentlyContinue

if ($process) {
    $startTime = $process.StartTime
    $elapsedTime = (Get-Date) - $startTime

    Write-Host "Minecraft (javaw.exe) Process ID: $($process.Id)" -ForegroundColor DarkYellow
    Write-Host "Started at: $startTime"
    Write-Host "Running for: $($elapsedTime.Hours)h $($elapsedTime.Minutes)m $($elapsedTime.Seconds)s"
    Write-Host ""
}

$bannedMods = @(
    @{ name = "Wurst Client"; value = "- wurst" },
    @{ name = "Meteor Client"; value = "- meteor-client" },
    @{ name = "Doomsday Client"; value = "- dd" },
    @{ name = "Prestige Client"; value = "- prestige" },
    @{ name = "Inertia Client"; value = "- inertia" },
    @{ name = "Thunder Hack"; value = "- thunderhack" },
    @{ name = "Walksy Optimizer"; value = "- walksycrystaloptimizer" },
    @{ name = "Walksy Shield Statuses"; value = "- shieldstatus" },
    @{ name = "Accurate Block Placement"; value = "- accurateblockplacement" },
    @{ name = "Elytra Chest Swapper"; value = "- ecs" },
    @{ name = "Click Crystals"; value = "- clickcrystals" },
    @{ name = "Fast Crystal"; value = "- fastcrystal" },
    @{ name = "Auto Totem"; value = "- autototem" },
    @{ name = "Item Scroller"; value = "- itemscroller" },
    @{ name = "Tweakeroo"; value = "- tweakeroo" },
    @{ name = "Mouse Tweaks"; value = "- mousetweaks" },
    @{ name = "Freecam"; value = "- freecam" },
    @{ name = "Xaero's Minimap"; value = "- xaerominimap" },
    @{ name = "HitRange"; value = "- hitrange" }
)

$cheatStrings = @(
    @{ name = "AimAssist"; value = "AimAssist" },
    @{ name = "AnchorTweaks"; value = "AnchorTweaks" },
    @{ name = "AutoAnchor"; value = "AutoAnchor" },
    @{ name = "AutoCrystal"; value = "AutoCrystal" },
    @{ name = "AutoDoubleHand"; value = "AutoDoubleHand" },
    @{ name = "AutoHitCrystal"; value = "AutoHitCrystal" },
    @{ name = "AutoPot"; value = "AutoPot" },
    @{ name = "AutoTotem"; value = "AutoTotem" },
    @{ name = "InventoryTotem"; value = "InventoryTotem" },
    @{ name = "Hitboxes"; value = "Hitboxes" },
    @{ name = "JumpReset"; value = "JumpReset" },
    @{ name = "LegitTotem"; value = "LegitTotem" },
    @{ name = "PingSpoof"; value = "PingSpoof" },
    @{ name = "Reach"; value = "Reach" },
    @{ name = "SelfDestruct"; value = "SelfDestruct" },
    @{ name = "ShieldBreaker"; value = "ShieldBreaker" },
    @{ name = "TriggerBot"; value = "TriggerBot" },
    @{ name = "Velocity"; value = "Velocity" },
    @{ name = "Argon"; value = "Argon" },
    @{ name = "Asteria"; value = "AsteriaSettingsModule" },
    @{ name = "VirginClient"; value = "Virgin.class" },
    @{ name = "ModuleManager"; value = "ModuleManager.class" },
    @{ name = "Francium AutoDoublehand"; value = "ADH.class" }
)

function Get-FileHashSHA1 {
    param ([string]$filePath)
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

function Get-AdsUrl {
    param ([string]$filePath)
    $ads = Get-Content -Stream Zone.Identifier $filePath -ErrorAction SilentlyContinue -Raw
    if ($ads -match "HostUrl=(.+)") {
        return $matches[1]
    }
    return $null
}

function Check-Strings {
    param (
        [string]$filePath,
        [hashtable[]]$stringList
    )
    $fileContent = Get-Content $filePath
    $stringsFound = New-Object System.Collections.Generic.HashSet[System.String]
    foreach ($line in $fileContent) {
        foreach ($string in $stringList) {
            if ($line -match $string.value) {
                $stringsFound.Add($string.name) | Out-Null
                break
            }
        }
    }
    return $stringsFound
}

function Fetch-ModrinthData {
    param ([string]$hash)
    $modrinthApiUrl = "https://api.modrinth.com/v2/version_file/$hash"
    try {
        $response = Invoke-RestMethod -Uri $modrinthApiUrl -Method Get -ErrorAction Stop
        if ($response.project_id) {
            $projectResponse = "https://api.modrinth.com/v2/project/$($response.project_id)"
            $projectData = Invoke-RestMethod -Uri $projectResponse -Method Get -ErrorAction Stop
            return @{ Name = $projectData.title; Slug = $projectData.slug }
        }
    } catch {}
    return @{ Name = ""; Slug = "" }
}

Add-Type -AssemblyName "System.IO.Compression.FileSystem"

function Scan-NestedJars {
    param ($mod)

    $modData = Fetch-ModrinthData -hash (Get-FileHashSHA1 -filePath $mod.FullName)
    if ($modData.Slug -ne "") {
        Write-Host "Mod is verified via Modrinth. Skipping nested JAR check." -ForegroundColor Green
        return
    }

    $nestedDir = "$env:TEMP\modchecker"
    if (Test-Path $nestedDir) { Remove-Item $nestedDir -Recurse -Force }
    New-Item -ItemType Directory -Path $nestedDir | Out-Null

    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($mod.FullName, $nestedDir)
    } catch {
        Write-Host "Error extracting JAR file: $($mod.FullName)" -ForegroundColor Red
        Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    $metaInfPath = Join-Path $nestedDir "META-INF\jars"
    if (-not (Test-Path $metaInfPath)) {
        Write-Host "No META-INF/jars folder found in $($mod.Name), skipping nested JAR check." -ForegroundColor Yellow
        return
    }

    $nestedJars = Get-ChildItem -Path $metaInfPath -Recurse -Filter *.jar
    foreach ($nestedJar in $nestedJars) {
        Write-Host "Scanning nested JAR: $($nestedJar.FullName)" -ForegroundColor DarkGray
        $nestedHash = Get-FileHashSHA1 -filePath $nestedJar.FullName
        $nestedModData = Fetch-ModrinthData -hash $nestedHash

        if ($nestedModData.Slug -ne "") {
            Write-Host "Nested FileName: $($nestedJar.Name)" -ForegroundColor DarkCyan
            Write-Host "Modrinth: $($nestedModData.Name)" -ForegroundColor Green
            Write-Host "Link: https://modrinth.com/mod/$($nestedModData.Slug)" -ForegroundColor DarkGray
            continue
        }

        $nestedStrings = Check-Strings -filePath $nestedJar.FullName -stringList $cheatStrings
        foreach ($str in $nestedStrings) {
            Write-Host "Found cheat string: $($str) in nested JAR: $($nestedJar.FullName)" -ForegroundColor Red
        }
    }

    Remove-Item -Path $nestedDir -Recurse -Force -ErrorAction SilentlyContinue
}


$unknownMods = @()

Get-ChildItem -Path $mods -Filter *.jar | ForEach-Object {
    $file = $_
    $hash = Get-FileHashSHA1 -filePath $file.FullName
    $modData = Fetch-ModrinthData -hash $hash

    if ($modData.Slug -ne "") {
        Write-Host "FileName: $($file.Name)" -ForegroundColor DarkCyan
        Write-Host "Modrinth: $($modData.Name)" -ForegroundColor Green
        Write-Host "Link: https://modrinth.com/mod/$($modData.Slug)" -ForegroundColor DarkGray
    } else {
        $url = Get-AdsUrl $file.FullName
        Write-Host "Unknown Mod" -ForegroundColor Red
        Write-Host "FileName: $($file.Name)" -ForegroundColor DarkCyan
        if ($url) {
            Write-Host "Link: $url" -ForegroundColor DarkGray
        }
        $unknownMods += $file
    }

    Scan-NestedJars -mod $file
    Write-Host "----------"
}

if ($unknownMods.Name.Count -gt 0) {
    Write-Host ""
    Write-Host "Suspicious mods:" -ForegroundColor Yellow
    $unknownMods.Name | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
}

$logPath = "$env:USERPROFILE\AppData\Roaming\.minecraft\logs\latest.log"

if (Test-Path $logPath) {
    $logMods = Check-Strings -filePath $logPath -stringList $bannedMods
    if ($logMods.Count -gt 0) {
        Write-Host ""
        Write-Host "Possibly bannable mods in /.minecraft/logs/latest.log:" -ForegroundColor Yellow
        $logMods | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    }
}

$foundStrings = @()

foreach ($mod in $unknownMods) {
    $result = Check-Strings -filePath $mod.FullName -stringList $cheatStrings
    foreach ($str in $result) {
        $foundStrings += [PSCustomObject]@{
            Cheat = $str
            Mod   = $mod.Name
        }
    }
}

if ($foundStrings.Count -gt 0) {
    Write-Host ""
    Write-Host "Found cheat strings:" -ForegroundColor Yellow
    foreach ($entry in $foundStrings) {
        Write-Host "Found " -NoNewline
        Write-Host "$($entry.Cheat)" -ForegroundColor Yellow -NoNewline
        Write-Host " in " -NoNewline
        Write-Host "$($entry.Mod)" -ForegroundColor Red
    }
}

Write-Host ""
