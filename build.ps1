$ErrorActionPreference = 'Stop'

# TODO: ugly workaround to invoke tests twice, first time always fails.
try {
    Invoke-Pester bootstrap.Tests.ps1
}
catch {
    Invoke-Pester bootstrap.Tests.ps1
}

if ($lastexitcode -ne 0) {
    throw ("Unit Test: " + $errorMessage)
}

powershell -Command "Invoke-ScriptAnalyzer -EnableExit -Recurse -Path . -ExcludeRule PSAvoidUsingInvokeExpression"
if ($lastexitcode -ne 0) {
    throw ("Powershell Linter: " + $errorMessage)
}
