<#
.DESCRIPTION
    Wrapper for installing dependencies of a project
#>

# Load configuration from bootstrap.json or use default values
function Get-BootstrapConfig {
    $bootstrapConfig = @{
        python_version                = "3.11"
        python_package_manager        = "poetry"
        scoop_installer               = "https://raw.githubusercontent.com/avengineers/ScoopInstall/refs/tags/v1.1.0/install.ps1"
        scoop_installer_with_repo_arg = $false
        scoop_default_bucket_base_url = "https://raw.githubusercontent.com/ScoopInstaller/Main/master/bucket"
        scoop_python_bucket_base_url  = "https://raw.githubusercontent.com/ScoopInstaller/Versions/master/bucket"
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

    # Install any installer dependencies
    # CAUTION: the order is important and shall not be changed!
    # - 7zip needs lessmsi for installation
    # - innounp needs 7zip
    $manifests = @(
        "lessmsi.json",
        "7zip.json",
        "innounp.json",
        "dark.json"
    )
    $manifests | ForEach-Object {
        Invoke-CommandLine "scoop install $($config.scoop_default_bucket_base_url)/$_" -Silent $true -PrintCommand $false
    }

    # Import scoopfile.json
    if ((-Not $config.scoop_ignore_scoopfile) -and (Test-Path -Path 'scoopfile.json')) {
        Write-Output "File 'scoopfile.json' found, installing ..."

        Import-ScoopFile -ScoopFilePath 'scoopfile.json'

        Initialize-EnvPath
    }
}

# Prepare virtual Python environment
function Install-PythonEnvironment {
    if ((Test-Path -Path 'pyproject.toml') -or (Test-Path -Path 'Pipfile')) {
        if ($clean) {
            # Start with a fresh virtual environment
            Remove-Path '.venv'
        }
        New-Directory '.venv'
        $bootstrapPy = Join-Path $PSScriptRoot "bootstrap.py"
        Invoke-CommandLine "$python $bootstrapPy"
    }
    else {
        Write-Output "No Python config file found, skipping Python setup."
    }
}

function Install-Python {
    # Check if python is installed
    $pythonPath = (Get-Command $python -ErrorAction SilentlyContinue).Source
    if ($null -eq $pythonPath) {
        Write-Output "$python not found. Try to install $python via scoop ..."
        # Install python
        Invoke-CommandLine "scoop install $($config.scoop_python_bucket_base_url)/$python.json"

        Initialize-EnvPath
    }
    else {
        Write-Output "$python found in $pythonPath, skipping installation."
    }
}

function Get-PythonExecutableName {
    param (
        [string]$pythonVersion
    )

    # Split the version and handle varying segment lengths
    $version_parts = $pythonVersion.Split(".")
    $major_minor_version = $version_parts[0]  # Always include the major version

    # Append the minor version if it exists
    if ($version_parts.Count -ge 2) {
        $major_minor_version += $version_parts[1]
    }

    return "python" + $major_minor_version
}

# Main function needed for testing (will be mocked)
function Main {
    Install-Scoop
    Install-Python
    Install-PythonEnvironment
}

## start of script

# Always set the $InformationPreference variable to "Continue" globally,
# this way it gets printed on execution and continues execution afterwards.
$InformationPreference = "Continue"

# Stop on first error
$ErrorActionPreference = "Stop"

# Load functions from utils.ps1
. "$PSScriptRoot\utils.ps1"

# Load config
$config = Get-BootstrapConfig

# python executable name
$python = Get-PythonExecutableName -pythonVersion $config.python_version

Write-Output "Python executable: $python"

Main

## end of script
