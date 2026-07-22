-- Behavior test for the built-in LSP setup (nvim 0.12 core client).
-- Loads the real nvim/init.lua headlessly, then drives the real objects it
-- created: the diagnostic config, the gd/gR mappings, the LspAttach handler
-- (fed fake clients), the server files behind vim.lsp.enable, and the
-- cheatsheet window. Nothing here greps source text.
--
-- Run: nvim -l tests/lsp_spec.lua   (wired as `npm test`)

local function fail(msg)
  io.stderr:write("FAIL: " .. msg .. "\n")
  os.exit(1)
end

-- Isolate lazy.nvim: pretend it is installed and make require("lazy") a no-op,
-- so the config loads offline with no plugin side effects.
local uv = vim.uv or vim.loop
local orig_fs_stat = uv.fs_stat
uv.fs_stat = function(path, ...)
  if type(path) == "string" and path:match("lazy%.nvim$") then
    return { type = "directory" }
  end
  return orig_fs_stat(path, ...)
end
package.preload["lazy"] = function()
  return { setup = function() end }
end

local this = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(this, ":p:h:h")

-- The repo's own lua/ modules (brot.bin) come from the repo, not the installed
-- config, so the specs test what is committed here.
package.path = root .. "/nvim/lua/?.lua;" .. root .. "/nvim/lua/?/init.lua;" .. package.path

-- Record which server names the config turns on, then let the real call run.
local enabled = {}
local orig_enable = vim.lsp.enable
vim.lsp.enable = function(names, ...)
  for _, n in ipairs(type(names) == "table" and names or { names }) do
    table.insert(enabled, n)
  end
  return orig_enable(names, ...)
end

dofile(root .. "/nvim/init.lua")

--------------------------------------------------------------------------
-- Diagnostics render as an ambient hint plus an expanded current-line block.
--------------------------------------------------------------------------
local diag = vim.diagnostic.config()
if type(diag.virtual_lines) ~= "table" or diag.virtual_lines.current_line ~= true then
  fail("diagnostics: virtual_lines.current_line is not true")
end
if type(diag.virtual_text) ~= "table" then
  fail("diagnostics: virtual_text is not a table (ambient hints are off)")
end
if diag.severity_sort ~= true or diag.underline ~= true then
  fail("diagnostics: severity_sort/underline are not both on")
end

--------------------------------------------------------------------------
-- gd and gR are real callbacks with real descriptions.
--------------------------------------------------------------------------
local function mapping(lhs)
  local m = vim.fn.maparg(lhs, "n", false, true)
  if type(m) ~= "table" or vim.tbl_isempty(m) then
    return nil
  end
  return m
end

for _, lhs in ipairs({ "gd", "gR" }) do
  local m = mapping(lhs)
  if not m then
    fail("no normal-mode mapping for '" .. lhs .. "'")
  end
  if type(m.callback) ~= "function" then
    fail("mapping '" .. lhs .. "' has no callback")
  end
  if type(m.desc) ~= "string" or m.desc == "" then
    fail("mapping '" .. lhs .. "' has an empty desc")
  end
end

-- The nvim 0.12 defaults this config must not have clobbered.
for _, lhs in ipairs({ "grn", "gra", "grr", "gri", "grt", "gO", "]d", "[d" }) do
  if not mapping(lhs) then
    fail("default LSP mapping '" .. lhs .. "' was clobbered")
  end
end

--------------------------------------------------------------------------
-- Every enabled server name has a config file that returns a usable spec.
--------------------------------------------------------------------------
if #enabled == 0 then
  fail("no servers passed to vim.lsp.enable")
end

local win32 = vim.fn.has("win32") == 1
local function npm_bin(n)
  return win32 and (n .. ".cmd") or n
end

-- uv-installed servers keep bare names (real .exe files); npm-installed ones
-- must name the .cmd shim on Windows or libuv hands CreateProcess npm's bare
-- sh script and the spawn dies with ENOENT.
local expected_cmd = {
  basedpyright = "basedpyright-langserver",
  ruff = "ruff",
  ts7 = npm_bin("tsc"),
  eslint = npm_bin("vscode-eslint-language-server"),
}
local uv_installed = { basedpyright = true, ruff = true }
local js_filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" }
local expected_filetypes = {
  basedpyright = { "python" },
  ruff = { "python" },
  ts7 = js_filetypes,
  eslint = js_filetypes,
}

