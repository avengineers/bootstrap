$ErrorActionPreference = "Stop"

Function Update-Env {
    $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# MQ proxy settings
$ProxyHost = 'osde01proxy02.marquardt.de:8080'
$Env:HTTP_PROXY = "http://$ProxyHost"
$Env:HTTPS_PROXY = $Env:HTTP_PROXY
$Env:NO_PROXY = "localhost,.marquardt.de,.marquardt.com"
$WebProxy = New-Object System.Net.WebProxy($Env:HTTP_PROXY, $true, ($Env:NO_PROXY).split(','))
[net.webrequest]::defaultwebproxy = $WebProxy
[net.webrequest]::defaultwebproxy.credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials


if (Test-Path -Path 'scoopfile.json') {
    # Initial Scoop installation
    if (-Not (Get-Command 'scoop' -ErrorAction SilentlyContinue)) {
    (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/xxthunder/ScoopInstall/master/install.ps1') | Invoke-Expression
        Update-Env
    }

    # Some old tweak to get 7zip installed correctly
    scoop config use_lessmsi $true

    # avoid deadlocks while updating scoop buckets
    scoop config autostash_on_conflict $true

    # install needed tools
    scoop update
    scoop import scoopfile.json
    Update-Env
}

if ((Test-Path -Path 'requirements.txt') -or (Test-Path -Path 'Pipfile')) {
    # Prepare python environment
    python -m pip install pipenv
    Update-Env
    if ($clean) {
        # Start with a fresh virtual environment
        python -m pipenv --rm
    }
    if (-Not (Test-Path -Path '.venv')) {
        New-Item -ItemType Directory '.venv'
    }
    if (Test-Path -Path 'requirements.txt') {
        python -m pipenv install --requirements requirements.txt
    }
    else {
        python -m pipenv install
    }
}
