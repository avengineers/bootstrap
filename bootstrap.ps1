$ErrorActionPreference = "Stop"

Function Update-Env {
    $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

Function Invoke-CommandLine {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$CommandLine,
        [Parameter(Mandatory = $false, Position = 1)]
        [bool]$StopAtError = $true,
        [Parameter(Mandatory = $false, Position = 2)]
        [bool]$Silent = $false
    )
    if (-Not$Silent) {
        Write-Host "Executing: $CommandLine"
    }
    Invoke-Expression $CommandLine
    if ($LASTEXITCODE -ne 0) {
        if ($StopAtError) {
            Write-Error "Command line call `"$CommandLine`" failed with exit code $LASTEXITCODE"
            exit 1
        }
        else {
            if (-Not$Silent) {
                Write-Host "Command line call `"$CommandLine`" failed with exit code $LASTEXITCODE, continuing ..."
            }
        }
    }
}

if (Test-Path -Path '.env') {
    # load environment properties
    $envProps = ConvertFrom-StringData (Get-Content '.env' -raw)
}

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

if (Test-Path -Path 'scoopfile.json') {
    # Initial Scoop installation
    if (-Not (Get-Command 'scoop' -ErrorAction SilentlyContinue)) {
    (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/xxthunder/ScoopInstall/master/install.ps1') | Invoke-Expression
        Update-Env
    }

    # Some old tweak to get 7zip installed correctly
    Invoke-CommandLine -CommandLine "scoop config use_lessmsi $true"

    # avoid deadlocks while updating scoop buckets
    Invoke-CommandLine -CommandLine "scoop config autostash_on_conflict $true"

    # install needed tools
    Invoke-CommandLine -CommandLine "scoop update"
    Invoke-CommandLine -CommandLine "scoop import scoopfile.json"
    Update-Env
}

if ((Test-Path -Path 'requirements.txt') -or (Test-Path -Path 'Pipfile')) {
    # Prepare python environment
    Invoke-CommandLine -CommandLine "python -m pip install pipenv"
    Update-Env
    if ($clean) {
        # Start with a fresh virtual environment
        Invoke-CommandLine -CommandLine "python -m pipenv --rm"
    }
    if (-Not (Test-Path -Path '.venv')) {
        New-Item -ItemType Directory '.venv'
    }
    if (Test-Path -Path 'requirements.txt') {
        Invoke-CommandLine -CommandLine "python -m pipenv install --requirements requirements.txt"
    }
    else {
        Invoke-CommandLine -CommandLine "python -m pipenv install"
    }
}
