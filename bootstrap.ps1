<#
.DESCRIPTION
    Wrapper for installing dependencies of a project
#>

# Always set the $InformationPreference variable to "Continue" globally,
# this way it gets printed on execution and continues execution afterwards.
$InformationPreference = "Continue"

# Stop on first error
$ErrorActionPreference = "Stop"

###################################################################################################
# Configuration
###################################################################################################

function Convert-JsonToHashtable {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [string]$JsonString
    )

    # Convert the JSON string to a PSCustomObject
    $customObject = $JsonString | ConvertFrom-Json

    # Create an empty hashtable
    $hashtable = @{}

    # Iterate through the properties of the PSCustomObject
    $customObject.psobject.properties | ForEach-Object {
        $hashtable[$_.Name] = $_.Value
    }

    # Return the hashtable
    return $hashtable
}

$bootstrapJsonPath = "bootstrap.json"
if (Test-Path $bootstrapJsonPath) {
    $json = Get-Content $bootstrapJsonPath | Out-String
    $config = Convert-JsonToHashtable -JsonString $json
}
else {
    $config = @{
        python_version                = "3.11"
        scoop_installer               = "https://raw.githubusercontent.com/ScoopInstaller/Install/master/install.ps1"
        scoop_default_bucket_base_url = "https://raw.githubusercontent.com/ScoopInstaller/Main/master/bucket"
        scoop_python_bucket_base_url  = "https://raw.githubusercontent.com/ScoopInstaller/Versions/master/bucket"
        scoop_config                  = @{
            use_lessmsi           = $true
            autostash_on_conflict = $true
        }
    }
}

###################################################################################################
# Utility functions
###################################################################################################

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
        Invoke-Expression $CommandLine *>$null
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

Function Install-Scoop {
    # Initial Scoop installation
    if (-Not (Get-Command 'scoop' -ErrorAction SilentlyContinue)) {
        $tempDir = [System.IO.Path]::GetTempPath()
        $tempFile = "$tempDir\install.ps1"
        Invoke-RestMethod $config.scoop_installer -OutFile $tempFile
        if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            & $tempFile -RunAsAdmin
        }
        else {
            & $tempFile
        }
        Remove-Item $tempFile
        Initialize-EnvPath
    }

    if ($config.scoop_config) {
        Write-Output "Setting scoop configuration ..."
        $config.scoop_config.PSObject.Properties | ForEach-Object {
            Write-Output "scoop config $_"
        }
    }

    # Install any installer dependencies
    $manifests = @(
        "$($config.scoop_default_bucket_base_url)/dark.json",
        "$($config.scoop_default_bucket_base_url)/lessmsi.json",
        "$($config.scoop_default_bucket_base_url)/innounp.json",
        "$($config.scoop_default_bucket_base_url)/7zip.json"
    )
    $manifests | ForEach-Object {
        Invoke-CommandLine "scoop install $_" -Silent $false
    }

    if (Test-Path -Path 'scoopfile.json') {
        Write-Output "File 'scoopfile.json' found, running 'scoop import' ..."

        Invoke-CommandLine "scoop update"

        # import project-specific scoopfile.json
        # TODO: scoop's import feature is not working properly, do it by yourself
        Invoke-CommandLine "scoop import scoopfile.json --reset"

        Initialize-EnvPath
    }
}

# Prepare virtual Python environment
Function Install-PythonEnvironment {
    if (Test-Path -Path 'pyproject.toml') {
        $bootstrapPy = Join-Path $PSScriptRoot "bootstrap.py"
        Invoke-CommandLine "python $bootstrapPy"
    }
    elseif ((Test-Path -Path 'requirements.txt') -or (Test-Path -Path 'Pipfile')) {
        Invoke-CommandLine "python -m pip install pipenv pip-system-certs"
        if ($clean) {
            # Start with a fresh virtual environment
            if (Test-Path -Path '.venv') {
                Invoke-CommandLine "python -m pipenv --rm" -StopAtError $false
            }
        }
        if (-Not (Test-Path -Path '.venv')) {
            New-Item -ItemType Directory '.venv'
        }
        if (Test-Path -Path 'requirements.txt') {
            Write-Output "File 'requirements.txt' found, running 'python -m pipenv' to create a virtual environment ..."
            Invoke-CommandLine "python -m pipenv install --requirements requirements.txt"
        }
        else {
            Write-Output "File 'Pipfile' found, running 'python -m pipenv' to create a virtual environment ..."
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
    #Install-Python
    #Install-PythonEnvironment
}

## start of script

Main

## end of script
