# Bootstrapping scripts to set up and initialize new Python based projects under Windows

![maintained](https://img.shields.io/badge/maintained-yes-success?style=flat-square)

## Description

This repository provides an easy way to fetch some dependencies in order to kickstart your Python project on a bare Windows machine.
By using it, [Scoop](https://github.com/ScoopInstaller/Scoop) will be installed and configured on your computer.
This in turn is then used to install [Python](https://www.python.org/) and a virtual environment is created for it.
It is possible to customize the installation process using configuration files.

## Getting started

To get started, follow these steps:

1. Open a PowerShell console and navigate to a (project) directory of your choice.
2. Clone this repository. (You can also achieve this by using [bootstrap-installer](https://github.com/avengineers/bootstrap-installer).)

    ```powershell
    git clone https://github.com/avengineers/bootstrap.git .bootstrap
    ```

3. Run `bootstrap.ps1` to start the setup process for your project environment.

    ```powershell
    .\.bootstrap\bootstrap.ps1
    ```

4. Wait and enjoy the automated installation of Scoop and Python. There is a preset of default configurations which are applied during this process.

That's it! You're now ready to start developing your Python project using this repository.

## Configuration

- **Default settings**: Without adjusting any settings in the files, the following options are used by default for the installation process:

  Python settings:
  - python_version = 3.11
  - python_package_manager = poetry

  General Scoop settings:
  - scoop_installer = <https://raw.githubusercontent.com/xxthunder/ScoopInstall/v1.1.0/install.ps1>
  - scoop_default_bucket_base_url = <https://raw.githubusercontent.com/ScoopInstaller/Main/master/bucket>
  - scoop_python_bucket_base_url = <https://raw.githubusercontent.com/ScoopInstaller/Versions/master/bucket>

  Scoop configuration:
  - autostash_on_conflict = true
  - use_lessmsi = true
  - scoop_repo = <https://github.com/xxthunder/Scoop.git>
  - scoop_branch = develop

- **How to customize the configuration**: If you want to configure your own settings, you have to create a `bootstrap.json` file. The values entered there overwrite the corresponding standard settings. See the following example:

  ```json
  {
    "python_version": "3.12",
    "scoop_ignore_scoopfile": true,
    "scoop_config": {
      "autostash_on_conflict": false
    }
  }
  ```

  This file will overwrite the corresponding entries in the default settings. A newer python version is now being used, scoopfile is ignored and autostash now applies when a conflict occurs. All the other entries remain at their default value.

- **`scoopfile.json`**: See the following example. Refer to the [official scoop documentation](https://github.com/ScoopInstaller/Scoop/wiki) for more details.

  ```json
  {
    "buckets": [
      {
        "Name": "spl",
        "Source": "https://github.com/avengineers/spl-bucket"
      }
    ],
    "apps": [
      {
        "Source": "spl",
        "Name": "mingw-winlibs-llvm-ucrt",
        "Version": "12.3.0-16.0.4-11.0.0-ucrt-r1"
      }
    ]
  }
  ```

- **`pyproject.toml`**: Refer to the [official python documentation](https://pip.pypa.io/en/stable/reference/build-system/pyproject-toml/). Create this file in order to setup your virtual Python environment.

## Internals

The entire working logic of the installation process is divided into several scripts. They will now be described in more detail:

- **`bootstrap.bat`**: This batch script only starts `bootstrap.ps1`.

- **`bootstrap.ps1`**: This PowerShell script is designed to be run from the command line and does not require any arguments. It is responsible for setting up the project environment by performing the following steps:
    1. Load configuration. If no `bootstrap.json` file is provided, default settings will be used.
    2. Install Scoop.
    3. Install Python using Scoop.
    4. When there is a `pyproject.toml` file, call `bootstrap.py` to create a virtual environment.

- **`bootstrap.py`**: This Python script provides a set of classes and methods for managing a Python environment. It includes functionality for creating a new virtual environment, configuring pip settings within it, and executing arbitrary commands inside it. There is also a mechanism to check if users provide new configuration settings, so that when the script is run again, all the functionality is only triggered if something has changed.

## Contributing

Contributions are welcome. Please fork this repository and create a pull request if you have something you want to add or change.

## License

This project is licensed under the MIT License - see the LICENSE.md file for details.

## Contact Information

For any queries, please raise an issue in this repository.