for _, name in ipairs(enabled) do
  local path = root .. "/nvim/lsp/" .. name .. ".lua"
  if vim.fn.filereadable(path) ~= 1 then
    fail("vim.lsp.enable('" .. name .. "') has no nvim/lsp/" .. name .. ".lua")
  end
  local spec = dofile(path)
  if type(spec) ~= "table" then
    fail("nvim/lsp/" .. name .. ".lua did not return a table")
  end
  if type(spec.cmd) ~= "table" or type(spec.cmd[1]) ~= "string" then
    fail("nvim/lsp/" .. name .. ".lua has no cmd[1] string")
  end
  if expected_cmd[name] and spec.cmd[1] ~= expected_cmd[name] then
    fail(name .. ": cmd[1] is '" .. spec.cmd[1] .. "', expected '" .. expected_cmd[name] .. "'")
  end
  -- uv-installed servers are real executables: bare names on every platform.
  if uv_installed[name] and (spec.cmd[1]:match("%.exe$") or spec.cmd[1]:match("%.cmd$")) then
    fail(name .. ": uv-installed server hardcodes a Windows suffix, breaking POSIX hosts")
  end
  if expected_filetypes[name] and not vim.deep_equal(spec.filetypes, expected_filetypes[name]) then
    fail(name .. ": filetypes is " .. vim.inspect(spec.filetypes) .. ", expected " .. vim.inspect(expected_filetypes[name]))
  end
  if type(spec.root_markers) ~= "table" or #spec.root_markers == 0 then
    fail(name .. ": root_markers is empty")
  end
end

--------------------------------------------------------------------------
-- The npm binary helper is the single place the Windows shim gotcha lives.
--------------------------------------------------------------------------
local brot_bin = require("brot.bin")
if brot_bin.npm("tsc") ~= (win32 and "tsc.cmd" or "tsc") then
  fail("brot.bin.npm returned '" .. brot_bin.npm("tsc") .. "' on this platform")
end
for _, name in ipairs({ "basedpyright", "ruff" }) do
  local spec = dofile(root .. "/nvim/lsp/" .. name .. ".lua")
  if spec.cmd[1] ~= expected_cmd[name] then
    fail(name .. ": uv-installed server must keep its bare name, got '" .. spec.cmd[1] .. "'")
  end
end

--------------------------------------------------------------------------
-- ts7: TS7's compiler IS the language server, and roots at the lockfile tier.
--------------------------------------------------------------------------
local ts7 = dofile(root .. "/nvim/lsp/ts7.lua")
if not vim.deep_equal({ ts7.cmd[2], ts7.cmd[3] }, { "--lsp", "--stdio" }) then
  fail("ts7: cmd does not end in --lsp --stdio, got " .. vim.inspect(ts7.cmd))
end
local tier = ts7.root_markers[1]
if type(tier) ~= "table" then
  fail("ts7: root_markers[1] is not a priority tier table")
end
for _, lockfile in ipairs({ "package-lock.json", "bun.lock" }) do
  if not vim.tbl_contains(tier, lockfile) then
    fail("ts7: top root-marker tier is missing " .. lockfile)
  end
end
for _, lockfile in ipairs(tier) do
  if lockfile:match("^tsconfig") or lockfile:match("^jsconfig") then
    fail("ts7: tsconfig sits in the top tier; a monorepo would root per-app")
  end
end

--------------------------------------------------------------------------
-- eslint: before_init fills in the workspaceFolder the server demands.
--------------------------------------------------------------------------
local eslint = dofile(root .. "/nvim/lsp/eslint.lua")
if type(eslint.before_init) ~= "function" then
  fail("eslint: no before_init hook; the server throws on its first diagnostic request")
end
if eslint.settings.format ~= false then
  fail("eslint: formatting is not disabled; it would fight prettier")
end
local eslint_config = { root_dir = "/home/user/code/web-app" }
eslint.before_init({}, eslint_config)
if eslint_config.settings.workspaceFolder.uri ~= "/home/user/code/web-app" then
  fail("eslint: before_init did not set settings.workspaceFolder.uri to root_dir")
end
if eslint_config.settings.workspaceFolder.name ~= "web-app" then
  fail("eslint: workspaceFolder.name is '" .. tostring(eslint_config.settings.workspaceFolder.name) .. "', expected the root basename")
end

--------------------------------------------------------------------------
-- LspAttach: ruff stops advertising hover so basedpyright alone answers K;
-- a server that advertises completion gets built-in completion switched on.
--------------------------------------------------------------------------
local attach = nil
for _, au in ipairs(vim.api.nvim_get_autocmds({ event = "LspAttach" })) do
  if type(au.callback) == "function" then
    attach = au.callback
  end
end
if not attach then
  fail("no LspAttach autocmd with a callback")
end

local completion_enabled_for = {}
vim.lsp.completion.enable = function(enable, client_id, bufnr, opts)
  completion_enabled_for[client_id] = enable and opts and opts.autotrigger
end

local clients = {}
local function fake_client(id, name, caps)
  local c = {
    id = id,
    name = name,
    server_capabilities = { hoverProvider = true },
    supports_method = function(_, method)
      return caps[method] == true
    end,
  }
  clients[id] = c
  return c
end

vim.lsp.get_client_by_id = function(id)
  return clients[id]
end

local ruff = fake_client(1, "ruff", { ["textDocument/completion"] = false })
local pyright = fake_client(2, "basedpyright", { ["textDocument/completion"] = true })

local buf = vim.api.nvim_create_buf(false, true)
attach({ buf = buf, data = { client_id = ruff.id } })
attach({ buf = buf, data = { client_id = pyright.id } })

if ruff.server_capabilities.hoverProvider ~= false then
  fail("LspAttach left ruff advertising hover; K would be ambiguous")
