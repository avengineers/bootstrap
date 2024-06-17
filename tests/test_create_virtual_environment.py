import sys
from pathlib import Path

from bootstrap import CreateVirtualEnvironment


def test_create_pip_ini_simple(tmp_path: Path):
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
