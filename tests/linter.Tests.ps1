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
