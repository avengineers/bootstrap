# Feature Specification: Isolated Package Manager Environment

## User Scenarios & Testing

### User Story 1 - Pristine Project Environments (Priority: high)

As a Developer, I want my project's virtual environment to contain only the libraries required by my application,
so that I don't encounter "dependency shadowing" or conflicts caused by the package manager's own dependencies.

**Why this priority**: This is the core value proposition. It guarantees that the development environment matches production
(where build tools are absent) and prevents obscure bugs where code works locally because it accidentally imports a library
installed by the package manager (e.g., `requests` or `toml`).

**Independent Test**: Can be fully tested by creating a new project with a known dependency that conflicts with a specific version
used by the package manager (or simply checking for the absence of the package manager in the final environment).

**Acceptance Scenarios**:

1. **Given** a fresh project configuration, **When** I run the bootstrap process, **Then** the resulting `.venv` should contain my project dependencies
   but **must not** contain the package manager executable (e.g., `poetry` or `uv`) or its specific dependencies (e.g., `cleo`, `crashtest`).
2. **Given** a project environment, **When** I run `pip list` inside it, **Then** I should see a clean list matching `pyproject.toml` (plus direct sub-dependencies) only.

---

### User Story 2 - Shared Toolchain Cache (Priority: medium)

As a Developer working on multiple projects, I want the system to download and install the package manager tool only once per version,
so that setting up subsequent projects is significantly faster and uses less disk space.

**Why this priority**: Medium. Reduces friction and setup time. If a developer works on 5 projects using the same toolchain, they shouldn't pay the installation penalty 5 times.

**Independent Test**: Can be tested by setting up Project A, then setting up Project B with identical configuration, and check that the same cached environment is used.

**Acceptance Scenarios**:

1. **Given** I have already bootstrapped "Project A" with Poetry 1.8, **When** I bootstrap "Project B" which also requires Poetry 1.8,
   **Then** the system should use the cached toolchain from `~/.bootstrap/` and **must not** download/install Poetry again.
2. **Given** I change the required package manager version in `bootstrap.json`, **When** I run bootstrap,
   **Then** a new isolated toolchain should be created for that specific version without affecting other projects.

---

### User Story 3 - Automatic Environment Recovery (Priority: medium)

As a Developer switching between branches with different Python versions (e.g., develop branch vs. old testing branch),
I want the system to automatically detect the mismatch and recreate the environment, so that I don't have to manually delete
and recreate the virtual environment every time I switch branches with incompatible Python versions.

**Why this priority**: Medium. Improves quality of life and reduces support requests from developers confused by obscure Python errors after switching branches.

**Independent Test**: Can be tested by creating a project with Python 3.10, bootstrapping it, then switching to a branch requiring Python 3.11 and running bootstrap again.

**Acceptance Scenarios**:

1. **Given** an existing environment created with Python 3.10, **When** I switch to a branch requiring Python 3.11 and run bootstrap,
   **Then** the system must delete the old 3.10 environment and create a new 3.11 environment automatically.
2. **Given** a valid environment, **When** I run bootstrap again (re-run), **Then** the system should detect no changes and do nothing (idempotency).

---

### User Story 4 - Easy Package Manager Access (Priority: high)

As a Developer managing project dependencies, I want to add, remove, or update project dependencies using the package manager without manually hunting for the bootstrap environment directory,
so that I can maintain my project's `pyproject.toml` efficiently during daily development.

**Why this priority**: High. This is critical for day-to-day development workflow. Without easy access to the package manager,
developers lose the ability to perform routine dependency management tasks (adding libraries, updating versions, removing unused packages),
defeating the purpose of using modern Python package managers.

**Independent Test**: Can be tested by trying to update a project's dependencies using standard package manager commands (e.g., `poetry add <package>`),
and verifying that the changes are reflected in `pyproject.toml` and the project environment.

**Acceptance Scenarios**:

1. **Given** a successfully bootstrapped project, **When** I need to add a new dependency (e.g., `requests>=2.31`),
   **Then** I should be able to accomplish this without manually navigating to `~/.bootstrap/<hash>/` or remembering the hash value.
2. **Given** a successfully bootstrapped project, **When** I add a dependency, **Then** the dependency must be added to the project's `pyproject.toml`
   and installed in the project's `.venv` (not in the bootstrap environment).
3. **Given** multiple projects using different package manager versions (e.g., Project A uses Poetry 1.8, Project B uses Poetry 2.1),
   **When** I manage dependencies in each project, **Then** each project must use its correct bootstrap environment's package manager version.
4. **Given** a developer unfamiliar with the bootstrap architecture, **When** they attempt to manage dependencies,
   **Then** the process should require no more steps than the standard package manager workflow (comparable friction to `poetry add requests`).

---

## Requirements

### Functional Requirements

