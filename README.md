# kotlin-extended-lsp.nvim

> A Neovim plugin that extends the [official JetBrains kotlin-lsp](https://github.com/Kotlin/kotlin-lsp) to enable navigation into JAR files and compiled classes with automatic decompilation.

**Note**: This plugin uses the official JetBrains kotlin-lsp, which is currently in pre-alpha stage.

[![Neovim](https://img.shields.io/badge/Neovim-0.8+-green.svg?style=flat-square&logo=neovim)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1+-blue.svg?style=flat-square&logo=lua)](https://www.lua.org)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

## Overview

kotlin-extended-lsp.nvim seamlessly integrates with the official JetBrains kotlin-lsp and automatically decompiles compiled JAR files and class files when you navigate to code definitions. Inspired by [omnisharp-extended-lsp.nvim](https://github.com/Hoffs/omnisharp-extended-lsp.nvim).

## Features

- Automatic decompilation when jumping to definitions in JAR files and class files
- Enhanced standard LSP operations (go-to-definition, implementation, type definition, declaration)
- Cached decompilation results for improved performance
- **Integrated Kotlin linters (detekt, ktlint)**
- **Integrated Kotlin formatters (ktlint, ktfmt)**
- **Editor settings and .editorconfig support**
- **Automatic code formatting and linting on save**
- Customizable keymaps and UI options
- Performance tuning capabilities
- Comprehensive logging and health check functionality

## Demo

<!-- Place demo GIF here -->
```
[Demo GIF Placeholder]
Jump to Kotlin code inside JAR files
and view automatically decompiled content
```

## Requirements

### Required
- Neovim 0.8 or higher
- [Official JetBrains kotlin-lsp](https://github.com/Kotlin/kotlin-lsp) installed and configured
  - Install with: `brew install JetBrains/utils/kotlin-lsp`
  - Currently in pre-alpha stage
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) (recommended)

### Optional (for linting and formatting)
- [detekt](https://github.com/detekt/detekt) - Static code analysis
  - Install: `brew install detekt` or use Gradle plugin
- [ktlint](https://pinterest.github.io/ktlint/) - Kotlin linter and formatter
  - Install: `brew install ktlint` or use Gradle plugin
- [ktfmt](https://github.com/facebook/ktfmt) - Kotlin code formatter
  - Install: Download from releases or use Gradle plugin

## Installation

### lazy.nvim

```lua
{
  'yourusername/kotlin-extended-lsp.nvim',
  dependencies = { 'neovim/nvim-lspconfig' },
  ft = 'kotlin',
  config = function()
    require('kotlin-extended-lsp').setup({
      -- Configuration options
    })
  end,
}
```

### packer.nvim

```lua
use {
  'yourusername/kotlin-extended-lsp.nvim',
  requires = { 'neovim/nvim-lspconfig' },
  ft = 'kotlin',
  config = function()
    require('kotlin-extended-lsp').setup({
      -- Configuration options
    })
  end,
}
```

### vim-plug

```vim
Plug 'neovim/nvim-lspconfig'
Plug 'yourusername/kotlin-extended-lsp.nvim'

" In init.lua or Lua script
lua << EOF
require('kotlin-extended-lsp').setup({
  -- Configuration options
})
EOF
```

## Quick Start

Minimal configuration example:

```lua
require('kotlin-extended-lsp').setup({
  enabled = true,
  auto_setup_keymaps = true,
})

-- Configure kotlin-lsp
require('lspconfig').kotlin_lsp.setup({
  -- Standard LSP configuration
})
```

This configuration automatically enables the plugin and sets up default keymaps when you open Kotlin files.

## Configuration

Complete configuration example with all default values:

```lua
require('kotlin-extended-lsp').setup({
  -- Enable plugin
  enabled = true,

  -- Auto-setup keymaps
  auto_setup_keymaps = true,
  keymaps = {
    -- Navigation (jump functions)
    definition = 'gd',          -- Jump to definition
    implementation = 'gi',      -- Jump to implementation
    type_definition = 'gy',     -- Jump to type definition
    declaration = 'gD',         -- Jump to declaration
    references = 'gr',          -- Find references

    -- Documentation
    hover = 'K',                -- Hover documentation
    signature_help = '<C-k>',   -- Signature help

    -- Editing
    rename = '<leader>rn',      -- Rename symbol
    code_action = '<leader>ca', -- Code actions
    format = '<leader>f',       -- Format

    -- Diagnostics
    goto_prev = '[d',           -- Go to previous diagnostic
    goto_next = ']d',           -- Go to next diagnostic
    open_float = '<leader>e',   -- Show diagnostic float
    setloclist = '<leader>q',   -- Set diagnostics to location list
  },

  -- Behavior settings
  use_global_handlers = false,      -- Use global handlers
  silent_fallbacks = false,         -- Don't notify on fallback
  decompile_on_jar = true,          -- Auto-decompile when jumping into JARs
  show_capabilities_on_attach = false,  -- Show server capabilities on attach

  -- Decompile settings
  decompile = {
    show_line_numbers = true,       -- Show line numbers
    syntax_highlight = true,        -- Enable syntax highlighting
    auto_close_on_leave = false,    -- Auto-close buffer when leaving
    prefer_source = true,           -- Prefer source when available
  },

  -- Performance settings
  performance = {
    debounce_ms = 100,              -- Debounce time (milliseconds)
    max_file_size = 1024 * 1024,    -- Maximum file size (1MB)
    cache_enabled = true,           -- Enable caching
    cache_ttl = 3600,               -- Cache time-to-live (seconds)
  },

  -- LSP settings
  lsp = {
    timeout_ms = 5000,              -- Timeout
    retry_count = 3,                -- Retry count
    retry_delay_ms = 500,           -- Retry delay
  },

  -- Logging settings
  log = {
    level = 'info',                 -- trace, debug, info, warn, error, off
    use_console = true,             -- Output to console
    use_file = false,               -- Output to file
    file_path = vim.fn.stdpath('cache') .. '/kotlin-extended-lsp.log',
  },

  -- UI settings
  ui = {
    float = {
      border = 'rounded',           -- Float window border style
      max_width = 100,              -- Maximum width
      max_height = 30,              -- Maximum height
    },
    signs = {
      decompiled = '󰘧',             -- Decompiled sign
      loading = '󰔟',                -- Loading sign
      error = '',                  -- Error sign
    },
  },

  -- Linting settings
  linting = {
    enabled = true,                 -- Enable linting
    on_save = true,                 -- Lint on save
    on_type = false,                -- Lint on type (debounced)
    debounce_ms = 500,              -- Debounce delay for on_type
    tools = {
      detekt = {
        enabled = true,             -- Enable detekt
        cmd = nil,                  -- Auto-detect or specify path
        config_file = nil,          -- Auto-detect detekt.yml or specify path
        baseline_file = nil,        -- Baseline file path
        build_upon_default_config = false,
        parallel = true,            -- Run in parallel
      },
      ktlint = {
        enabled = true,             -- Enable ktlint
        cmd = nil,                  -- Auto-detect or specify path
        config_file = nil,          -- .editorconfig auto-detected
        android = false,            -- Use Android style
        experimental = false,       -- Use experimental rules
      },
    },
  },

  -- Formatting settings
  formatting = {
    enabled = true,                 -- Enable formatting
    on_save = false,                -- Format on save
    prefer_formatter = 'ktlint',    -- 'ktlint', 'ktfmt', 'lsp', 'none'
    tools = {
      ktlint = {
        enabled = true,             -- Enable ktlint formatter
        cmd = nil,                  -- Auto-detect or specify path
        config_file = nil,          -- .editorconfig auto-detected
        android = false,            -- Use Android style
      },
      ktfmt = {
        enabled = true,             -- Enable ktfmt formatter
        cmd = nil,                  -- Auto-detect or specify path
        style = 'google',           -- 'google', 'kotlinlang', 'dropbox'
        max_width = 100,            -- Maximum line width
      },
    },
  },

  -- Editor settings
  editor = {
    editorconfig = true,            -- Auto-detect and apply .editorconfig
    organize_imports_on_save = true,-- Organize imports on save
    trim_trailing_whitespace = true,-- Trim trailing whitespace on save
    insert_final_newline = true,    -- Insert final newline on save
    max_line_length = 120,          -- Visual guide for max line length
  },
})
```

## Commands

The plugin provides the following user commands:

### `:KotlinLspCapabilities`

Display kotlin-lsp server capabilities.

```vim
:KotlinLspCapabilities
```

### `:KotlinDecompile [uri]`

Decompile the specified JAR/class file URI. If no argument is provided, decompiles the current buffer's file.

```vim
:KotlinDecompile
:KotlinDecompile jar:file:///path/to/library.jar!/com/example/MyClass.class
```

### `:KotlinClearCache`

Clear the decompilation cache.

```vim
:KotlinClearCache
```

### `:KotlinToggleLog [level]`

Change the log level. If no argument is provided, displays the current log level.

```vim
:KotlinToggleLog debug
:KotlinToggleLog info
:KotlinToggleLog
```

Available levels: `trace`, `debug`, `info`, `warn`, `error`, `off`

### `:KotlinShowConfig`

Display the current configuration.

```vim
:KotlinShowConfig
```

### `:KotlinLint`

Run linters on the current buffer.

```vim
:KotlinLint
```

### `:KotlinToggleLinting`

Toggle linting on/off.

```vim
:KotlinToggleLinting
```

### `:KotlinFormat [formatter]`

Format the current buffer. Optionally specify a formatter (`ktlint`, `ktfmt`, or `lsp`).

```vim
:KotlinFormat
:KotlinFormat ktlint
:KotlinFormat ktfmt
```

### `:KotlinOrganizeImports`

Organize imports in the current buffer using LSP.

```vim
:KotlinOrganizeImports
```

### `:KotlinExtendedLspHealth`

Run a health check for the plugin.

```vim
:KotlinExtendedLspHealth
```

## Keymaps

Default keymaps (when `auto_setup_keymaps = true`):

### Navigation (Jump Functions)

| Key | Function | Description |
|-----|----------|-------------|
| `gd` | Jump to definition | Auto-decompiles definitions in JAR files |
| `gi` | Jump to implementation | Falls back to definition if implementation not found |
| `gy` | Jump to type definition | Jump to type definition location |
| `gD` | Jump to declaration | Jump to declaration location |
| `gr` | Find references | Search for symbol references |

### Documentation

| Key | Function | Description |
|-----|----------|-------------|
| `K` | Hover documentation | Display documentation for symbol under cursor |
| `<C-k>` | Signature help | Display function signature (works in insert mode) |

### Editing

| Key | Function | Description |
|-----|----------|-------------|
| `<leader>rn` | Rename symbol | Rename symbol under cursor |
| `<leader>ca` | Code actions | Display available code actions (works in visual mode) |
| `<leader>f` | Format | Format entire document or selection |

### Diagnostics

| Key | Function | Description |
|-----|----------|-------------|
| `[d` | Go to previous diagnostic | Jump to previous error/warning |
| `]d` | Go to next diagnostic | Jump to next error/warning |
| `<leader>e` | Show diagnostic float | Display diagnostic in float window |
| `<leader>q` | Set diagnostics to location list | Add all diagnostics to location list |

### Keymap Customization

You can freely customize keymaps in the configuration. Set to empty string to disable a keymap.

```lua
require('kotlin-extended-lsp').setup({
  keymaps = {
    -- Navigation
    definition = '<leader>gd',
    implementation = '<leader>gi',
    type_definition = '',  -- Disabled
    declaration = '',      -- Disabled
    references = 'gr',

    -- Documentation
    hover = 'K',
    signature_help = '<C-s>',  -- Changed to Ctrl-s

    -- Editing
    rename = '<F2>',           -- Changed to F2
    code_action = '<leader>ca',
    format = '<leader>lf',     -- Changed to <leader>lf

    -- Diagnostics
    goto_prev = '[e',          -- Changed to [e
    goto_next = ']e',          -- Changed to ]e
    open_float = 'gl',         -- Changed to gl
    setloclist = '',           -- Disabled
  },
})
```

## Health Check

To check the plugin status, run:

```vim
:KotlinExtendedLspHealth
```

Or use Neovim's standard health check:

```vim
:checkhealth kotlin-extended-lsp
```

The health check verifies:

- Plugin initialization status
- kotlin-lsp server connection
- Server-supported capabilities
- Decompilation feature availability
- Cache status

## Troubleshooting

### Cannot jump into JAR files

1. Verify that the official JetBrains kotlin-lsp is correctly installed
   - `brew install JetBrains/utils/kotlin-lsp`
2. Run the health check to verify the `kotlin/jarClassContents` command is available
3. Set log level to `debug` to view detailed logs

```vim
:KotlinToggleLog debug
```

### Decompilation results not displayed

1. Check if file size exceeds `performance.max_file_size`
2. Try clearing the cache: `:KotlinClearCache`
3. Try extending the timeout

```lua
require('kotlin-extended-lsp').setup({
  lsp = {
    timeout_ms = 10000,  -- Extend to 10 seconds
  },
})
```

### Performance issues

1. Verify caching is enabled
2. Adjust debounce time
3. Limit maximum file size

```lua
require('kotlin-extended-lsp').setup({
  performance = {
    cache_enabled = true,
    debounce_ms = 200,
    max_file_size = 512 * 1024,  -- Limit to 512KB
  },
})
```

### Checking log files

Enable log file output to view detailed information:

```lua
require('kotlin-extended-lsp').setup({
  log = {
    level = 'debug',
    use_file = true,
    file_path = vim.fn.stdpath('cache') .. '/kotlin-extended-lsp.log',
  },
})
```

Log file location:

```bash
# Unix/Linux/macOS
~/.cache/nvim/kotlin-extended-lsp.log

# Windows
~/AppData/Local/nvim-data/kotlin-extended-lsp.log
```

## Contributing

Contributions are welcome! Bug reports, feature suggestions, and pull requests are all appreciated.

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

MIT License - See [LICENSE](LICENSE) file for details.

## Acknowledgments

This project is grateful to:

- [Official JetBrains kotlin-lsp](https://github.com/Kotlin/kotlin-lsp) - Official Kotlin language server implementation (pre-alpha stage)
- [omnisharp-extended-lsp.nvim](https://github.com/Hoffs/omnisharp-extended-lsp.nvim) - Inspiration for this plugin
- Neovim community - For the amazing editor and ecosystem

## Links

- [Issue Tracker](https://github.com/yourusername/kotlin-extended-lsp.nvim/issues)
- [Pull Requests](https://github.com/yourusername/kotlin-extended-lsp.nvim/pulls)
- [Changelog](https://github.com/yourusername/kotlin-extended-lsp.nvim/releases)
