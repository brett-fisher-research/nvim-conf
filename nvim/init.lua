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
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.termguicolors = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.swapfile = false
vim.opt.clipboard = "unnamedplus"
-- Completion menu behavior: show the popup (menuone lets it appear for a lone
-- match) but never auto-insert or auto-select - the first item stays unpicked
-- until the user chooses, so typing through a trigger char inserts nothing.
vim.opt.completeopt = { "menu", "menuone", "noinsert", "noselect", "popup" }

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

-- LSP: nvim 0.12's built-in client only. No plugins are involved.
-- Servers are declared one file per server in nvim/lsp/<name>.lua and turned on
-- by name here. Adding a language = install its binary + drop one file + list it.
vim.lsp.enable({ "basedpyright", "ruff", "ts7", "eslint" })

-- Diagnostic display: red undercurl (tokyonight already styles the group),
-- a terse ambient hint on every offending line, and the full multi-line
-- message expanded under the cursor's line only.
vim.diagnostic.config({
  severity_sort = true,
  underline = true,
  update_in_insert = false,
  virtual_text = { spacing = 2, prefix = "●" },
  virtual_lines = { current_line = true },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "E",
      [vim.diagnostic.severity.WARN] = "W",
      [vim.diagnostic.severity.INFO] = "I",
      [vim.diagnostic.severity.HINT] = "H",
    },
  },
  float = { border = "rounded", source = true },
})

-- Nvim 0.12 already maps grr/grn/gra/gri/grt/grx/gO/K/<C-]>/]d/[d/<C-w>d.
-- Only the two muscle-memory keys it leaves free are added here.
vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "LSP: go to definition" })
vim.keymap.set("n", "gR", vim.lsp.buf.references, { desc = "LSP: list references" })

local lsp_group = vim.api.nvim_create_augroup("BrotLspAttach", { clear = true })
vim.api.nvim_create_autocmd("LspAttach", {
  group = lsp_group,
  desc = "Per-client LSP setup: completion autotrigger, single hover provider",
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then
      return
    end

    -- ruff's hover is a lint-rule blurb; basedpyright's is the real docs, so
    -- ruff stops advertising hover and K always reaches basedpyright.
    if client.name == "ruff" then
      client.server_capabilities.hoverProvider = false
    end

    -- Built-in completion (<C-x><C-o> plus autotrigger) for any server that
    -- offers it, with no completion plugin involved.
    if client:supports_method("textDocument/completion") then
      pcall(vim.lsp.completion.enable, true, client.id, args.buf, { autotrigger = true })
    end
  end,
})

-- Save pipeline. Per-filetype LSP code actions run on BufWritePre, then
-- prettier (when the project ships one) reformats the buffer.
local js_kinds = { "source.fixAll.eslint", "source.organizeImports" }
local save_action_kinds = {
  python = { "source.fixAll.ruff", "source.organizeImports.ruff" },
  javascript = js_kinds,
  javascriptreact = js_kinds,
  typescript = js_kinds,
  typescriptreact = js_kinds,
}

