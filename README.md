# Bootstrap

This is a set of bootstrap PowerShell functions to

- initialize proxy settings, if required,
- install scoop, if required,
- install python packages, if required,
- install pipenv, if required,
- install west, if required.

You can execute and use them by:

```powershell
(New-Object System.Net.WebClient).DownloadFile("https://raw.githubusercontent.com/avengineers/bootstrap/develop/bootstrap.ps1",".\bootstrap.ps1")
. .\bootstrap.ps1
```

In case a proxy is required, it is important that the project that uses the bootstrap, has a `.env` file containing the following variables:

```properties
HTTP_PROXY=<proxy url>
HTTPS_PROXY=<proxy url>
NO_PROXY=<domain suffixes to be excluded>
```

The `.env` file is used, even if there is no pipenv in place.

The test execution requires two PowerShell modules to be installed:

* `Install-Module -Name Pester -Force -SkipPublisherCheck`
* `Install-Module -Name PSScriptAnalyzer -Force`
