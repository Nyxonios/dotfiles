require 'nyxonios.commands'
require 'nyxonios.set'
require 'nyxonios.remap'
require 'nyxonios.autocmd'

-- On macOS with Nix, the wrapped cc/clang injects --target flags that conflict
-- with tree-sitter build's own --target, causing linker errors. Force the use
-- of the system Apple clang for any in-editor compilation (treesitter, mason, etc).
if vim.fn.has('mac') == 1 then
  vim.env.CC = '/usr/bin/clang'
  vim.env.CXX = '/usr/bin/clang++'
end

local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', -- latest stable release
    lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup {
  spec = 'nyxonios.plugins',
  change_detection = { notify = false },
}
