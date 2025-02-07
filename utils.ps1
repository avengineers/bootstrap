<#
.DESCRIPTION
    Utility methods for common tasks.
#>

function Invoke-CommandLine {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Usually this statement must be avoided (https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/avoid-using-invoke-expression?view=powershell-7.3), here it is OK as it does not execute unknown code.')]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$CommandLine,
        [Parameter(Mandatory = $false, Position = 1)]
        [bool]$StopAtError = $true,
        [Parameter(Mandatory = $false, Position = 2)]
        [bool]$PrintCommand = $true,
        [Parameter(Mandatory = $false, Position = 3)]
        [bool]$Silent = $false
    )
    if ($PrintCommand) {
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

function Update-ScoopPath {
    param (
        [string]$ScoopFilePath
    )

    # Read the content of the scoopfile.json
    $scoopFileContent = Get-Content -Path $ScoopFilePath -Raw | ConvertFrom-Json

    # Iterate over each app in the scoopfile
    foreach ($app in $scoopFileContent.apps) {
        Write-Output "Processing app: $($app.Name)"

        # Extract the app details from the dictionary
        $source = $app.Source
        $name = $app.Name
        $version = $app.Version

        # Construct the scoop info command
        $appIdentifier = if ($version) { "$source/$name@$version" } else { "$source/$name" }

        # Get the scoop info for the app with --verbose flag
        $appInfo = scoop info $appIdentifier --verbose

        # Check if the appInfo contains 'Path Added'
        if ($appInfo.'Path Added') {
            $pathAdded = $appInfo.'Path Added'

            $env:PATH = "$pathAdded;$env:PATH"
            Write-Output "Added $pathAdded to PATH for app $appIdentifier"
        }
    }

    Write-Output "Updated PATH: $env:PATH"
}

# Update/Reload current environment variable PATH with settings from registry
function Initialize-EnvPath {
    # workaround for system-wide installations (e.g. in GitHub Actions)
    if ($Env:USER_PATH_FIRST) {
        $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    }
    else {
        $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }
}

function Remove-Path {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$path
    )
    if (Test-Path -Path $path -PathType Container) {
        Write-Output "Deleting directory '$path' ..."
        Remove-Item $path -Force -Recurse
    }
    elseif (Test-Path -Path $path -PathType Leaf) {
        Write-Output "Deleting file '$path' ..."
        Remove-Item $path -Force
    }
}

function New-Directory {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$dir
    )
    if (-Not (Test-Path -Path $dir)) {
        Write-Output "Creating directory '$dir' ..."
        New-Item -ItemType Directory $dir
    }
}

function CloneOrPullGitRepo {
    param (
        [Parameter(Mandatory = $true)]
        [string]$RepoUrl,
        [Parameter(Mandatory = $true)]
        [string]$TargetDirectory,
        [Parameter(Mandatory = $false)]
        [string]$Tag,
        [Parameter(Mandatory = $false)]
        [string]$Branch = "develop"
    )

    $baselineName = "branch"
    $baseline = $Branch
    if ($Tag) {
        $baselineName = "tag"
        $baseline = $Tag
    }

    if (Test-Path -Path "$TargetDirectory\.git" -PathType Container) {
        # When the repository directory exists, fetch the latest changes and checkout the baseline
        try {
            Push-Location $TargetDirectory
            Invoke-CommandLine "git fetch --tags" -Silent $true
            if ($Tag) {
                Invoke-CommandLine "git checkout $Tag --quiet" -Silent $true
            }
            else {
                Invoke-CommandLine "git checkout -B $Branch origin/$Branch --quiet" -Silent $true
            }
            Invoke-CommandLine "git reset --hard"
            return
        }
        catch {
            Write-Output "Failed to checkout $baselineName '$baseline' in repository '$RepoUrl' at directory '$TargetDirectory'."
        }
        finally {
            Pop-Location
        }
    }

    # Repo directory does not exist, remove any possible leftovers and get a fresh clone
    try {
        Remove-Path $TargetDirectory
        New-Directory $TargetDirectory
        Push-Location $TargetDirectory
        Invoke-CommandLine "git -c advice.detachedHead=false clone --branch $baseline $RepoUrl ." -Silent $true
        Invoke-CommandLine "git config pull.rebase true" -Silent $true -PrintCommand $false
        Invoke-CommandLine "git log -1 --pretty='format:%h %B'" -PrintCommand $false
    }
    catch {
        Write-Output "Failed to clone repository '$RepoUrl' at directory '$TargetDirectory'."
    }
    finally {
        Pop-Location
    }
}

function Test-RunningInCIorTestEnvironment {
    return [Boolean]($Env:JENKINS_URL -or $Env:PYTEST_CURRENT_TEST -or $Env:GITHUB_ACTIONS)
}

function Get-UserConfirmation {
    param (
        [Parameter(Mandatory = $true)]
        [string]$message,
        # Default value of the confirmation prompt
        [Parameter(Mandatory = $false)]
        [bool]$defaultValueForUser = $true,
        # Value when running in CI or test environment
        [Parameter(Mandatory = $false)]
        [bool]$valueForCi = $false
    )
    
    if (Test-RunningInCIorTestEnvironment) {
        return $valueForCi
    } else {
        $defaultText = if ($defaultValueForUser) { "[Y/n]" } else { "[y/N]" }
        $userResponse = Read-Host "$message $defaultText"
        if ($userResponse -eq '') {
            return $defaultValueForUser
        } elseif ($userResponse -match '^[Yy]') {
            return $true
        } else {
            return $false
        }
    }
}
