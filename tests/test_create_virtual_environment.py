import sys
from pathlib import Path

from bootstrap import CreateVirtualEnvironment


def test_pip_configure(tmp_path: Path):
    # Arrange
    venv_dir = tmp_path / ".venv"
    venv_dir.mkdir(parents=True)

    # Act
    my_venv = CreateVirtualEnvironment.instantiate_os_specific_venv(venv_dir)
    my_venv.pip_configure("https://my.pypi.org/simple/stable")
    my_venv.create()

    # Assert
    assert my_venv.pip_path().exists()  # Make sure the pip path is properly set
    pip_ini = venv_dir / ("pip.ini" if sys.platform.startswith("win32") else "pip.conf")
    assert pip_ini.exists()
    assert (
        pip_ini.read_text()
        == """\
[global]
index-url = https://my.pypi.org/simple/stable
"""
    )

    # Act: call item under test again with different index-url
    my_venv.pip_configure("https://some.other.pypi.org/simple/stable", False)

    # Assert
    assert (
        pip_ini.read_text()
        == """\
[global]
index-url = https://some.other.pypi.org/simple/stable
cert = false
"""
    )


def test_gitignore_configure(tmp_path: Path):
    # Arrange
    venv_dir = tmp_path / ".venv"
    venv_dir.mkdir(parents=True)

    # Act
    my_venv = CreateVirtualEnvironment.instantiate_os_specific_venv(venv_dir)
    my_venv.gitignore_configure()

    # Assert
    gitignore = venv_dir / ".gitignore"
    assert gitignore.exists()
    assert gitignore.read_text() == "*\n"


def test_get_inputs(tmp_path: Path):
    # Arrange
    pipfile = tmp_path / "Pipfile"
    bootstrap_json = tmp_path / "bootstrap.json"
    bootstrap_py = tmp_path / ".bootstrap" / "bootstrap.py"

    # Act
    creator = CreateVirtualEnvironment(tmp_path)
    inputs = creator.get_inputs()

    # Assert
    assert pipfile in inputs
    assert bootstrap_json in inputs
    assert bootstrap_py in inputs
