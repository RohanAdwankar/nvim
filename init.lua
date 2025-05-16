-- init.lua

-- Leader keys
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Basic options
vim.opt.number         = true
vim.opt.relativenumber = true
vim.opt.mouse          = "a"
vim.opt.clipboard      = "unnamedplus"
vim.opt.expandtab      = true
vim.opt.shiftwidth     = 2
vim.opt.tabstop        = 2
vim.opt.smartindent    = true
vim.opt.wrap           = false

-- Keymaps
vim.api.nvim_set_keymap('i', 'ii', '<Esc>', { noremap = true, silent = true })

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

-- Bootstrap lazy.nvim
vim.opt.rtp:prepend("~/.config/nvim/lazy/lazy.nvim")

require("lazy").setup({
  -- UI & navigation
  { "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" } },
  { "nvim-tree/nvim-tree.lua",    dependencies = { "nvim-tree/nvim-web-devicons" } },
  { "nvim-lualine/lualine.nvim",  dependencies = { "nvim-tree/nvim-web-devicons" } },
  { "lewis6991/gitsigns.nvim" },

  -- LSP & tooling
  { "williamboman/mason.nvim",             build        = ":MasonUpdate" },
  { "williamboman/mason-lspconfig.nvim",   dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" } },
  { "neovim/nvim-lspconfig",               dependencies = { "williamboman/mason.nvim" } },
})

-- Plugin setups
require('lualine').setup()
require('nvim-tree').setup()
require('gitsigns').setup()

-- Telescope keymaps
map("n", "<leader>ff", require("telescope.builtin").find_files, {})
map("n", "<leader>fg", require("telescope.builtin").live_grep,   {})
map("n", "<leader>fb", require("telescope.builtin").buffers,     {})
map("n", "<leader>e", ":NvimTreeToggle<CR>",                    { silent = true })

-- Mason & LSPInstaller
require("mason").setup()
require("mason-lspconfig").setup({
  ensure_installed = { "gopls", "pyright", "ts_ls" },
})

-- LSP configuration
local lspconfig = require("lspconfig")

local on_attach = function(client, bufnr)
  local bufmap = vim.api.nvim_buf_set_keymap
  local opts   = { noremap = true, silent = true }
  bufmap(bufnr, "n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
  bufmap(bufnr, "n", "K",  "<cmd>lua vim.lsp.buf.hover()<CR>",      opts)
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