end
if pyright.server_capabilities.hoverProvider ~= true then
  fail("LspAttach stripped hover from basedpyright; K would show nothing")
end
if completion_enabled_for[pyright.id] ~= true then
  fail("LspAttach did not enable autotrigger completion for a completion-capable server")
end
if completion_enabled_for[ruff.id] ~= nil then
  fail("LspAttach enabled completion for a server that does not advertise it")
end

--------------------------------------------------------------------------
-- completeopt keeps the popup from auto-filling: noinsert stops the first
-- match being inserted, noselect stops it being pre-highlighted, so typing
-- through a trigger char inserts nothing until the user picks.
--------------------------------------------------------------------------
local completeopt = vim.opt.completeopt:get()
for _, want in ipairs({ "noinsert", "noselect" }) do
  if not vim.tbl_contains(completeopt, want) then
    fail("completeopt is missing '" .. want .. "'; the completion popup would auto-fill the first match")
  end
end

--------------------------------------------------------------------------
-- Inlay hints: the user dislikes the type ghosts, so LspAttach leaves nvim's
-- default (hints off) alone even when a server advertises them.
--------------------------------------------------------------------------
local hinting = fake_client(3, "ts7", { ["textDocument/inlayHint"] = true })
local hint_buf = vim.api.nvim_create_buf(false, true)
attach({ buf = hint_buf, data = { client_id = hinting.id } })
if vim.lsp.inlay_hint.is_enabled({ bufnr = hint_buf }) ~= false then
  fail("LspAttach enabled inlay hints for a server that advertises them; they should stay off")
end

-- An attach event for an already-gone client must not error.
local ok = pcall(attach, { buf = buf, data = { client_id = 99 } })
if not ok then
  fail("LspAttach errored on an unknown client id")
end

--------------------------------------------------------------------------
-- The <leader>h cheatsheet advertises no key that has no mapping.
--------------------------------------------------------------------------
-- Load the plugin specs the way lazy would (config functions run, `keys`
-- entries become mappings) against permissive stub modules, so plugin-owned
-- cheatsheet keys are live here too.
local orig_require = require
_G.require = function(name)
  local loaded, mod = pcall(orig_require, name)
  if loaded then
    return mod
  end
  local stub
  stub = setmetatable({}, {
    __index = function()
      return function()
        return stub
      end
    end,
    __call = function()
      return stub
    end,
  })
  return stub
end

for _, file in ipairs(vim.fn.glob(root .. "/nvim/lua/plugins/*.lua", false, true)) do
  local spec = dofile(file)
  if type(spec.config) == "function" then
    pcall(spec.config, spec, spec.opts or {})
  end
  for _, k in ipairs(spec.keys or {}) do
    local lhs, rhs = k[1], k[2]
    if lhs and rhs then
      vim.keymap.set(k.mode or "n", lhs, rhs, { desc = k.desc })
    end
  end
end
_G.require = orig_require

local cheat_buf
mapping(" h").callback()
cheat_buf = vim.api.nvim_get_current_buf()
local lines = vim.api.nvim_buf_get_lines(cheat_buf, 0, -1, false)
if #lines == 0 then
  fail("<leader>h opened an empty cheatsheet")
end

-- Turn a cheatsheet key column into the lhs values maparg understands.
local function lhs_forms(token)
  if token == "Ctrl+hjkl" then
    return { "<C-h>", "<C-j>", "<C-k>", "<C-l>" }
  end
  if token == "Esc" then
    return { "<Esc>" }
  end
  local ctrl = token:match("^Ctrl%+(%a)$")
  if ctrl then
    return { "<C-" .. ctrl .. ">" }
  end
  local space = token:match("^<Space>(%S+)$")
  if space then
    return { " " .. space }
  end
  return { token }
end

-- K is mapped buffer-locally by the core client on attach, so it is not live
-- in a headless run with no server; its target is asserted instead.
local attach_provided = { K = true }
if type(vim.lsp.buf.hover) ~= "function" then
  fail("cheatsheet advertises K but vim.lsp.buf.hover is missing")
end

local checked = 0
for _, line in ipairs(lines) do
  -- Key column: the run of non-space text (plus "Ctrl+w d") before 2+ spaces.
  local keys, rest = line:match("^%s%s%s(%S.-)%s%s+(%S.*)$")
  if keys and rest and not keys:match("^:") then
    keys = keys:gsub("Ctrl%+w%s+d", "<C-w>d")
    for token in keys:gmatch("%S+") do
      if not attach_provided[token] then
        local found = false
        for _, lhs in ipairs(lhs_forms(token)) do
          if mapping(lhs) then
            found = true
          end
        end
        if not found then
          fail("cheatsheet advertises '" .. token .. "' but nothing maps it")
        end
        checked = checked + 1
      end
    end
  end
end
if checked < 20 then
  fail("cheatsheet parser only checked " .. checked .. " keys; it is not reading the sheet")
end

io.stdout:write("PASS: built-in LSP (diagnostics, gd/gR, attach handler, server files, cheatsheet)\n")
os.exit(0)
