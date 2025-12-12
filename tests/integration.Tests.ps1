Describe "Bootstrap Integration Tests" {
    It "Python <pythonVersion> project should be bootstrapped" -ForEach @("3.10", "3.11", "3.12") {
        # Arrange
        $testDataPath = Join-Path -Path $PSScriptRoot -ChildPath "\data\python$_"
        $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "\..\bootstrap.ps1"
        Push-Location $testDataPath
        Remove-Item -Path '.venv' -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path 'poetry.lock' -Recurse -Force -ErrorAction SilentlyContinue

        # Act
        & "$scriptPath"

        # Assert
        'poetry.lock' | Should -Exist
        ".venv\create-virtual-environment.deps.json" | Should -Exist
        ".venv\Scripts\python.exe" | Should -Exist
        ".venv\Scripts\pip.exe" | Should -Exist
        ".venv\.gitignore" | Should -Exist

        Pop-Location
    }
}
