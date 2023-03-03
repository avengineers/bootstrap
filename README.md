# Bootstrap

This repository provides an easy way to setup a Python and/or West based project under Windows.

## Creation of Initial Project Structure

* Download [bootstrap.ps1](https://github.com/avengineers/bootstrap/raw/develop/bootstrap.ps1) to a directory of your choice.
* Start a powershell console in that directory and run:

  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force
  ```

* Depending on whether your are behind a proxy or not run the downloaded bootstrap.ps1 with or without the parameter -proxy. (Adapt the command line parameters 'projectDirectory' and 'http://your.proxy.here' to your needs.)
  * With Proxy:

    ```powershell
    .\bootstrap.ps1 -init projectDirectory -proxy http://your.proxy.here
    ```

  * Without Proxy:

    ```powershell
    .\bootstrap.ps1 -init projectDirectory
    ```

* After that a minimal project structure is available.
* Change to the created project directory and run `ls`:

  ```powershell
  cd projectDirectory
  ls

  Mode                 LastWriteTime         Length Name
  ----                 -------------         ------ ----
  -a---          16.02.2023    17:52            114 .env
  -a---          16.02.2023    17:52             89 build.bat
  -a---          16.02.2023    17:52           3357 build.ps1
  -a---          16.02.2023    17:52            503 scoopfile.json
  ```

* Call build.ps1 to install the initial project dependencies (currently just Scoop and Python, see scoopfile.json):

  ```powershell
  .\build.ps1 -install
  ```

* As stated at the end of the previous command restart the powershell console and call build.ps1 (does nothing but an echo):

  ```powershell
  .\build.ps1
  ```

* Final file structure:

  ```powershell
  ls

  Mode                 LastWriteTime         Length Name
  ----                 -------------         ------ ----
  d-----         2/22/2023  10:20 AM                .bootstrap
  -a----         2/22/2023  10:20 AM            117 .env
  -a----         2/22/2023  10:20 AM             92 build.bat
  -a----         2/22/2023  10:20 AM           3374 build.ps1
  -a----         2/22/2023  10:20 AM            506 scoopfile.json
  ```

  * ```.bootstrap```: directory with helper scripts for installation (created and updated automatically)
  * ```.env```: environment definition for build script and Python environment
  * ```build.bat```: Windows console wrapper for build script 'build.ps1'
  * ```build.ps1```: build script to be adapted to your needs
  * ```scoopfile.json```: package definition list to be installed via scoop. Can be adapted for additional needed packages for your build.

* Further steps:
  * Creation of virtual Python environment:

    ```powershell
    New-Item -ItemType Directory .venv
    New-Item -ItemType File Pipfile
    .\build.ps1 -install
    ```
