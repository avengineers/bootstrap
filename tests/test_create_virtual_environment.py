import sys
from pathlib import Path

from bootstrap import CreateVirtualEnvironment


def test_pip_configure(tmp_path: Path):
    # input
    venv_dir = tmp_path / ".venv"
    venv_dir.mkdir(parents=True)

    # call item under test
    my_venv = CreateVirtualEnvironment.instantiate_os_specific_venv(venv_dir)
    my_venv.pip_configure("https://my.pypi.org/simple/stable")

    # check pip configuration
    pip_ini = venv_dir / ("pip.ini" if sys.platform.startswith("win32") else "pip.conf")
    assert pip_ini.exists()
    assert (
        pip_ini.read_text()
        == """\
[global]
index-url = https://my.pypi.org/simple/stable
"""
    )

    # call item under test again with different index-url
    my_venv.pip_configure("https://some.other.pypi.org/simple/stable", False)

    # check changed pip configuration
    assert (
        pip_ini.read_text()
        == """\
[global]
index-url = https://some.other.pypi.org/simple/stable
cert = false
"""
    )


def test_get_inputs(tmp_path: Path):
    # some input files
    pipfile = tmp_path / "Pipfile"
    bootstrap_json = tmp_path / "bootstrap.json"
    bootstrap_py = tmp_path / ".bootstrap" / "bootstrap.py"

    # call item under test
    creator = CreateVirtualEnvironment(tmp_path)
    inputs = creator.get_inputs()

    # check list of input dependencies
    assert pipfile in inputs
    assert bootstrap_json in inputs
    assert bootstrap_py in inputs
