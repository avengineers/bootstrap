$ErrorActionPreference = 'Stop'

Invoke-Pester bootstrap.Tests.ps1
if ($lastexitcode -ne 0) {
    throw ("Unit Test: " + $errorMessage)
}

powershell -Command "Invoke-ScriptAnalyzer -EnableExit -Recurse -Path . -ExcludeRule PSAvoidUsingInvokeExpression"
if ($lastexitcode -ne 0) {
    throw ("Powershell Linter: " + $errorMessage)
}
