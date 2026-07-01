return {
  "nvim-tree/nvim-tree.lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("nvim-tree").setup({
      view = {
        side = "right",
        width = 50,
      },
      update_focused_file = {
        enable = true,
        update_root = true,
      },
      sync_root_with_cwd = true,
    })
    vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { silent = true, desc = "Toggle file explorer" })
  end,
}
