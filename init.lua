-- init.lua

-- Leader keys
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.opt.number            = true
vim.opt.relativenumber    = true
vim.opt.mouse             = "a"
vim.opt.clipboard         = "unnamedplus"
vim.opt.expandtab         = true
vim.opt.shiftwidth        = 2
vim.opt.tabstop           = 2
vim.opt.smartindent       = true
vim.opt.wrap              = false

-- Indent-based folding
vim.opt.foldmethod      = "indent"
vim.opt.foldlevelstart  = 99

-- True Color & Syntax Highlighting
vim.cmd('syntax on')
vim.cmd('filetype plugin indent on')
vim.opt.synmaxcol = 200

-- Keymaps
vim.api.nvim_set_keymap('i', 'jj', '<Esc>', { noremap = true, silent = true })

local map = vim.keymap.set
-- Window navigation (normal mode)
map("n", "<leader>h", "<C-w>h")
map("n", "<leader>j", "<C-w>j")
map("n", "<leader>k", "<C-w>k")
map("n", "<leader>l", "<C-w>l")
-- Window navigation (terminal mode)
map("t", "<leader>h", [[<C-\><C-n><C-w>h]])
map("t", "<leader>j", [[<C-\><C-n><C-w>j]])
map("t", "<leader>k", [[<C-\><C-n><C-w>k]])
map("t", "<leader>l", [[<C-\><C-n><C-w>l]])
-- Open terminal split
map("n", "<leader>tt", ":belowright split | terminal<CR>", { silent = true })

-- Scratch buffer for messing around
vim.api.nvim_create_user_command("Scratch", function()
  vim.cmd("enew")
  vim.opt_local.buftype = "nofile"
  vim.opt_local.bufhidden = "wipe"
  vim.opt_local.swapfile = false
end, {})

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- UI & navigation
  { "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" } },
  { "nvim-tree/nvim-tree.lua",    dependencies = { "nvim-tree/nvim-web-devicons" } },
  { "nvim-lualine/lualine.nvim",  dependencies = { "nvim-tree/nvim-web-devicons" } },
  { "lewis6991/gitsigns.nvim" },
  
  -- ─── LSP & Tooling ──────────────────────────────────────────────────────
  { "williamboman/mason.nvim",           build        = ":MasonUpdate" },
  { "williamboman/mason-lspconfig.nvim", dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" } },
  { "neovim/nvim-lspconfig",             dependencies = { "williamboman/mason.nvim" } },
  
  -- ─── Treesitter (Enhanced Syntax) ───────────────────────────────────────
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup {
        ensure_installed = { "lua", "python", "go", "typescript" },
        highlight = { 
          enable = true,
        },
      }
    end,
  },

  --dev tools
  {
  "CopilotC-Nvim/CopilotChat.nvim",
	  dependencies = {
	    "github/copilot.vim",
	    "nvim-lua/plenary.nvim"
	  }
  },
})

-- Basic Colorscheme
vim.opt.background = "dark"
vim.cmd[[colorscheme habamax]]

-- Plugin Setups
require("lualine").setup()
require("nvim-tree").setup()
require("gitsigns").setup()
require("CopilotChat").setup({
  sticky = {"@claude-3.7-sonnet","buffers"},
  selection = function(source)
    return require("CopilotChat.select").buffer(source)
  end,
})

map("n", ";c", "<cmd>CopilotChatToggle<CR>", { noremap = true, silent = true })

-- Telescope keymaps
map("n", "<leader>ff", require("telescope.builtin").find_files, {})
map("n", "<leader>fg", require("telescope.builtin").live_grep,   {})
map("n", "<leader>fb", require("telescope.builtin").buffers,     {})
map("n", "<leader>e", ":NvimTreeToggle<CR>",                    { silent = true })

-- Mason & LSPInstaller
require("mason").setup()
require("mason-lspconfig").setup({
  ensure_installed = { "gopls", "pyright", "ts_ls", "rust_analyzer" },
})

-- LSP configuration
local lspconfig = require("lspconfig")

local on_attach = function(client, bufnr)
  local bufmap = vim.api.nvim_buf_set_keymap
  local opts   = { noremap = true, silent = true }
  bufmap(bufnr, "n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
  bufmap(bufnr, "n", "K",  "<cmd>lua vim.lsp.buf.hover()<CR>",      opts)
if client.server_capabilities.documentFormattingProvider then
  vim.api.nvim_create_autocmd("BufWritePre", {
    buffer = bufnr,
    callback = function()
      vim.lsp.buf.format()
    end,
  })
end
end

-- Python (Pyright)
lspconfig.pyright.setup({
  on_attach = on_attach,
})

-- Go (gopls)
lspconfig.gopls.setup({
  on_attach = on_attach,
  settings = {
    gopls = {
      analyses   = { unusedparams = true },
      staticcheck = true,
    },
  },
})

-- JavaScript/TypeScript (ts_ls)
lspconfig.ts_ls.setup({
  on_attach = on_attach,
})

-- Rust (rust_analyzer)
lspconfig.rust_analyzer.setup({
  on_attach = on_attach,
})
