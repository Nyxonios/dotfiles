-- Override foldexpr set by pkl-neovim's ftplugin for nvim-treesitter main branch compatibility
vim.opt_local.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
