BeforeAll {
    $testData = Join-Path $PSScriptRoot 'out\build'
    $testDataWithProxy = Join-Path $testData 'withProxy'
    $testDataWithoutProxy = Join-Path $testData 'withoutProxy'

    # Remove any created test data
    if (Test-Path $testData) {
        Remove-Item $testData -Recurse -Force
    }
    # Execute bootstrap.ps1
    powershell -Command "$PSScriptRoot\..\bootstrap.ps1 -init `"$testDataWithProxy`" -proxy http://some.proxy.de:8080"
    powershell -Command "$PSScriptRoot\..\bootstrap.ps1 -init `"$testDataWithoutProxy`""

    # Load created build script for testing
    # Inhibit execution of Main function of SUT
    Set-Alias Main out-null
    . "$testDataWithProxy\build.ps1"
    Remove-Item Alias:Main
}

Describe "Full integration tests for project creation" {
    It "Shall create project directory structure with executable build script" {
        Test-Path (Join-Path $testDataWithoutProxy 'build.bat') | Should -Be $true
        Test-Path (Join-Path $testDataWithoutProxy 'build.ps1') | Should -Be $true
        Test-Path (Join-Path $testDataWithoutProxy '.env') | Should -Be $false
        powershell -Command "$testDataWithoutProxy\build.ps1 -install"
        $LASTEXITCODE | Should -Be 0
        Test-Path (Join-Path $testDataWithoutProxy '.bootstrap\bootstrap.ps1') | Should -Be $true
        Test-Path (Join-Path $Env:USERPROFILE "scoop") | Should -Be $true
    }

    It "Shall create project directory structure" {
        Test-Path (Join-Path $testDataWithProxy 'build.bat') | Should -Be $true
        Test-Path (Join-Path $testDataWithProxy 'build.ps1') | Should -Be $true
        Test-Path (Join-Path $testDataWithProxy '.env') | Should -Be $true
        (Join-Path $testDataWithProxy '.env') | Should -FileContentMatch 'HTTPS_PROXY=http://some.proxy.de:8080'
    }
}

Describe "importing .env file" {
    It "shall not load environment file if not existing" {
        Mock -CommandName Test-Path -MockWith { $false }

        $envProps = Import-Dot-Env
        $envProps | Should -Be $null
    }

    It "shall load environment file to variable" {
        Mock -CommandName Test-Path -MockWith { $true }
        Mock -CommandName Get-Content -MockWith { "my_variable=my_content" }

        $envProps = Import-Dot-Env
        $envProps.my_variable | Should -Be "my_content"
    }
}

Describe "initialize proxy settings" {
    BeforeEach {
        $Env:NO_PROXY = ""
        $Env:HTTP_PROXY = ""
    }

    AfterEach {
        $Env:NO_PROXY = ""
        $Env:HTTP_PROXY = ""
        [net.webrequest]::defaultwebproxy = New-Object System.Net.WebProxy
    }

    It "shall not do anything if proxy was not defined in .env" {
        Mock -CommandName Import-Dot-Env -MockWith {}
        Mock -CommandName New-Object -MockWith {}

        Initialize-Proxy
        Should -Invoke -CommandName Import-Dot-Env -Times 1
        Should -Invoke -CommandName New-Object -Times 0
    }

    It "shall set http proxy" {
        Mock -CommandName Test-Path -MockWith { $true }
        Mock -CommandName Get-Content -MockWith { "HTTP_PROXY=http://my.proxy" }
        Mock -CommandName Write-Output -MockWith {}

        Initialize-Proxy
        $Env:NO_PROXY | Should -Be $null
        $Env:HTTP_PROXY | Should -Be "http://my.proxy"
    }

    It "shall set http proxy and no-proxy" {
        Mock -CommandName Test-Path -MockWith { $true }
        Mock -CommandName Get-Content -MockWith { "HTTP_PROXY=http://my.proxy`nNO_PROXY=github.com" }
        Mock -CommandName Write-Output -MockWith {}

        Initialize-Proxy
        $Env:NO_PROXY | Should -Be "github.com"
        $Env:HTTP_PROXY | Should -Be "http://my.proxy"
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

Describe "Analysis of generated build script 'build.ps1' against Script Analyzer Rules" {
    It "Shall not have deviations" {
        $analysisRules = Get-ScriptAnalyzerRule -Severity Warning, Error
        $analysisResult = Invoke-ScriptAnalyzer -IncludeRule $analysisRules -Path "$testDataWithProxy\build.ps1"
        if ($analysisResult) {
            $ScriptAnalyzerResultString = $analysisResult | Out-String
            Write-Warning $ScriptAnalyzerResultString
        }
        $analysisResult | Should -BeNullOrEmpty
    }
}