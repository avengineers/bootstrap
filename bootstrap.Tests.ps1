# to execute tests you have to
# 1. Update 'Pester': "Install-Module -Name Pester -Force -SkipPublisherCheck"
# 2. call "Invoke-Pester spl-functions.Tests.ps1" from within the test directory
# Note: I noticed that sometimes after a test was changed it will fail with a overloading problem; retry helps

$WebProxy = [net.webrequest]::defaultwebproxy

BeforeAll {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Variable i used in included script.')]
  $TestExecution = $true
  . .\bootstrap.ps1
}

Describe "invoking command line calls" {
  BeforeEach {
    Mock -CommandName Write-Information -MockWith {}
    $global:LASTEXITCODE = 0
  }

  It "shall not write the command to console if silent" {
    Invoke-CommandLine -CommandLine "echo test" -Silent $true -StopAtError $true
    Should -Invoke -CommandName Write-Information -Times 0
  }

  It "shall write the command to console as default" {
    Invoke-CommandLine -CommandLine "echo test"
    Should -Invoke -CommandName Write-Information -Times 1
  }

  It "shall print an error on failure" {
    $ErrorActionPreference = "Stop"
    Mock -CommandName Invoke-Expression -MockWith { $global:LASTEXITCODE = 1 }

    Invoke-CommandLine -CommandLine "echo test" -Silent $false -StopAtError $false
    Should -Invoke -CommandName Write-Information -Times 2
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
    [net.webrequest]::defaultwebproxy = $WebProxy
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
    Mock -CommandName Write-Information -MockWith {}

    Initialize-Proxy
    $Env:NO_PROXY | Should -Be $null
    $Env:HTTP_PROXY | Should -Be "http://my.proxy"
  }

  It "shall set http proxy and no-proxy" {
    Mock -CommandName Test-Path -MockWith { $true }
    Mock -CommandName Get-Content -MockWith { "HTTP_PROXY=http://my.proxy`nNO_PROXY=github.com" }
    Mock -CommandName Write-Information -MockWith {}

    Initialize-Proxy
    $Env:NO_PROXY | Should -Be "github.com"
    $Env:HTTP_PROXY | Should -Be "http://my.proxy"
  }
}

Describe "install scoop" {
  BeforeEach {
    Mock -CommandName Invoke-Expression -MockWith {}
    Mock -CommandName Invoke-CommandLine -MockWith {}
    Mock -CommandName Edit-Env -MockWith {}
  }

  It "shall not run scoop if no scoopfile exists" {
    Mock -CommandName Test-Path -MockWith { $false }

    Install-Scoop
    Should -Invoke -CommandName Invoke-Expression -Times 0
    Should -Invoke -CommandName Invoke-CommandLine -Times 0
    Should -Invoke -CommandName Edit-Env -Times 0
  }

  It "shall run scoop if scoopfile exists" {
    Mock -CommandName Test-Path -MockWith { $true }
    Mock -CommandName Test-Path -MockWith { $true }

    Install-Scoop
    Should -Invoke -CommandName Invoke-CommandLine -Times 4
    Should -Invoke -CommandName Edit-Env -Times 1
  }
}

Describe "install python deps" {
  BeforeEach {
    Mock -CommandName Invoke-CommandLine -MockWith {}
    Mock -CommandName Edit-Env -MockWith {}
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
    Mock -CommandName Edit-Env -MockWith {}
  }

  It "shall not run west if no west config exists" {
    Mock -CommandName Test-Path -MockWith { $false }

    Install-West
    Should -Invoke -CommandName Invoke-CommandLine -Times 0
    Should -Invoke -CommandName Edit-Env -Times 0
  }

  It "shall run west if west config exists" {
    Mock -CommandName Test-Path -MockWith { $true }
    Mock -CommandName Test-Path -MockWith { $false } -ParameterFilter { $Path -eq ".venv" }

    Install-West
    Should -Invoke -CommandName Invoke-CommandLine -Times 2
    Should -Invoke -CommandName Edit-Env -Times 1
  }

  It "shall run west if west config exists and use existing .venv" {
    Mock -CommandName Test-Path -MockWith { $true }
    Mock -CommandName Test-Path -MockWith { $true } -ParameterFilter { $Path -eq ".venv" }

    Install-West
    Should -Invoke -CommandName Invoke-CommandLine -Times 2
    Should -Invoke -CommandName Edit-Env -Times 1
  }
}
