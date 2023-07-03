BeforeAll {
    # Load SUT
    $sut = (Split-Path -Leaf $PSCommandPath).Replace('.Tests.ps1', '.ps1')
    # Inhibit execution of Main function of SUT
    Set-Alias Main out-null
    . ".\$sut"
    Remove-Item Alias:Main
}

Describe "Initialize a new project directory" {
    BeforeEach {
        # Prepare test output folder
        $testData = Join-Path $PSScriptRoot 'out\bootstrap\init'
        if (Test-Path $testData) {
            Remove-Item $testData -Recurse -Force
        }
    }

    It "Shall create project directory and files" {
        Initialize-Directory $testData

        Test-Path (Join-Path $testData 'build.bat') | Should -Be $true
        Test-Path (Join-Path $testData 'build.ps1') | Should -Be $true
        Test-Path (Join-Path $testData 'scoopfile.json') | Should -Be $true
    }

    It "Shall create directory with proxy config" {
        Initialize-Directory $testData "http://someproxy"

        Test-Path $testData | Should -Be $true
        Test-Path (Join-Path $testData '.env') | Should -Be $true
        (Join-Path $testData '.env') | Should -FileContentMatch 'HTTPS_PROXY=http://someproxy'
    }
}

Describe "Create a file with confirmation" {
    BeforeAll {
        $testData = Join-Path $PSScriptRoot 'out\bootstrap\fileCreate'
        # Remove any created test data
        if (Test-Path $testData) {
            Remove-Item $testData -Recurse -Force
        }
    }
    It "Shall create a file" {
        $testFile = Join-Path $testData 'someFile'

        Initialize-File-With-Confirmation $testFile "some content to be written into that file"

        Test-Path $testFile | Should -Be $true
    }
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
        Mock -CommandName Invoke-Expression -MockWith {}
        Mock -CommandName Invoke-CommandLine -MockWith {}
        Mock -CommandName Initialize-EnvPath -MockWith {}
    }

    It "shall not run scoop if no scoopfile exists" {
        Mock -CommandName Test-Path -MockWith { $false }

        Install-Scoop
        Should -Invoke -CommandName Invoke-Expression -Times 0
        Should -Invoke -CommandName Invoke-CommandLine -Times 0
        Should -Invoke -CommandName Initialize-EnvPath -Times 0
    }

    It "shall run scoop if scoopfile exists" {
        Mock -CommandName Test-Path -MockWith { $true }
        Mock -CommandName Get-Command -MockWith { $true }

        Install-Scoop
        Should -Invoke -CommandName Invoke-CommandLine -Times 4
        Should -Invoke -CommandName Initialize-EnvPath -Times 1
    }
}

Describe "install python deps" {
    BeforeEach {
        Mock -CommandName Invoke-CommandLine -MockWith {}
    }

    It "shall not run python deps installation if no deps are given" {
        Mock -CommandName Test-Path -MockWith { $false }

        Install-Python-Dependency
        Should -Invoke -CommandName Invoke-CommandLine -Times 0
    }

    It "shall run python deps installation if requirements.txt exists and create .venv directory" {
        Mock -CommandName New-Item -MockWith {}
        Mock -CommandName Test-Path -MockWith { $false }
        Mock -CommandName Test-Path -MockWith { $true } -ParameterFilter { $Path -eq "requirements.txt" }

        Install-Python-Dependency
        Should -Invoke -CommandName Invoke-CommandLine -Times 2
        Should -Invoke -CommandName New-Item -Times 1
    }

    It "shall run python deps installation if Pipfile exists and create .venv directory" {
        Mock -CommandName New-Item -MockWith {}
        Mock -CommandName Test-Path -MockWith { $false }
        Mock -CommandName Test-Path -MockWith { $true } -ParameterFilter { $Path -eq "Pipfile" }

        Install-Python-Dependency
        Should -Invoke -CommandName Invoke-CommandLine -Times 2
        Should -Invoke -CommandName New-Item -Times 1
    }

    It "shall run python deps installation if Pipfile exists and create .venv directory" {
        Mock -CommandName New-Item -MockWith {}
        Mock -CommandName Test-Path -MockWith { $false }
        Mock -CommandName Test-Path -MockWith { $true } -ParameterFilter { $Path -eq ".venv" }
        Mock -CommandName Test-Path -MockWith { $true } -ParameterFilter { $Path -eq "Pipfile" }

        Install-Python-Dependency
        Should -Invoke -CommandName Invoke-CommandLine -Times 1
        Should -Invoke -CommandName New-Item -Times 0
    }
}

Describe "install west" {
    BeforeEach {
        Mock -CommandName Invoke-CommandLine -MockWith {}
        Mock -CommandName New-Item -MockWith {}
    }

    It "shall install west if no west config exists" {
        Mock -CommandName Test-Path -MockWith { $false } -ParameterFilter { $Path -eq '.west/config' }

        Install-West

        Should -Invoke -CommandName Invoke-CommandLine -Times 0
        Should -Invoke -CommandName New-Item -Times 0
    }

    It "shall install west if west config exists" {
        Mock -CommandName Test-Path -MockWith { $true } -ParameterFilter { $Path -eq '.west/config' }
        Mock -CommandName Test-Path -MockWith { $false } -ParameterFilter { $Path -eq ".venv" }

        Install-West

        Should -Invoke -CommandName Invoke-CommandLine -Times 1
        Should -Invoke -CommandName New-Item -Times 1
    }

    It "shall install west if west config exists and .venv exists" {
        Mock -CommandName Test-Path -MockWith { $true } -ParameterFilter { $Path -eq '.west/config' }
        Mock -CommandName Test-Path -MockWith { $true } -ParameterFilter { $Path -eq ".venv" }

        Install-West

        Should -Invoke -CommandName Invoke-CommandLine -Times 1
        Should -Invoke -CommandName New-Item -Times 0
    }
}
