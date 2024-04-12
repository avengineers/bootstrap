BeforeAll {
    # Load SUT
    $sut = (Split-Path -Leaf $PSCommandPath).Replace('.Tests.ps1', '.ps1')
    # Inhibit execution of Main function of SUT
    Set-Alias Main out-null
    . ".\$sut"
    Remove-Item Alias:Main
}

Describe "Convert-CustomObjectToHashtable" {
    It "should convert a PSCustomObject to a hashtable" {
        # Arrange
        $customObject = [PSCustomObject]@{
            Name = "John"
            Age  = 30
            City = "New York"
        }

        # Act
        $result = Convert-CustomObjectToHashtable -CustomObject $customObject

        # Assert
        $result.Name | Should -Be "John"
        $result.Age | Should -Be 30
        $result.City | Should -Be "New York"
    }

    It "should handle an empty PSCustomObject" {
        # Arrange
        $customObject = [PSCustomObject]@{}

        # Act
        $result = Convert-CustomObjectToHashtable -CustomObject $customObject

        # Assert
        $result | Should -BeLike @{ }
    }

    It "should handle a PSCustomObject with null values" {
        # Arrange
        $customObject = [PSCustomObject]@{
            Name = $null
            Age  = $null
            City = $null
        }

        # Act
        $result = Convert-CustomObjectToHashtable -CustomObject $customObject

        # Assert
        $result.Name | Should -Be $null
        $result.Age | Should -Be $null
        $result.City | Should -Be $null
    }
}

Describe "Invoke-CommandLine" {
    BeforeEach {
        Mock -CommandName Write-Output -MockWith {}
        Mock -CommandName Write-Error -MockWith {}
    }

    It "shall not write the executed command to console if silent" {
        Invoke-CommandLine "dir" -Silent $true
        
        Should -Invoke -CommandName Write-Output -Exactly 0
        Should -Invoke -CommandName Write-Error -Exactly 0
        $global:LASTEXITCODE | Should -Be 0
    }

    It "shall write the executed command to console (default)" {
        Invoke-CommandLine "dir"
        
        Should -Invoke -CommandName Write-Output -Exactly 1
        Should -Invoke -CommandName Write-Output -Exactly 1 -ParameterFilter { $InputObject -eq "Executing: dir" }
        Should -Invoke -CommandName Write-Error -Exactly 0
    }

    It "shall write the executed command to console (default)" {
        Invoke-CommandLine "git --version"
        
        Should -Invoke -CommandName Write-Output -Exactly 1
        Should -Invoke -CommandName Write-Output -Exactly 1 -ParameterFilter { $InputObject -eq "Executing: git --version" }
        Should -Invoke -CommandName Write-Error -Exactly 0
    }

    It "shall write and create an error when existing command fails (default)" {
        Invoke-CommandLine "git fanatic"
        
        Should -Invoke -CommandName Write-Output -Exactly 1
        Should -Invoke -CommandName Write-Output -Exactly 1 -ParameterFilter { $InputObject -eq "Executing: git fanatic" }
        Should -Invoke -CommandName Write-Error -Exactly 1
        Should -Invoke -CommandName Write-Error -Exactly 1 -ParameterFilter { $Message -eq "Command line call `"git fanatic`" failed with exit code 1" }
    }

    It "shall write the command but not create an error when existing command fails" {
        Invoke-CommandLine "git fanatic" -StopAtError $false
        
        Should -Invoke -CommandName Write-Output -Exactly 2
        Should -Invoke -CommandName Write-Output -Exactly 1 -ParameterFilter { $InputObject -eq "Executing: git fanatic" }
        Should -Invoke -CommandName Write-Output -Exactly 1 -ParameterFilter { $InputObject -eq "Command line call `"git fanatic`" failed with exit code 1, continuing ..." }
        Should -Invoke -CommandName Write-Error -Exactly 0
    }

    It "shall not write the command but create and write an error when existing command fails" {
        Invoke-CommandLine "git fanatic" -Silent $true
        
        Should -Invoke -CommandName Write-Output -Exactly 0
        Should -Invoke -CommandName Write-Error -Exactly 1
        Should -Invoke -CommandName Write-Error -Exactly 1 -ParameterFilter { $Message -eq "Command line call `"git fanatic`" failed with exit code 1" }
    }
    It "shall not write the command nor create and write an error when existing command fails" {
        Invoke-CommandLine "git fanatic" -Silent $true -StopAtError $false
        
        Should -Invoke -CommandName Write-Output -Exactly 1
        Should -Invoke -CommandName Write-Output -Exactly 1 -ParameterFilter { $InputObject -eq "Command line call `"git fanatic`" failed with exit code 1, continuing ..." }
        Should -Invoke -CommandName Write-Error -Exactly 0
    }
}

Describe "Install-Scoop" {
    BeforeEach {
        Mock -CommandName Invoke-RestMethod -MockWith { 
            New-Item -Path $OutFile -ItemType File
        }
        Mock -CommandName Invoke-CommandLine -MockWith {}
        Mock -CommandName Initialize-EnvPath -MockWith {}
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

        Should -Invoke -CommandName Invoke-CommandLine -Exactly 10
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -eq "scoop update" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -eq "scoop import scoopfile.json --reset" }
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

        Should -Invoke -CommandName Invoke-CommandLine -Exactly 2
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -eq "python -m pip install pipenv pip-system-certs" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -eq "python -m pipenv install --dev" }
        Should -Invoke -CommandName New-Item -Exactly 1
    }

    It "shall run python deps installation if pyproject.toml exists and create .venv directory" {
        Mock -CommandName Test-Path -MockWith { $false }
        Mock -CommandName Test-Path -MockWith { $true } -ParameterFilter { $Path -eq "pyproject.toml" }

        Install-PythonEnvironment

        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -like "python *\bootstrap.py" }
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
        Should -Invoke -CommandName Write-Output -Exactly 2
        Should -Invoke -CommandName Write-Output -Exactly 1 -ParameterFilter { $InputObject -eq "python311 found in somebloodypath" }
    }
}
