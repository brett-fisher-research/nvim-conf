return {
  "sindrets/diffview.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("diffview").setup()

    local keymap = vim.keymap
    keymap.set("n", "<leader>gd", "<cmd>DiffviewOpen<cr>", { desc = "Full diff view" })
    keymap.set("n", "<leader>gq", "<cmd>DiffviewClose<cr>", { desc = "close diff view" })
  end,
}
