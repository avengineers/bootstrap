#Requires -Version 5.1

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

Exit $testResult.FailedCount
