<#
.DESCRIPTION
    Wrapper for installing dependencies of a project
#>

param(
    [System.IO.FileInfo]$init ## initialize an project directory
    , [String]$proxy ## initialize proxy configuration
)

# About preference variables: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variable

# Stop execution on first non-terminating error (an error that doesn't stop the cmdlet processing)
$ErrorActionPreference = "Stop"

Function Initialize-Directory {
    param(
        [Parameter(Mandatory = $True, Position = 0)]
        [System.IO.FileInfo]$DirPath ,
        [Parameter(Position = 1)]
        [String]$proxyUrl
    )

    Initialize-File-With-Confirmation (Join-Path $DirPath 'build.bat') @'
pushd %~dp0
powershell -ExecutionPolicy Bypass -File .\build.ps1 %* || exit /b 1
popd
'@

    Initialize-File-With-Confirmation (Join-Path $DirPath 'build.ps1') @'
param(
    [switch]$clean ## clean build, wipe out all build artifacts
    , [switch]$install ## install mandatory packages
)

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

Function Import-Dot-Env {
    if (Test-Path -Path '.env') {
        # load environment properties
        $envProps = ConvertFrom-StringData (Get-Content '.env' -raw)
    }

    Return $envProps
}

Function Initialize-Proxy {
    $envProps = Import-Dot-Env
    if ($envProps.'HTTP_PROXY') {
        $Env:HTTP_PROXY = $envProps.'HTTP_PROXY'
        $Env:HTTPS_PROXY = $Env:HTTP_PROXY
        if ($envProps.'NO_PROXY') {
            $Env:NO_PROXY = $envProps.'NO_PROXY'
            $WebProxy = New-Object System.Net.WebProxy($Env:HTTP_PROXY, $true, ($Env:NO_PROXY).split(','))
        }
        else {
            $WebProxy = New-Object System.Net.WebProxy($Env:HTTP_PROXY, $true)
        }

        [net.webrequest]::defaultwebproxy = $WebProxy
        [net.webrequest]::defaultwebproxy.credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    }
}

Function Main {
    param (
        [Parameter(Position = 0)]
        [bool]$install,
        [Parameter(Position = 1)]
        [bool]$clean
    )

    Push-Location $PSScriptRoot
    Write-Output "Running in ${pwd}"
    
    Initialize-Proxy
    
    if ($install) {
        if (-Not (Test-Path -Path '.bootstrap')) {
            New-Item -ItemType Directory '.bootstrap'
        }
        $bootstrapSource = 'https://raw.githubusercontent.com/avengineers/bootstrap/develop/bootstrap.ps1'
        if ($Env:GITHUB_HEAD_REF){
            $bootstrapSource = "https://raw.githubusercontent.com/avengineers/bootstrap/$Env:GITHUB_HEAD_REF/bootstrap.ps1"
            Write-Output "Downloading bootstrap from $bootstrapSource ..."
        }
        Invoke-RestMethod $bootstrapSource -OutFile '.\.bootstrap\bootstrap.ps1'
        . .\.bootstrap\bootstrap.ps1
        Write-Output "For installation changes to take effect, please close and re-open your current shell."
    }
    else {
        if ($clean) {
            # Remove all build artifacts
            $buildDir = '.\build'
            if (Test-Path -Path $buildDir) {
                Remove-Item $buildDir -Force -Recurse
            }
        }
        Invoke-CommandLine 'python --version'
    }

    Pop-Location
}

## start of script
$ErrorActionPreference = "Stop"

Main $install $clean
## end of script

'@

    if ($proxyUrl -And ($proxyUrl -ne "")) {
        Initialize-File-With-Confirmation (Join-Path $DirPath '.env') @"
HTTP_PROXY=$proxyUrl
HTTPS_PROXY=$proxyUrl
NO_PROXY=
"@
    }

    Initialize-File-With-Confirmation (Join-Path $DirPath 'scoopfile.json') @'
{
    "buckets": [
        {
            "Name": "main",
            "Source": "https://github.com/ScoopInstaller/Main"
        },
        {
            "Name": "versions",
            "Source": "https://github.com/ScoopInstaller/Versions"
        },
        {
            "Name": "extras",
            "Source": "https://github.com/ScoopInstaller/Extras"
        }
    ],
    "apps": [
        {
            "Source": "versions",
            "Name": "python311"
        }
    ]
}
'@

}

