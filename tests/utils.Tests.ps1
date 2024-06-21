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
