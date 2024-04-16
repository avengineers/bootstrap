# Bootstrapping scripts to set up and initialize new Python based projects under Windows

![maintained](https://img.shields.io/badge/maintained-yes-success?style=flat-square)

## Description

This repository provides an easy way to fetch some dependencies in order to kickstart your Python project on a bare Windows machine.
By using it, [Scoop](https://github.com/ScoopInstaller/Scoop) will be installed and configured on your computer.
This in turn is then used to install [Python](https://www.python.org/) and a virtual environment is created for it.
It is possible to customize the installation process using configuration files.

## Getting started

To get started, follow these steps:

1. Clone this repository to your local machine. You can also achieve this by using [bootstrap-installer](https://github.com/avengineers/bootstrap-installer).
2. Open a command prompt and navigate to the repository's directory.
3. Run `bootstrap.bat` or `bootstrap.ps1` to start the setup process for the project environment.
4. Wait and enjoy the automated installation. There is a preset of default configurations which are applied during this process.

That's it! You're now ready to start developing your Python project using this repository.

## Bootstrap Scripts

The entire working logic of the installation process is divided into several scripts. They will now be described in more detail:

- **`bootstrap.bat`**: This batch script only starts `bootstrap.ps1`. It is intended for all people who prefer to do things with a mouse click.

- **`bootstrap.ps1`**: This PowerShell script is designed to be run from the command line and does not require any arguments. It is responsible for setting up the project environment by performing the following steps:
    1. Load configuration. If no `bootstrap.json` file is provided, default settings will be used.
    2. Install Scoop.
    3. Install Python using Scoop.
    4. When there is a `pyproject.toml`file, call `bootstrap.py` to create a virtual environment and configure pip settings within the environment. Otherwise, when there is a `pipfile` instead, create the environment directly.

- **`bootstrap.py`**: This Python script provides a set of classes and methods for managing a Python environment. It includes functionality for creating a new virtual environment, configuring pip settings within it, and executing arbitrary commands inside it. There is also a mechanism to check if users provide new configuration settings, so that when the script is run again, all the functionality is only triggered if something has changed.

## Configuration

TODO: add details about configuration files (bootsrap.json, scoopfile.json, pyproject.toml, pipfile)

## Contributing

Contributions are welcome. Please fork this repository and create a pull request if you have something you want to add or change.

## License

This project is licensed under the MIT License - see the LICENSE.md file for details.

## Contact Information

For any queries, please contact us via email.
