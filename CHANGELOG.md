# Changelog

All notable changes to kotlin-extended-lsp.nvim will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- LRU (Least Recently Used) cache system for decompiled files
  - Configurable maximum entries (`max_cache_entries`)
  - TTL (Time-To-Live) for cache entries
  - Cache statistics tracking
  - Automatic expired entry cleanup
- New commands:
  - `:KotlinCleanCache` - Remove expired cache entries
  - `:KotlinCacheStats` - Display cache statistics
- Comprehensive test suite (60%+ coverage)
  - Unit tests for all core modules
  - Integration tests
  - Cache tests
  - Logger tests
  - LSP client tests
  - Decompile tests
- CI/CD pipeline
  - Automated testing on Ubuntu and macOS
  - Testing against Neovim stable and nightly
  - Code linting with luacheck
  - Code formatting with stylua
  - Documentation validation
  - Integration tests
- Release workflow for automated releases
- Makefile for development tasks
- English README (README.md)
- Japanese README (README.ja.md)

### Changed
- Migrated to Neovim 0.10 API
  - Replaced deprecated `vim.api.nvim_buf_set_option` with `vim.bo[bufnr]`
- Improved timeout handling in LSP requests
  - Proper timer cleanup
  - Timeout notification to handlers
  - Prevention of duplicate callbacks
- Enhanced logger with file handle leak protection
  - Automatic cleanup on re-initialization
  - Error handling for file operations

### Security
- Strengthened URI validation
  - Length limit (4096 characters) to prevent DoS
  - Path traversal attack detection
  - Invalid control character detection
  - Scheme validation (only `jar:file:` and `file:` allowed)
- Fixed file handle leaks in logger module
- Added race condition protection for buffer operations
  - Safe buffer validity checks with pcall
  - Rollback on error during buffer creation

### Removed
- Synchronous LSP request function (`request_sync`)
  - Removed to prevent UI blocking
  - All operations are now fully asynchronous

### Fixed
- Buffer cleanup on BufDelete event
- Potential memory leaks in cache system
- Race conditions in buffer operations

## [1.0.0] - Initial Release

### Added
- JAR/class file decompilation support
- Integration with JetBrains kotlin-lsp
- Basic LSP handlers for navigation
- Configuration system with validation
- Logger module
- Basic caching
- User commands
- Keymaps
- Documentation

[Unreleased]: https://github.com/yourusername/kotlin-extended-lsp.nvim/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/yourusername/kotlin-extended-lsp.nvim/releases/tag/v1.0.0
