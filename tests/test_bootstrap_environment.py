import json
from pathlib import Path
from typing import Any

import pytest
from pytest_mock import MockerFixture

from bootstrap import (
    BOOTSTRAP_COMPLETE_MARKER,
    CERTIFI_REQUIREMENT,
    DEFAULT_BOOTSTRAP_PACKAGES,
    DEFAULT_PACKAGE_MANAGER,
    MIN_PIP_VERSION,
    PIP_REQUIREMENTS_FILE,
    PIP_WHEEL_SHA256,
    BootstrapConfig,
    CreateBootstrapEnvironment,
    CreateVirtualEnvironment,
    UserNotificationException,
    VirtualEnvironment,
    check_python_version,
    extract_package_manager_name,
)


def test_bootstrap_config_defaults():
    # Act
    config = BootstrapConfig()

    # Assert
    assert config.python_version == ""
    assert config.package_manager == DEFAULT_PACKAGE_MANAGER
    assert config.package_manager_args == []
    assert config.bootstrap_packages == list(DEFAULT_BOOTSTRAP_PACKAGES)
    assert config.bootstrap_cache_dir is None
    assert config.venv_install_command is None


def test_bootstrap_config_from_json_file(tmp_path: Path):
    # Arrange
    config_data = {
        "python_version": "3.11.4",
        "python_package_manager": "poetry==2.1.0",
        "python_package_manager_args": ["--no-dev"],
        "bootstrap_packages": ["pip-system-certs==4.0.0", "wrapt==1.14.0"],
        "bootstrap_cache_dir": "~/.my-bootstrap-cache",
        "venv_install_command": "poetry install --no-interaction",
    }
    config_file = tmp_path / "bootstrap.json"
    config_file.write_text(json.dumps(config_data))

    # Act
    config = BootstrapConfig.from_json_file(config_file)

    # Assert
    assert config.python_version == "3.11.4"
    assert config.package_manager == "poetry==2.1.0"
    assert config.package_manager_args == ["--no-dev"]
    assert config.bootstrap_packages == ["pip-system-certs==4.0.0", "wrapt==1.14.0"]
    assert config.bootstrap_cache_dir == Path("~/.my-bootstrap-cache").expanduser()
    assert config.venv_install_command == "poetry install --no-interaction"


def test_bootstrap_config_from_missing_file_returns_defaults(tmp_path: Path):
    # Act
    config = BootstrapConfig.from_json_file(tmp_path / "nonexistent.json")

    # Assert
    assert config.python_version == ""
    assert config.package_manager == DEFAULT_PACKAGE_MANAGER


def test_bootstrap_config_get_cache_dir_default():
    # Arrange
    config = BootstrapConfig()

    # Act
    cache_dir = config.get_bootstrap_cache_dir()

    # Assert
    assert cache_dir == Path.home() / ".bootstrap"


def test_bootstrap_config_get_cache_dir_custom(tmp_path: Path):
    # Arrange
    config = BootstrapConfig(bootstrap_cache_dir=tmp_path / "custom-cache")

    # Act
    cache_dir = config.get_bootstrap_cache_dir()

    # Assert
    assert cache_dir == tmp_path / "custom-cache"


def test_bootstrap_env_hash_deterministic():
    # Arrange
    config = BootstrapConfig(
        python_version="3.11",
        package_manager="poetry==2.1.0",
        bootstrap_packages=["pip-system-certs==4.0.0"],
    )

    # Act
    hash1 = config.compute_bootstrap_env_hash()
    hash2 = config.compute_bootstrap_env_hash()

    # Assert
    assert hash1 == hash2
    assert len(hash1) == 12


@pytest.mark.parametrize(
    ("config1_kwargs", "config2_kwargs"),
    [
        (
            {"python_version": "3.11", "package_manager": "poetry==2.1.0"},
            {"python_version": "3.12", "package_manager": "poetry==2.1.0"},
        ),
        (
            {"python_version": "3.11", "package_manager": "poetry==2.1.0", "bootstrap_packages": ["pkg-a"]},
            {"python_version": "3.11", "package_manager": "poetry==2.1.0", "bootstrap_packages": ["pkg-b"]},
        ),
        (
            {"python_version": "3.11", "package_manager": "poetry==2.0.0"},
            {"python_version": "3.11", "package_manager": "poetry==2.1.0"},
        ),
        (
            {"python_version": "3.13", "package_manager": "poetry==2.1.0"},
            {"python_version": "3.13.17", "package_manager": "poetry==2.1.0"},
        ),
    ],
)
def test_bootstrap_env_hash_different_configs(config1_kwargs, config2_kwargs):
    # Arrange
    config1 = BootstrapConfig(**config1_kwargs)
    config2 = BootstrapConfig(**config2_kwargs)

    # Act
    hash1 = config1.compute_bootstrap_env_hash()
    hash2 = config2.compute_bootstrap_env_hash()

    # Assert
    assert hash1 != hash2


