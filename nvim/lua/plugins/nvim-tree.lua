return {
  "nvim-tree/nvim-tree.lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("nvim-tree").setup({
      -- Workspaces like brot-os gitignore whole tenant dirs; the tree must still show them
      filters = {
        git_ignored = false,
      },
      view = {
        side = "right",
        width = 50,
      },
      update_focused_file = {
        enable = true,
        update_root = true,
      },
      sync_root_with_cwd = true,
      -- Claude Code agent churn blows past max_events (1000); the tree refreshes on focus instead
      filesystem_watchers = {
        enable = false,
      },
    })
    vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { silent = true, desc = "Toggle file explorer" })

    -- Watchers are off, so reload the tree when nvim regains focus (wezterm forwards focus events)
    vim.api.nvim_create_autocmd("FocusGained", {
      group = vim.api.nvim_create_augroup("NvimTreeFocusRefresh", { clear = true }),
      callback = function()
        local ok, api = pcall(require, "nvim-tree.api")
        if ok and api.tree.is_visible() then
          api.tree.reload()
        end
      end,
    })
  end,
}
