$ErrorActionPreference = 'Stop'

powershell -Command "Invoke-ScriptAnalyzer -ReportSummary -Severity Warning -EnableExit -Recurse -Path ."
if ($lastexitcode -ne 0) {
    Write-Error "Rule violation(s) found."
}

Invoke-Pester bootstrap.Tests.ps1
if ($lastexitcode -ne 0) {
    Write-Error "Unit test(s) failed."
}
