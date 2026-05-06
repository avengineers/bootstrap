BeforeDiscovery {
    $toBeAnalysed = (Get-ChildItem -Path $PSScriptRoot -Depth 0 -Filter "*.ps1").FullName
    $toBeAnalysed += (Get-ChildItem -Path "$PSScriptRoot\.." -Depth 0 -Filter "*.ps1").FullName
}

Describe 'Analysis of file <_> against Script Analyzer Rules' -ForEach $toBeAnalysed {
    It "Shall not have deviations" {
        $analysisRules = Get-ScriptAnalyzerRule -Severity Warning, Error
        $analysisResult = Invoke-ScriptAnalyzer -IncludeRule $analysisRules -Path $_
        if ($analysisResult) {
            $ScriptAnalyzerResultString = $analysisResult | Out-String
            Write-Warning $ScriptAnalyzerResultString
        }
        $analysisResult | Should -BeNullOrEmpty
    }
}

Describe 'UTF-8 BOM check for file <_>' -ForEach $toBeAnalysed {
    It "Shall not contain a UTF-8 BOM" {
        $bytes = [System.IO.File]::ReadAllBytes($_)
        if ($bytes.Length -ge 3) {
            $hasBom = ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
            $hasBom | Should -BeFalse -Because "UTF-8 BOM breaks Invoke-Expression piping on PowerShell 5.1"
        }
    }
}
