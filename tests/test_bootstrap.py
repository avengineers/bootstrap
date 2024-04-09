import sys
from pathlib import Path

from bootstrap import (
    CreateVirtualEnvironment,
    PyPiSourceParser,
)


def test_pypi_source_from_toml():
    pyproject_toml_content = """
[[tool.poetry.source]]
name = "my_pypi"
url = "https://pypi.org/simple"
"""
    pypi_source = PyPiSourceParser.from_pyproject_toml_content(pyproject_toml_content)
    assert pypi_source
    assert pypi_source.name == "my_pypi"
    assert pypi_source.url == "https://pypi.org/simple"

    pyproject_toml_content = """
[tool.poetry.source]
name = my_pypi
url = "https://pypi.org/simple"
"""
    pypi_source = PyPiSourceParser.from_pyproject_toml_content(pyproject_toml_content)
    assert pypi_source
    assert pypi_source.name == "my_pypi"
    assert pypi_source.url == "https://pypi.org/simple"


def test_create_pip_ini_simple(tmp_path: Path) -> None:
    venv_dir = tmp_path / ".venv"
    venv_dir.mkdir(parents=True)
    my_venv = CreateVirtualEnvironment.instantiate_os_specific_venv(venv_dir)
    my_venv.pip_configure("https://my.pypi.org/simple/stable", True)
    pip_ini = venv_dir / ("pip.ini" if sys.platform.startswith("win32") else "pip.conf")
    assert pip_ini.exists()
    assert (
        pip_ini.read_text()
        == """\
[global]
index-url = https://my.pypi.org/simple/stable
trusted-host = my.pypi.org
"""
    )
