-- Minimal init for testing

-- Add plugin to runtimepath
vim.opt.runtimepath:append('.')

-- Add plenary.nvim for testing
local plenary_dir = vim.fn.stdpath('data') .. '/site/pack/vendor/start/plenary.nvim'
vim.opt.runtimepath:append(plenary_dir)

-- Minimal LSP setup (mocked)
vim.lsp = vim.lsp or {}
vim.lsp.buf_request = vim.lsp.buf_request or function() end
vim.lsp.get_clients = vim.lsp.get_clients or function()
  return {}
end
vim.lsp.get_buffers_by_client_id = vim.lsp.get_buffers_by_client_id or function()
  return {}
end

-- Load plugin
require('kotlin-extended-lsp')
