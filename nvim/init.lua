-- Leader must be set before lazy.nvim loads so plugin keymaps bind correctly.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Options
vim.opt.number = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.termguicolors = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.swapfile = false

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = { { import = "plugins" } },
  -- Never nag about plugin updates.
  checker = { enabled = false },
})

-- Syntax highlighting via core treesitter (nvim 0.12): start it for any
-- filetype that has a parser installed; fail silently for the rest.
local ts_group = vim.api.nvim_create_augroup("TreesitterStart", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = ts_group,
  desc = "Start core treesitter highlighting when a parser exists",
  callback = function(args)
    pcall(vim.treesitter.start, args.buf)
  end,
})

-- :PR <num> — check out a GitHub PR and review it as a diff against the
-- repo's default branch.
vim.api.nvim_create_user_command("PR", function(opts)
  local num = opts.args
  local out = vim.fn.system({ "gh", "pr", "checkout", num })
  if vim.v.shell_error ~= 0 then
    vim.notify("gh pr checkout " .. num .. " failed:\n" .. out, vim.log.levels.ERROR)
    return
  end
  local default = vim.trim(vim.fn.system({
    "gh", "repo", "view", "--json", "defaultBranchRef", "-q", ".defaultBranchRef.name",
  }))
  if vim.v.shell_error ~= 0 or default == "" then
    default = "main"
  end
  vim.cmd("DiffviewOpen origin/" .. default .. "...HEAD")
end, { nargs = 1, desc = "Check out PR <num> and diff it against the default branch" })
