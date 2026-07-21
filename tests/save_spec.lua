-- Behavior test for the on-save pipeline in nvim/init.lua: per-filetype LSP
-- code actions, then the project-local prettier shell-out.
--
-- Loads the real init.lua headlessly and invokes the real BufWritePre callback
-- it registered. Nothing here greps source text.
--
-- Run: nvim -l tests/save_spec.lua   (wired as `npm test`)

local function fail(msg)
  io.stderr:write("FAIL: " .. msg .. "\n")
  os.exit(1)
end

local uv = vim.uv or vim.loop
local win32 = vim.fn.has("win32") == 1

-- Isolate lazy.nvim exactly as the other specs do: no network, no plugins.
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
package.path = root .. "/nvim/lua/?.lua;" .. root .. "/nvim/lua/?/init.lua;" .. package.path

dofile(root .. "/nvim/init.lua")

local on_save = nil
for _, au in ipairs(vim.api.nvim_get_autocmds({ event = "BufWritePre" })) do
  if type(au.callback) == "function" then
    on_save = au.callback
  end
end
if not on_save then
  fail("no BufWritePre autocmd with a callback")
end

--------------------------------------------------------------------------
-- Each language's save actions are the ones that language's servers answer.
--------------------------------------------------------------------------
local requested = {}
vim.lsp.buf_request_sync = function(bufnr, method, params)
  if method == "textDocument/codeAction" then
    for _, kind in ipairs(params.context.only) do
      table.insert(requested, kind)
    end
  end
  return {}
end

local function write_buffer(filetype, name)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "const a = 1", "const b = 2" })
  vim.bo[buf].filetype = filetype
  if name then
    vim.api.nvim_buf_set_name(buf, name)
  end
  vim.api.nvim_win_set_buf(0, buf)
  requested = {}
  on_save({ buf = buf })
  return buf
end

for _, filetype in ipairs({ "typescript", "typescriptreact", "javascript", "javascriptreact" }) do
  write_buffer(filetype)
  if not vim.deep_equal(requested, { "source.fixAll.eslint", "source.organizeImports" }) then
    fail(filetype .. " save requested " .. vim.inspect(requested) .. ", expected the eslint fixAll then organizeImports")
  end
end

write_buffer("python")
if not vim.deep_equal(requested, { "source.fixAll.ruff", "source.organizeImports.ruff" }) then
  fail("python save requested " .. vim.inspect(requested) .. ", expected the ruff kinds")
end

write_buffer("lua")
if #requested ~= 0 then
  fail("a lua buffer save issued code actions: " .. vim.inspect(requested))
end

--------------------------------------------------------------------------
-- Prettier: no project binary = untouched buffer, no error.
--------------------------------------------------------------------------
local tmp = vim.fn.tempname()
local bare = tmp .. "/bare"
vim.fn.mkdir(bare, "p")

local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "const   x=1" })
vim.bo[buf].filetype = "typescript"
vim.api.nvim_buf_set_name(buf, bare .. "/index.ts")
vim.api.nvim_win_set_buf(0, buf)

local ok, err = pcall(on_save, { buf = buf })
if not ok then
  fail("saving with no prettier installed raised: " .. tostring(err))
end
if not vim.deep_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { "const   x=1" }) then
  fail("a buffer with no project prettier was rewritten anyway")
end

--------------------------------------------------------------------------
-- Prettier: a project-local binary rewrites the buffer, cursor view intact.
--------------------------------------------------------------------------
local proj = tmp .. "/proj"
local bindir = proj .. "/node_modules/.bin"
vim.fn.mkdir(bindir, "p")

-- Stub formatter: reads stdin, prepends a marker, echoes the rest back.
vim.fn.writefile({
  "let input = '';",
  "process.stdin.setEncoding('utf8');",
  "process.stdin.on('data', (c) => { input += c; });",
  "process.stdin.on('end', () => { process.stdout.write('// formatted\\n' + input); });",
}, bindir .. "/prettier.js")

if win32 then
  vim.fn.writefile({ "@echo off", 'node "%~dp0prettier.js"' }, bindir .. "/prettier.cmd")
else
  vim.fn.writefile({ "#!/bin/sh", 'exec node "$(dirname "$0")/prettier.js"' }, bindir .. "/prettier")
  vim.fn.setfperm(bindir .. "/prettier", "rwxr-xr-x")
end

local pbuf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(pbuf, 0, -1, false, { "const a = 1", "const b = 2", "const c = 3" })
vim.bo[pbuf].filetype = "typescript"
vim.api.nvim_buf_set_name(pbuf, proj .. "/src/index.ts")
vim.api.nvim_win_set_buf(0, pbuf)
vim.api.nvim_win_set_cursor(0, { 3, 0 })
local before_view = vim.fn.winsaveview()

on_save({ buf = pbuf })

local after = vim.api.nvim_buf_get_lines(pbuf, 0, -1, false)
if not vim.deep_equal(after, { "// formatted", "const a = 1", "const b = 2", "const c = 3" }) then
  fail("project prettier did not rewrite the buffer; got " .. vim.inspect(after))
end
local after_view = vim.fn.winsaveview()
if after_view.topline ~= before_view.topline or after_view.leftcol ~= before_view.leftcol then
  fail("the prettier rewrite scrolled the window away from the user's view")
end

io.stdout:write("PASS: save pipeline (per-filetype code actions, project-local prettier)\n")
os.exit(0)
