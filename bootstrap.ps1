<#
.DESCRIPTION
    Wrapper for installing dependencies of a project
#>

# Load configuration from bootstrap.json or use default values
function Get-BootstrapConfig {
    $bootstrapConfig = @{
        python_package_manager        = "poetry"
        scoop_installer               = "https://raw.githubusercontent.com/avengineers/ScoopInstall/refs/tags/v1.1.0/install.ps1"
        scoop_installer_with_repo_arg = $false
        scoop_ignore_scoopfile        = $false
        scoop_config                  = @{
            autostash_on_conflict = "true"
            use_lessmsi           = "true"
            scoop_repo            = "https://github.com/avengineers/Scoop.git"
            scoop_branch          = "master"
        }
    }

    $bootstrapJsonPath = "bootstrap.json"
    if (Test-Path $bootstrapJsonPath) {
        $JsonString = Get-Content $bootstrapJsonPath | Out-String
        $custom_config = Convert-CustomObjectToHashtable -CustomObject (ConvertFrom-Json $JsonString)
        if ($custom_config.scoop_config) {
            $custom_config.scoop_config = Convert-CustomObjectToHashtable -CustomObject $custom_config.scoop_config
        }
        else {
            $custom_config.scoop_config = @{}
        }
    }

    # Merge the default and custom configuration
    if ($custom_config) {
        $custom_config.GetEnumerator() | ForEach-Object {
            # Handle nested configuration
            # Overwrite every key in the default configuration with the custom configuration if it exists
            if ($bootstrapConfig[$_.Key] -is [Hashtable] -and $_.Value -is [Hashtable]) {
                $hashtableValue = $_.Key
                $_.Value.GetEnumerator() | ForEach-Object {
                    $bootstrapConfig[$hashtableValue][$_.Key] = $_.Value
                }
            }
            else {
                $bootstrapConfig[$_.Key] = $_.Value
            }
        }
    }

    return $bootstrapConfig
}

function Get-PythonFromScoopManifest {
    param(
        [Parameter(Mandatory = $true)]
        [Hashtable]$Config
    )

    $result = [PSCustomObject]@{
        Name    = $null
        Version = $null
    }

    if ($Config.scoop_manifest -and $Config.scoop_manifest.apps) {
        $pythonApps = @($Config.scoop_manifest.apps | Where-Object { $_.Name -match '^python\d' })
        if ($pythonApps.Count -gt 1) {
            Write-Warning "Multiple Python apps found in scoop_manifest: $($pythonApps.Name -join ', '). Using the first one: '$($pythonApps[0].Name)'."
        }
        if ($pythonApps.Count -ge 1) {
            $result.Name = $pythonApps[0].Name
            # Extract python version: prefer explicit Version key, otherwise derive from app name
            if ($pythonApps[0].Version) {
                $result.Version = $pythonApps[0].Version
            }
            elseif ($pythonApps[0].Name -match '^python(\d)(\d+)$') {
                $result.Version = "$($Matches[1]).$($Matches[2])"
            }
            elseif ($pythonApps[0].Name -match '^python(\d)$') {
                $result.Version = $Matches[1]
            }
        }
    }

    return $result
}

function Install-Scoop {
    if (-Not (Get-Command 'scoop' -ErrorAction SilentlyContinue)) {
        $tempDir = [System.IO.Path]::GetTempPath()
        $tempFile = Join-Path $tempDir "install.ps1"
        Invoke-RestMethod -Uri $config.scoop_installer -OutFile $tempFile
        $installCmd = @("$tempFile")
        if ($config.scoop_installer_with_repo_arg) {
            $installCmd += "-ScoopAppRepoGit"
            $installCmd += $config.scoop_config.scoop_repo
        }
        if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            $installCmd += "-RunAsAdmin"
        }
        Invoke-CommandLine "& $($installCmd)"
        Remove-Item $tempFile
        Initialize-EnvPath
    }

    Write-Output "Applying scoop configuration"
    foreach ($item in $config.scoop_config.GetEnumerator()) {
        Invoke-CommandLine ("scoop config " + $item.Key + " " + $item.Value) -Silent $true -PrintCommand $false
    }

    # Install scoop dependencies from scoop_manifest (mandatory in bootstrap.json).
    # CAUTION: the order of apps in scoop_manifest is important and shall not be changed!
    # E.g. 7zip needs lessmsi, innounp needs 7zip.
    if (-Not $config.scoop_manifest) {
        Write-Error "scoop_manifest is required in bootstrap.json. Please define your scoop dependencies there."
    }
    $tempScoopFile = Join-Path ([System.IO.Path]::GetTempPath()) "bootstrap-scoopfile.json"
    try {
        $config.scoop_manifest | ConvertTo-Json -Depth 3 | Set-Content -Path $tempScoopFile -Encoding UTF8
        Import-ScoopFile -ScoopFilePath $tempScoopFile
    }
    finally {
        Remove-Item -Path $tempScoopFile -Force -ErrorAction SilentlyContinue
    }
    Initialize-EnvPath

    # Import scoopfile.json
    if ((-Not $config.scoop_ignore_scoopfile) -and (Test-Path -Path 'scoopfile.json')) {
        Write-Output "File 'scoopfile.json' found, installing ..."

        Import-ScoopFile -ScoopFilePath 'scoopfile.json'

        Initialize-EnvPath
    }
}

# Prepare virtual Python environment
function Install-PythonEnvironment {
    if (-Not $python) {
        Write-Output "No Python app found in scoop_manifest. Skipping Python environment setup."
        return
    }
    if ((Test-Path -Path 'pyproject.toml') -or (Test-Path -Path 'Pipfile')) {
        if ($clean) {
            # Start with a fresh virtual environment
            Remove-Path '.venv'
        }
        New-Directory '.venv'
        $bootstrapPy = Join-Path $PSScriptRoot "bootstrap.py"
        $bootstrapArgs = "$python $bootstrapPy"
        if ($pythonVersion) {
            $bootstrapArgs += " --python-version $pythonVersion"
        }
        Invoke-CommandLine $bootstrapArgs
    }
    else {
        Write-Output "No Python config file found, skipping Python setup."
    }
}

# Main function needed for testing (will be mocked)
function Main {
    Install-Scoop
    Install-PythonEnvironment
}

## start of script

# Always set the $InformationPreference variable to "Continue" globally,
# this way it gets printed on execution and continues execution afterwards.
$InformationPreference = "Continue"

# Stop on first error
$ErrorActionPreference = "Stop"

# Load functions from utils.ps1 and scoop-utils.ps1
. "$PSScriptRoot\utils.ps1"
. "$PSScriptRoot\scoop-utils.ps1"

# Load config
$config = Get-BootstrapConfig

# Determine python executable name and version from scoop_manifest apps.
$pythonInfo = Get-PythonFromScoopManifest -Config $config
$python = $pythonInfo.Name
$pythonVersion = $pythonInfo.Version

if ($python) {
    Write-Output "Python executable: $python"
}
if ($pythonVersion) {
    Write-Output "Python version: $pythonVersion"
}

Main

## end of script
