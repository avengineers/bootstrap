BeforeAll {
    # Load SUT
    $sut = (Split-Path -Leaf $PSCommandPath).Replace('.Tests.ps1', '.ps1')
    # Inhibit execution of Main function of SUT
    Set-Alias Main out-null
    . ".\$sut"
    Remove-Item Alias:Main

    # Set $python and $pythonVersion for tests (normally derived from scoop_manifest, but no bootstrap.json in test context)
    # PSScriptAnalyzer does not detect that $python is used by dot-sourced functions via dynamic scoping
    Set-Variable -Name python -Value "python311"
    Set-Variable -Name pythonVersion -Value "3.11"

    class ComparableHashTable : Hashtable {
        ComparableHashTable($obj) : base($obj) {}
        [string] ToString() {
            return ($this | ConvertTo-Json)
        }
    }
}

Describe "Get-BootstrapConfig" {
    It "should return the default configuration" {
        # Arrange
        Mock -CommandName Test-Path -MockWith { $false }

        # Act
        $result = Get-BootstrapConfig

        # Assert
        $result.scoop_ignore_scoopfile | Should -Be $false
        $result.scoop_config.autostash_on_conflict | Should -Be "true"
        $result.scoop_config.use_lessmsi | Should -Be "true"
    }

    It "should support custom configuration" {
        # Arrange
        Mock -CommandName Test-Path -MockWith { $true }
        Mock -CommandName Get-Content -MockWith {
            '{
                "scoop_ignore_scoopfile": true,
                "scoop_config": {
                    "autostash_on_conflict": "false",
                    "some_value_without_default": "true"
                }
            }'
        }

        # Act
        $result = Get-BootstrapConfig

        # Assert
        $result.scoop_ignore_scoopfile | Should -Be $true
        $result.scoop_config.autostash_on_conflict | Should -Be "false"
        $result.scoop_config.use_lessmsi | Should -Be "true"
        $result.scoop_config.some_value_without_default | Should -Be "true"
    }

    It "should support empty custom configuration" {
        # Arrange
        Mock -CommandName Test-Path -MockWith { $true }
        Mock -CommandName Get-Content -MockWith {
            '{}'
        }

        # Act
        $result = Get-BootstrapConfig

        # Assert
        $result.scoop_ignore_scoopfile | Should -Be $false
        $result.scoop_config.autostash_on_conflict | Should -Be "true"
        $result.scoop_config.use_lessmsi | Should -Be "true"
    }

    It "should load scoop_manifest from custom configuration" {
        # Arrange
        Mock -CommandName Test-Path -MockWith { $true }
        Mock -CommandName Get-Content -MockWith {
            '{
                "scoop_manifest": {
                    "buckets": [
                        {"Name": "sple", "Source": "https://git.example.com/scoop-bucket.git"}
                    ],
                    "apps": [
                        {"Name": "lessmsi", "Source": "sple"},
                        {"Name": "7zip", "Source": "sple", "Version": "26.00"}
                    ]
                }
            }'
        }

        # Act
        $result = Get-BootstrapConfig

        # Assert
        $result.scoop_manifest | Should -Not -BeNullOrEmpty
        $result.scoop_manifest.buckets.Count | Should -Be 1
        $result.scoop_manifest.apps.Count | Should -Be 2
    }

    It "should not have scoop_manifest when not configured" {
        # Arrange
        Mock -CommandName Test-Path -MockWith { $true }
        Mock -CommandName Get-Content -MockWith {
            '{
                "python_package_manager": "poetry"
            }'
        }

        # Act
        $result = Get-BootstrapConfig

        # Assert
        $result.scoop_manifest | Should -BeNullOrEmpty
    }
}

