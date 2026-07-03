-- Leader must be set before lazy.nvim loads so plugin keymaps bind correctly.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Options
-- Windows only: wezterm's Git Bash leaks $SHELL into nvim while shellcmdflag
-- stays cmd-style `/s /c`, breaking every :! (exit 127); pin cmd.exe to restore
-- nvim's consistent Windows defaults. POSIX machines keep their normal shell.
if vim.fn.has("win32") == 1 then
  vim.o.shell = "cmd.exe"
end
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

-- <leader>h — floating cheatsheet of this config's commands.
local cheatsheet = {
  "  Files",
  "   <Space>e     toggle file tree   (in tree: I gitignored, H dotfiles)",
  "   <Space>ff    find files",
  "   <Space>fr    recent files",
  "   <Space>fs    grep in cwd",
  "   <Space>fc    grep word under cursor",
  "",
  "  Pull requests (octo — API only, never touches your checkout)",
  "   <Space>pl    list ALL my open PRs, every repo (Enter opens one)",
  "   <Space>pd    diff the open PR",
  "   <Space>po    open PR by number",
  "   <Space>pc    PR checks (CI)",
  "   <Space>pb    open PR in browser",
  "",
  "  Misc",
  "   <Space>mp    toggle markdown preview (current buffer)",
  "   <Space>h     this cheatsheet (q or Esc closes)",
  "   :Lazy update update plugins (never automatic)",
}
vim.keymap.set("n", "<leader>h", function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, cheatsheet)
  vim.bo[buf].modifiable = false
  local width = 0
  for _, l in ipairs(cheatsheet) do width = math.max(width, #l) end
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width + 2,
    height = #cheatsheet,
    row = math.floor((vim.o.lines - #cheatsheet) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " Cheatsheet ",
  })
  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, function() vim.api.nvim_win_close(win, true) end, { buffer = buf })
  end
end, { desc = "Show keymap cheatsheet" })
