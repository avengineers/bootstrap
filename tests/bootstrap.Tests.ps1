BeforeAll {
    # Load SUT
    $sut = (Split-Path -Leaf $PSCommandPath).Replace('.Tests.ps1', '.ps1')
    # Inhibit execution of Main function of SUT
    Set-Alias Main out-null
    . ".\$sut"
    Remove-Item Alias:Main
}

Describe "invoking command line calls" {
    BeforeEach {
        Mock -CommandName Write-Output -MockWith {}
        Mock -CommandName Write-Error -MockWith {}
    }

    It "shall not write the command to console if silent" {
        Invoke-CommandLine "dir" -Silent $true
        Should -Invoke -CommandName Write-Output -Times 0
        Should -Invoke -CommandName Write-Error -Times 0
    }

    It "shall write the command to console (default)" {
        Invoke-CommandLine "dir"
        Should -Invoke -CommandName Write-Output -Times 1
        Should -Invoke -CommandName Write-Error -Times 0
    }

    It "shall write the command to console (default)" {
        Invoke-CommandLine "git --version"
        Should -Invoke -CommandName Write-Output -Times 1
        Should -Invoke -CommandName Write-Error -Times 0
    }

    It "shall write and create an error when existing command fails (default)" {
        Invoke-CommandLine "git fanatic"
        Should -Invoke -CommandName Write-Output -Times 1
        Should -Invoke -CommandName Write-Error -Times 1
    }

    It "shall write the command but not create an error when existing command fails" {
        Invoke-CommandLine "git fanatic" -StopAtError $false
        Should -Invoke -CommandName Write-Output -Times 2
        Should -Invoke -CommandName Write-Error -Times 0
    }

    It "shall not write the command but create and write an error when existing command fails" {
        Invoke-CommandLine "git fanatic" -Silent $true
        Should -Invoke -CommandName Write-Output -Times 0
        Should -Invoke -CommandName Write-Error -Times 1
    }
    It "shall not write the command nor create and write an error when existing command fails" {
        Invoke-CommandLine "git fanatic" -Silent $true -StopAtError $false
        Should -Invoke -CommandName Write-Output -Times 0
        Should -Invoke -CommandName Write-Error -Times 0
    }
}

Describe "install scoop" {
    BeforeEach {
        Mock -CommandName Invoke-RestMethod -MockWith { 
            New-Item -Path $OutFile -ItemType File
        }
        Mock -CommandName Invoke-CommandLine -MockWith {}
        Mock -CommandName Initialize-EnvPath -MockWith {}
    }

    It "shall not install scoop if scoop is already available" {
        Mock -CommandName Get-Command -MockWith { $true }

        Install-Scoop
        Should -Invoke -CommandName Invoke-RestMethod -Times 0
        Should -Invoke -CommandName Invoke-CommandLine -Times 5
        Should -Invoke -CommandName Initialize-EnvPath -Times 0
    }

    It "shall install scoop if scoop is not available" {
        Mock -CommandName Get-Command -MockWith { $false }

        Install-Scoop
        Should -Invoke -CommandName Invoke-RestMethod -Times 1
        Should -Invoke -CommandName Invoke-CommandLine -Times 3
        Should -Invoke -CommandName Initialize-EnvPath -Times 1
    }

}

Describe "install python deps" {
    BeforeEach {
        Mock -CommandName Invoke-CommandLine -MockWith {}
    }

    It "shall not run python deps installation if no deps are given" {
        Mock -CommandName Test-Path -MockWith { $false }

        Install-PythonEnvironment
        Should -Invoke -CommandName Invoke-CommandLine -Times 0
    }

    It "shall run python deps installation if requirements.txt exists and create .venv directory" {
        Mock -CommandName New-Item -MockWith {}
        Mock -CommandName Test-Path -MockWith { $false }
        Mock -CommandName Test-Path -MockWith { $true } -ParameterFilter { $Path -eq "requirements.txt" }

        Install-PythonEnvironment
        Should -Invoke -CommandName Invoke-CommandLine -Times 2
        Should -Invoke -CommandName New-Item -Times 1
    }

    It "shall run python deps installation if Pipfile exists and create .venv directory" {
        Mock -CommandName New-Item -MockWith {}
        Mock -CommandName Test-Path -MockWith { $false }
        Mock -CommandName Test-Path -MockWith { $true } -ParameterFilter { $Path -eq "Pipfile" }

        Install-PythonEnvironment
        Should -Invoke -CommandName Invoke-CommandLine -Times 2
        Should -Invoke -CommandName New-Item -Times 1
    }

    It "shall run python deps installation if Pipfile exists and create .venv directory" {
        Mock -CommandName New-Item -MockWith {}
        Mock -CommandName Test-Path -MockWith { $false }
        Mock -CommandName Test-Path -MockWith { $true } -ParameterFilter { $Path -eq ".venv" }
        Mock -CommandName Test-Path -MockWith { $true } -ParameterFilter { $Path -eq "Pipfile" }

        Install-PythonEnvironment
        Should -Invoke -CommandName Invoke-CommandLine -Times 1
        Should -Invoke -CommandName New-Item -Times 0
    }
}
