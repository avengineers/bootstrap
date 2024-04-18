<#
.DESCRIPTION
    Wrapper for installing dependencies of a project
#>

function Convert-CustomObjectToHashtable {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [PSCustomObject]$CustomObject
    )

    # Create an empty hashtable
    $hashtable = @{}

    # Iterate through the properties of the PSCustomObject
    $CustomObject.psobject.properties | ForEach-Object {
        $hashtable[$_.Name] = $_.Value
    }

    # Return the hashtable
    return $hashtable
}

# Update/Reload current environment variable PATH with settings from registry
Function Initialize-EnvPath {
    # workaround for system-wide installations (e.g. in GitHub Actions)
    if ($Env:USER_PATH_FIRST) {
        $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    }
    else {
        $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }
}

Function Invoke-CommandLine {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Usually this statement must be avoided (https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/avoid-using-invoke-expression?view=powershell-7.3), here it is OK as it does not execute unknown code.')]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$CommandLine,
        [Parameter(Mandatory = $false, Position = 1)]
        [bool]$StopAtError = $true,
        [Parameter(Mandatory = $false, Position = 2)]
        [bool]$Silent = $false
    )
    if (-Not $Silent) {
        Write-Output "Executing: $CommandLine"
    }
    $global:LASTEXITCODE = 0
    if ($Silent) {
        # Omit information stream (6) and stdout (1)
        Invoke-Expression $CommandLine 6>&1 | Out-Null
    }
    else {
        Invoke-Expression $CommandLine
    }
    if ($global:LASTEXITCODE -ne 0) {
        if ($StopAtError) {
            Write-Error "Command line call `"$CommandLine`" failed with exit code $global:LASTEXITCODE"
        }
        else {
            Write-Output "Command line call `"$CommandLine`" failed with exit code $global:LASTEXITCODE, continuing ..."
        }
    }
}

# Load configuration from bootstrap.json or use default values
Function Get-BootstrapConfig {
    $bootstrapConfig = @{
        python_version                = "3.11"
        python_package_manager        = "poetry>=1.7.1"
        scoop_installer               = "https://raw.githubusercontent.com/xxthunder/ScoopInstall/v1.0.0/install.ps1"
        scoop_installer_with_repo_arg = $false
        scoop_default_bucket_base_url = "https://raw.githubusercontent.com/ScoopInstaller/Main/master/bucket"
        scoop_python_bucket_base_url  = "https://raw.githubusercontent.com/ScoopInstaller/Versions/master/bucket"
        scoop_ignore_scoopfile        = $false
        scoop_config                  = @{
            autostash_on_conflict = "true"
            use_lessmsi           = "true"
            scoop_repo            = "https://github.com/xxthunder/Scoop.git"
            scoop_branch          = "develop"
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

Function Install-Scoop {
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
        Invoke-CommandLine ("scoop config " + $item.Key + " " + $item.Value) -Silent $true
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
        Invoke-CommandLine "scoop install $($config.scoop_default_bucket_base_url)/$_" -Silent $true
    }

    # Import scoopfile.json
    if ((-Not $config.scoop_ignore_scoopfile) -and (Test-Path -Path 'scoopfile.json')) {
        Write-Output "File 'scoopfile.json' found, running 'scoop import' ..."

        Invoke-CommandLine "scoop update"

        # TODO: scoop's import feature is not working properly, do it with our ScoopWrapper in Pypeline
        Invoke-CommandLine "scoop import scoopfile.json --reset"

        Initialize-EnvPath
    }
}

# Prepare virtual Python environment
Function Install-PythonEnvironment {
    if ((Test-Path -Path 'pyproject.toml') -or (Test-Path -Path 'Pipfile')) {
        if ($clean) {
            # Start with a fresh virtual environment
            if (Test-Path -Path '.venv') {
                Remove-Item -Path '.venv' -Recurse -Force
            }
        }
        if (-Not (Test-Path -Path '.venv' -PathType Container)) {
            New-Item -ItemType Directory '.venv'
        }
        if (Test-Path -Path 'pyproject.toml') {
            $bootstrapPy = Join-Path $PSScriptRoot "bootstrap.py"
            Invoke-CommandLine "python $bootstrapPy"
        }
        elseif (Test-Path -Path 'Pipfile') {
            Write-Output "File 'Pipfile' found, running 'python -m pipenv' to create a virtual environment ..."
            Invoke-CommandLine "python -m pip install pipenv pip-system-certs"
            Invoke-CommandLine "python -m pipenv install --dev"
        }
    }
    else {
        Write-Output "No Python config file found, skipping Python setup."
    }
}

Function Install-Python {
    # python executable name
    $python = "python" + $config.python_version.Replace(".", "")

    # Check if python is installed
    $pythonPath = (Get-Command $python -ErrorAction SilentlyContinue).Source
    if ($null -eq $pythonPath) {
        Write-Output "$python not found. Try to install $python via scoop ..."
        # Install python
        Invoke-CommandLine "scoop install $($config.scoop_python_bucket_base_url)/$python.json"
    }
    else {
        Write-Output "$python found in $pythonPath"
        # Extract the directory of python exe file and add it to PATH. It needs to be the first entry in PATH
        # such that this version is used when the user calls python and not python311
        $pythonDir = [System.IO.Path]::GetDirectoryName($pythonPath)
        Write-Output "Adding $pythonDir to PATH"
        $Env:Path += ";$pythonDir"
    }
}

# Main function needed for testing (will be mocked)
Function Main {
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

# Load config
$config = Get-BootstrapConfig

Main

## end of script
