from pathlib import Path

import pytest

from bootstrap import BootstrapConfig, CreateBootstrapEnvironment


@pytest.fixture
def project_dir(tmp_path: Path) -> Path:
    path = tmp_path / "project"
    path.mkdir()
    return path


@pytest.fixture
def bootstrap_config(tmp_path: Path) -> BootstrapConfig:
    return BootstrapConfig(bootstrap_cache_dir=tmp_path / ".bootstrap")


@pytest.fixture
def bootstrap_env(bootstrap_config: BootstrapConfig, project_dir: Path) -> CreateBootstrapEnvironment:
    return CreateBootstrapEnvironment(bootstrap_config, project_dir)
