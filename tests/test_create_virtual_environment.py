import sys
from pathlib import Path
from unittest.mock import patch

import pytest

from bootstrap import (
    VENV_PYTHON_VERSION_MARKER,
    CreateBootstrapEnvironment,
    CreateVirtualEnvironment,
    instantiate_os_specific_venv,
)


def test_pip_configure(tmp_path: Path) -> None:
    # Arrange
    venv_dir = tmp_path / ".venv"
    venv_dir.mkdir(parents=True)
    my_venv = instantiate_os_specific_venv(venv_dir)

    # Act
    my_venv.pip_configure("https://my.pypi.org/simple/stable")
    my_venv.create()

    # Assert
    pip_ini = venv_dir / ("pip.ini" if sys.platform.startswith("win32") else "pip.conf")
    assert my_venv.pip_path().exists()
    assert pip_ini.read_text() == "[global]\nindex-url = https://my.pypi.org/simple/stable\n"


def test_pip_configure_without_ssl(tmp_path: Path) -> None:
    # Arrange
    venv_dir = tmp_path / ".venv"
    venv_dir.mkdir(parents=True)
    my_venv = instantiate_os_specific_venv(venv_dir)

    # Act
    my_venv.pip_configure("https://some.pypi.org/simple/stable", verify_ssl=False)

    # Assert
    pip_ini = venv_dir / ("pip.ini" if sys.platform.startswith("win32") else "pip.conf")
    assert pip_ini.read_text() == "[global]\nindex-url = https://some.pypi.org/simple/stable\ncert = false\n"


def test_gitignore_configure(tmp_path: Path) -> None:
    # Arrange
    venv_dir = tmp_path / ".venv"
    venv_dir.mkdir(parents=True)
    my_venv = instantiate_os_specific_venv(venv_dir)

    # Act
    my_venv.gitignore_configure()

    # Assert
    assert (venv_dir / ".gitignore").read_text() == "*\n"


def test_scripts_path_windows(tmp_path: Path) -> None:
    # Arrange
    venv_dir = tmp_path / ".venv"
    venv_dir.mkdir(parents=True)

    # Act
    with patch("sys.platform", "win32"):
        my_venv = instantiate_os_specific_venv(venv_dir)
        scripts_path = my_venv.scripts_path()

    # Assert
    assert scripts_path == venv_dir / "Scripts"


def test_scripts_path_unix(tmp_path: Path) -> None:
    # Arrange
    venv_dir = tmp_path / ".venv"
    venv_dir.mkdir(parents=True)

    # Act
    with patch("sys.platform", "linux"):
        my_venv = instantiate_os_specific_venv(venv_dir)
        scripts_path = my_venv.scripts_path()

    # Assert
    assert scripts_path == venv_dir / "bin"


def test_scripts_path_consistency_with_python_path(tmp_path: Path) -> None:
    # Arrange
    venv_dir = tmp_path / ".venv"
    venv_dir.mkdir(parents=True)
    my_venv = instantiate_os_specific_venv(venv_dir)

    # Act
    scripts_path = my_venv.scripts_path()
    python_parent = my_venv.python_path().parent

    # Assert
    assert scripts_path == python_parent


@pytest.mark.parametrize(
    "expected_file",
    ["Pipfile", "bootstrap.json", ".bootstrap/bootstrap.py"],
)
def test_get_inputs_includes_relevant_files(tmp_path: Path, bootstrap_env: CreateBootstrapEnvironment, expected_file: str) -> None:
    # Arrange
    creator = CreateVirtualEnvironment(tmp_path, bootstrap_env)

    # Act
    inputs = creator.get_inputs()

    # Assert
    assert tmp_path / expected_file in inputs


def test_get_outputs_includes_bootstrap_and_project_scripts_paths(tmp_path: Path, bootstrap_env: CreateBootstrapEnvironment) -> None:
    # Arrange
    creator = CreateVirtualEnvironment(tmp_path, bootstrap_env)

    # Act
    outputs = creator.get_outputs()

    # Assert
    assert len(outputs) == 2
    assert creator.virtual_env.scripts_path() in outputs
    assert bootstrap_env.virtual_env.scripts_path() in outputs


def test_python_version_marker_written_after_package_manager_run(tmp_path: Path, bootstrap_env: CreateBootstrapEnvironment) -> None:
    # Arrange
    venv_dir = tmp_path / ".venv"
    creator = CreateVirtualEnvironment(tmp_path, bootstrap_env=bootstrap_env)

    # Simulate package manager creating the venv
    venv_dir.mkdir(parents=True)
    current_version = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"

    # Act
    creator._write_python_version_marker(current_version)

    # Assert
    marker_file = venv_dir / VENV_PYTHON_VERSION_MARKER
    assert marker_file.exists()
    assert marker_file.read_text().strip() == current_version


def test_venv_deleted_when_no_marker_found(tmp_path: Path, bootstrap_env: CreateBootstrapEnvironment) -> None:
    # Arrange
    venv_dir = tmp_path / ".venv"
    venv_dir.mkdir(parents=True)

    # Create a dummy file to verify deletion
    (venv_dir / "dummy.txt").write_text("test")

    # Act - no marker file, should delete for clean state
    creator = CreateVirtualEnvironment(tmp_path, bootstrap_env=bootstrap_env)
    creator._check_python_version_compatibility()

    # Assert
    assert not venv_dir.exists()


def test_venv_deleted_when_python_version_changes(tmp_path: Path, bootstrap_env: CreateBootstrapEnvironment) -> None:
    # Arrange
    venv_dir = tmp_path / ".venv"
    venv_dir.mkdir(parents=True)
    marker_file = venv_dir / VENV_PYTHON_VERSION_MARKER

    # Simulate venv created with Python 3.10.5
    old_version = "3.10.5"
    marker_file.write_text(old_version)

    # Create a dummy file to verify deletion
    (venv_dir / "dummy.txt").write_text("test")

    # Act - current Python version is different
    creator = CreateVirtualEnvironment(tmp_path, bootstrap_env=bootstrap_env)
    with patch("sys.version_info") as mock_version:
        mock_version.major = 3
        mock_version.minor = 11
        mock_version.micro = 8
        creator._check_python_version_compatibility()

    # Assert
    assert not venv_dir.exists()


def test_venv_preserved_when_python_version_matches(tmp_path: Path, bootstrap_env: CreateBootstrapEnvironment) -> None:
    # Arrange
    venv_dir = tmp_path / ".venv"
    venv_dir.mkdir(parents=True)
    marker_file = venv_dir / VENV_PYTHON_VERSION_MARKER
    current_version = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
    marker_file.write_text(current_version)

    # Create a dummy file to verify preservation
    dummy_file = venv_dir / "dummy.txt"
    dummy_file.write_text("test")

    # Act
    CreateVirtualEnvironment(tmp_path, bootstrap_env=bootstrap_env)

    # Assert
    assert venv_dir.exists()
    assert dummy_file.exists()
    assert marker_file.read_text().strip() == current_version
