# AGENTS.md

This document guides AI coding agents and human contributors when working with this Python project.

## Persona & Philosophy

Role: Senior Python Engineer.

Core Values:

- Explicit over Implicit: Code should be readable and obvious. Avoid "magic" logic.
- Robustness: Prioritize error handling and edge cases over happy-path-only code.
- Statelessness: Avoid mutable global state. Prefer pure functions.
- Testability: Code must be designed to be easily tested (dependency injection, small units).

## Project Overview

**Bootstrap** is a Python-based tooling project that automates the setup of Python development environments on Windows. It installs [Scoop](https://scoop.sh/), Python, and creates virtual environments with minimal configuration.

### Key Technologies

- **Language**: Python 3.10+
- **Package Manager**: Poetry
- **Testing**: pytest, pytest-cov
- **Linting**: Ruff
- **Target OS**: Windows (PowerShell automation)

### Project Structure

```
bootstrap.py          # Core bootstrap logic (CLI entry point)
bootstrap.ps1         # PowerShell wrapper
pyproject.toml        # Poetry configuration
tests/                # Test suite
  test_*.py          # Python unit tests
  *.Tests.ps1        # PowerShell integration tests
docs/                 # Documentation
```

## Code Standards

### Python Style (Inspired by Google Python Style Guide)

#### 1. Type Hints

- **Required** for all function signatures, public attributes, and constants
- Use `typing` module annotations (`List`, `Optional`, `Dict`, etc.)
- Example:

  ```python
  def process_config(path: Path, timeout: int = 30) -> BootstrapConfig:
      """Load and validate bootstrap configuration."""
      ...
  ```

#### 2. Naming Conventions

- **Functions/Variables**: `snake_case` (e.g., `create_virtual_environment`)
- **Classes**: `PascalCase` (e.g., `BootstrapConfig`, `PyPiSourceParser`)
- **Constants**: `UPPER_SNAKE_CASE` (e.g., `DEFAULT_PACKAGE_MANAGER`)
- **Private members**: prefix with `_` (e.g., `_internal_helper`)
- Avoid single-letter names except in tight loops or mathematical contexts

#### 3. Docstrings

- Use for **public APIs** and non-obvious logic
- Keep concise; code should be self-documenting
- Format: Google style (summary line, then details)

  ```python
  def from_json_file(cls, json_path: Path) -> "BootstrapConfig":
      """Load configuration from a JSON file.
      
      Args:
          json_path: Path to the bootstrap.json configuration file.
      
      Returns:
          BootstrapConfig instance with loaded settings.
      """
  ```

#### 4. Code Structure

- **Pythonic constructs**: Use context managers, `pathlib.Path`, comprehensions (when clear), `enumerate`, `zip`
- **Early returns**: Avoid deep nesting; return/raise early
- **Max line length**: 220 characters (configured in ruff)
- **Imports**:
  - No wildcards (`from module import *`)
  - Group: stdlib → third-party → local (separated by blank lines)
  - Sort within groups

#### 5. SOLID Principles

- **Single Responsibility**: Each class/function does one thing well
- **Composition over inheritance**: Use mixins or protocols sparingly
- **Protocols/ABCs**: Define interfaces explicitly (see `Executor` ABC)
- **Dependency injection**: Pass dependencies via constructors or parameters

#### 6. Error Handling

- Raise **specific exceptions** (e.g., `UserNotificationException`, `FileNotFoundError`)
- Never use bare `except:` — always catch specific types
- Add **actionable context** in error messages

  ```python
  raise UserNotificationException(
      f"Could not find Python executable at {python_path}. "
      f"Please ensure Python {version} is installed."
  )
  ```

#### 7. Testing

- Use **pytest** (no test classes unless needed for fixtures)
- Test files: `test_<module>.py`
- Tests should be **self-explanatory** and minimal
- Use parametrization for similar test cases:

  ```python
  @pytest.mark.parametrize("version,expected", [
      ("3.10.1", (3, 10, 1)),
      ("3.11", (3, 11)),
  ])
  def test_version_parsing(version, expected):
      assert Version(version).version == expected
  ```

### PowerShell Style

The PowerShell components (`bootstrap.ps1`, `utils.ps1`) are critical for Windows automation and Scoop integration.

#### 1. Function Naming

- **Verb-Noun pattern**: PowerShell approved verbs (`Get-`, `Set-`, `Install-`, `Invoke-`)
- **PascalCase**: `Get-BootstrapConfig`, `Install-Scoop`, `Import-ScoopFile`
- **Variables**: `$camelCase` for local variables, `$PascalCase` for script-level

#### 2. Comment-Based Help

```powershell
<#
.DESCRIPTION
    Brief description of what the function does
.PARAMETER ParameterName
    Description of the parameter
.EXAMPLE
    Get-BootstrapConfig
#>
function Get-BootstrapConfig {
    # Implementation
}
```

#### 3. Error Handling

- Use `ErrorAction` parameter: `-ErrorAction SilentlyContinue`, `-ErrorAction Stop`
- Validate input with `[Parameter(Mandatory = $true)]`
- Use `Write-Error` for failures, `Write-Output` for normal output
- Set `$StopAtError` parameter in utility functions

#### 4. Testing with Pester

- **Test files**: `*.Tests.ps1`
- **Structure**: Use `Describe`, `Context`, `It` blocks
- **Mocking**: Mock external dependencies with `Mock -CommandName`
- **Assertions**: Use `Should -Be`, `Should -Exist`, etc.

Example:

```powershell
Describe "Get-BootstrapConfig" {
    It "should return the default configuration" {
        Mock -CommandName Test-Path -MockWith { $false }
        
        $result = Get-BootstrapConfig
        
        $result.python_version | Should -Be "3.11"
    }
}
```

#### 5. PowerShell Best Practices

- **Use approved verbs**: `Get-Verb` to list approved verbs
- **Avoid aliases in scripts**: Write `ForEach-Object`, not `%` or `foreach`
- **Use splatting** for readability with many parameters:
  
  ```powershell
  $params = @{
      CommandLine  = $cmd
      StopAtError  = $true
      PrintCommand = $false
  }
  Invoke-CommandLine @params
  ```

- **Suppress false positives**: Use `[Diagnostics.CodeAnalysis.SuppressMessageAttribute]` with justification
- **Return typed objects**: Use `[PSCustomObject]@{}` or hashtables, not plain strings
- **Path handling**: Use `Join-Path`, `Split-Path`, `Test-Path`

#### 6. Scoop Integration

- **Bucket URLs**: Use raw URLs for bucket manifests
- **Installation order matters**: Dependencies like `7zip` → `innounp` → `dark`
- **Silent installations**: Use `-Silent $true -PrintCommand $false` for dependencies
- **Environment refresh**: Call `Initialize-EnvPath` after installs

## Development Workflow

### Setup

```powershell
# Run bootstrap to set up environment
.\.bootstrap\bootstrap.ps1
```

### Testing

```powershell
# Python tests
pytest

# PowerShell tests (requires Pester)
.\tests\bin\test.ps1
```

### Code Quality

```bash
# Linting
ruff check .

# Auto-fix
ruff check --fix .

# Coverage
pytest --cov=. --cov-report=term-missing
```

## Windows-Specific Considerations

- Use `pathlib.Path` for cross-platform compatibility
- PowerShell scripts use UTF-8 BOM encoding
- Handle Windows paths with backslashes properly
- Scoop requires PowerShell execution policy adjustments

## Review Checklist

When reviewing code:

- [ ] Tests added/updated for new functionality
- [ ] Error messages are actionable
- [ ] No hardcoded paths or credentials
- [ ] Documentation updated (README, docstrings, comment-based help)
- [ ] Backward compatibility maintained

---

*This file is optimized for both AI agents and human contributors. When in doubt, prioritize clarity and maintainability over cleverness.*
