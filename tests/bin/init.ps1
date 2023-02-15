#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Write-Output "PowerShell: $($PSVersionTable.PSVersion)"

Write-Output 'Check and install dependencies ...'
if (Get-InstalledModule -Name Pester -MinimumVersion 5.2 -MaximumVersion 5.99 -ErrorAction SilentlyContinue) {
    Write-Output 'Pester 5 is already installed.'
} else {
    Write-Output 'Installing Pester 5 ...'
    Install-Module -Repository PSGallery -Scope CurrentUser -Force -Name Pester -MinimumVersion 5.2 -MaximumVersion 5.99 -SkipPublisherCheck
}
if (Get-InstalledModule -Name PSScriptAnalyzer -MinimumVersion 1.17 -ErrorAction SilentlyContinue) {
    Write-Output 'PSScriptAnalyzer is already installed.'
} else {
    Write-Output 'Installing PSScriptAnalyzer ...'
    Install-Module -Repository PSGallery -Scope CurrentUser -Force -Name PSScriptAnalyzer -SkipPublisherCheck
}
