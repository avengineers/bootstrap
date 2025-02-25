BeforeAll {
    # Load SUT
    $sut = (Split-Path -Leaf $PSCommandPath).Replace('.Tests.ps1', '.ps1')
    # Inhibit execution of Main function of SUT
    Set-Alias Main out-null
    . ".\$sut"
    Remove-Item Alias:Main

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
        $result.python_version | Should -Be "3.11"
        $result.scoop_ignore_scoopfile | Should -Be $false
        $result.scoop_config.autostash_on_conflict | Should -Be "true"
        $result.scoop_config.use_lessmsi | Should -Be "true"
    }

    It "should support custom configuration" {
        # Arrange
        Mock -CommandName Test-Path -MockWith { $true }
        Mock -CommandName Get-Content -MockWith {
            '{
                "python_version": "3.9",
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
        $result.python_version | Should -Be "3.9"
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
        $result.python_version | Should -Be "3.11"
        $result.scoop_ignore_scoopfile | Should -Be $false
        $result.scoop_config.autostash_on_conflict | Should -Be "true"
        $result.scoop_config.use_lessmsi | Should -Be "true"
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
    }

    It "shall not install scoop if scoop is already available" {
        Mock -CommandName Get-Command -MockWith { $true }
        Mock -CommandName Test-Path -MockWith { $false }

        Install-Scoop

        Should -Invoke -CommandName Invoke-RestMethod -Exactly 0
        Should -Invoke -CommandName Initialize-EnvPath -Exactly 0
    }

    It "shall install scoop if scoop is not available" {
        Mock -CommandName Get-Command -MockWith { $false }
        Mock -CommandName Test-Path -MockWith { $false }

        Install-Scoop

        Should -Invoke -CommandName Invoke-RestMethod -Exactly 1 -ParameterFilter { $Uri -eq $config.scoop_installer }
        Should -Invoke -CommandName Initialize-EnvPath -Exactly 1
    }

    It "shall configure scoop" {
        Mock -CommandName Get-Command -MockWith { $true }
        Mock -CommandName Test-Path -MockWith { $false }

        Install-Scoop

        Should -Invoke -CommandName Invoke-CommandLine -Exactly 8
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 4 -ParameterFilter { $CommandLine -like "scoop config *" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -eq "scoop config use_lessmsi true" }
    }

    It "shall install scoop dependencies" {
        Mock -CommandName Get-Command -MockWith { $true }
        Mock -CommandName Test-Path -MockWith { $false }

        Install-Scoop

        Should -Invoke -CommandName Invoke-CommandLine -Exactly 8
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 4 -ParameterFilter { $CommandLine -like "scoop install */*.json" }
    }

    It "shall import scoopfile.json" {
        Mock -CommandName Get-Command -MockWith { $true }
        Mock -CommandName Test-Path -MockWith { $true }

        Install-Scoop

        Should -Invoke -CommandName Invoke-CommandLine -Exactly 8
        Should -Invoke -CommandName Import-ScoopFile -Exactly 1 -ParameterFilter { $ScoopFilePath -eq "scoopfile.json" }
    }

    It "shall not import scoopfile.json if scoop_ignore_scoopfile is configured" {
        Mock -CommandName Get-Command -MockWith { $true }
        Mock -CommandName Test-Path -MockWith { $true }

        $config.scoop_ignore_scoopfile = $true
        Install-Scoop
        $config.scoop_ignore_scoopfile = $false

        Should -Invoke -CommandName Invoke-CommandLine -Exactly 8
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 0 -ParameterFilter { $CommandLine -eq "scoop update" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 0 -ParameterFilter { $CommandLine -eq "scoop import scoopfile.json --reset" }
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
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -like "python311 *\bootstrap.py" }
        Should -Invoke -CommandName New-Item -Exactly 1
    }

    It "shall run python deps installation if pyproject.toml exists and create .venv directory" {
        Mock -CommandName Test-Path -MockWith { $false }
        Mock -CommandName Test-Path -MockWith { $true } -ParameterFilter { $Path -eq "pyproject.toml" }

        Install-PythonEnvironment

        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -like "python311 *\bootstrap.py" }
        Should -Invoke -CommandName New-Item -Exactly 1
    }
}

Describe "Install-Python" {
    BeforeEach {
        Mock -CommandName Invoke-CommandLine -MockWith {}
        Mock -CommandName Write-Output -MockWith {}
    }
    
    It "shall install python if python is not available" {
        Mock -CommandName Get-Command -MockWith { $null }
        
        Install-Python
        
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -like "scoop install */python311.json" }
        Should -Invoke -CommandName Write-Output -Exactly 1 -ParameterFilter { $InputObject -eq "python311 not found. Try to install python311 via scoop ..." }
    }
    
    It "shall not install python if python is available" {
        Mock -CommandName Get-Command -MockWith { [PSCustomObject]@{
                Source = "somebloodypath"
            } }
         
        Install-Python

        Should -Invoke -CommandName Invoke-CommandLine -Exactly 0
        Should -Invoke -CommandName Write-Output -Exactly 1
        Should -Invoke -CommandName Write-Output -Exactly 1 -ParameterFilter { $InputObject -eq "python311 found in somebloodypath, skipping installation." }
    }
}


Describe "Get-PythonExecutableName" {
    It "should only consider major and minor version" {
        # Act
        $python_version = Get-PythonExecutableName -pythonVersion "3.9.1"

        # Assert
        $python_version | Should -Be "python39"
    }
    
    It "should only consider major version" {
        # Act
        $python_version = Get-PythonExecutableName -pythonVersion "4"

        # Assert
        $python_version | Should -Be "python4"
    }
}
