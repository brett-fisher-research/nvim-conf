return {
  "lewis6991/gitsigns.nvim",
  config = function()
    require("gitsigns").setup()

    local keymap = vim.keymap
    keymap.set("n", "<leader>gp", require("gitsigns").preview_hunk, { desc = "Preview hunk diff" })
  end,
}
