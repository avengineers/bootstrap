# Bootstrap

## Requirements

* [x] The powershell code shall be kept at minimum.
* [x] Usage of bootstrap: there shall be "one" liner of powershell to get the bootstrap script and start it.
* [x] Bootstrap shall be idempotent.
* [x] Bootstrap shall keep track of the dependencies and do incremental installs.
* [x] it should support both on-premise and public dependencies
  * [x] this means that bootstrap shall also work without internet connection, only intranet
* [x] the bootstrap shall create the virtual environment with the python version configured by the user
* [x] bootstrap shall run for users without administrative rights
* [x] bootstrap shall use semantic versioning
* [x] bootstrap shall have a configuration file for the user to define parameters like python version, python package manager, scoop installer, scoop python json base url 


Why do we need a bootstrap?

* scoop - package manager for Windows
  * we need it to install all tools a project needs
  * scoop is implemented in powershell
* powershell - available on all Windows machines
  * no batch
* python


**avengineers/bootstrap**

* install scoop - only if there is a scoopfile.json in the project
* install dependencies out of the scoop file json - only if there is a scoopfile.json in the project
* install pipenv - only if there is a pipfile in the project
* use pipenv to create the virtual environment

Problem with the scoop install:

If you have the version of a tool already installed, the shims for that tool are not updated!
We need to have the shims updated because we need them to point to the version that we just want to install.

Bootstrap is using scoop import and not a scoop install.

Scoop import will not reset the shims:

```json
        {
            "Source": "sple",
            "Name": "mingw-winlibs-llvm-ucrt",
            "Version": "13.2.0-16.0.6-11.0.0-r1"
        },
```

There is a PR from Karsten to add a `--reset` option for import.


**pypackage-template/bootstrap**

* install scoop
* install python with the configured version (see bootstrap.json)
* start bootstrap.py
  * create venv
  * installs poetry in venv
  * starts poetry to install all dependencies in venv (based on pyproject.toml)


```json
{
  "python_version": "3.10",
  "python_package_manager": "poetry>=1.7.1",
  "scoop_installer": "https://raw.githubusercontent.com/ScoopInstaller/Install/master/install.ps1",
  "scoop_python_json_base_url": "https://raw.githubusercontent.com/ScoopInstaller/Versions/master/bucket",
  "bootstrap_version": "0.5.1"
}
```

**Deploy bootstrap as an exe**

Disadvantages:

* installer is quite big
* installer might be slow if it needs to unpack the exe
* (!) the anti-virus software might mark it as a trojan (false positive)

Advantages:

* easy to install
* it can be a standalone python application using any python module


**Use case**

We want to use Python 3.12 in a project. What do I have to do?

* in the **pypackage-template/bootstrap** we need to update the bootstrap.json
* in the **avengineers/bootstrap** we need to update the scoopfile.json

**Use case**

Some colleagues do not have administrative rights and get Python installed by IT with admin rights.
The python path is added to the **system** PATH environment variable.
This means that the python from the system path will be found before the user path.

The problem is that build.ps1 calls `python.exe` in order to execute python scripts.
This means a different python version (3.12 instead of 3.10) might be use. 

**Use case**

If I am in VS Code and the virtual environment is activated, VS code will run python in the background.
This means that cleaning and recreating the virtual environment will not work because VS Code keeps a handle on the python.exe.

One needs to close VS Code and run bootstrap again.

## Steps to be executed to build an SPL project on a fresh Windows machine

* install scoop to be able to install tools with scoop
* install tools with scoop (python included)
* install pipenv (or poetry) with python to be able to create a virtual environment
  * we need a virtual environment to install the dependencies of the project (SPL-Core needs python)
* run pipenv to create the virtual environment
* run the build with the user defined targets

## Steps to be executed to build a Python package on a fresh Windows machine

* install scoop to be able to install tools with scoop
* install tools with scoop (python included)
* install pipenv (or poetry) with python to be able to create a virtual environment
  * we need a virtual environment to install the dependencies of the project (SPL-Core needs python)
* run pipenv to create the virtual environment
* run tests
* build package
* publish package

## Design Decisions

* All Bootstrap functionality is implemented inside bootstrap.ps1 and bootstrap.py inside this repository.
* When we speak about Bootstrap we talk about these both files.
* Bootstrap is used by "other" repositories to install all external dependencies needed to start a build.
* Bootstrap is
  * either included in those other repositories (as "generated copy", not clone-and-own)
  * or fetched as external dependency (using git to clone/pull this repository)
    * This shall be a powershell one-liner (e.g. using "irm") usable, e.g., in build.ps1 of the "other" repository
* A repo using Bootstrap contains a bootstrap.json for configuration (might be generated or updated by generation)
