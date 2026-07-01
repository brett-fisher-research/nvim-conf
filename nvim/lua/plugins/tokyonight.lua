return {
  "folke/tokyonight.nvim",
  lazy = false,
  priority = 1000, -- load before everything else so the colorscheme applies first
  config = function()
    vim.cmd.colorscheme("tokyonight")
  end,
}
