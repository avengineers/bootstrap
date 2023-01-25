This is a set of bootstrap scripts to
- initialize proxy settings
- install scoop, if required
- install python packages, if required
- install pipenv, if required
- install west, if required

You can execute and use it by:

```powershell
(New-Object System.Net.WebClient).DownloadFile("https://git.marquardt.de/projects/SWSDRM/repos/bootstrap/raw/bootstrap.ps1",".\\bootstrap.ps1")
. .\\bootstrap.ps1
```