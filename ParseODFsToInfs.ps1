# Prompt the user to choose which files to create
$makeInf = Read-Host "Make INF? (y/n)" -eq 'y'
$makeDes = Read-Host "Make DES? (y/n)" -eq 'y'
$makeVxt = Read-Host "Make VXT? (y/n)" -eq 'y'

# Specify the root directory to search for .odf files
$rootDirectory = "C:\scripts"

# Specify the output directory for .inf and .des files
$outputDirectory = "C:\scripts"

# Hash table to map parameter names to display names
$displayNameMapping = @{
    'ScrapValue' = 'Scrap Value'
    'ScrapCost'  = 'Scrap Cost'
    'BuildTime'  = 'Time to Build'
    'MaxHealth'  = 'Hull'
    'MaxAmmo'    = 'Ammo'
    'RangeScan'  = 'Radar Range'
}

# List of parameters to extract
$parametersToExtract = $displayNameMapping.Keys

# Recursive search for .odf files and process each one
Get-ChildItem -Path $rootDirectory -Filter *.odf -File -Recurse | ForEach-Object {
    $filePath = $_.FullName
    $fileName = $_.BaseName
    $outputInfPath = Join-Path -Path $outputDirectory -ChildPath "$fileName.inf"
    $outputDesPath = Join-Path -Path $outputDirectory -ChildPath "$fileName.des"
    $outputVxtPath = Join-Path -Path $outputDirectory -ChildPath "$fileName.vxt"

    # Read the content of the .odf file with UTF-8 encoding
    $fileContent = Get-Content -Path $filePath -Raw -Encoding UTF8

    # Check if the file contains the [HoverCraftClass] header
    if ($fileContent -notmatch '\[CraftClass\]') {
        Write-Host "Skipping '$filename' [CraftClass] header not found"
        return
    }

    # Check if the output files already exist
    $filesExist = (Test-Path $outputInfPath) -or (Test-Path $outputDesPath) -or (Test-Path $outputVxtPath)

    if ($filesExist) {
        $confirmation = Read-Host "Files already exist for '$fileName'. Do you want to overwrite them? (y/n)"
        if ($confirmation -ne 'y') {
            Write-Host "Operation canceled for '$fileName'."
            return
        }
    }

    # Initialize an empty array to store parameter values
    $parameterValues = @()

    # Extract unitName
    $unitNamePattern = "unitName\s*=\s*""([^""]+)"""
    $unitNameMatch = $fileContent -match $unitNamePattern

    if ($unitNameMatch) {
        $unitName = $matches[1]
    }
    else {
        $unitName = "UnitNameNotFound"
    }

    # Loop through each specified parameter and extract its value
    foreach ($parameter in $parametersToExtract) {
        $pattern = "$parameter\s*=\s*([\d.]+)"
        $match = $fileContent -match $pattern

        if ($match) {
            $displayName = $displayNameMapping[$parameter]
            $parameterValues += "$displayName = $($matches[1])"
        }
        else {
            $parameterValues += "$parameter not found"
        }
    }

    # Sort parameter values alphabetically, excluding unitName
    $sortedParameterValues = $parameterValues | Where-Object {$_ -notmatch 'Unit Name'} | Sort-Object

    # Output static values, line breaks, unitName, sorted matched parameters and values, and "Built By = " to .inf file
    if ($makeInf) {
        ("$unitName`r`n[Unit Description]`r`n`r`n$unitName`r`n" + ($sortedParameterValues -join "`r`n") + "`r`nBuilt By = ") | Out-File -FilePath $outputInfPath -Encoding UTF8
        Write-Host "Processed: $outputInfPath"
    }

    # Copy .inf content to .des
    if ($makeDes) {
        Copy-Item -Path $outputInfPath -Destination $outputDesPath -Force
        Write-Host "Processed: $outputDesPath"
    }

    # Output VXT content
    if ($makeVxt) {
        "$fileName $fileName.des x $unitName" | Out-File -FilePath $outputVxtPath -Encoding UTF8
        Write-Host "Processed: $outputVxtPath"
    }
}
