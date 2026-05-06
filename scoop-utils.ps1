<#
.DESCRIPTION
    Scoop package manager utilities for bootstrap.
    Provides functions for parsing scoop manifests, querying installed app state,
    and importing scoopfile definitions (buckets + apps).
#>

# Load shared utilities (Invoke-CommandLine, etc.)
. "$PSScriptRoot\utils.ps1"

function Convert-ScoopFileJsonToHashTable {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ScoopFileJson
    )

    $return = @{
        "buckets" = @();
        "apps"    = @() 
    }

    $scoopFileData = ConvertFrom-Json -InputObject $ScoopFileJson

    if ($scoopFileData.buckets -is [System.Collections.IEnumerable]) {
        foreach ($bucket in $scoopFileData.buckets) {
            $return.buckets += @{
                "Name"   = $bucket.Name
                "Source" = $bucket.Source
            }
        }
    }

    if ($scoopFileData.apps -is [System.Collections.IEnumerable]) {
        foreach ($app in $scoopFileData.apps) {
            $return.apps += @{
                "Name"       = $app.Name
                "Source"     = $app.Source
                "Version"    = $app.Version
                "Identifier" = if ($app.Version) { "$($app.Source)/$($app.Name)@$($app.Version)" } else { "$($app.Source)/$($app.Name)" }
            }
        }
    }

    return $return
}

<#
.DESCRIPTION
    Retrieve the installed bucket and version of a Scoop app by inspecting its local metadata files.
.PARAMETER AppName
    The name of the Scoop app to look up.
#>
function Get-ScoopAppInstallInfo {
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName
    )

    $scoopDir = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE "scoop" }
    $appBaseDir = Join-Path $scoopDir "apps\$AppName"
    $appDir = Join-Path $appBaseDir "current"

    # Fallback: if 'current' junction is broken/missing, find the highest version directory
    if (-not (Test-Path $appDir)) {
        if (Test-Path $appBaseDir) {
            $versionDir = Get-ChildItem -Path $appBaseDir -Directory | Where-Object { $_.Name -ne 'current' } | Sort-Object { [System.Version]$_.Name } -Descending | Select-Object -First 1
            if ($versionDir) {
                $appDir = $versionDir.FullName
            }
            else {
                return $null
            }
        }
        else {
            return $null
        }
    }

    $result = @{}

    $installJsonPath = Join-Path $appDir "install.json"
    if (Test-Path $installJsonPath) {
        $installData = Get-Content $installJsonPath -Raw | ConvertFrom-Json
        $result.bucket = $installData.bucket
    }

    $manifestJsonPath = Join-Path $appDir "manifest.json"
    if (Test-Path $manifestJsonPath) {
        $manifestData = Get-Content $manifestJsonPath -Raw | ConvertFrom-Json
        $result.version = $manifestData.version
    }

    return $result
}

<#
.DESCRIPTION
    Install a single Scoop app with pre-install checks, post-install verification,
    and automatic retry on failure.
.PARAMETER App
    Hashtable with keys: Name, Source, Version, Identifier.
