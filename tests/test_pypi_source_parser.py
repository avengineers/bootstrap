from pathlib import Path

import pytest

from bootstrap import PyPiSourceParser


@pytest.mark.parametrize(
    "section, name, url",
    [
        ("tool.poetry.source", "my_pypi", "https://pypi.org/simple"),
        ("tool.poetry.source", "some_pypi", "https://somepypi.org/elsewhere"),
        ("invalid_section", "my_pypi", "https://pypi.org/simple"),
        ("source", "just_another_pypi", "https://somepypi.org/wherever"),
    ],
)
def test_pypi_source_toml(section, name, url):
    # input
    toml_content = f"""
[{section}]
name = "{name}"
url = "{url}"
"""

    # call item under test
    pypi_source = PyPiSourceParser.from_toml_content(toml_content, section)

    # check result
    assert pypi_source
    assert pypi_source.name == name
    assert pypi_source.url == url


def test_pypi_source_from_pyproject(tmp_path: Path):
    # create project directory as input
    project_dir = tmp_path / "some_project"
    project_dir.mkdir(parents=True)

    # call item under test
    pypi_source = PyPiSourceParser.from_pyproject(project_dir)

    # check result
    assert not pypi_source

    # input
    pipfile = project_dir / "Pipfile"
    pipfile.write_text(
        """
[[source]]
name = "my_pypi"
url = "https://pypi.org/simple"
"""
    )

    # call item under test
    pypi_source = PyPiSourceParser.from_pyproject(project_dir)

    # check changed result
    assert pypi_source
    assert pypi_source.name == "my_pypi"
    assert pypi_source.url == "https://pypi.org/simple"

    # more input
    pyproject_toml = project_dir / "pyproject.toml"
    pyproject_toml.write_text(
        """
[tool.poetry.source]
name = "another_pypi"
url = "https://anotherpypi.org/wherever"
"""
    )

    # call item under test
    pypi_source = PyPiSourceParser.from_pyproject(project_dir)

    # pyproject.toml has precedence over Pipfile
    assert pypi_source
    assert pypi_source.name == "another_pypi"
    assert pypi_source.url == "https://anotherpypi.org/wherever"
