return {
  "pwntester/octo.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  config = function()
    require("octo").setup({})

    -- PR family: viewing is API-only and never touches the local checkout
    local keymap = vim.keymap
    -- All open PRs across every repo the account owns, not just the cwd repo
    keymap.set("n", "<leader>pl", "<cmd>Octo search is:open is:pr user:@me<cr>", { desc = "List all my open PRs" })
    keymap.set("n", "<leader>pd", "<cmd>Octo pr diff<cr>", { desc = "Diff the open PR" })
    keymap.set("n", "<leader>pc", "<cmd>Octo pr checks<cr>", { desc = "PR checks (CI)" })
    keymap.set("n", "<leader>po", function()
      vim.ui.input({ prompt = "PR number: " }, function(num)
        if num and num ~= "" then
          vim.cmd("Octo pr edit " .. num)
        end
      end)
    end, { desc = "Open PR by number" })
  end,
}
