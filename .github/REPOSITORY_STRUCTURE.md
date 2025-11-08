# Repository Structure

## Overview

This document describes the structure of the kotlin-extended-lsp.nvim repository for new contributors and users.

## Top-Level Structure

```
kotlin-extended-lsp.nvim/
├── .github/              # GitHub configuration
│   ├── ISSUE_TEMPLATE/   # Issue templates (bug, feature)
│   └── workflows/        # CI/CD workflows (ci.yml, release.yml)
├── doc/                  # Vim help documentation
│   ├── kotlin-extended-lsp.txt   # Main help file
│   └── tags              # Help tags (auto-generated)
├── lua/                  # Lua source code
│   └── kotlin-extended-lsp/
│       ├── cache.lua     # LRU cache implementation
│       ├── config.lua    # Configuration management
│       ├── decompile.lua # JAR/class decompilation logic
│       ├── handlers.lua  # LSP handlers
│       ├── init.lua      # Plugin entry point
│       ├── logger.lua    # Logging system
│       └── lsp_client.lua # LSP client utilities
├── plugin/               # Vim plugin loader
│   └── kotlin-extended-lsp.lua
├── test-project/         # Comprehensive Kotlin test project
│   ├── src/main/kotlin/  # Test source code
│   ├── src/test/kotlin/  # Test cases
│   └── build.gradle.kts  # Gradle build file
├── tests/                # Plugin test suite
│   ├── cache_spec.lua    # Cache module tests
│   ├── config_spec.lua   # Config module tests
│   ├── decompile_spec.lua # Decompile module tests
│   ├── integration_spec.lua # Integration tests
│   ├── logger_spec.lua   # Logger module tests
│   ├── lsp_client_spec.lua # LSP client tests
│   └── minimal_init.lua  # Test initialization
├── CHANGELOG.md          # Version history
├── CONTRIBUTING.md       # Contribution guidelines
├── LICENSE               # MIT License
├── Makefile              # Development tasks
├── README.md             # Main documentation (English)
└── README.ja.md          # Main documentation (Japanese)
```

## Directory Descriptions

### Core Plugin Code (`lua/kotlin-extended-lsp/`)

- **cache.lua**: LRU (Least Recently Used) cache system for decompiled files
- **config.lua**: Configuration validation and management
- **decompile.lua**: JAR/class file decompilation logic with kotlin-lsp integration
- **handlers.lua**: Enhanced LSP handlers for navigation and editing
- **init.lua**: Main plugin initialization and setup
- **logger.lua**: Structured logging system with file/console output
- **lsp_client.lua**: LSP client utilities with retry logic and timeout handling

### Test Suite (`tests/`)

Comprehensive test suite with 60%+ code coverage:
- Unit tests for all core modules
- Integration tests
- Mock LSP server for testing

### Test Project (`test-project/`)

Real-world Kotlin server-side application for testing all LSP features:
- Domain models (sealed interfaces, value classes, data classes)
- Repository layer (Exposed ORM)
- Service layer (Arrow, Coroutines)
- API layer (Ktor)
- Comprehensive LSP test matrix

See `test-project/README.md` for detailed testing instructions.

### Documentation (`doc/`)

Vim help documentation in standard format:
- `:help kotlin-extended-lsp` - Main help
- `:help kotlin-extended-lsp-commands` - Command reference
- `:help kotlin-extended-lsp-configuration` - Configuration guide

### CI/CD (`.github/workflows/`)

- **ci.yml**: Continuous Integration
  - Linting with luacheck
  - Formatting with stylua
  - Testing on Ubuntu/macOS with Neovim stable/nightly
  - Documentation validation

- **release.yml**: Automated releases
  - Version validation
  - Changelog generation
  - GitHub Release creation

## File Purposes

### Root Files

| File | Purpose |
|------|---------|
| `CHANGELOG.md` | Version history following Keep a Changelog format |
| `CONTRIBUTING.md` | Guidelines for contributors |
| `LICENSE` | MIT License |
| `Makefile` | Development tasks (test, lint, format, etc.) |
| `README.md` | Main documentation (English) |
| `README.ja.md` | Main documentation (Japanese) |
| `.gitignore` | Git ignore rules |
| `.luacheckrc` | Luacheck configuration |
| `.stylua.toml` | StyLua formatting configuration |

## Getting Started

### For Users
1. Read `README.md` for installation and usage
2. Check `:help kotlin-extended-lsp` for detailed documentation

### For Contributors
1. Read `CONTRIBUTING.md` for contribution guidelines
2. Run `make test` to run the test suite
3. Run `make lint` to check code quality
4. Use `test-project/` for manual testing

### For Developers
1. Clone the repository
2. Install dependencies (plenary.nvim for testing)
3. Run `make help` to see available commands
4. Check `.github/workflows/ci.yml` for CI requirements

## Quality Assurance

- **Code Coverage**: 60%+ (aim for 80% on core modules)
- **Linting**: All code passes luacheck
- **Formatting**: All code formatted with stylua
- **Testing**: Automated tests on multiple OS/Neovim versions
- **Documentation**: Comprehensive help files and README

## Questions?

- Check existing documentation first
- Open an issue for bugs or feature requests
- Refer to `CONTRIBUTING.md` for contribution process