def test_bootstrap_env_hash_package_order_independent():
    # Arrange
    config1 = BootstrapConfig(
        python_version="3.11",
        package_manager="poetry==2.1.0",
        bootstrap_packages=["pkg-a", "pkg-b"],
    )
    config2 = BootstrapConfig(
        python_version="3.11",
        package_manager="poetry==2.1.0",
        bootstrap_packages=["pkg-b", "pkg-a"],
    )

    # Act
    hash1 = config1.compute_bootstrap_env_hash()
    hash2 = config2.compute_bootstrap_env_hash()

    # Assert
    assert hash1 == hash2


@pytest.mark.parametrize(
    ("spec", "expected"),
    [
        ("poetry>=1.7.1", "poetry"),
        ("poetry==2.1.0", "poetry"),
        ("uv", "uv"),
        ("pipenv>=2023.0.0", "pipenv"),
    ],
)
def test_extract_package_manager_name_valid(spec: str, expected: str):
    # Act
    result = extract_package_manager_name(spec)

    # Assert
    assert result == expected


def test_extract_package_manager_name_invalid_raises():
    # Act & Assert
    with pytest.raises(UserNotificationException):
        extract_package_manager_name(">=1.0.0")


def test_create_bootstrap_environment_paths(project_dir: Path, tmp_path: Path):
    # Arrange
    config = BootstrapConfig(
        python_version="3.11",
        package_manager="poetry==2.1.0",
        bootstrap_cache_dir=tmp_path / ".bootstrap",
    )

    # Act
    bootstrap_env = CreateBootstrapEnvironment(config, project_dir)

    # Assert
    expected_hash = config.compute_bootstrap_env_hash()
    assert bootstrap_env.env_hash == expected_hash
    assert bootstrap_env.bootstrap_env_dir == tmp_path / ".bootstrap" / expected_hash
    assert bootstrap_env.venv_dir == tmp_path / ".bootstrap" / expected_hash / ".venv"
    assert bootstrap_env.marker_file == tmp_path / ".bootstrap" / expected_hash / BOOTSTRAP_COMPLETE_MARKER


def test_create_bootstrap_environment_is_valid_no_marker(bootstrap_env: CreateBootstrapEnvironment):
    # Act
    is_valid = bootstrap_env._is_valid_environment()

    # Assert
    assert is_valid is False


def test_create_bootstrap_environment_is_valid_wrong_hash(bootstrap_env: CreateBootstrapEnvironment):
    # Arrange
    bootstrap_env.bootstrap_env_dir.mkdir(parents=True)
    bootstrap_env.marker_file.write_text("wrong-hash")

    # Act
    is_valid = bootstrap_env._is_valid_environment()

    # Assert
    assert is_valid is False


def test_create_bootstrap_environment(bootstrap_env: CreateBootstrapEnvironment):
    assert bootstrap_env.get_name() == "create-bootstrap-environment"
    assert bootstrap_env.get_inputs() == []


def test_create_bootstrap_environment_get_config(bootstrap_env: CreateBootstrapEnvironment):
    # Act
    config = bootstrap_env.get_config()

    # Assert
    assert config is not None
    assert "package_manager" in config
    assert "bootstrap_packages" in config
    assert "python_version" in config


@pytest.fixture
def pip_calls(mocker: MockerFixture) -> list[list[str]]:
    """Mock venv creation and record the pip commands of the bootstrap environment in order."""
    calls: list[list[str]] = []
    mocker.patch("bootstrap.venv.create", side_effect=lambda env_dir, with_pip: Path(env_dir).mkdir(parents=True))
    mocker.patch.object(VirtualEnvironment, "run", side_effect=lambda args, *_, **__: calls.append(["run", *args]))
    mocker.patch.object(VirtualEnvironment, "pip", side_effect=lambda args: calls.append(["pip", *args]))
    return calls


@pytest.mark.parametrize(
    ("bundled_pip", "expect_upgrade", "expect_trusted_host"),
    [
        ("23.0.1", True, True),
        ("25.0.1", True, False),
        ("26.2.2", False, False),
    ],
)
def test_create_bootstrap_environment_upgrades_old_pip(mocker: MockerFixture, bootstrap_env: CreateBootstrapEnvironment, pip_calls: list[list[str]], bundled_pip: str, expect_upgrade: bool, expect_trusted_host: bool):
    # Arrange
    mocker.patch("bootstrap.ensurepip.version", return_value=bundled_pip)

    # Act
    bootstrap_env.run()

    # Assert
    upgrade_calls = [call for call in pip_calls if call[0] == "run"]
    assert len(upgrade_calls) == (1 if expect_upgrade else 0)
    if expect_upgrade:
        upgrade_args = upgrade_calls[0]
        assert pip_calls.index(upgrade_args) == 0
        assert upgrade_args[1:4] == ["python", "-m", "pip"]
        assert "--require-hashes" in upgrade_args
        assert ("--trusted-host" in upgrade_args) == expect_trusted_host
        requirements = (bootstrap_env.bootstrap_env_dir / PIP_REQUIREMENTS_FILE).read_text()
        assert requirements == f"pip=={MIN_PIP_VERSION} --hash=sha256:{PIP_WHEEL_SHA256}\n"
    install_args = pip_calls[-1]
    assert install_args[:2] == ["pip", "install"]
    assert CERTIFI_REQUIREMENT in install_args
    assert "--trusted-host" not in install_args
    assert bootstrap_env.marker_file.exists()


