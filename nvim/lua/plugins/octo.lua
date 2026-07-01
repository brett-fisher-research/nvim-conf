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
    keymap.set("n", "<leader>pl", "<cmd>Octo pr list<cr>", { desc = "List open PRs" })
    keymap.set("n", "<leader>pd", "<cmd>Octo pr diff<cr>", { desc = "Diff the open PR" })
    keymap.set("n", "<leader>pc", "<cmd>Octo pr checks<cr>", { desc = "PR checks (CI)" })
    keymap.set("n", "<leader>pb", "<cmd>Octo pr browser<cr>", { desc = "Open PR in browser" })
    keymap.set("n", "<leader>po", function()
      vim.ui.input({ prompt = "PR number: " }, function(num)
        if num and num ~= "" then
          vim.cmd("Octo pr edit " .. num)
        end
      end)
    end, { desc = "Open PR by number" })
  end,
}
