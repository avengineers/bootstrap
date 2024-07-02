BeforeAll {
    # Load SUT
    $sut = (Split-Path -Leaf $PSCommandPath).Replace('.Tests.ps1', '.ps1')
    # Inhibit execution of Main function of SUT
    Set-Alias Main out-null
    . ".\$sut"
    Remove-Item Alias:Main
}

Describe "Invoke-CommandLine" {
    BeforeEach {
        Mock -CommandName Write-Output -MockWith {}
        Mock -CommandName Write-Error -MockWith {}
    }

    It "shall not write the executed command to console if silent" {
        Invoke-CommandLine "dir" -PrintCommand $false
        
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
        Invoke-CommandLine "git fanatic" -Silent $true -PrintCommand $false
        
        Should -Invoke -CommandName Write-Output -Exactly 0
        Should -Invoke -CommandName Write-Error -Exactly 1
        Should -Invoke -CommandName Write-Error -Exactly 1 -ParameterFilter { $Message -eq "Command line call `"git fanatic`" failed with exit code 1" }
    }
    It "shall not write the command nor create and write an error when existing command fails" {
        Invoke-CommandLine "git fanatic" -Silent $true  -PrintCommand $false -StopAtError $false
        
        Should -Invoke -CommandName Write-Output -Exactly 1
        Should -Invoke -CommandName Write-Output -Exactly 1 -ParameterFilter { $InputObject -eq "Command line call `"git fanatic`" failed with exit code 1, continuing ..." }
        Should -Invoke -CommandName Write-Error -Exactly 0
    }
}

Describe "Test-RunningInCIorTestEnvironment" {
    It "shall return true when running in a CI or test environment" {
        $Env:PYTEST_CURRENT_TEST="1"
        $Env:GITHUB_ACTIONS=""
        $Env:JENKINS_URL=""

        Test-RunningInCIorTestEnvironment | Should -Be $true
    }

    It "shall return false when not running in a CI or test environment" {
        $Env:PYTEST_CURRENT_TEST=""
        $Env:GITHUB_ACTIONS=""
        $Env:JENKINS_URL=""

        Test-RunningInCIorTestEnvironment | Should -Be $false
    }
}

Describe 'Get-UserConfirmation' {
    Context 'When running in CI environment' {
        BeforeEach {
            $env:JENKINS_URL = "http://example.com"
        }
        AfterEach {
            Remove-Item Env:JENKINS_URL
        }
        It 'Returns the default value' {
            $result = Get-UserConfirmation -message "Test" -valueForCi $true
            $result | Should -Be $true

            $result = Get-UserConfirmation -message "Test" -valueForCi $false
            $result | Should -Be $false
            
            $result = Get-UserConfirmation -message "Test"
            $result | Should -Be $false
        }
    }

    Context 'When running interactively' {
        BeforeEach {
            Mock -CommandName Read-Host -MockWith {
                return $script:MockReadHostResponse
            }
        }
        It 'Returns true when user input is yes' {
            $script:MockReadHostResponse = 'y'
            $result = Get-UserConfirmation -message "Test" -defaultValueForUser $false
            $result | Should -Be $true
            $script:MockReadHostResponse = 'Y'
            $result = Get-UserConfirmation -message "Test" -defaultValueForUser $false
            $result | Should -Be $true
        }
        It 'Returns false when user input is no' {
            $script:MockReadHostResponse = 'n'
            $result = Get-UserConfirmation -message "Test" -defaultValueForUser $true
            $result | Should -Be $false
            $script:MockReadHostResponse = 'N'
            $result = Get-UserConfirmation -message "Test" -defaultValueForUser $true
            $result | Should -Be $false
        }
        It 'Returns default true when user input is empty' {
            $script:MockReadHostResponse = ''
            $result = Get-UserConfirmation -message "Test"
            $result | Should -Be $true
        }
        It 'Returns true when user input is empty and default is true' {
            $script:MockReadHostResponse = ''
            $result = Get-UserConfirmation -message "Test" -defaultValueForUser $true
            $result | Should -Be $true
        }
        It 'Returns false when user input is empty and default is false' {
            $script:MockReadHostResponse = ''
            $result = Get-UserConfirmation -message "Test" -defaultValueForUser $false
            $result | Should -Be $false
        }
    }
}