Describe "Install-Scoop" {
    BeforeEach {
        Mock -CommandName Invoke-RestMethod -MockWith { 
            New-Item -Path $OutFile -ItemType File
        }
        Mock -CommandName Invoke-CommandLine -MockWith {}
        Mock -CommandName Initialize-EnvPath -MockWith {}
        Mock -CommandName Invoke-Expression -MockWith {}
        Mock -CommandName Import-ScoopFile -MockWith {}

        # scoop_manifest is mandatory for all Install-Scoop tests
        $config.scoop_manifest = [PSCustomObject]@{
            buckets = @(
                [PSCustomObject]@{ Name = "main"; Source = "https://github.com/ScoopInstaller/Main" }
            )
            apps    = @(
                [PSCustomObject]@{ Name = "lessmsi"; Source = "main" },
                [PSCustomObject]@{ Name = "7zip"; Source = "main" },
                [PSCustomObject]@{ Name = "innounp"; Source = "main" },
                [PSCustomObject]@{ Name = "dark"; Source = "main" }
            )
        }
    }

    AfterEach {
        $config.Remove('scoop_manifest')
    }

    It "shall not install scoop if scoop is already available" {
        Mock -CommandName Get-Command -MockWith { $true }
        Mock -CommandName Test-Path -MockWith { $false }

        Install-Scoop

        Should -Invoke -CommandName Invoke-RestMethod -Exactly 0
        Should -Invoke -CommandName Initialize-EnvPath -Exactly 1
    }

    It "shall install scoop if scoop is not available" {
        Mock -CommandName Get-Command -MockWith { $false }
        Mock -CommandName Test-Path -MockWith { $false }

        Install-Scoop

        Should -Invoke -CommandName Invoke-RestMethod -Exactly 1 -ParameterFilter { $Uri -eq $config.scoop_installer }
        Should -Invoke -CommandName Initialize-EnvPath -Exactly 2
    }

    It "shall configure scoop" {
        Mock -CommandName Get-Command -MockWith { $true }
        Mock -CommandName Test-Path -MockWith { $false }

        Install-Scoop

        Should -Invoke -CommandName Invoke-CommandLine -Exactly 4
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 4 -ParameterFilter { $CommandLine -like "scoop config *" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -eq "scoop config use_lessmsi true" }
    }

    It "shall install scoop dependencies via scoop_manifest" {
        Mock -CommandName Get-Command -MockWith { $true }
        Mock -CommandName Test-Path -MockWith { $false }

        Install-Scoop

        # Only scoop config commands, no direct dependency install commands
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 4
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 4 -ParameterFilter { $CommandLine -like "scoop config *" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 0 -ParameterFilter { $CommandLine -eq "scoop bucket add main" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 0 -ParameterFilter { $CommandLine -match "^scoop install" }
        # Import-ScoopFile called with temp file path
        Should -Invoke -CommandName Import-ScoopFile -Exactly 1 -ParameterFilter { $ScoopFilePath -like "*bootstrap-scoopfile.json" }
    }

    It "shall import scoopfile.json" {
        Mock -CommandName Get-Command -MockWith { $true }
        Mock -CommandName Test-Path -MockWith { $true }

        Install-Scoop

        Should -Invoke -CommandName Invoke-CommandLine -Exactly 4
        Should -Invoke -CommandName Initialize-EnvPath -Exactly 2
        Should -Invoke -CommandName Import-ScoopFile -Exactly 1 -ParameterFilter { $ScoopFilePath -like "*bootstrap-scoopfile.json" }
        Should -Invoke -CommandName Import-ScoopFile -Exactly 1 -ParameterFilter { $ScoopFilePath -eq "scoopfile.json" }
    }

    It "shall not import scoopfile.json if scoop_ignore_scoopfile is configured" {
        Mock -CommandName Get-Command -MockWith { $true }
        Mock -CommandName Test-Path -MockWith { $true }

        $config.scoop_ignore_scoopfile = $true
        Install-Scoop
        $config.scoop_ignore_scoopfile = $false

        Should -Invoke -CommandName Invoke-CommandLine -Exactly 4
        Should -Invoke -CommandName Initialize-EnvPath -Exactly 1
        Should -Invoke -CommandName Import-ScoopFile -Exactly 1 -ParameterFilter { $ScoopFilePath -like "*bootstrap-scoopfile.json" }
        Should -Invoke -CommandName Import-ScoopFile -Exactly 0 -ParameterFilter { $ScoopFilePath -eq "scoopfile.json" }
    }

    It "shall error when scoop_manifest is missing" {
        Mock -CommandName Get-Command -MockWith { $true }
        Mock -CommandName Test-Path -MockWith { $false }

        $config.Remove('scoop_manifest')

        { Install-Scoop } | Should -Throw "*scoop_manifest is required*"
    }
}

Describe "Install-PythonEnvironment" {
    BeforeEach {
        Mock -CommandName Invoke-CommandLine -MockWith {}
        Mock -CommandName Write-Output -MockWith {}
        Mock -CommandName New-Item -MockWith {}
    }

    It "shall not run python deps installation if no deps are given" {
        Mock -CommandName Test-Path -MockWith { $false }

        Install-PythonEnvironment

        Should -Invoke -CommandName Invoke-CommandLine -Exactly 0
        Should -Invoke -CommandName Write-Output -Exactly 1 -ParameterFilter { $InputObject -eq "No Python config file found, skipping Python setup." }
    }

    It "shall run python deps installation if Pipfile exists and create .venv directory" {
        Mock -CommandName Test-Path -MockWith { $false }
        Mock -CommandName Test-Path -MockWith { $true } -ParameterFilter { $Path -eq "Pipfile" }

        Install-PythonEnvironment

        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -like "python311 *bootstrap.py --python-version 3.11" }
        Should -Invoke -CommandName New-Item -Exactly 1
    }

    It "shall run python deps installation if pyproject.toml exists and create .venv directory" {
        Mock -CommandName Test-Path -MockWith { $false }
        Mock -CommandName Test-Path -MockWith { $true } -ParameterFilter { $Path -eq "pyproject.toml" }

        Install-PythonEnvironment

        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -like "python311 *bootstrap.py --python-version 3.11" }
        Should -Invoke -CommandName New-Item -Exactly 1
    }

    It "shall skip python environment setup if no python app in scoop_manifest" {
        $savedPython = $python
        try {
            Set-Variable -Name python -Value $null

            Install-PythonEnvironment

            Should -Invoke -CommandName Invoke-CommandLine -Exactly 0
            Should -Invoke -CommandName Write-Output -Exactly 1 -ParameterFilter { $InputObject -eq "No Python app found in scoop_manifest. Skipping Python environment setup." }
        }
        finally {
            Set-Variable -Name python -Value $savedPython
        }
    }
}

