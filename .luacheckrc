-- Luacheck configuration for kotlin-extended-lsp.nvim

std = "luajit"
globals = { "vim" }
max_line_length = false

-- Ignore warnings for unused arguments
ignore = {
  "212", -- Unused argument
  "631", -- Line is too long (we handle this with formatters)
  "122", -- Setting read-only field of global variable
}

-- Read-only globals (but allow setting fields)
read_globals = {
  "vim",
}

-- Files to check
files = {
  "lua/**/*.lua",
  "plugin/**/*.lua",
}

-- Exclude generated or external files
exclude_files = {
  "tests/minimal_init.lua",
}