def test_create_bootstrap_environment_pip_upgrade_trusts_only_pypi_source_host(mocker: MockerFixture, bootstrap_env: CreateBootstrapEnvironment, pip_calls: list[list[str]]):
    # Arrange
    mocker.patch("bootstrap.ensurepip.version", return_value="23.0.1")
    (bootstrap_env.project_dir / "pyproject.toml").write_text('[tool.poetry.source]\nname = "mirror"\nurl = "https://mirror.example.com/simple"\n')

    # Act
    bootstrap_env.run()

    # Assert
    upgrade_args = pip_calls[0]
    trusted_hosts = [upgrade_args[i + 1] for i, arg in enumerate(upgrade_args) if arg == "--trusted-host"]
    assert trusted_hosts == ["mirror.example.com"]


def test_create_bootstrap_environment_pip_upgrade_failure_stops(mocker: MockerFixture, bootstrap_env: CreateBootstrapEnvironment, pip_calls: list[list[str]]):
    # Arrange
    mocker.patch("bootstrap.ensurepip.version", return_value="24.0")
    mocker.patch.object(VirtualEnvironment, "run", side_effect=UserNotificationException("no matching distribution"))

    # Act & Assert
    with pytest.raises(UserNotificationException, match=MIN_PIP_VERSION):
        bootstrap_env.run()
    assert pip_calls == []
    assert not bootstrap_env.marker_file.exists()


@pytest.mark.parametrize(
    ("required_version", "actual_version"),
    [
        ("", (3, 13, 12)),
        ("3.13", (3, 13, 12)),
        ("3.13.17", (3, 13, 17)),
        ("3.13.17", (3, 13, 18)),
        ("3.13.17", (3, 14, 0)),
    ],
)
def test_check_python_version_accepts(required_version: str, actual_version: tuple[int, ...]):
    # Act & Assert
    check_python_version(required_version, actual_version)


@pytest.mark.parametrize(
    ("required_version", "actual_version"),
    [
        ("3.13.17", (3, 13, 12)),
        ("3.13.17", (3, 11, 9)),
    ],
)
def test_check_python_version_rejects_older(required_version: str, actual_version: tuple[int, ...]):
    # Act & Assert
    with pytest.raises(UserNotificationException, match=r"3\.13\.17.*python313"):
        check_python_version(required_version, actual_version)


def test_create_bootstrap_environment_get_outputs_contains_marker(bootstrap_env: CreateBootstrapEnvironment):
    # Act
    outputs = bootstrap_env.get_outputs()

    # Assert
    assert bootstrap_env.marker_file in outputs


def test_create_virtual_environment_with_bootstrap_env(bootstrap_env: CreateBootstrapEnvironment, project_dir: Path):
    # Act
    project_venv = CreateVirtualEnvironment(project_dir, bootstrap_env)

    # Assert
    assert project_venv.bootstrap_env == bootstrap_env
    assert project_venv.config == bootstrap_env.config
    assert project_venv.package_manager_name == "poetry"


@pytest.mark.parametrize(
    ("config_kwargs", "expected_command"),
    [
        (
            {"package_manager": "poetry==2.1.0"},
            ["poetry", "install"],
        ),
        (
            {"package_manager": "poetry==2.1.0", "venv_install_command": "poetry install --no-interaction --no-dev"},
            ["poetry", "install", "--no-interaction", "--no-dev"],
        ),
        (
            {"package_manager": "pipenv", "package_manager_args": ["--clean"]},
            ["pipenv", "install", "--clean"],
        ),
        (
            {"package_manager": "uv"},
            ["uv", "sync"],
        ),
    ],
)
def test_create_virtual_environment_get_install_command(tmp_path: Path, project_dir: Path, config_kwargs: dict[str, Any], expected_command: list[str]):
    # Arrange
    config = BootstrapConfig(bootstrap_cache_dir=tmp_path / ".bootstrap", **config_kwargs)
    bootstrap_env = CreateBootstrapEnvironment(config, project_dir)

    # Act
    project_venv = CreateVirtualEnvironment(project_dir, bootstrap_env)
    command = project_venv._get_install_command()

    # Assert - verify command uses bootstrap env's package manager (unless overridden by venv_install_command)
    if config.venv_install_command:
        assert command == expected_command
    else:
        # Command should start with bootstrap env scripts path followed by package manager name
        assert str(command[0]).endswith(expected_command[0]) or str(command[0]).endswith(f"{expected_command[0]}.exe")
        assert command[1:] == expected_command[1:]


def test_create_virtual_environment_inputs_include_bootstrap_marker(bootstrap_env: CreateBootstrapEnvironment, project_dir: Path):
    # Arrange
    project_venv = CreateVirtualEnvironment(project_dir, bootstrap_env)

    # Act
    inputs = project_venv.get_inputs()

    # Assert
    assert any(str(bootstrap_env.marker_file) in str(inp) for inp in inputs)