- **FR-001**: System must create a centralized, shared "Bootstrap Environment" to host package management tools. The location must be configurable (e.g., via environment variable), defaulting to the user's home directory (`~/.bootstrap`).
- **FR-002**: System must uniquely identify Bootstrap Environments using a hash derived from the Python version, Package Manager version, and auxiliary bootstrap packages.
- **FR-003**: The Project Virtual Environment (`.venv`) must be created using the tools located in the Bootstrap Environment.
- **FR-004**: The Project Virtual Environment must not contain the package manager itself (e.g., Poetry) installed as a library.
- **FR-005**: System must validate the existing Project Virtual Environment against the current configuration (Python version) and recreate it if a mismatch is detected.
- **FR-006**: System must support defining the specific package manager (e.g., `poetry>=1.8`, `uv`) via a configuration file (`bootstrap.json`).
- **FR-007**: System must allow configuration of additional packages (e.g., `pip-system-certs`) to be installed into the Bootstrap Environment alongside the package manager.

### Key Entities

- **BootstrapConfig**: Defines the rules for the environment (Required Python Version, Package Manager Name/Version, Bootstrap Packages).
- **BootstrapEnvironment**: The shared, cached directory containing the executable tools. This is reused across multiple projects with the same configuration.
- **ProjectEnvironment**: The local, project-specific directory (`.venv`) containing only application dependencies. This is "One-to-One" mapped to a project.

---

## Architectural Decision: Why Install Package Manager in Virtual Environment?

### Context

Many organizations use on-premise artifact repositories with self-signed SSL certificates for security and governance reasons. These repositories typically host:

- **Mirrored PyPI Index**: A local copy of the official PyPI packages for faster downloads and supply chain control
- **Inner Source Packages**: Private company packages not available on public PyPI

A typical Poetry configuration for such an environment looks like:

```toml
[[tool.poetry.source]]
name = "company-pypi"
url = "https://artifactory.company.com/artifactory/api/pypi/pypi-virtual/simple"
priority = "primary"
```

### The Problem: System-Installed Package Managers Cannot Handle Self-Signed Certificates

When package managers like Poetry or UV are installed **system-wide** (e.g., via Scoop on Windows, Homebrew on macOS and Linux), they run in an isolated environment that does not have access to the operating system's certificate trust store. This causes SSL verification failures when trying to access repositories with self-signed certificates:

```
SSL: CERTIFICATE_VERIFY_FAILED
```

**Why this happens:**

1. **Poetry installed via Scoop** uses its own embedded Python interpreter and certificate bundle
2. The system's trusted root certificates (added via Windows Certificate Manager or `certutil`) are **not accessible** to this isolated environment
3. Manual workarounds (like `poetry config certificates.company-pypi.cert false`) are insecure and violate corporate policies

### The Solution: Package Manager in Python Virtual Environment + pip-system-certs

By installing the package manager (Poetry/UV) **inside a Python virtual environment** and including the `pip-system-certs` package, we enable automatic detection and use of the operating system's certificate trust store.

**How it works:**

The package manager and `pip-system-certs` are installed together in a dedicated virtual environment (`~/.bootstrap/<hash>/venv`). The `pip-system-certs` package patches Python's `ssl` module at runtime to read certificates from the operating system's trust store (Windows Certificate Store, macOS Keychain, or Linux CA bundles). When the package manager runs from this environment, it automatically trusts certificates that the OS trusts—including corporate self-signed certificates.

> **⚠️ Important**: During the initial bootstrap environment setup, pip must install the package manager and `pip-system-certs` packages from the corporate PyPI repository. Since `pip-system-certs` is not yet installed at this stage, pip cannot automatically trust the self-signed certificate. The bootstrap process handles this by passing `--trusted-host <hostname>` to pip for this initial installation only. Once `pip-system-certs` is installed, all subsequent operations (including creating the project's `.venv`) will automatically trust system certificates without needing `--trusted-host`.

### Benefits

1. **Zero Configuration**: Developers don't need to manually configure certificate paths or disable SSL verification (which would be a security risk)
2. **Automatic Updates**: When IT updates root certificates system-wide, the package manager automatically picks them up
3. **Security**: SSL verification remains enabled; we're not compromising on security to work around certificate issues
4. **Consistency**: The same solution works across Windows, macOS, and Linux (with appropriate certificate stores)
5. **Private Package Support**: Developers can seamlessly access private PyPI repositories without additional configuration

### Drawbacks

- ⚠️ Slightly more complex bootstrap process (creating a virtual environment instead of using system packages)
- ⚠️ Developers coming from simple `pip install poetry` workflows need to understand the architecture

### Configuration Example

To use this architecture with a corporate PyPI repository:

**bootstrap.json:**

```json
{
  "python_version": "3.11",
  "package_manager": "poetry>=1.8",
  "bootstrap_packages": ["pip-system-certs"]
}
```

**pyproject.toml:**

```toml
[[tool.poetry.source]]
name = "company-pypi"
url = "https://artifactory.company.com/artifactory/api/pypi/pypi-virtual/simple"
priority = "primary"

[tool.poetry.dependencies]
python = "^3.11"
requests = "^2.31"  # Will be fetched from company-pypi with SSL verification
```

**What happens during bootstrap:**

1. Creates `~/.bootstrap/<hash>/venv` with Python 3.11
2. Installs `poetry>=1.8` and `pip-system-certs` into this environment
3. Uses `~/.bootstrap/<hash>/venv/Scripts/poetry.exe` to create the project's `.venv`
4. Poetry automatically trusts the self-signed certificate from `company-pypi`
