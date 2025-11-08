-- plugin/kotlin-extended-lsp.lua
-- Entry point for kotlin-extended-lsp.nvim

-- Prevent double loading
if vim.g.loaded_kotlin_extended_lsp then
  return
end
vim.g.loaded_kotlin_extended_lsp = 1

-- Create plugin commands immediately (before setup is called)
-- This allows users to access help and check health before configuration

vim.api.nvim_create_user_command('KotlinExtendedLspHealth', function()
  local ok, plugin = pcall(require, 'kotlin-extended-lsp')
  if not ok then
    vim.notify('Failed to load kotlin-extended-lsp: ' .. plugin, vim.log.levels.ERROR)
    return
  end

  plugin.check()
end, { desc = 'Run health check for kotlin-extended-lsp.nvim' })

-- Note: The main setup is done by users in their config
-- Example:
-- require('kotlin-extended-lsp').setup({
--   -- config here
-- })