Function Initialize-File-With-Confirmation {
    param(
        [Parameter(Mandatory = $True, Position = 0)]
        [System.IO.FileInfo]$FilePath
        , [Parameter(Mandatory = $True, Position = 1)]
        [string]$FileContent
    )
    if (Test-Path -Path $FilePath -PathType Leaf) {
        $confirmation = Read-Host "The file '$FilePath' already exists. Shall it be recreated? (y/n)"
        if ($confirmation -ne 'y') {
            # no overwrite
            return
        }
    }
    $parentPath = Split-Path -Path $FilePath -Parent
    if (-Not (Test-Path -Path $parentPath -PathType Container)) {
        Write-Output "Creating directory $parentPath"
        New-Item -ItemType Directory $parentPath
    }
    Write-Output "Creating file $FilePath"
    $FileContent | Out-File -FilePath $FilePath -Encoding utf8
}

Function Edit-Env {
    # workaround for GithubActions
    if ($Env:INVERT_PATH_VARIABLE -eq "true") {
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
            Invoke-RestMethod 'https://raw.githubusercontent.com/xxthunder/ScoopInstall/master/install.ps1' -outfile "$PSScriptRoot\bootstrap.scoop.ps1"
            if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                & $PSScriptRoot\bootstrap.scoop.ps1 -RunAsAdmin
            }
            else {
                & $PSScriptRoot\bootstrap.scoop.ps1
            }
            Edit-Env
        }

        # install needed tools
        Invoke-CommandLine "scoop update"
        Invoke-CommandLine "scoop install lessmsi" -Silent $true

        # Some old tweak to get 7zip installed correctly
        Invoke-CommandLine "scoop config use_lessmsi $true" -Silent $true

        # avoid deadlocks while updating scoop buckets
        Invoke-CommandLine "scoop config autostash_on_conflict $true" -Silent $true

        # some prerequisites to install other packages
        Invoke-CommandLine "scoop install 7zip" -Silent $true
        Invoke-CommandLine "scoop install innounp" -Silent $true
        Invoke-CommandLine "scoop install dark" -Silent $true
        Invoke-CommandLine "scoop import scoopfile.json"
        Edit-Env
    }
    else {
        Write-Output "File 'scoopfile.json' not found, skipping Scoop setup."
    }
}

Function Install-Python-Dependency {
    # Prepare virtual Python environment
    Invoke-CommandLine "python -m pip install pipenv pip-system-certs"

    if ((Test-Path -Path 'requirements.txt') -or (Test-Path -Path 'Pipfile')) {
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
            Invoke-CommandLine "python -m pipenv install"
        }
    }
    else {
        Write-Output "File 'Pipfile' not found, skipping Python setup."
    }
}

Function Install-West {
    if ((Test-Path -Path '.west/config')) {
        Write-Output "File '.west/config' found, installing 'west' ..."
        # install west into virtual environment
        if (-Not (Test-Path -Path '.venv')) {
            New-Item -ItemType Directory '.venv'
        }
        Invoke-CommandLine "python -m pipenv install west"
    }
    else {
        Write-Output "File '.west/config' not found, skipping west setup."
    }
}

Function Main {
    param (
        [Parameter(Position = 0)]
        [System.IO.FileInfo]$init,
        [Parameter(Position = 1)]
        [String]$proxy
    )

    if ($init) {
        Initialize-Directory $init $proxy
    }
    else {
        Install-Scoop
        Install-Python-Dependency
        Install-West
    }
}

## start of script
Main $init $proxy
## end of script
