# Bootstrap

This is a set of bootstrap scripts to

- initialize proxy settings
- install scoop, if required
- install python packages, if required
- install pipenv, if required
- install west, if required

You can execute and use it by:

```powershell
(New-Object System.Net.WebClient).DownloadFile("https://raw.githubusercontent.com/avengineers/bootstrap/develop/bootstrap.ps1",".\bootstrap.ps1")
. .\\bootstrap.ps1
```

In case a proxy is required, it is important that the main project that uses the bootstrap, has a `.env` file containing the following two variables:


```
HTTP_PROXY
NO_PROXY
```

The `.env` file is used, even if there is no pipenv in place.

The test execution requires two PowerShell modules to be installed:

* `Install-Module -Name Pester -Force -SkipPublisherCheck`
* `Install-Module -Name PSScriptAnalyzer -Force`
