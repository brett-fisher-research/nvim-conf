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
    -- Not `Octo pr browser`: octo shells out via `:!`, which breaks when nvim runs
    -- under Git Bash on Windows (bash shell + cmd-style shellcmdflag, silent exit 127).
    -- vim.ui.open spawns the OS opener directly, no shell involved.
    keymap.set("n", "<leader>pb", function()
      local buffer = require("octo.utils").get_current_buffer()
      if not buffer or not buffer.node or not buffer.node.url then
        vim.notify("Not in an Octo buffer — open a PR first (<leader>pl)", vim.log.levels.WARN)
        return
      end
      vim.ui.open(buffer.node.url)
    end, { desc = "Open PR in browser" })
    keymap.set("n", "<leader>po", function()
      vim.ui.input({ prompt = "PR number: " }, function(num)
        if num and num ~= "" then
          vim.cmd("Octo pr edit " .. num)
        end
      end)
    end, { desc = "Open PR by number" })
  end,
}
