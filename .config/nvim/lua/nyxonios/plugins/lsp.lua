-- Config taking form kickstart.nvim: https://github.com/nvim-lua/kickstart.nvim/blob/master/init.lua
return {
  -- Go LSP with extra stuff.
  {
    'ray-x/go.nvim',
    dependencies = { -- optional packages
      'neovim/nvim-lspconfig',
      'nvim-treesitter/nvim-treesitter',
    },
    config = function()
      require('go').setup {
        icons = false,
        lsp_inlay_hints = {
          enable = false,
        },
        lsp_cfg = true,
        lsp_keymaps = false,
        dap_debug_keymap = false,
        diagnostic = { -- set diagnostic to false to disable diagnostic
          hdlr = false, -- hook diagnostic handler and send error to quickfix
          underline = true,
          -- virtual text setup
          virtual_text = { spacing = 0, prefix = '■' },
          update_in_insert = false,
          signs = true, -- use a table to configure the signs texts
        },
      }
      vim.keymap.set('n', '<leader>tf', '<cmd>GoTestFunc<CR>')
      vim.keymap.set('n', '<leader>db', '<cmd>GoDebug<CR>')
      vim.keymap.set('n', '<leader>fs', '<cmd>GoFillStruct<CR>')
      vim.keymap.set('n', '<leader>at', '<cmd>GoAddTest<CR>')
    end,
    event = { 'CmdlineEnter' },
    ft = { 'go', 'gomod' },
    build = ':lua require("go.install").update_all_sync()', -- if you need to install/update all binaries
  },
  -- Typescript LSP with extra stuff.
  {
    'pmizio/typescript-tools.nvim',
    dependencies = { 'nvim-lua/plenary.nvim', 'neovim/nvim-lspconfig' },
    opts = {
      settings = {
        tsserver_format_options = {
          importModuleSpecifierPreference = 'project-relative',
        },
      },
    },
  },
  -- Pickle language
  {
    'apple/pkl-neovim',
    lazy = true,
    ft = 'pkl',
    dependencies = {
      {
        'nvim-treesitter/nvim-treesitter',
        build = function(_)
          vim.cmd 'TSUpdate'
        end,
      },
      'L3MON4D3/LuaSnip',
    },
    build = function()
      require('pkl-neovim.internal').init()

      -- Set up syntax highlighting.
      vim.cmd 'TSInstall! pkl'
    end,
    config = function()
      -- Set up snippets.
      require('luasnip.loaders.from_snipmate').lazy_load()
    end,
  },
  {
    -- LSP Configuration & Plugins
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Neovim completion
      { 'folke/neodev.nvim', opts = {} },

      -- Useful status updates for LSP.
      -- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
      { 'j-hui/fidget.nvim', opts = {} },
    },
    config = function()
      local lspconfig = require 'lspconfig'

      local flakePath = '~/dotfiles/nix/flake.nix'
      lspconfig.nixd.setup {
        cmd = { 'nixd' },
        settings = {
          nixd = {
            nixpkgs = {
              expr = 'import (builtins.getFlake "' .. flakePath .. '").inputs.nixpkgs { }',
            },
            formatting = {
              command = { 'nixpkgs-fmt' }, -- or nixfmt or nixpkgs-fmt
            },
            options = {
              nixos = {
                expr = '(builtins.getFlake "' .. flakePath .. '").darwinConfigurations.work.options',
              },
              home_manager = {
                expr = '(builtins.getFlake "' .. flakePath .. '").homeConfigurations.options',
              },
            },
          },
        },
      }
      lspconfig.zls.setup {
        cmd = { 'zls' },
        settings = {},
      }
      lspconfig.rust_analyzer.setup {}

      --  This function gets run when an LSP attaches to a particular buffer.
      --    That is to say, every time a new file is opened that is associated with
      --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
      --    function will be executed to configure the current buffer
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
        callback = function(event)
          -- NOTE: Remember that lua is a real programming language, and as such it is possible
          -- to define small helper and utility functions so you don't have to repeat yourself
          -- many times.
          --
          -- In this case, we create a function that lets us more easily define mappings specific
          -- for LSP related items. It sets the mode, buffer and description for us each time.
          local map = function(keys, func, desc)
            vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- Jump to the definition of the word under your cursor.
          --  This is where a variable was first declared, or where a function is defined, etc.
          --  To jump back, press <C-T>.
          map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')

          -- Find references for the word under your cursor.
          map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')

          -- Jump to the implementation of the word under your cursor.
          --  Useful when your language has ways of declaring types without an actual implementation.
          map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')

          -- Jump to the type of the word under your cursor.
          --  Useful when you're not sure what type a variable is and you want to see
          --  the definition of its *type*, not where it was *defined*.
          map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')

          -- Fuzzy find all the symbols in your current document.
          --  Symbols are things like variables, functions, types, etc.
          map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')

          -- Fuzzy find all the symbols in your current workspace
          --  Similar to document symbols, except searches over your whole project.
          map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')

          -- Rename the variable under your cursor
          --  Most Language Servers support renaming across files, etc.
          map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')

          -- Opens a popup that displays documentation about the word under your cursor
          --  See `:help K` for why this keymap
          map('K', vim.lsp.buf.hover, 'Hover Documentation')

          -- WARN: This is not Goto Definition, this is Goto Declaration.
          --  For example, in C this would take you to the header
          map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
        end,
      })

      -- LSP servers and clients are able to communicate to each other what features they support.
      --  By default, Neovim doesn't support everything that is in the LSP Specification.
      --  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
      --  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

      --   -- Enable the following language servers
      --   --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
      --   --
      --   --  Add any additional override configuration in the following tables. Available keys are:
      --   --  - cmd (table): Override the default command used to start the server
      --   --  - filetypes (table): Override the default list of associated filetypes for the server
      --   --  - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
      --   --  - settings (table): Override the default settings passed when initializing the server.
      --   --        For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
      --   local servers = {
      --     -- gopls = {}, -- Handled with external plugin
      --     -- tsserver = {}, -- Handled with external plugin
      --     -- rust_analyzer = {},
      --     -- templ = {},
      --     -- html = {
      --     --   filetypes = { 'html', 'templ' },
      --     -- },
      --     -- htmx = {
      --     --   filetypes = { 'html', 'templ' },
      --     -- },
      --     -- tailwindcss = {
      --     --   filetypes = { 'html', 'templ' },
      --     -- },
      --     -- ... etc. See `:help lspconfig-all` for a list of all the pre-configured LSPs
      --     --
      --     -- Some languages (like typescript) have entire language plugins that can be useful:
      --     --    https://github.com/pmizio/typescript-tools.nvim
      --     --
      --     -- But for many setups, the LSP (`tsserver`) will work just fine
      --     -- tsserver = {},
      --     --
      --
      --     lua_ls = {
      --       -- cmd = {...},
      --       -- filetypes { ...},
      --       -- capabilities = {},
      --       settings = {
      --         Lua = {
      --           runtime = { version = 'LuaJIT' },
      --           workspace = {
      --             checkThirdParty = false,
      --             -- Tells lua_ls where to find all the Lua files that you have loaded
      --             -- for your neovim configuration.
      --             library = {
      --               '${3rd}/luv/library',
      --               unpack(vim.api.nvim_get_runtime_file('', true)),
      --             },
      --             -- If lua_ls is really slow on your computer, you can try this instead:
      --             -- library = { vim.env.VIMRUNTIME },
      --           },
      --           completion = {
      --             callSnippet = 'Replace',
      --           },
      --           -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
      --           -- diagnostics = { disable = { 'missing-fields' } },
      --         },
      --       },
      --     },
      --   }
      --
      --   -- Ensure the servers and tools above are installed
      --   --  To check the current status of installed tools and/or manually install
      --   --  other tools, you can run
      --   --    :Mason
      --   --
      --   --  You can press `g?` for help in this menu
      --   require('mason').setup()
      --
      --   -- You can add other tools here that you want Mason to install
      --   -- for you, so that they are available from within Neovim.
      --   local ensure_installed = vim.tbl_keys(servers or {})
      --   vim.list_extend(ensure_installed, {})
      --   require('mason-tool-installer').setup { ensure_installed = ensure_installed }
      --
      --   require('mason-lspconfig').setup {
      --     handlers = {
      --       function(server_name)
      --         local server = servers[server_name] or {}
      --         -- This handles overriding only values explicitly passed
      --         -- by the server configuration above. Useful when disabling
      --         -- certain features of an LSP (for example, turning off formatting for tsserver)
      --         server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
      --         require('lspconfig')[server_name].setup(server)
      --       end,
      --     },
      --   }
    end,
  },
}
