BeforeAll {
    # Load SUT
    $sut = (Split-Path -Leaf $PSCommandPath).Replace('.Tests.ps1', '.ps1')
    # Inhibit execution of Main function of SUT (loaded transitively via utils.ps1 -> bootstrap.ps1 chain)
    Set-Alias Main out-null
    $sutPath = Join-Path -Path $PSScriptRoot -ChildPath "..\$sut"
    . $sutPath
    Remove-Item Alias:Main
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
        Mock -CommandName Write-Warning -MockWith {}
        Mock -CommandName Write-Error -MockWith {}
        Mock -CommandName Invoke-CommandLine -MockWith {}
        Mock -CommandName Get-ScoopAppInstallInfo -MockWith { $null }
        Mock -CommandName Test-Path -MockWith { $false }
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
        # Pre-install: not installed. Post-install: installed successfully.
        $script:callCount = 0
        Mock -CommandName Get-ScoopAppInstallInfo -MockWith {
            $script:callCount++
            if ($script:callCount -le 1) { return $null }
            return @{ bucket = "some_bucket"; version = "0.0.1" }
        }

        # Act
        Import-ScoopFile -ScoopFilePath $scoopFilePath

        # Assert
        Should -Invoke -CommandName Write-Output -Exactly 1
        Should -Invoke -CommandName Write-Output -Exactly 1 -ParameterFilter { $InputObject -eq "Processing app: some_app" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -like "scoop install *" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -like "scoop reset *" }
        Should -Invoke -CommandName Write-Warning -Exactly 0
        Should -Invoke -CommandName Write-Error -Exactly 0
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
        # Pre-install: not installed. Post-install: installed from correct bucket with correct version.
        $script:appCallCounts = @{}
        Mock -CommandName Get-ScoopAppInstallInfo -MockWith {
            if (-not $script:appCallCounts[$AppName]) { $script:appCallCounts[$AppName] = 0 }
            $script:appCallCounts[$AppName]++
            if ($script:appCallCounts[$AppName] -le 1) { return $null }
            switch ($AppName) {
                "some_app" { return @{ bucket = "some_bucket"; version = "0.0.1" } }
                "another_app" { return @{ bucket = "another_bucket"; version = "0.0.2" } }
                "yet_another_app" { return @{ bucket = "another_bucket"; version = "0.0.3" } }
            }
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
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -eq "scoop update" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 3 -ParameterFilter { $CommandLine -like "scoop install */*@*" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 3 -ParameterFilter { $CommandLine -like "scoop reset */*@*" }
        Should -Invoke -CommandName Write-Warning -Exactly 0
        Should -Invoke -CommandName Write-Error -Exactly 0
    }

    It "shall uninstall app when installed from different bucket" {
        # Arrange
        $scoopFilePath = "scoopfile.json"
        Mock -CommandName Get-Content -MockWith {
            @"
            {
                "apps": [
                    {
                        "Name": "some_app",
                        "Source": "sple",
                        "Version": "1.0.0"
                    }
                ]
            }
"@
        }
        # Pre-install: installed from "main" with different version. Post-install: installed from "sple".
        $script:callCount = 0
        Mock -CommandName Get-ScoopAppInstallInfo -MockWith {
            $script:callCount++
            if ($script:callCount -le 1) { return @{ bucket = "main"; version = "1.0.1" } }
            return @{ bucket = "sple"; version = "1.0.0" }
        }

        # Act
        Import-ScoopFile -ScoopFilePath $scoopFilePath

        # Assert
        Should -Invoke -CommandName Write-Warning -Exactly 1 -ParameterFilter { $Message -like "*does not match config*" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -eq "scoop uninstall some_app --purge" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -eq "scoop install sple/some_app@1.0.0" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -eq "scoop reset sple/some_app@1.0.0" }
    }

    It "shall not uninstall app when installed from same bucket" {
        # Arrange
        $scoopFilePath = "scoopfile.json"
        Mock -CommandName Get-Content -MockWith {
            @"
            {
                "apps": [
                    {
                        "Name": "some_app",
                        "Source": "sple",
                        "Version": "1.0.0"
                    }
                ]
            }
"@
        }
        Mock -CommandName Get-ScoopAppInstallInfo -MockWith {
            return @{ bucket = "sple"; version = "1.0.0" }
        }

        # Act
        Import-ScoopFile -ScoopFilePath $scoopFilePath

        # Assert
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 0 -ParameterFilter { $CommandLine -like "scoop uninstall *" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -eq "scoop install sple/some_app@1.0.0" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -eq "scoop reset sple/some_app@1.0.0" }
        Should -Invoke -CommandName Write-Warning -Exactly 0
    }

    It "shall warn on version mismatch after install" {
        # Arrange
        $scoopFilePath = "scoopfile.json"
        Mock -CommandName Get-Content -MockWith {
            @"
            {
                "apps": [
                    {
                        "Name": "some_app",
                        "Source": "sple",
                        "Version": "1.0.0"
                    }
                ]
            }
"@
        }
        # Pre-install: not installed. Post-install: wrong version.
        $script:callCount = 0
        Mock -CommandName Get-ScoopAppInstallInfo -MockWith {
            $script:callCount++
            if ($script:callCount -le 1) { return $null }
            return @{ bucket = "sple"; version = "1.0.1" }
        }

        # Act
        Import-ScoopFile -ScoopFilePath $scoopFilePath

        # Assert
        Should -Invoke -CommandName Write-Warning -Exactly 1 -ParameterFilter { $Message -like "*Version mismatch*'1.0.0'*'1.0.1'*" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 0 -ParameterFilter { $CommandLine -like "scoop uninstall *" }
    }

    It "shall error when install fails completely" {
        # Arrange
        $scoopFilePath = "scoopfile.json"
        Mock -CommandName Get-Content -MockWith {
            @"
            {
                "apps": [
                    {
                        "Name": "some_app",
                        "Source": "sple",
                        "Version": "1.0.0"
                    }
                ]
            }
"@
        }
        # App never appears as installed
        Mock -CommandName Get-ScoopAppInstallInfo -MockWith { $null }

        # Act
        Import-ScoopFile -ScoopFilePath $scoopFilePath

        # Assert
        Should -Invoke -CommandName Write-Error -Exactly 1 -ParameterFilter { $Message -like "*Failed to install*some_app*" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 0 -ParameterFilter { $CommandLine -like "scoop reset *" }
    }

    It "shall continue processing remaining apps when scoop throws a terminating error" {
        # Arrange
        $scoopFilePath = "scoopfile.json"
        Mock -CommandName Get-Content -MockWith {
            @"
            {
                "apps": [
                    {
                        "Name": "failing_app",
                        "Source": "sple",
                        "Version": "1.0.0"
                    },
                    {
                        "Name": "good_app",
                        "Source": "sple",
                        "Version": "2.0.0"
                    }
                ]
            }
"@
        }
        # failing_app: never installed. good_app: succeeds after install.
        $script:appCallCounts = @{}
        Mock -CommandName Get-ScoopAppInstallInfo -MockWith {
            if (-not $script:appCallCounts[$AppName]) { $script:appCallCounts[$AppName] = 0 }
            $script:appCallCounts[$AppName]++
            if ($AppName -eq "failing_app") { return $null }
            if ($script:appCallCounts[$AppName] -le 1) { return $null }
            return @{ bucket = "sple"; version = "2.0.0" }
        }
        # First install of failing_app throws, retry also throws
        Mock -CommandName Invoke-CommandLine -MockWith {
            if ($CommandLine -eq "scoop install sple/failing_app@1.0.0") {
                throw "Move-Item : Cannot create a file when that file already exists."
            }
        }

        # Act
        Import-ScoopFile -ScoopFilePath $scoopFilePath

        # Assert - retry attempted (uninstall --purge called for failing_app)
        Should -Invoke -CommandName Invoke-CommandLine -ParameterFilter { $CommandLine -eq "scoop uninstall failing_app --purge" }
        # Warning indicates failure after retry
        Should -Invoke -CommandName Write-Warning -ParameterFilter { $Message -like "*Install of 'failing_app' failed*" }
        Should -Invoke -CommandName Write-Warning -ParameterFilter { $Message -like "*Failed to process app 'failing_app' after retry*" }
        # Second app still processed
        Should -Invoke -CommandName Write-Output -Exactly 1 -ParameterFilter { $InputObject -eq "Processing app: good_app" }
    }

    It "shall detect zombie app state and purge before install" {
        # Arrange
        $scoopFilePath = "scoopfile.json"
        Mock -CommandName Get-Content -MockWith {
            @"
            {
                "apps": [
                    {
                        "Name": "zombie_app",
                        "Source": "sple",
                        "Version": "1.0.0"
                    }
                ]
            }
"@
        }
        # App base directory exists (zombie) but Get-ScoopAppInstallInfo returns null pre-install,
        # then returns valid info after install
        Mock -CommandName Test-Path -MockWith { $true }
        $script:callCount = 0
        Mock -CommandName Get-ScoopAppInstallInfo -MockWith {
            $script:callCount++
            if ($script:callCount -le 1) { return $null }
            return @{ bucket = "sple"; version = "1.0.0" }
        }

        # Act
        Import-ScoopFile -ScoopFilePath $scoopFilePath

        # Assert - zombie detected and purged before install
        Should -Invoke -CommandName Write-Warning -Exactly 1 -ParameterFilter { $Message -like "*Zombie state detected*zombie_app*" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -eq "scoop uninstall zombie_app --purge" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -eq "scoop install sple/zombie_app@1.0.0" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -eq "scoop reset sple/zombie_app@1.0.0" }
    }

    It "shall retry install after purge when first attempt throws Cannot create a file error" {
        # Arrange
        $scoopFilePath = "scoopfile.json"
        Mock -CommandName Get-Content -MockWith {
            @"
            {
                "apps": [
                    {
                        "Name": "some_app",
                        "Source": "sple",
                        "Version": "1.0.0"
                    }
                ]
            }
"@
        }
        # Pre-install: not installed, no zombie. Post-retry: installed successfully.
        $script:callCount = 0
        Mock -CommandName Get-ScoopAppInstallInfo -MockWith {
            $script:callCount++
            # Call 1: pre-install check (not installed)
            # Call 2: retry check in catch block (installed successfully)
            if ($script:callCount -le 1) { return $null }
            return @{ bucket = "sple"; version = "1.0.0" }
        }
        # First install throws, retry (second call) succeeds
        $script:installCallCount = 0
        Mock -CommandName Invoke-CommandLine -MockWith {
            if ($CommandLine -eq "scoop install sple/some_app@1.0.0") {
                $script:installCallCount++
                if ($script:installCallCount -eq 1) {
                    throw "Move-Item : Cannot create a file when that file already exists."
                }
            }
        }

        # Act
        Import-ScoopFile -ScoopFilePath $scoopFilePath

        # Assert - retry succeeded
        Should -Invoke -CommandName Write-Warning -Exactly 1 -ParameterFilter { $Message -like "*Install of 'some_app' failed*Attempting cleanup and retry*" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -eq "scoop uninstall some_app --purge" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 2 -ParameterFilter { $CommandLine -eq "scoop install sple/some_app@1.0.0" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -eq "scoop reset sple/some_app@1.0.0" }
    }

    It "shall uninstall with purge and reinstall when post-install bucket does not match requested source" {
        # Arrange
        $scoopFilePath = "scoopfile.json"
        Mock -CommandName Get-Content -MockWith {
            @"
            {
                "apps": [
                    {
                        "Name": "some_app",
                        "Source": "sple",
                        "Version": "1.0.0"
                    }
                ]
            }
"@
        }
        # Pre-install: not installed. First post-install: wrong bucket. Second post-install: correct bucket.
        $script:callCount = 0
        Mock -CommandName Get-ScoopAppInstallInfo -MockWith {
            $script:callCount++
            if ($script:callCount -le 1) { return $null }
            if ($script:callCount -eq 2) { return @{ bucket = "main"; version = "1.0.1" } }
            return @{ bucket = "sple"; version = "1.0.0" }
        }

        # Act
        Import-ScoopFile -ScoopFilePath $scoopFilePath

        # Assert - wrong bucket detected, purged and reinstalled
        Should -Invoke -CommandName Write-Warning -Exactly 1 -ParameterFilter { $Message -like "*installed from bucket 'main' instead of 'sple'*Purging and reinstalling*" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -eq "scoop uninstall some_app --purge" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 2 -ParameterFilter { $CommandLine -eq "scoop install sple/some_app@1.0.0" }
        Should -Invoke -CommandName Invoke-CommandLine -Exactly 1 -ParameterFilter { $CommandLine -eq "scoop reset sple/some_app@1.0.0" }
    }
}

Describe "Get-ScoopAppInstallInfo" {
    It "shall return null when app is not installed" {
        # Arrange
        Mock -CommandName Test-Path -MockWith { $false }

        # Act
        $result = Get-ScoopAppInstallInfo -AppName "nonexistent_app"

        # Assert
        $result | Should -BeNullOrEmpty
    }

    It "shall return bucket and version when app is installed" {
        # Arrange
        Mock -CommandName Test-Path -MockWith { $true }
        Mock -CommandName Get-Content -MockWith {
            '{"bucket": "sple", "architecture": "64bit"}'
        } -ParameterFilter { $Path -like "*install.json" }
        Mock -CommandName Get-Content -MockWith {
            '{"version": "2.12.5"}'
        } -ParameterFilter { $Path -like "*manifest.json" }

        # Act
        $result = Get-ScoopAppInstallInfo -AppName "lessmsi"

        # Assert
        $result.bucket | Should -Be "sple"
        $result.version | Should -Be "2.12.5"
    }

    It "shall fall back to version directory when current junction is broken" {
        # Arrange
        $script:testPathCalls = @{}
        Mock -CommandName Test-Path -MockWith {
            # 'current' does not exist, but base dir and version files do
            if ($Path -like "*\current") { return $false }
            return $true
        }
        Mock -CommandName Get-ChildItem -MockWith {
            @([PSCustomObject]@{ Name = "26.01"; FullName = "C:\Users\test\scoop\apps\7zip\26.01"; LastWriteTime = (Get-Date) })
        }
        Mock -CommandName Get-Content -MockWith {
            '{"bucket": "main", "architecture": "64bit"}'
        } -ParameterFilter { $Path -like "*install.json" }
        Mock -CommandName Get-Content -MockWith {
            '{"version": "26.01"}'
        } -ParameterFilter { $Path -like "*manifest.json" }

        # Act
        $result = Get-ScoopAppInstallInfo -AppName "7zip"

        # Assert
        $result.bucket | Should -Be "main"
        $result.version | Should -Be "26.01"
    }

    It "shall pick highest version directory when multiple exist and current is broken" {
        # Arrange
        Mock -CommandName Test-Path -MockWith {
            if ($Path -like "*\current") { return $false }
            return $true
        }
        # Intentionally give 23.01 the newest LastWriteTime to prove version sort wins
        Mock -CommandName Get-ChildItem -MockWith {
            @(
                [PSCustomObject]@{ Name = "23.01"; FullName = "C:\Users\test\scoop\apps\7zip\23.01"; LastWriteTime = (Get-Date "2026-05-08") },
                [PSCustomObject]@{ Name = "26.00"; FullName = "C:\Users\test\scoop\apps\7zip\26.00"; LastWriteTime = (Get-Date "2026-01-01") },
                [PSCustomObject]@{ Name = "26.01"; FullName = "C:\Users\test\scoop\apps\7zip\26.01"; LastWriteTime = (Get-Date "2025-12-01") }
            )
        }
        Mock -CommandName Get-Content -MockWith {
            '{"bucket": "sple", "architecture": "64bit"}'
        } -ParameterFilter { $Path -like "*install.json" }
        Mock -CommandName Get-Content -MockWith {
            '{"version": "26.01"}'
        } -ParameterFilter { $Path -like "*manifest.json" }

        # Act
        $result = Get-ScoopAppInstallInfo -AppName "7zip"

        # Assert - must pick 26.01 (highest version), not 23.01 (newest timestamp)
        $result.bucket | Should -Be "sple"
        $result.version | Should -Be "26.01"
    }

    It "shall return null when app base dir does not exist" {
        # Arrange
        Mock -CommandName Test-Path -MockWith { $false }

        # Act
        $result = Get-ScoopAppInstallInfo -AppName "nonexistent_app"

        # Assert
        $result | Should -BeNullOrEmpty
    }
}
