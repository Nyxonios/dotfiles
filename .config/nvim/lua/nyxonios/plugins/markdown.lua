return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
    opts = {},
    config = function()
      -- We disable by default.
      require('render-markdown').disable()
    end,
  },
  {
    'richardbizik/nvim-toc',
    opts = {},
  },
}
