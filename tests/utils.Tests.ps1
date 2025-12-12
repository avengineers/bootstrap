BeforeAll {
    # Load SUT
    $sut = (Split-Path -Leaf $PSCommandPath).Replace('.Tests.ps1', '.ps1')
    # Inhibit execution of Main function of SUT
    Set-Alias Main out-null
    $sutPath = Join-Path -Path $PSScriptRoot -ChildPath "..\$sut"
    . $sutPath
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

Describe "Convert-ScoopFileJsonToHashTable" {
    It "shall convert an empty scoopfile.json to a hashtable" {
        # Arrange
        $scoopFileJson = "{}"

        # Act
        $result = Convert-ScoopFileJsonToHashTable -ScoopFileJson $scoopFileJson

        # Assert
        $result.buckets.Count | Should -Be 0
        $result.buckets | Should -Be @()
        $result.apps.Count | Should -Be 0
        $result.apps | Should -Be @()
    }

    It "shall convert a scoopfile.json with apps to a hashtable" {
        # Arrange
        $scoopFileJson = @"
        {
            "apps": [
                {
                    "Name": "some_app",
                    "Source": "some_bucket",
                    "Version": "0.0.1"
                }
            ]
        }
"@

        # Act
        $result = Convert-ScoopFileJsonToHashTable -ScoopFileJson $scoopFileJson

        # Assert
        $result.buckets.Count | Should -Be 0
        $result.buckets | Should -Be @()
        $result.apps.Count | Should -Be 1
        $result.apps.Name | Should -Be "some_app"
        $result.apps.Source | Should -Be "some_bucket"
        $result.apps.Version | Should -Be "0.0.1"
    }

    It "shall convert a scoopfile.json with buckets to a hashtable" {
        # Arrange
        $scoopFileJson = @"
        {
            "buckets": [
                {
                    "Name": "some_bucket",
                    "Source": "https://example.com"
                }
            ]
        }
"@

        # Act
        $result = Convert-ScoopFileJsonToHashTable -ScoopFileJson $scoopFileJson

        # Assert
        $result.buckets.Count | Should -Be 1
        $result.buckets.Name | Should -Be "some_bucket"
        $result.buckets.Source | Should -Be "https://example.com"
        $result.apps.Count | Should -Be 0
        $result.apps | Should -Be @()
    }

    It "shall convert a scoopfile.json with apps and buckets to a hashtable" {
        # Arrange
        $scoopFileJson = @"
        {
            "buckets": [
                {
                    "Name": "some_bucket",
                    "Source": "https://example.com"
                },
                {
                    "Name": "another_bucket",
                    "Source": "https://another.com"
                }
            ],
            "apps": [
                {
                    "Name": "some_app",
                    "Source": "some_bucket",
                    "Version": "0.0.1"
                },
                {
                    "Name": "another_app",
                    "Source": "another_bucket",
                    "Version": "0.0.2"
                },
                {
                    "Name": "yet_another_app",
                    "Source": "another_bucket",
                    "Version": "0.0.3"
                }
            ]
        }
"@

        # Act
        $result = Convert-ScoopFileJsonToHashTable -ScoopFileJson $scoopFileJson

        # Assert
        $result.buckets.Count | Should -Be 2
        $result.buckets[0].Name | Should -Be "some_bucket"
        $result.buckets[0].Source | Should -Be "https://example.com"
        $result.buckets[1].Name | Should -Be "another_bucket"
        $result.buckets[1].Source | Should -Be "https://another.com"
        $result.apps.Count | Should -Be 3
        $result.apps[0].Name | Should -Be "some_app"
        $result.apps[0].Source | Should -Be "some_bucket"
        $result.apps[0].Version | Should -Be "0.0.1"
        $result.apps[1].Name | Should -Be "another_app"
        $result.apps[1].Source | Should -Be "another_bucket"
        $result.apps[1].Version | Should -Be "0.0.2"
        $result.apps[2].Name | Should -Be "yet_another_app"
        $result.apps[2].Source | Should -Be "another_bucket"
        $result.apps[2].Version | Should -Be "0.0.3"
    }
}

Describe "Import-ScoopFile" {
    BeforeEach {
        Mock -CommandName Write-Output -MockWith {}
        Mock -CommandName Invoke-CommandLine -MockWith {}
    }

    It "shall import an empty scoopfile.json" {
        # Arrange
        $scoopFilePath = "scoopfile.json"
        Mock -CommandName Get-Content -MockWith { "{}" }

        # Act
        Import-ScoopFile -ScoopFilePath $scoopFilePath

        # Assert
        Should -Invoke -CommandName Write-Output -Exactly 0
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 0
    }

    It "shall import a scoopfile.json with apps" {
        # Arrange
        $scoopFilePath = "scoopfile.json"
        Mock -CommandName Get-Content -MockWith {
            @"
            {
                "apps": [
                    {
                        "Name": "some_app",
                        "Source": "some_bucket",
                        "Version": "0.0.1"
                    }
                ]
            }
"@
        }

        # Act
        Import-ScoopFile -ScoopFilePath $scoopFilePath

        # Assert
        Should -Invoke -CommandName Write-Output -Exactly 1
        Should -Invoke -CommandName Write-Output -Exactly 1 -ParameterFilter { $InputObject -eq "Processing app: some_app" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -eq "scoop install some_bucket/some_app@0.0.1" }
    }

    It "shall import a scoopfile.json with buckets and apps" {
        # Arrange
        $scoopFilePath = "scoopfile.json"
        Mock -CommandName Get-Content -MockWith {
            @"
            {
                "buckets": [
                    {
                        "Name": "some_bucket",
                        "Url": "https://example.com"
                    },
                    {
                        "Name": "another_bucket",
                        "Url": "https://another.com"
                    }
                ],
                "apps": [
                    {
                        "Name": "some_app",
                        "Source": "some_bucket",
                        "Version": "0.0.1"
                    },
                    {
                        "Name": "another_app",
                        "Source": "another_bucket",
                        "Version": "0.0.2"
                    },
                    {
                        "Name": "yet_another_app",
                        "Source": "another_bucket",
                        "Version": "0.0.3"
                    }
                ]
            }
"@
        }

        # Act
        Import-ScoopFile -ScoopFilePath $scoopFilePath

        # Assert
        Should -Invoke -CommandName Write-Output -Exactly 5
        Should -Invoke -CommandName Write-Output -Exactly 1 -ParameterFilter { $InputObject -eq "Processing bucket: some_bucket" }
        Should -Invoke -CommandName Write-Output -Exactly 1 -ParameterFilter { $InputObject -eq "Processing bucket: another_bucket" }
        Should -Invoke -CommandName Write-Output -Exactly 1 -ParameterFilter { $InputObject -eq "Processing app: some_app" }
        Should -Invoke -CommandName Write-Output -Exactly 1 -ParameterFilter { $InputObject -eq "Processing app: another_app" }
        Should -Invoke -CommandName Write-Output -Exactly 1 -ParameterFilter { $InputObject -eq "Processing app: yet_another_app" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 2 -ParameterFilter { $CommandLine -like "scoop bucket add *" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 3 -ParameterFilter { $CommandLine -like "scoop install */*@*" }
    }
}

Describe "Test-RunningInCIorTestEnvironment" {
    It "shall return true when running in a CI or test environment" {
        $Env:PYTEST_CURRENT_TEST = "1"
        $Env:GITHUB_ACTIONS = ""
        $Env:JENKINS_URL = ""

        Test-RunningInCIorTestEnvironment | Should -Be $true
    }

    It "shall return false when not running in a CI or test environment" {
        $Env:PYTEST_CURRENT_TEST = ""
        $Env:GITHUB_ACTIONS = ""
        $Env:JENKINS_URL = ""

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
