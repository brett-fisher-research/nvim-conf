-- Behavior test for the <leader>t* tab keymaps.
-- Loads the real nvim/init.lua in a headless nvim (via `nvim -l`), then invokes
-- each mapping's callback and asserts the actual tab-page effect. It exercises
-- the mapped commands, not the source text.
--
-- Run: nvim -l tests/keymaps_spec.lua   (wired as `npm test`)

local function fail(msg)
  io.stderr:write("FAIL: " .. msg .. "\n")
  os.exit(1)
end

-- Isolate init.lua's lazy.nvim bootstrap: pretend lazy is installed (so the
-- clone is skipped on every platform) and make require("lazy") a no-op. This
-- keeps the test offline and free of plugin side effects while still loading
-- the real keymap definitions.
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

-- Locate and load the real config (tests/ -> repo root -> nvim/init.lua).
local this = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(this, ":p:h:h")
dofile(root .. "/nvim/init.lua")

-- mapleader is a space, so the stored lhs for "<leader>to" is " to", etc.
local function mapping(lhs)
  local m = vim.fn.maparg(lhs, "n", false, true)
  if type(m) ~= "table" or vim.tbl_isempty(m) then
    fail("no normal-mode mapping for '" .. lhs .. "'")
  end
  if type(m.callback) ~= "function" then
    fail("mapping '" .. lhs .. "' has no callback")
  end
  if type(m.desc) ~= "string" or m.desc == "" then
    fail("mapping '" .. lhs .. "' has an empty desc")
  end
  return m.callback
end

-- <leader>to opens a new tab.
local before = vim.fn.tabpagenr("$")
mapping(" to")()
if vim.fn.tabpagenr("$") ~= before + 1 then
  fail("<leader>to did not open a new tab")
end

-- Set up 3 tabs so next/prev are observable.
vim.cmd("tabnew")
while vim.fn.tabpagenr("$") < 3 do vim.cmd("tabnew") end
vim.cmd("tabfirst")

-- <leader>tn moves to the next tab.
local cur = vim.fn.tabpagenr()
mapping(" tn")()
if vim.fn.tabpagenr() ~= cur + 1 then
  fail("<leader>tn did not move to the next tab")
end

-- <leader>tp moves back to the previous tab.
mapping(" tp")()
if vim.fn.tabpagenr() ~= cur then
  fail("<leader>tp did not move to the previous tab")
end

-- <leader>tx closes the current tab.
local n = vim.fn.tabpagenr("$")
mapping(" tx")()
if vim.fn.tabpagenr("$") ~= n - 1 then
  fail("<leader>tx did not close the tab")
end

-- <Esc> in normal mode clears the search highlight. The rhs is a string
-- (`<cmd>nohlsearch<CR><Esc>`), not a callback: assert the mapping exists and
-- that feeding Esc through it turns v:hlsearch off.
local esc = vim.fn.maparg("<Esc>", "n", false, true)
if type(esc) ~= "table" or vim.tbl_isempty(esc) then
  fail("no normal-mode mapping for '<Esc>'")
end
if type(esc.rhs) ~= "string" or not esc.rhs:lower():match("nohlsearch") then
  fail("'<Esc>' mapping rhs does not invoke nohlsearch")
end
vim.opt.hlsearch = true
vim.fn.setreg("/", "needle")
vim.cmd("let v:hlsearch = 1")
if vim.v.hlsearch ~= 1 then
  fail("could not arm v:hlsearch for the <Esc> test")
end
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "mx", false)
if vim.v.hlsearch ~= 0 then
  fail("<Esc> did not clear the search highlight (v:hlsearch still 1)")
end

io.stdout:write("PASS: tab keymaps (to/tn/tp/tx) drive tab pages; <Esc> clears search highlight\n")
os.exit(0)