Describe "Get-PythonFromScoopManifest" {
    It "shall return null Name and Version when no python entry in scoop_manifest" {
        $testConfig = @{
            scoop_manifest = [PSCustomObject]@{
                apps = @(
                    [PSCustomObject]@{ Name = "lessmsi"; Source = "main" },
                    [PSCustomObject]@{ Name = "7zip"; Source = "main" }
                )
            }
        }

        $result = Get-PythonFromScoopManifest -Config $testConfig

        $result.Name | Should -BeNullOrEmpty
        $result.Version | Should -BeNullOrEmpty
    }

    It "shall return null Name and Version when scoop_manifest has no apps key" {
        $testConfig = @{
            scoop_manifest = [PSCustomObject]@{
                buckets = @(
                    [PSCustomObject]@{ Name = "main"; Source = "https://github.com/ScoopInstaller/Main" }
                )
            }
        }

        $result = Get-PythonFromScoopManifest -Config $testConfig

        $result.Name | Should -BeNullOrEmpty
        $result.Version | Should -BeNullOrEmpty
    }

    It "shall return null Name and Version when scoop_manifest is not defined" {
        $testConfig = @{
            python_package_manager = "poetry"
        }

        $result = Get-PythonFromScoopManifest -Config $testConfig

        $result.Name | Should -BeNullOrEmpty
        $result.Version | Should -BeNullOrEmpty
    }

    It "shall derive version from app name when no Version key is present (python311 -> 3.11)" {
        $testConfig = @{
            scoop_manifest = [PSCustomObject]@{
                apps = @(
                    [PSCustomObject]@{ Name = "lessmsi"; Source = "main" },
                    [PSCustomObject]@{ Name = "python311"; Source = "versions" }
                )
            }
        }

        $result = Get-PythonFromScoopManifest -Config $testConfig

        $result.Name | Should -Be "python311"
        $result.Version | Should -Be "3.11"
    }

    It "shall derive version from single-digit app name (python3 -> 3)" {
        $testConfig = @{
            scoop_manifest = [PSCustomObject]@{
                apps = @(
                    [PSCustomObject]@{ Name = "python3"; Source = "main" }
                )
            }
        }

        $result = Get-PythonFromScoopManifest -Config $testConfig

        $result.Name | Should -Be "python3"
        $result.Version | Should -Be "3"
    }

    It "shall use explicit Version key when present" {
        $testConfig = @{
            scoop_manifest = [PSCustomObject]@{
                apps = @(
                    [PSCustomObject]@{ Name = "python311"; Source = "versions"; Version = "3.11.9" }
                )
            }
        }

        $result = Get-PythonFromScoopManifest -Config $testConfig

        $result.Name | Should -Be "python311"
        $result.Version | Should -Be "3.11.9"
    }

    It "shall use the first python entry and warn when multiple python apps are present" {
        Mock -CommandName Write-Warning -MockWith {}

        $testConfig = @{
            scoop_manifest = [PSCustomObject]@{
                apps = @(
                    [PSCustomObject]@{ Name = "lessmsi"; Source = "main" },
                    [PSCustomObject]@{ Name = "python310"; Source = "versions" },
                    [PSCustomObject]@{ Name = "python311"; Source = "versions"; Version = "3.11.9" }
                )
            }
        }

        $result = Get-PythonFromScoopManifest -Config $testConfig

        $result.Name | Should -Be "python310"
        $result.Version | Should -Be "3.10"
        Should -Invoke -CommandName Write-Warning -Exactly 1 -ParameterFilter {
            $Message -like "*Multiple Python apps found*python310*python311*"
        }
    }
}
