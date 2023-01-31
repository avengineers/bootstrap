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
