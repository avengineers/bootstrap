import sys
from pathlib import Path

from bootstrap import CreateVirtualEnvironment


def test_create_pip_ini_simple(tmp_path: Path):
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