#>
function Install-ScoopAppWithRetry {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$App
    )

    try {
        # Pre-install: detect zombie state (base dir exists but no valid installation)
        $scoopDir = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE "scoop" }
        $appBaseDir = Join-Path $scoopDir "apps\$($App.Name)"
        $preInstallInfo = Get-ScoopAppInstallInfo -AppName $App.Name

        if ((Test-Path $appBaseDir) -and (-not $preInstallInfo)) {
            Write-Warning "Zombie state detected for '$($App.Name)': directory exists but app is not properly installed. Purging."
            Invoke-CommandLine "scoop uninstall $($App.Name) --purge" -StopAtError $false
        }
        # Pre-install: detect bucket or version mismatch with previously installed version
        elseif ($preInstallInfo -and (
                ($App.Source -and $preInstallInfo.bucket -and $preInstallInfo.bucket -ne $App.Source) -or
                ($App.Version -and $preInstallInfo.version -and $preInstallInfo.version -ne $App.Version)
            )) {
            Write-Warning "App '$($App.Name)' installed (bucket='$($preInstallInfo.bucket)', version='$($preInstallInfo.version)') does not match config (bucket='$($App.Source)', version='$($App.Version)'). Uninstalling to reinstall."
            Invoke-CommandLine "scoop uninstall $($App.Name) --purge" -StopAtError $false
        }

        Invoke-CommandLine "scoop install $($App.Identifier)" -StopAtError $false

        # Post-install: verify the app was actually installed
        $postInstallInfo = Get-ScoopAppInstallInfo -AppName $App.Name
        if (-not $postInstallInfo) {
            Write-Error "Failed to install '$($App.Name)'. App directory does not exist after installation."
            return
        }

        # Post-install: verify bucket matches requested source - if not, purge and reinstall
        if ($App.Source -and $postInstallInfo.bucket -and $postInstallInfo.bucket -ne $App.Source) {
            Write-Warning "App '$($App.Name)' was installed from bucket '$($postInstallInfo.bucket)' instead of '$($App.Source)'. Purging and reinstalling."
            Invoke-CommandLine "scoop uninstall $($App.Name) --purge" -StopAtError $false
            Invoke-CommandLine "scoop install $($App.Identifier)" -StopAtError $false

            $postInstallInfo = Get-ScoopAppInstallInfo -AppName $App.Name
            if (-not $postInstallInfo) {
                Write-Error "Failed to reinstall '$($App.Name)' from bucket '$($App.Source)'."
                return
            }
            if ($postInstallInfo.bucket -ne $App.Source) {
                Write-Warning "App '$($App.Name)' still resolves from bucket '$($postInstallInfo.bucket)' instead of '$($App.Source)' after reinstall."
            }
        }

        # Post-install: verify version matches what was requested
        if ($App.Version -and $postInstallInfo.version -and $postInstallInfo.version -ne $App.Version) {
            Write-Warning "Version mismatch for '$($App.Name)': bootstrap.json specifies '$($App.Version)' but '$($postInstallInfo.version)' is installed."
        }

        # TODO: Replace this by some scoop env mechanism in the .venv directory
        Invoke-CommandLine "scoop reset $($App.Identifier)" -StopAtError $false
    }
    catch {
        # Retry once after purge on terminating errors (e.g. "Cannot create a file when that file already exists")
        Write-Warning "Install of '$($App.Name)' failed: $_. Attempting cleanup and retry."
        try {
            Invoke-CommandLine "scoop uninstall $($App.Name) --purge" -StopAtError $false
            Invoke-CommandLine "scoop install $($App.Identifier)" -StopAtError $false

            $retryInfo = Get-ScoopAppInstallInfo -AppName $App.Name
            if ($retryInfo) {
                Invoke-CommandLine "scoop reset $($App.Identifier)" -StopAtError $false
            }
            else {
                Write-Warning "Failed to process app '$($App.Name)' after retry."
            }
        }
        catch {
            Write-Warning "Failed to process app '$($App.Name)' after retry: $_"
        }
    }
}

function Import-ScoopFile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ScoopFilePath
    )

    $scoopFileData = Convert-ScoopFileJsonToHashTable -ScoopFileJson (Get-Content -Path $ScoopFilePath -Raw)

    # Add the buckets
    $scoopFileData.buckets | ForEach-Object {
        $bucket = $_
        Write-Output "Processing bucket: $($bucket.Name)"
        # We try to add each bucket, even if it already exists (we ignore any error here)
        Invoke-CommandLine "scoop bucket add $($bucket.Name) $($bucket.Source)" -StopAtError $false
    }

    # Update buckets only if there are any buckets or apps to process
    if ($scoopFileData.buckets.Count -gt 0 -or $scoopFileData.apps.Count -gt 0) {
        Invoke-CommandLine "scoop update"
    }

    # Install the apps
    $scoopFileData.apps | ForEach-Object {
        $app = $_
        Write-Output "Processing app: $($app.Name)"
        Install-ScoopAppWithRetry -App $app
    }
}
