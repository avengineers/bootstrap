<#
.DESCRIPTION
    Wrapper for installing dependencies of a project
#>

## start of script
# Always set the $InformationPreference variable to "Continue" globally,
# this way it gets printed on execution and continues execution afterwards.
$InformationPreference = "Continue"

# Stop on first error
$ErrorActionPreference = "Stop"

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
    Invoke-Expression $CommandLine
    if ($global:LASTEXITCODE -ne 0) {
        if ($StopAtError) {
            Write-Error "Command line call `"$CommandLine`" failed with exit code $global:LASTEXITCODE"
        }
        else {
            if (-Not $Silent) {
                Write-Output "Command line call `"$CommandLine`" failed with exit code $global:LASTEXITCODE, continuing ..."
            }
        }
    }
}

Function Install-Scoop {
    if (Test-Path -Path 'scoopfile.json') {
        Write-Output "File 'scoopfile.json' found, installing scoop and running 'scoop import' ..."
        # Initial Scoop installation
        if (-Not (Get-Command 'scoop' -ErrorAction SilentlyContinue)) {
            Invoke-RestMethod 'https://raw.githubusercontent.com/ScoopInstaller/Install/master/install.ps1' -outfile "$PSScriptRoot\bootstrap.scoop.ps1"
            if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                & $PSScriptRoot\bootstrap.scoop.ps1 -RunAsAdmin
            }
            else {
                & $PSScriptRoot\bootstrap.scoop.ps1
            }
            Initialize-EnvPath
        }

        # Some old tweak to get 7zip installed correctly
        Invoke-CommandLine "scoop config use_lessmsi $true" -Silent $true

        # avoid deadlocks while updating scoop buckets
        Invoke-CommandLine "scoop config autostash_on_conflict $true" -Silent $true

        # Update scoop app itself
        Invoke-CommandLine "scoop config scoop_repo https://github.com/xxthunder/Scoop"
        Invoke-CommandLine "scoop config scoop_branch develop"
        Invoke-CommandLine "scoop update scoop"

        # import project-specific scoopfile.json
        # TODO: scoop's import feature is not working properly, do it by yourself
        Invoke-CommandLine "scoop import scoopfile.json --reset"

        Initialize-EnvPath
    }
    else {
        Write-Output "File 'scoopfile.json' not found, skipping Scoop setup."
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

# Main function needed for testing (will be mocked)
Function Main {
    Install-Scoop
    Install-PythonEnvironment
}

## start of script
Main
## end of script
