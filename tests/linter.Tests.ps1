BeforeDiscovery {
    $toBeAnalysed = Get-ChildItem -Path $PSScriptRoot -Include "*.ps1" -Depth 0
    $toBeAnalysed += Get-ChildItem -Path "$PSScriptRoot\.." -Include *.ps1 -Depth 0
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
