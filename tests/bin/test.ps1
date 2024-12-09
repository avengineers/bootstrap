#Requires -Version 5.1
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.4.0'}

param(
    [string]$TestPath = (Join-Path $PSScriptRoot ".."),
    [string]$ReportPath = (Join-Path $PSScriptRoot "..\out\TestResults.xml"), 
    [string]$Verbosity = 'Detailed',
    [string]$Filter 
)

$testConfig = New-PesterConfiguration -Hashtable @{
    Run    = @{
        Path    = $TestPath
        PassThru = $true
        Filter = $Filter 
    }
    Output = @{
        Verbosity = $Verbosity
    }
}

$testResult = Invoke-Pester -Configuration $testConfig

try {
    $testResult | Export-JUnitReport -Path $ReportPath
    Write-Host "JUnit report generated at: $ReportPath"
}
catch {
    Write-Warning "Failed to generate JUnit report: $($_.Exception.Message)"
}

Exit $testResult.FailedCount