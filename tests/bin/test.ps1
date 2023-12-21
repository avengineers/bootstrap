#Requires -Version 5.1

$LogPath = Join-Path -Path $PSScriptRoot -ChildPath "$($MyInvocation.MyCommand.Name.Replace('.ps1','')).log"
Start-Transcript -Path $LogPath

$testsFolder = Join-Path $PSScriptRoot ".."

$testConfig = New-PesterConfiguration -Hashtable @{
    Run    = @{
        Path     = $testsFolder
        PassThru = $true
    }
    Output = @{
        Verbosity = 'Detailed'
    }
}

$testResult = Invoke-Pester -Configuration $testConfig

$testResult | Export-JUnitReport -Path (Join-Path $testsFolder "out\TestResults.xml")

Stop-Transcript

Exit $testResult.FailedCount