local function whole_buffer_range(bufnr)
  local last = math.max(vim.api.nvim_buf_line_count(bufnr) - 1, 0)
  local text = vim.api.nvim_buf_get_lines(bufnr, last, last + 1, false)[1] or ""
  return { start = { line = 0, character = 0 }, ["end"] = { line = last, character = #text } }
end

local function run_save_actions(bufnr)
  local kinds = save_action_kinds[vim.bo[bufnr].filetype]
  if not kinds then
    return
  end
  for _, kind in ipairs(kinds) do
    local params = {
      textDocument = { uri = vim.uri_from_bufnr(bufnr) },
      range = whole_buffer_range(bufnr),
      context = { only = { kind }, diagnostics = {}, triggerKind = 2 },
    }
    local responses = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, 3000) or {}
    for client_id, response in pairs(responses) do
      local client = vim.lsp.get_client_by_id(client_id)
      for _, action in ipairs(response.result or {}) do
        if action.edit then
          pcall(vim.lsp.util.apply_workspace_edit, action.edit, client and client.offset_encoding or "utf-16")
        end
        if action.command and client then
          local cmd = type(action.command) == "table" and action.command or action
          pcall(function()
            client:exec_cmd(cmd, { bufnr = bufnr })
          end)
        end
      end
    end
  end
end

-- Prettier has no language server, so this is the zero-plugin path: shell out
-- to the PROJECT-LOCAL binary. Global/bare names are deliberately not tried -
-- an unresolvable bare name hangs the whole editor. No binary = silent no-op,
-- which is the common case.
local function prettier_binary(bufnr)
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == "" then
    return nil
  end
  local suffix = vim.fn.has("win32") == 1 and ".cmd" or ""
  for dir in vim.fs.parents(vim.fn.fnamemodify(file, ":p")) do
    local candidate = dir .. "/node_modules/.bin/prettier" .. suffix
    if (vim.uv or vim.loop).fs_stat(candidate) then
      return candidate
    end
  end
  return nil
end

local function run_prettier(bufnr)
  if not save_action_kinds[vim.bo[bufnr].filetype] or vim.bo[bufnr].filetype == "python" then
    return
  end
  local bin = prettier_binary(bufnr)
  if not bin then
    return
  end
  local input = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n") .. "\n"
  -- Hard timeout: a hung formatter must never hold the editor hostage.
  local ok, result = pcall(function()
    return vim
      .system({ bin, "--stdin-filepath", vim.api.nvim_buf_get_name(bufnr) }, { stdin = input, text = true })
      :wait(10000)
  end)
  if not ok or type(result) ~= "table" or result.code ~= 0 then
    return
  end
  local out = result.stdout
  if type(out) ~= "string" or out == "" or out == input then
    return
  end
  local lines = vim.split(out:gsub("\r\n", "\n"):gsub("\n$", ""), "\n", { plain = true })
  local view = vim.fn.winsaveview()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.fn.winrestview(view)
end

vim.api.nvim_create_autocmd("BufWritePre", {
  group = lsp_group,
  desc = "On save: LSP fixAll + organize imports, then project-local prettier",
  callback = function(args)
    run_save_actions(args.buf)
    run_prettier(args.buf)
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
  "  Code (LSP)",
  "   gd           go to definition",
  "   gR           list references",
  "   K            hover docs",
  "   grn          rename symbol",
  "   gra          code action",
  "   ]d  [d       next / previous diagnostic",
  "   Ctrl+w d     diagnostic in a float",
  "",
  "  Git",
  "   <Space>gb    branches (Enter checks out)",
  "   <Space>gl    git log",
  "   <Space>gs    changed files (status)",
  "   <Space>gp    preview hunk diff",
  "   <Space>gd    full diff view",
  "   <Space>gq    close diff view",
  "",
  "  Windows",
  "   <Space>sv    split vertically",
  "   <Space>sh    split horizontally",
  "   <Space>sx    close split",
  "",
  "  Tabs",
  "   <Space>to    open new tab",
  "   <Space>tn    next tab",
  "   <Space>tp    previous tab",
  "   <Space>tx    close tab",
  "",
  "  Misc",
  "   Ctrl+hjkl    navigate splits/panes (nvim <-> tmux)",
  "   Esc          also clears search highlight",
  "   <Space>mp    toggle markdown preview (current buffer)",
  "   <Space>h     this cheatsheet (q or Esc closes)",
  "   :Lazy update update plugins (never automatic)",
}
-- Native window splits (no plugin). splitright/splitbelow set above.
vim.keymap.set("n", "<leader>sv", vim.cmd.vsplit, { desc = "Split window vertically" })
vim.keymap.set("n", "<leader>sh", vim.cmd.split, { desc = "Split window horizontally" })
vim.keymap.set("n", "<leader>sx", vim.cmd.close, { desc = "Close split" })

-- Native tab pages (pure vim commands, cross-platform).
vim.keymap.set("n", "<leader>to", vim.cmd.tabnew, { desc = "Open new tab" })
vim.keymap.set("n", "<leader>tn", vim.cmd.tabnext, { desc = "Next tab" })
vim.keymap.set("n", "<leader>tp", vim.cmd.tabprevious, { desc = "Previous tab" })
vim.keymap.set("n", "<leader>tx", vim.cmd.tabclose, { desc = "Close tab" })

-- Esc in normal mode also clears the current search highlight, then falls
-- through to its normal behavior.
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR><Esc>", { desc = "Clear search highlight" })

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
